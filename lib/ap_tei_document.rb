require 'nokogiri'

require 'ap_vol_dates'
require 'ap_vol_titles'

# Subclass of Nokogiri::XML::SAX::Document for streaming parsing
#  TEI xml corresponding to volumes of the Archives Parlementaires
class ApTeiDocument < Nokogiri::XML::SAX::Document
  
  COLL_VAL = "Archives parlementaires"  

  attr_reader :doc_hash

  # @param [RSolr::Client] rsolr_client used to write the Solr documents as we build them
  # @param [String] druid the druid for the DOR object that contains this TEI doc
  # @param [String] volume the volume number (it might not be a strict number string, e.g. '71B')
  def initialize (rsolr_client, druid, volume)
    @rsolr_client = rsolr_client
    @druid = druid
    @volume = volume
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
    when 'pb'
      if @page_has_content && (@in_body || @in_back)
        add_doc_to_solr
      end
      new_page_id = attributes.select { |a| a[0] == 'id'}.first.last
      @doc_hash[:id] = new_page_id
    when 'p'
      @page_has_content = true
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
      if @page_has_content
        add_doc_to_solr
      end
      @in_back = false
    end
  end
  
  # --------- Not part of the Nokogiri::XML::SAX::Document events -----------------
    
  # initialize instance variable @doc_hash with values appropriate for the volume level
  def init_doc_hash
    @doc_hash = {}
    @doc_hash[:collection_si] = COLL_VAL
    @doc_hash[:druid] = @druid
    @doc_hash[:volume_ssi] = @volume
    @doc_hash[:volume_title_ssi] = VOL_TITLES[@volume]
    # The format for a Solr date field is 1995-12-31T23:59:59Z
    @doc_hash[:vol_date_start_dti] = VOL_DATES[@volume].first
    @doc_hash[:vol_date_end_dti] = VOL_DATES[@volume].last
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
