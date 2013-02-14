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
    @page_has_content = false
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
      if @page_has_content && @in_body
        add_doc_to_solr
      else
        init_doc_hash
      end
      process_pb_attribs attributes
    when 'p'
      @in_p = true
      @page_has_content = true
    when 'sp'
      @in_sp = true
      if @need_session_date
        @logger.warn("Didn't find <date> tag before <sp> for session in page #{doc_hash[:id]}")
        @need_session_date = false
      end
    when 'speaker'
      @in_speaker = true
    end
  end
  
  # @param [String] name the element tag
  def end_element name    
    case name
    when 'body'
      if @page_has_content
        add_doc_to_solr
      end
      @in_body = false
    when 'back'
      @in_back = false
    when 'div2'
      @in_div2 = false
      @@div2_doc_type = nil
      @in_session = false
    when 'head'
      text = @text_buffer.strip if @text_buffer && @text_buffer != NO_BUFFER
      add_session_govt_ssi(text) if  @in_session && @need_session_govt
    when 'p'
      text = @text_buffer.strip if @text_buffer && @text_buffer != NO_BUFFER
      add_session_govt_ssi(text) if @in_session && @need_session_govt && text && text == text.upcase
      if @in_sp && @speaker
        add_value_to_doc_hash(:spoken_text_timv, "#{@speaker} #{text}") if text
      end
      @text_buffer = NO_BUFFER
      @in_p = false
    when 'sp'
      @speaker = nil
      if @text_buffer != NO_BUFFER
        @logger.warn("Found <sp> tag with direct text content: '#{@text_buffer.strip}' in page #{@doc_hash[:id]}") if !@text_buffer.strip!.empty?
        @text_buffer = NO_BUFFER
      end
      @in_sp = false
    when 'speaker'
      @speaker = @text_buffer.strip if @text_buffer && @text_buffer != NO_BUFFER
      @speaker = nil if @speaker.empty?
      add_value_to_doc_hash(:speaker_ssim, @speaker) if @speaker
      @text_buffer = NO_BUFFER
      @in_speaker = false
    end
    @element_just_ended = true
  end
  
  # Characters within element tags.  This method might be called multiple
  # times given one contiguous string of characters.
  #
  # @param [String] data contains the character data
  def characters(data)
    chars = data.gsub(/\s+/, ' ')
    @text_buffer = add_chars_to_buffer(chars, @text_buffer)
    @element_just_ended = false
  end
  alias cdata_block characters
  
  # --------- Not part of the Nokogiri::XML::SAX::Document events -----------------
    
  COLL_VAL = "ap-collection"
  PAGE_TYPE = "page"
  NO_BUFFER = :no_buffer
  DIV2_TYPE = {'session' => 'séance',
                'contents' => 'table des matières',
                'other' => 'errata, rapport, cahier, etc.',
                'table_alpha' => 'liste',
                'alpha' => 'liste',
                'introduction' => 'introduction'}

  # @param [String] chars the characters to be concatenated to the buffer
  # @param [String] the text buffer
  def add_chars_to_buffer(chars, buffer)
    if buffer == NO_BUFFER
      buffer = chars.dup
    else
      buffer << (@element_just_ended ? ' ' : '') + chars.dup
    end
    buffer.gsub!(/\s+/, ' ') if buffer && buffer != NO_BUFFER    
  end
  
  # add :session_govt_ssi field to doc_hash, and reset appropriate vars
  def add_session_govt_ssi value
    value.strip if value && value != NO_BUFFER
    add_value_to_doc_hash(:session_govt_ssi, value.sub(/[[:punct:]]$/, '')) if value
    @text_buffer = NO_BUFFER
    @need_session_govt = false
  end
  
  # add :id, :page_num_ss, :image_id_ss and ocr_id_ss to doc_hash, based on attributes
  # @param [Array<String>] attributes an assoc list of namespaces and attributes, e.g.:
  #     [ ["xmlns:foo", "http://sample.net"], ["size", "large"] ]
  def process_pb_attribs attributes
    new_page_id = get_attribute_val('id', attributes)
    add_value_to_doc_hash(:id, new_page_id)
    page_num = get_attribute_val('n', attributes)
    add_value_to_doc_hash(:page_num_ss,  page_num) if page_num
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
    @text_buffer = NO_BUFFER
    @page_buffer = NO_BUFFER
  end
  
  # add the value to the doc_hash for the Solr field.
  # @param [Symbol] key the Solr field name 
  # @param [String] value the value to add to the doc_hash for the key
  def add_value_to_doc_hash(key, value)
    fname = key.to_s
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

  # write @doc_hash to Solr and reinitialize @doc_hash, but only if the current page has content
  def add_doc_to_solr
    if @page_has_content
      @rsolr_client.add(@doc_hash)
      init_doc_hash
      @page_has_content = false
    end
  end

end # ApTeiDocument class
