# encoding: UTF-8
require 'date'
require 'nokogiri'

require 'ap_vol_dates'
require 'ap_vol_titles'

require 'normalization_helper'

# Subclass of Nokogiri::XML::SAX::Document for streaming parsing
#  TEI xml corresponding to volumes of the Archives Parlementaires
class ApTeiDocument < Nokogiri::XML::SAX::Document
  
  include NormalizationHelper
  
  attr_reader :page_doc_hash

  # @param [RSolr::Client] rsolr_client used to write the Solr documents as we build them
  # @param [String] druid the druid for the DOR object that contains this TEI doc
  # @param [String] volume the volume number (it might not be a strict number string, e.g. '71B')
  # @param [Hash<Symbol, String>] vol_constants_hash Solr fields to be included in each Solr doc for this volume
  # @param [Hash<String, String>] page_id_hash key page id (e.g. "bg262qk2288_00_0003"), value Page sequence number (e.g. "3")
  # @param [Logger] logger to receive output
  def initialize (rsolr_client, druid, volume, vol_constants_hash, page_id_hash, logger)
    @rsolr_client = rsolr_client
    @druid = druid
    @volume = volume.sub(/^Volume /i, '')
    @logger = logger
    @vol_constants_hash = vol_constants_hash
    @page_id_hash = page_id_hash
  end
  
  def start_document
    @element_name_stack = []
    @in_body = false
    @in_back = false
    init_doc_hash
  end
    
  # @param [String] name the element tag
  # @param [Array<String>] attributes an assoc list of namespaces and attributes, e.g.:
  #     [ ["xmlns:foo", "http://sample.net"], ["size", "large"] ]
  def start_element name, attributes
    @element_name_stack.push(name)
    case name
    when 'body'
      @in_body = true
    when 'back'
      @in_back = true
    when 'div2'
      @in_div2 = true
      div2_type = attributes.select { |a| a[0] == 'type'}.first.last if !attributes.empty?
      @div2_doc_type = DIV2_TYPE[div2_type] if div2_type
      if div2_type == 'session'
        if @page_buffer.empty? || !@session_fields
          @session_fields = {}
        end
        @in_session = true
        @need_session_govt = true
        @need_session_date = true
        @need_session_title = true
        @need_session_first_page = true
        @session_title = ''
      else
        @session_fields = nil
      end
      if @in_body || @in_back
        add_value_to_page_doc_hash(:doc_type_ssim, @div2_doc_type)
      end
    when 'date'
      date_val_str = get_attribute_val('value', attributes)
      d = normalize_date(date_val_str)
      if @need_session_date && date_val_str
        add_field_value_to_hash(:session_date_val_ssim, date_val_str, @session_fields)
        add_field_value_to_hash(:session_date_dtsim, d.strftime('%Y-%m-%dT00:00:00Z'), @session_fields) if d
        @need_session_date = false
      end
    when 'pb'
      if !@page_buffer.empty? && (@in_body || @in_back)
        add_doc_to_solr
      end
      init_doc_hash
      process_pb_attribs attributes
    when 'sp'
      @in_sp = true
      if @need_session_date
        @logger.warn("Didn't find <date> tag before <sp> for session in page #{page_doc_hash[:id]}")
        @need_session_date = false
      end
    when 'speaker'
      @in_speaker = true
    end
    @element_just_started = true unless name == 'hi'  # we don't want to add spaces at beginning of <hi> elements
  end
  
  # @param [String] name the element tag
  def end_element name
    @element_name_stack.pop

    case name
    when 'body'
      if !@page_buffer.empty?
        add_doc_to_solr
        init_doc_hash
      end
      @in_body = false
    when 'back'
      add_doc_to_solr
      init_doc_hash
      @in_back = false
    when 'date'
      if @need_session_title 
        @session_title << @element_buffer
        @got_date = true
      end
    when 'div2'
      @in_div2 = false
      @div2_doc_type = nil
      @in_session = false
    when 'head'
      add_session_govt_ssim(@element_buffer.strip) if @in_session && @need_session_govt
    when 'p'
      text = @element_buffer.strip if !@element_buffer.strip.empty?
      add_session_govt_ssim(text) if @in_session && @need_session_govt && text && text == text.upcase
      if @in_sp && @speaker
        add_value_to_page_doc_hash(:spoken_text_timv, "#{@speaker}#{SEP}#{text}") if text
      end
      if @in_session && @need_session_title && @got_date
        @session_title << @element_buffer
        title = normalize_session_title(@session_title)
        add_field_value_to_hash(:session_title_ftsim, title, @session_fields) 
        add_field_value_to_hash(:session_date_title_ssim, "#{@session_fields[:session_date_val_ssim].last}#{SEP}#{title}", @session_fields) 
        @need_session_title = false
        @got_date = false
      end
    when 'sp'
      @speaker = nil
      @in_sp = false
    when 'speaker'
      @speaker = normalize_speaker(@element_buffer.strip) if !@element_buffer.strip.empty?
      add_value_to_page_doc_hash(:speaker_ssim, @speaker.strip) if @speaker && !(@page_doc_hash[:speaker_ssim] && @page_doc_hash[:speaker_ssim].include?(@speaker.strip))
      @in_speaker = false
    end # case name
    
    @element_just_ended = true
    @element_buffer = ''
  end
  
  # Characters within element tags.  This method might be called multiple
  # times given one contiguous string of characters.
  #
  # @param [String] data contains the character data
  def characters(data)
    chars = data.gsub(/\s+/, ' ')
    @element_buffer = add_chars_to_buffer(chars, @element_buffer)

    if NO_TEXT_ELEMENTS.include?(@element_name_stack.last) 
      if !@element_buffer.strip.empty?
        @logger.warn("Found <#{@element_name_stack.last}> tag with direct text content: '#{@element_buffer.strip}' in page #{@page_doc_hash[:id]}")
      end
    end
    @page_buffer = add_chars_to_buffer(chars, @page_buffer) if (@in_body || @in_back) && !IGNORE_ELEMENTS.include?(@element_name_stack.last)
    @element_just_started = false
    @element_just_ended = false
  end
  alias cdata_block characters
  
  # --------- Not part of the Nokogiri::XML::SAX::Document events -----------------
    
  COLL_VAL = "Archives parlementaires"
  PAGE_TYPE = "page"
  DIV2_TYPE = {'session' => 'séance',
                'contents' => 'table des matières',
                'other' => 'errata, rapport, cahier, etc.',
                'table_alpha' => 'liste',
                'alpha' => 'liste',
                'introduction' => 'introduction'}
  # elements that should not have direct text content - they wrap other elements
  NO_TEXT_ELEMENTS = ['text', 'front', 'body', 'back', 'div', 'div1', 'div2', 'div3', 'list', 'sp', 'pb']
  # ignore the contents of these elements
  IGNORE_ELEMENTS = ['trailer']
  SEP = '-|-'

  # @param [String] chars the characters to be concatenated to the buffer
  # @param [String] buffer the text buffer
  def add_chars_to_buffer(chars, buffer)
    unless chars.empty?
      if buffer
        buffer << (@element_just_started || @element_just_ended ? ' ' : '') + chars.dup
      else
        buffer = chars.dup
      end
      buffer.gsub(/\s+/, ' ')
    end
  end
  
  # add :session_govt_ssim field to doc_hash, and reset appropriate vars
  def add_session_govt_ssim value
    value.strip if value
    add_field_value_to_hash(:session_govt_ssim, value.sub(/[[:punct:]]$/, ''), @session_fields) if value
    @need_session_govt = false
  end
  
  # add :id, :page_num_ssi, :image_id_ss and ocr_id_ss to doc_hash, based on attributes
  # @param [Array<String>] attributes an assoc list of namespaces and attributes, e.g.:
  #     [ ["xmlns:foo", "http://sample.net"], ["size", "large"] ]
  def process_pb_attribs attributes
    new_page_id = get_attribute_val('id', attributes)
    add_value_to_page_doc_hash(:id, new_page_id)
    page_num = get_attribute_val('n', attributes)
    add_value_to_page_doc_hash(:page_num_ssi,  page_num) if page_num
    add_value_to_page_doc_hash(:page_sequence_isi, @page_id_hash[new_page_id]) if @page_id_hash[new_page_id]
    add_value_to_page_doc_hash(:image_id_ssm, new_page_id + ".jp2")
    add_value_to_page_doc_hash(:ocr_id_ss, new_page_id.sub(/_00_/, '_99_') + ".txt")
    if @in_session && @need_session_first_page && @page_id_hash[new_page_id]
      add_field_value_to_hash(:session_seq_first_isim, @page_id_hash[new_page_id], @session_fields)
      @need_session_first_page = false
    end
  end

  # @param [String] attr_name the name of the desired attribute
  # @param [Array<String>] attributes an assoc list of namespaces and attributes, e.g.:
  #     [ ["xmlns:foo", "http://sample.net"], ["size", "large"] ]
  # @return value of the desired attribute, or nil
  def get_attribute_val attr_name, attributes
    attr_array = attributes.select { |a| a[0] == attr_name}
    attr_val = attr_array.first.last if attr_array && !attr_array.empty? && !attr_array.first.last.empty?
  end
  
  # initialize instance variable @page_doc_hash with mappings appropriate for all docs in the volume
  #  and reset variables
  def init_doc_hash
    @page_doc_hash = {}
    @page_doc_hash[:collection_ssi] = COLL_VAL
    @page_doc_hash[:druid_ssi] = @druid
    @page_doc_hash[:vol_num_ssi] = @volume
    @page_doc_hash.merge!(@vol_constants_hash)
    @page_doc_hash[:vol_title_ssi] = VOL_TITLES[@volume]
    @page_doc_hash[:vol_date_start_dti] = VOL_DATES[@volume].first
    @page_doc_hash[:vol_date_end_dti] = VOL_DATES[@volume].last
    @page_doc_hash[:type_ssi] = PAGE_TYPE
    if (@in_body || @in_back) && @in_div2
      add_value_to_page_doc_hash(:doc_type_ssim, @div2_doc_type)
    end
    @element_buffer = ''
    @page_buffer = ''
    @session_title = ''
    if @in_session
      @session_fields.each { |k, v|  
        @session_fields[k] = [v.last] if v && v.size > 1
      }
    else
      @session_fields = {}
    end
  end
  
  # add the value to the doc_hash for the Solr field.
  # @param [Symbol] key the Solr field name 
  # @param [String] value the value to add to the doc_hash for the key
  def add_value_to_page_doc_hash(key, value)
    add_field_value_to_hash(key, value, @page_doc_hash)
  end
  
  # add the value to the hash for the Solr field.
  # @param [Symbol] key the Solr field name 
  # @param [String] value the value to add to the hash for the key
  # @param [Hash<Symbol, String>] hash the hash to receive the field value
  def add_field_value_to_hash(key, value, hash)
    fname = key.to_s
    unless value.is_a?(String) && value.strip.empty?
      if value.is_a?(String)
        val = value.strip.gsub(/\s+/, ' ')
      else
        val = value
      end
      if hash[key]
        if fname.end_with?('m') || fname.end_with?('mv')
          hash[key] << val if !hash[key].include?(val)
        else
          @logger.warn("Solr field #{key} is single-valued (first value: #{hash[key]}), but got an IGNORED additional value: #{val}")
        end
      else
        if fname.end_with?('m') || fname.end_with?('mv')
          hash[key] = [val] 
        else
          hash[key] = val
        end
      end
    end
  end

  # write @page_doc_hash to Solr and reinitialize @page_doc_hash, but only if the current page has content
  def add_doc_to_solr
    if !@page_buffer.strip.empty?
      add_value_to_page_doc_hash(:text_tiv, @page_buffer)
      @page_doc_hash.merge!(@session_fields) if @session_fields
      @rsolr_client.add(@page_doc_hash)
    end
  end
  
end # ApTeiDocument class
