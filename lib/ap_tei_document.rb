# encoding: UTF-8
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
      if div2_type == 'session'
        @in_session = true
      end
      if @in_body
        @doc_hash[:doc_type_si] = DIV2_TYPE[div2_type]
      end
    when 'pb'
      if @page_has_content && @in_body
        add_doc_to_solr
      end
      new_page_id = attributes.select { |a| a[0] == 'id'}.first.last
      @doc_hash[:id] = new_page_id
      vol_page_array = attributes.select { |a| a[0] == 'n'}
      @doc_hash[:page_num_ss] = vol_page_array.first.last if vol_page_array && !vol_page_array.empty? && !vol_page_array.first.last.empty?
      @doc_hash[:image_id_ss] = new_page_id + ".jp2"
      @doc_hash[:ocr_id_ss] = new_page_id.sub(/_00_/, '_99_') + ".txt"
    when 'p'
      @in_p = true
      @page_has_content = true
    when 'sp'
      @in_sp = true
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
    when 'p'
      @text = @text_buffer.strip if @text_buffer && @text_buffer != NO_BUFFER
      if @in_sp && @speaker
        add_value_to_doc_hash(:spoken_text_ftsimv, "#{@speaker} #{@text}")
      else
        add_value_to_doc_hash(:text_ftsimv, @text)
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
  end
  
  # Characters within element tags.  This method might be called multiple
  # times given one contiguous string of characters.
  #
  # @param [String] data contains the character data
  def characters(data)
    chars = data.gsub(/\s+/, ' ')
    if @text_buffer == NO_BUFFER
      @text_buffer = chars.dup
    else
      @text_buffer << ' ' + chars.dup
    end
    @text_buffer.gsub!(/\s+/, ' ') if @text_buffer && @text_buffer != NO_BUFFER
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

  # initialize instance variable @doc_hash with mappings appropriate for all docs in the volume
  def init_doc_hash
    @doc_hash = {}
    @doc_hash[:collection_ssi] = COLL_VAL
    @doc_hash[:druid_ssi] = @druid
    @doc_hash[:vol_num_ssi] = @volume
    @doc_hash[:vol_title_ssi] = VOL_TITLES[@volume]
    # The format for a Solr date field is 1995-12-31T23:59:59Z
    @doc_hash[:vol_date_start_dti] = VOL_DATES[@volume].first
    @doc_hash[:vol_date_end_dti] = VOL_DATES[@volume].last
    @doc_hash[:type_ssi] = PAGE_TYPE
    @text_buffer = NO_BUFFER
  end
  
  # add the value to the doc_hash for the Solr field.
  # @param [String] key the Solr field name 
  # @param [String] value the value to add to the doc_hash for the key
  def add_value_to_doc_hash(key, value)
    fname = key.to_s
    val = value.strip.gsub(/\s+/, ' ')
    if @doc_hash[key]
      if fname.end_with?('m') || fname.end_with?('mv')
        @doc_hash[key] << val
      else
        logger.warn("Solr field #{key} is single-valued (first value: #{@doc_hash[key]}), but got an IGNORED additional value: #{val}")
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
