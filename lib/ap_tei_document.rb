# encoding: UTF-8
require 'date'
require 'nokogiri'

require 'ap_vol_dates'
require 'ap_vol_titles'

# Subclass of Nokogiri::XML::SAX::Document for streaming parsing
#  TEI xml corresponding to volumes of the Archives Parlementaires
class ApTeiDocument < Nokogiri::XML::SAX::Document
  
  attr_reader :doc_hash

  # @param [RSolr::Client] rsolr_client used to write the Solr documents as we build them
  # @param [String] druid the druid for the DOR object that contains this TEI doc
  # @param [String] volume the volume number (it might not be a strict number string, e.g. '71B')
  # @param [Logger] logger to receive output
  def initialize (rsolr_client, druid, volume, logger)
    @rsolr_client = rsolr_client
    @druid = druid
    @volume = volume.sub(/^Volume /i, '')
    @logger = logger
  end
  
  def start_document
    @in_body = false
    @in_back = false
    init_doc_hash
  end
    
  # @param [String] name the element tag
  # @param [Array<String>] attributes an assoc list of namespaces and attributes, e.g.:
  #     [ ["xmlns:foo", "http://sample.net"], ["size", "large"] ]
  def start_element name, attributes
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
        @in_session = true
        @need_session_govt = true
        @need_session_date = true
      end
      if @in_body
        add_value_to_doc_hash(:doc_type_ssim, @div2_doc_type)
      end
    when 'date'
      date_val_str = get_attribute_val('value', attributes)
      d = normalize_date(date_val_str)
      if @need_session_date && date_val_str
        add_value_to_doc_hash(:session_date_val_ssi,  date_val_str) 
        add_value_to_doc_hash(:session_date_dtsi,  d.strftime('%Y-%m-%dT00:00:00Z')) if d
        @need_session_date = false
      end
    when 'pb'
      if !@page_buffer.empty? && @in_body
        add_doc_to_solr
      end
      init_doc_hash
      process_pb_attribs attributes
    when 'sp'
      @in_sp = true
      if @need_session_date
        @logger.warn("Didn't find <date> tag before <sp> for session in page #{doc_hash[:id]}")
        @need_session_date = false
      end
    when 'speaker'
      @in_speaker = true
    when 'trailer'
      @in_trailer = true
    end
    @element_just_started = true unless name == 'hi'  # we don't want to add spaces at beginning of <hi> elements
  end
  
  # @param [String] name the element tag
  def end_element name    
    case name
    when 'body'
      if !@page_buffer.empty?
        add_doc_to_solr
        init_doc_hash
      end
      @in_body = false
    when 'back'
#      if !@page_buffer.empty?
#        add_doc_to_solr
#        init_doc_hash
#      end
      @in_back = false
    when 'div2'
      @in_div2 = false
      @@div2_doc_type = nil
      @in_session = false
    when 'head'
      add_session_govt_ssi(@element_buffer.strip) if @in_session && @need_session_govt
      @element_buffer = ''
    when 'list'
      if !@element_buffer.strip.empty?
        @logger.warn("Found <list> tag with direct text content: '#{@element_buffer.strip}' in page #{@doc_hash[:id]}")
        @element_buffer = ''
      end
    when 'p'
      text = @element_buffer.strip if !@element_buffer.strip.empty?
      add_session_govt_ssi(text) if @in_session && @need_session_govt && text && text == text.upcase
      if @in_sp && @speaker
        add_value_to_doc_hash(:spoken_text_timv, "#{@speaker} #{text}") if text
      end
      @element_buffer = ''
    when 'pb'
      if !@element_buffer.strip.empty?
        @logger.warn("Found <pb> tag with direct text content: '#{@element_buffer.strip}' in page #{@doc_hash[:id]}")
        @element_buffer = ''
      end
    when 'sp'
      @speaker = nil
      if !@element_buffer.strip.empty?
        @logger.warn("Found <sp> tag with direct text content: '#{@element_buffer.strip}' in page #{@doc_hash[:id]}")
        @element_buffer = ''
      end
      @in_sp = false
    when 'speaker'
      @speaker = @element_buffer.strip if !@element_buffer.strip.empty?
      add_value_to_doc_hash(:speaker_ssim, @speaker) if @speaker
      @element_buffer = ''
      @in_speaker = false
    when 'trailer'
      @in_trailer = false
    end
    @element_just_ended = true
  end
  
  # Characters within element tags.  This method might be called multiple
  # times given one contiguous string of characters.
  #
  # @param [String] data contains the character data
  def characters(data)
    chars = data.gsub(/\s+/, ' ')
    @element_buffer = add_chars_to_buffer(chars, @element_buffer)
    @page_buffer = add_chars_to_buffer(chars, @page_buffer) if @in_body || @in_back && @in_trailer == false
    @element_just_started = false
    @element_just_ended = false
  end
  alias cdata_block characters
  
  # --------- Not part of the Nokogiri::XML::SAX::Document events -----------------
    
  COLL_VAL = "ap-collection"
  PAGE_TYPE = "page"
  DIV2_TYPE = {'session' => 'séance',
                'contents' => 'table des matières',
                'other' => 'errata, rapport, cahier, etc.',
                'table_alpha' => 'liste',
                'alpha' => 'liste',
                'introduction' => 'introduction'}
