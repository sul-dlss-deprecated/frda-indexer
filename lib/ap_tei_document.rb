require 'nokogiri'

require 'ap_vol_dates'

# Subclass of Nokogiri::XML::SAX::Document for parsing
#  TEI xml corresponding to volumes of the Archives Parlementaires
class ApTeiDocument < Nokogiri::XML::SAX::Document
  
  COLL_VAL = "Archives parlementaires"  

  attr_reader :volume, :druid, :doc_hash

  # @param [String] druid the druid for the DOR object that contains this TEI doc
  # @param [String] volume the volume number (it might not be a strict number string, e.g. '71B')
  def initialize (druid, volume)
    @druid = druid
    @volume = volume
  end
  
  def start_document
    init_doc_hash
  end
  
  # @param [String] name the element tag
  # @param [Array<String>] attributes an assoc list of namespaces and attributes, e.g.:
  #     [ ["xmlns:foo", "http://sample.net"], ["size", "large"] ]
  def start_element name, attributes
    case name
    when 'teiHeader'
      ;
    end
  end
  
  # --------- Not part of the Nokogiri::XML::SAX::Document events -----------------
    
  # initialize instance variable @doc_hash with values appropriate for the volume level
  def init_doc_hash
    @doc_hash = {}
    @doc_hash[:collection_si] = COLL_VAL
    @doc_hash[:druid] = @druid
    @doc_hash[:volume_ssi] = @volume
    # The format for a Solr date field is 1995-12-31T23:59:59Z
    @doc_hash[:date_start_dti] = VOL_DATES[@volume].first
    @doc_hash[:date_end_dti] = VOL_DATES[@volume].last
  end
end # ApTeiDocument class
