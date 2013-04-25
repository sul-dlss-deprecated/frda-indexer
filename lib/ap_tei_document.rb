# encoding: UTF-8
require 'date'
require 'nokogiri'
require 'unicode_utils'

require 'ap_vol_dates'
require 'ap_vol_sort'
require 'ap_vol_titles'

require 'normalization_helper'

# Subclass of Nokogiri::XML::SAX::Document for streaming parsing
#  TEI xml corresponding to volumes of the Archives Parlementaires
class ApTeiDocument < Nokogiri::XML::SAX::Document
  
  include NormalizationHelper
  
  attr_reader :page_doc_hash, :div2_doc_hash # exposed for tests

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
    init_page_doc_hash
    @div2_counter = 0
    # much of the below is for reusing the @atd object in testing
    @page_id = nil
    @page_num_s = nil
    @page_num_i = nil
    @need_div2_title = false
    @div2_type = nil
    @need_session_govt = false
    @need_session_title = false
    @need_first_page = true
    @last_page_added = nil
    @last_div2_added = nil
    @div2_doc_hash = nil
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
      # write out last div2, if we didn't already
      if @div2_doc_hash && @div2_doc_hash[:id] && @div2_doc_hash[:id] != @last_div2_added
        add_div2_doc_to_solr
        @div2_buffer = ''
        @div2_doc_type = nil
      end
      @in_div2 = true
      @div2_counter = @div2_counter + 1
      @div2_type = attributes.select { |a| a[0] == 'type'}.first.last if !attributes.empty?
      @div2_doc_type = DIV2_TYPE[@div2_type] if @div2_type
      if @div2_type == 'session'
        if @page_buffer.empty? || !@page_session_fields
          @page_session_fields = {}
        end
        @in_session = true
        @need_session_govt = true
        @need_session_date = true
        @need_session_title = true
        @need_session_first_page = true
        @session_title = ''
        # have copyfield for session title -> div2_title field
      else
        @page_session_fields = nil
        @need_div2_title = true
      end
      add_value_to_page_doc_hash(:doc_type_ssim, @div2_doc_type)
      init_div2_doc_hash
    when 'date'
      date_val_str = get_attribute_val('value', attributes)
      d = normalize_date(date_val_str)
      if @need_session_date && date_val_str
        add_field_value_to_hash(:session_date_val_ssim, date_val_str, @page_session_fields)
        add_value_to_div2_doc_hash(:session_date_val_ssi, date_val_str) if @div2_doc_hash
        add_field_value_to_hash(:session_date_dtsim, d.strftime('%Y-%m-%dT00:00:00Z'), @page_session_fields) if d
        add_value_to_div2_doc_hash(:session_date_dtsi, d.strftime('%Y-%m-%dT00:00:00Z')) if d && @div2_doc_hash
        @need_session_date = false
      end
    when 'pb'
      if @need_first_page
        @need_first_page = false
      else
        # add previous page to div2 if it's not already there
        last_page_val = current_page_pages_ssim_val
        if @in_div2 && last_page_val && (@div2_doc_hash[:pages_ssim] && !@div2_doc_hash[:pages_ssim].include?(last_page_val))
          add_value_to_div2_doc_hash(:pages_ssim, last_page_val)
        end
        add_page_doc_to_solr
      end
      init_page_doc_hash
      process_pb_attribs attributes
    when 'sp'
      @in_sp = true
      if @need_session_date
        @logger.warn("Didn't find <date> tag before <sp> for session in page #{page_doc_hash[:id]}")
        @need_session_date = false
      end
    when 'speaker'
      @in_speaker = true
    when 'list'
      # if we still don't have a div2 title for 'contents', and we have some text, then do it here
      if @in_div2 && @need_div2_title && @div2_type == "contents" && @div2_title_buffer
        val = sentence_case(remove_trailing_and_leading_characters(@div2_title_buffer))
        add_value_to_div2_doc_hash(:div2_title_ssi, val)
        @need_div2_title = false
      end
    end
    @element_just_started = true unless name == 'hi'  # we don't want to add spaces at beginning of <hi> elements
  end
  
  # @param [String] name the element tag
  def end_element name
    @element_name_stack.pop
    text = @element_buffer.strip if !@element_buffer.strip.empty?
    case name
    when 'body'
      @in_body = false
    when 'back'
      @in_back = false
    when 'date'
      if @need_session_title 
        @session_title << @element_buffer
        @got_date = true
      else
        add_unspoken_text_to_doc_hashes text
      end
    when 'div2'
      # add current page to div2, if it's non-empty and not already there
      last_page_val = current_page_pages_ssim_val
      if last_page_val && (@div2_doc_hash[:pages_ssim] && !@div2_doc_hash[:pages_ssim].include?(last_page_val)) &&
            @page_buffer && !@page_buffer.strip.gsub(/\s+/, ' ').empty?
        add_value_to_div2_doc_hash(:pages_ssim, last_page_val)
      end
      # NOTE: can't add @div2_doc_hash to Solr here, because <pb> within closing tag(s) might not be part of THIS div2?
      @in_div2 = false
      @in_session = false
      @div2_title_buffer = nil
    when 'head'
      if @in_session && @need_session_govt
        add_session_govt_ssim(text)
      elsif @in_div2 && @need_div2_title
        case @div2_type
          when "alpha"
            add_value_to_div2_doc_hash(:div2_title_ssi, text.strip)
            @need_div2_title = false
          when "contents"
            # sometimes the div2 title is split across multiple <head> elements
            @div2_title_buffer = @div2_title_buffer ? "#{@div2_title_buffer} #{text}" : text
            # there are three formats of expected titles
            if @div2_title_buffer.match(/\ATable.*tome/i)
              val = sentence_case(remove_trailing_and_leading_characters(@div2_title_buffer))
              if val.match(/\ATable chronologique.*tome/i) || val.match(/\ATable générale chronologique des tomes.*/i)
                # capitalize Tome
                val.sub!(' tome', ' Tome')
                # capitalize last token (roman numeral)
                roman_num_str = val.split.last
                val.sub!(roman_num_str, roman_num_str.upcase)
              end
              if val.match(/\ATable générale chronologique des tomes.*/i)
                # capitalize 3rd-to-last token
                roman_num_str = (val.split)[-3]
                val.sub!(roman_num_str, roman_num_str.upcase)
              end
              add_value_to_div2_doc_hash(:div2_title_ssi, val)
              @need_div2_title = false
            elsif @div2_title_buffer.match(/Table par ordre des? mati(e|è)res du tome/i)
              val = remove_trailing_and_leading_characters(@div2_title_buffer)
              parts = val.split('. ')
              new_val = ''
              parts.each { |part| 
                new_val << sentence_case(part) + '. '
              }
              val = remove_trailing_and_leading_characters(new_val.strip)
              add_value_to_div2_doc_hash(:div2_title_ssi, val)
              @need_div2_title = false
            end
            # other
          when "introduction"
            add_value_to_div2_doc_hash(:div2_title_ssi, 'Introduction')
            @need_div2_title = false
          when "other"
            val = remove_trailing_and_leading_characters text
            add_value_to_div2_doc_hash(:div2_title_ssi, sentence_case(val))
            @need_div2_title = false
          when "table_alpha"
            val = remove_trailing_and_leading_characters text
            if val.size >= 10 && val[0, 9] == UnicodeUtils.upcase(val[0, 9])
              add_value_to_div2_doc_hash(:div2_title_ssi, sentence_case(val))
            elsif val == UnicodeUtils.upcase(val)
              add_value_to_div2_doc_hash(:div2_title_ssi, sentence_case(val))
            else
              add_value_to_div2_doc_hash(:div2_title_ssi, val)
            end
            @need_div2_title = false
          # NOTE: have copyfield for session div2_title, so no need to have it here
        end
      else
        add_unspoken_text_to_doc_hashes text 
      end
    when 'p'
      if @in_session && @need_session_title && @got_date && @page_session_fields
        @session_title << @element_buffer
        title = normalize_session_title(@session_title)
        add_field_value_to_hash(:session_title_ftsim, title, @page_session_fields) if title
        add_value_to_div2_doc_hash(:session_title_ftsi, title) if title
        if @page_session_fields[:session_date_val_ssim]
          val = "#{@page_session_fields[:session_date_val_ssim].last}#{SEP}#{title}"
          add_field_value_to_hash(:session_date_title_ssim, val, @page_session_fields)
          add_value_to_div2_doc_hash(:session_date_title_ssi, val)
        end
        @need_session_title = false
        @got_date = false
      elsif @in_div2 && @need_div2_title && @div2_type == 'other' 
        val = remove_trailing_and_leading_characters text
        add_value_to_div2_doc_hash(:div2_title_ssi, sentence_case(val))
        @need_div2_title = false
      elsif text
        if @in_session && @need_session_govt && text == text.upcase
          add_session_govt_ssim(text)
        elsif @in_sp && @speaker
          add_value_to_page_doc_hash(:spoken_text_timv, "#{@speaker}#{SEP}#{text}")
          add_value_to_div2_doc_hash(:spoken_text_timv, "#{@page_id}#{SEP}#{@speaker}#{SEP}#{text}")
        else
          add_unspoken_text_to_doc_hashes text
        end
      end
    when 'sp'
      @speaker = nil
      @in_sp = false
    when 'speaker'
      @speaker = normalize_speaker(text) if text
      @speaker.strip! if @speaker
      if @speaker
        add_value_to_div2_doc_hash(:speaker_ssim, @speaker) unless @div2_doc_hash && @div2_doc_hash[:speaker_ssim] && @div2_doc_hash[:speaker_ssim].include?(@speaker)
      end
      @in_speaker = false
    when 'list'
      # if we still don't have a div2 title for 'contents', and we have some text, then do it here
      if @in_div2 && @need_div2_title && @div2_type == "contents" && @div2_title_buffer
        val = sentence_case(remove_trailing_and_leading_characters(@div2_title_buffer))
        add_value_to_div2_doc_hash(:div2_title_ssi, val)
        @need_div2_title = false
      end
    when 'hi', 'note', 'item', 'signed'
      add_unspoken_text_to_doc_hashes text
    end # case name
    
    @element_just_ended = true
    @element_buffer = ''
  end
  
  # ensure we output the last page / div2 documents
  def end_document
    # write out last page, if we didn't already
    if @page_doc_hash && @page_doc_hash[:id] && @page_doc_hash[:id] != @last_page_added
      add_page_doc_to_solr
    end
    # write out last div2, if we didn't already
    if @div2_doc_hash && @div2_doc_hash[:id] && @div2_doc_hash[:id] != @last_div2_added
      # add last page of the document if it's needed
      last_page_val = current_page_pages_ssim_val
      if last_page_val && (!@div2_doc_hash[:pages_ssim] ||
                            (@div2_doc_hash[:pages_ssim] && !@div2_doc_hash[:pages_ssim].include?(last_page_val)))
        add_value_to_div2_doc_hash(:pages_ssim, last_page_val)
      end
      add_div2_doc_to_solr
    end
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
    @div2_buffer = add_chars_to_buffer(chars, @div2_buffer) if @in_div2 && !IGNORE_ELEMENTS.include?(@element_name_stack.last)
    # did a page start before we got to this div2?
    if @div2_doc_hash && !@div2_doc_hash[:pages_ssim] && !div2_buffer_empty? && @page_id
      add_value_to_div2_doc_hash(:pages_ssim, @page_id + SEP + (@page_num_s ? @page_num_s : "") )
    end
    
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
  
  # add value to unspoken_text_timv in page_doc_hash and div2_doc_hash
  # @param text [String] text to add
  def add_unspoken_text_to_doc_hashes text
    if text && text.match(/\w+/)
      add_value_to_page_doc_hash(:unspoken_text_timv, "#{text}")
      add_value_to_div2_doc_hash(:unspoken_text_timv, "#{@page_id}#{SEP}#{text}") if @div2_doc_hash
    end
  end
  
  # add :session_govt_ssim field to doc_hash, and reset appropriate vars
  def add_session_govt_ssim value
    val = value.strip if value
    val = val.sub(/[[:punct:]]$/, '') if val
    if val
      add_field_value_to_hash(:session_govt_ssim, val, @page_session_fields)
      add_value_to_div2_doc_hash(:session_govt_ssi, val)
    end
    @need_session_govt = false
  end
  
  # add :id, :page_num_ssi, :image_id_ss and ocr_id_ss to doc_hash, based on attributes
  # @param [Array<String>] attributes an assoc list of namespaces and attributes, e.g.:
  #     [ ["xmlns:foo", "http://sample.net"], ["size", "large"] ]
  def process_pb_attribs attributes
    @page_num_s = nil
    old_page_id = @page_id
    @page_id = get_attribute_val('id', attributes)
    @page_id.strip! if @page_id
    if !@page_id.match(/^#{@druid}.*/) || @page_id.nil?
      @logger.error("TEI for #{@druid} has <pb> element with incorrect druid: #{@page_id}; continuing with given page id.")
    end

    add_value_to_page_doc_hash(:id, @page_id) if @page_id

    # image id sequence numbers
    old_seq_num = old_page_id.split('_').last.to_i if old_page_id
    seq_num = @page_id.split('_').last.to_i
    if seq_num == 0
      @logger.warn("Non-integer image sequence number: #{@page_id}; continuing with processing.") 
    elsif old_seq_num && seq_num != old_seq_num + 1
      @logger.error("Image ids not consecutive in TEI: #{@page_id} occurs after #{old_page_id}; continuing with processing.")
    end
    
    # (printed) page numbers
    page_num = get_attribute_val('n', attributes)
    @page_num_s = page_num.strip if page_num
    add_value_to_page_doc_hash(:page_num_ssi,  @page_num_s) if @page_num_s
    if @page_num_i && !@page_num_s
      @logger.warn("Missing printed page number in TEI for #{@page_id}; continuing with processing.")
    end
        
    # integer page num
    old_page_num = @page_num_i if @page_num_i
    if page_num && page_num.match(/\d+/)
      @page_num_i = page_num.to_i 
    else
      @page_num_i = nil
    end
    if old_page_num && @page_num_i && @page_num_i != old_page_num + 1
      @logger.warn("Printed page numbers not consecutive in TEI: #{@page_num_i} (in image #{@page_id}) occurs after #{old_page_num} (in image #{old_page_id}); continuing with processing.")
    end

    add_value_to_page_doc_hash(:page_sequence_isi, @page_id_hash[@page_id]) if @page_id_hash[@page_id]
    add_value_to_page_doc_hash(:image_id_ssm, @page_id + ".jp2")
    add_value_to_page_doc_hash(:ocr_id_ss, @page_id.sub(/_00_/, '_99_') + ".txt")
    if @in_session && @need_session_first_page && @page_id_hash[@page_id]
      add_field_value_to_hash(:session_seq_first_isim, @page_id_hash[@page_id], @page_session_fields)
      @need_session_first_page = false
    end
  end # process_pb_attribs

  # @return true if @div2_buffer is empty or nil
  def div2_buffer_empty?
    div2_text = @div2_buffer.strip.gsub(/\s+/, ' ') if @div2_buffer && @div2_buffer.strip
    if div2_text && !div2_text.empty?
      true
    else
      false
    end
  end

  # @return [String] the value for a div2 doc's pages_ssim field for the current page
  def current_page_pages_ssim_val
    @page_id + SEP + (@page_num_s ? @page_num_s : "") if @page_id
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
  def init_page_doc_hash
    @page_doc_hash = {}
    @page_doc_hash[:type_ssi] = PAGE_TYPE
    add_value_to_page_doc_hash(:doc_type_ssim, @div2_doc_type) if @div2_doc_type
    add_vol_fields_to_hash(@page_doc_hash)
    @element_buffer = ''
    @page_buffer = ''
    # ensure session information doesn't carry incorrectly across pages
    @session_title = ''
    if @in_session && @page_session_fields
      @page_session_fields.each { |k, v|  
        @page_session_fields[k] = [v.last] if v && v.size > 1
      }
    else
      @page_session_fields = {}
    end
  end
  
  # initialize instance variable @page_doc_hash with mappings appropriate for all docs in the volume
  #  and reset variables
  def init_div2_doc_hash
    @div2_doc_hash = {}
    add_value_to_div2_doc_hash(:id, "#{@druid}_div2_#{@div2_counter}")
    if @in_div2
      add_value_to_div2_doc_hash(:doc_type_ssi, @div2_doc_type)
      add_value_to_div2_doc_hash(:type_ssi, @div2_doc_type)
    end
    add_vol_fields_to_hash(@div2_doc_hash)
    @div2_buffer = ''
  end
  
  # initialize hash with mappings appropriate for all docs in the volume
  def add_vol_fields_to_hash(hash)
    hash[:collection_ssi] = COLL_VAL
    hash[:druid_ssi] = @druid
    hash[:vol_num_ssi] = @volume
    hash.merge!(@vol_constants_hash)
    hash[:vol_title_ssi] = VOL_TITLES[@volume]
    hash[:vol_ssort] = VOL_SORT[@volume]
    hash[:vol_date_start_dti] = VOL_DATES[@volume].first
    hash[:vol_date_end_dti] = VOL_DATES[@volume].last
  end
  
  # add the value to the page_doc_hash for the Solr field.
  # @param [Symbol] key the Solr field name 
  # @param [String] value the value to add to the page_doc_hash for the key
  def add_value_to_page_doc_hash(key, value)
    add_field_value_to_hash(key, value, @page_doc_hash)
  end
  
  # add the value to the div2_doc_hash for the Solr field.
  # @param [Symbol] key the Solr field name 
  # @param [String] value the value to add to the div2_doc_hash for the key
  def add_value_to_div2_doc_hash(key, value)
    add_field_value_to_hash(key, value, @div2_doc_hash) if @div2_doc_hash
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
  
  # write @page_doc_hash to Solr, but only if the current page has content
  def add_page_doc_to_solr
    if @page_doc_hash[:id] && @page_doc_hash[:id] != @last_page_added
      text = @page_buffer.strip.gsub(/\s+/, ' ') if @page_buffer && @page_buffer.strip
      add_value_to_page_doc_hash(:text_tiv, text) if text && !text.empty?
      @page_doc_hash.merge!(@page_session_fields) if @page_session_fields
      @rsolr_client.add(@page_doc_hash)
      @last_page_added = @page_doc_hash[:id]
    end
  end
  
  # write @div2_doc_hash to Solr
  def add_div2_doc_to_solr
    if @div2_doc_hash[:id] && @div2_doc_hash[:id] != @last_div2_added
      text = @div2_buffer.strip.gsub(/\s+/, ' ') if @div2_buffer && @div2_buffer.strip
      add_value_to_div2_doc_hash(:text_tiv, text)
      @rsolr_client.add(@div2_doc_hash)
      @last_div2_added = @div2_doc_hash[:id]
    end
  end
  
end # ApTeiDocument class
