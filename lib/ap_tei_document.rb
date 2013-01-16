require 'nokogiri'

# Subclass of Nokogiri::XML::SAX::Document for parsing
#  TEI xml corresponding to volumes of the Archives Parlementaires
class ApTeiDocument < Nokogiri::XML::SAX::Document
  
  COLL_VAL = "Archives parlementaires"  
  VOL_CONTEXT_FIELDS = [:collection_si, :volume_ssi, :druid]
  VOL_CONTEXT_FIELDS.each { |f| 
    attr_reader f.to_sym
  }

  @collection_si = COLL_VAL
  
  # Called at the beginning of an element
  # @param [String] name the element tag
  # @param [Array<String>] attributes an assoc list of namespaces and attributes, e.g.:
  #     [ ["xmlns:foo", "http://sample.net"], ["size", "large"] ]
  def start_element name, attributes
    case name
    when 'teiHeader'
      @druid ||= attributes.select { |a| a[0] == 'id'}.first.last
    end
  end
  
end # ApTeiDocument class