#  TEXT_TIV = ['head', 'p', 'sp', 'item', 'speaker', 'term', 'date', 'hi', 'note']

  # @param [String] chars the characters to be concatenated to the buffer
  # @param [String] the text buffer
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
  
  # add :session_govt_ssi field to doc_hash, and reset appropriate vars
  def add_session_govt_ssi value
    value.strip if value
    add_value_to_doc_hash(:session_govt_ssi, value.sub(/[[:punct:]]$/, '')) if value
    @need_session_govt = false
  end
  
  # add :id, :page_num_ssi, :image_id_ss and ocr_id_ss to doc_hash, based on attributes
  # @param [Array<String>] attributes an assoc list of namespaces and attributes, e.g.:
  #     [ ["xmlns:foo", "http://sample.net"], ["size", "large"] ]
  def process_pb_attribs attributes
    new_page_id = get_attribute_val('id', attributes)
    add_value_to_doc_hash(:id, new_page_id)
    page_num = get_attribute_val('n', attributes)
    add_value_to_doc_hash(:page_num_ssi,  page_num) if page_num
    add_value_to_doc_hash(:image_id_ss, new_page_id + ".jp2")
    add_value_to_doc_hash(:ocr_id_ss, new_page_id.sub(/_00_/, '_99_') + ".txt")
  end

  # @param [String] attr_name the name of the desired attribute
  # @param [Array<String>] attributes an assoc list of namespaces and attributes, e.g.:
  #     [ ["xmlns:foo", "http://sample.net"], ["size", "large"] ]
  # @return value of the desired attribute, or nil
  def get_attribute_val attr_name, attributes
    attr_array = attributes.select { |a| a[0] == attr_name}
    attr_val = attr_array.first.last if attr_array && !attr_array.empty? && !attr_array.first.last.empty?
  end
  
  # turns the String representation of the date to a Date object.  
  #  Logs a warning message if it can't parse the date string.
  # @param [String] date_str a String representation of a date
  # @return [Date] a Date object
  def normalize_date date_str
    begin
      norm_date = date_str.gsub(/ +\- +/, '-')
      norm_date.gsub!(/-00$/, '-01')
      norm_date.concat('-01-01') if norm_date.match(/^\d{4}$/)
      norm_date.concat('-01') if norm_date.match(/^\d{4}\-\d{2}$/)
      Date.parse(norm_date)
    rescue
      @logger.warn("Found <date> tag with unparseable date value: '#{date_str}' in page #{doc_hash[:id]}")
      nil
    end
  end

  # initialize instance variable @doc_hash with mappings appropriate for all docs in the volume
  def init_doc_hash
    @doc_hash = {}
    @doc_hash[:collection_ssi] = COLL_VAL
    @doc_hash[:druid_ssi] = @druid
    @doc_hash[:vol_num_ssi] = @volume
    @doc_hash[:vol_title_ssi] = VOL_TITLES[@volume]
    @doc_hash[:vol_date_start_dti] = VOL_DATES[@volume].first
    @doc_hash[:vol_date_end_dti] = VOL_DATES[@volume].last
    @doc_hash[:type_ssi] = PAGE_TYPE
    if @in_body && @in_div2
      add_value_to_doc_hash(:doc_type_ssim, @div2_doc_type)
    end
    @element_buffer = ''
    @page_buffer = ''
  end
  
  # add the value to the doc_hash for the Solr field.
  # @param [Symbol] key the Solr field name 
  # @param [String] value the value to add to the doc_hash for the key
  def add_value_to_doc_hash(key, value)
    fname = key.to_s
    unless value.strip.empty?
      val = value.strip.gsub(/\s+/, ' ')
      if @doc_hash[key]
        if fname.end_with?('m') || fname.end_with?('mv')
          @doc_hash[key] << val
        else
          @logger.warn("Solr field #{key} is single-valued (first value: #{@doc_hash[key]}), but got an IGNORED additional value: #{val}")
        end
      else
        if fname.end_with?('m') || fname.end_with?('mv')
          @doc_hash[key] = [val] 
        else
          @doc_hash[key] = val
        end
      end
    end
  end

  # write @doc_hash to Solr and reinitialize @doc_hash, but only if the current page has content
  def add_doc_to_solr
    if !@page_buffer.strip.empty?
      add_value_to_doc_hash(:text_tiv, @page_buffer)
      @rsolr_client.add(@doc_hash)
    end
  end

end # ApTeiDocument class
