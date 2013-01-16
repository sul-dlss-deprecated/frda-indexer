# A mixin to the SolrDocBuilder class.
# Methods for Solr field values determined from the DOR object's purl page public xml 
class SolrDocBuilder

  # Retrieve the image file ids from the contentMetadata: xpath  contentMetadata/resource[@type='image']/file/@id
  #  but with jp2 file extension stripped off.
  # @return [Array<String>] the ids of the image files, without file type extension (e.g. 'W188_000002_300')
  def image_ids
    @image_ids ||= begin
      ids = []
      if content_md
        content_md.xpath('./resource[@type="image"]/file/@id').each { |node|
          ids << node.text.gsub(".jp2", '')
        }
      end
      return nil if ids.empty?
      ids
    end
  end
  
  protected #---------------------------------------------------------------------
  
  # the value of the type attribute for a DOR object's contentMetadata
  #  more info about these values is here:
  #    https://consul.stanford.edu/display/chimera/DOR+content+types%2C+resource+types+and+interpretive+metadata
  #    https://consul.stanford.edu/display/chimera/Summary+of+Content+Types%2C+Resource+Types+and+their+behaviors
  # @return [String] 
  def dor_content_type
    @dor_content_type ||= content_md ? content_md.xpath('@type').text : nil
  end
  
  # the contentMetadata for this object, derived from the public_xml
  # @return [Nokogiri::XML::Element] containing the contentMetadata
  def content_md 
# FIXME:  create nom-xml terminology for contentMetadata in harvestdor?
    @content_md ||= public_xml.root.xpath('/publicObject/contentMetadata').first
  end
  
end # SolrDocBuilder class