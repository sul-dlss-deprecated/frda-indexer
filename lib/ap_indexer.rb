require 'harvestdor-indexer'
require 'ap_tei_document'

# Indexer for Archives Parlementaires data
#  Harvest AP info from DOR via harvestdor-indexer gem, then index it 
class ApIndexer < Harvestdor::Indexer

  # create Solr doc for the druid and add it to Solr, unless it is on the blacklist.  
  #  NOTE: don't forget to send commit to Solr, either once at end (already in harvest_and_index), or for each add, or ...
  # @param [String] druid e.g. ab123cd4567
  def index druid
    if blacklist.include?(druid)
      logger.info("AP Druid #{druid} is on the blacklist and will have no Solr doc created")
    else
      pub_xml_ng_doc = public_xml druid
      
      vol = volume(druid)
      constants_hash = content_md_hash pub_xml_ng_doc
      
      saxdoc = ApTeiDocument.new(solr_client, druid, vol, logger)
      parser = Nokogiri::XML::SAX::Parser.new(saxdoc)
      tei_xml = tei(druid)
      logger.info("About to parse #{druid} (#{vol})")
      parser.parse(tei_xml)
      logger.info("Finished parsing #{druid}")
      solr_client.commit
      logger.info("Sent commit to Solr")
      # TODO: update DOR object's workflow datastream??
    end
  end
  
  # get the AP volume "number" from the identityMetadata in the public_xml for the druid
  # @param [String] druid we are seeking the volume number for this druid, e.g. ab123cd4567
  # @return [String] the volume number for the druid, per the identity from the public_xml
  def volume druid
# FIXME: refactor to get identityMeatdata from public_xml
    idmd = harvestdor_client.identity_metadata(druid)
    idmd.root.xpath('objectLabel').text.strip
  end
  
  # get the TEI for the AP volume via the digital stacks.
  # @param [String] druid e.g. ab123cd4567
  # @return [String] the TEI as a String
  def tei druid
    url = "#{config.stacks}/file/druid:#{druid}/#{druid}.xml"
    open(url)
  rescue Exception => e
    logger.error("error while retrieving tei at #{url} -- #{e.message}")
    "<TEI.2/>"
  end
  
  # create a Hash of Solr fields based on contentMetadata in public xml
  # @param [Nokogiri::XML::Document] the public xml for a DOR object
  # @return [Hash<String, String>] with the Solr fields derived from the contentMetadata
  def content_md_hash pub_xml_ng_doc
    doc_hash = {}
    content_md_doc = content_metadata pub_xml_ng_doc
    obj_resource_nodes = content_md_doc.root.xpath('/contentMetadata/resource[@type="object"][@sequence="1"][label="Object 1"]')
    raise "content_md didn't have single object node" if obj_resource_nodes.size != 1
    obj_node = obj_resource_nodes.first
    pdf_nodes = obj_node.xpath('file[@mimetype="application/pdf"]')
    if pdf_nodes.size == 1
      pdf_node = pdf_nodes.first
      pdf_name = pdf_node.xpath('@id').text
      doc_hash[:vol_pdf_name_ss] = pdf_name.strip if pdf_name && pdf_name.strip
      pdf_size = pdf_node.xpath('@size').text
      # TODO: ensure size is an integer?
      doc_hash[:vol_pdf_size_is] = pdf_size.strip if pdf_size && pdf_size.strip
    else
      logger.warn("couldn't find pdf in contentMetadata object <resource> element: #{obj_node.to_xml}")
    end
    tei_nodes = obj_node.xpath('file[@mimetype="application/xml"]')
    if tei_nodes.size == 1
      tei_node = tei_nodes.first
      tei_name = tei_node.xpath('@id').text
      doc_hash[:vol_tei_name_ss] = tei_name.strip if tei_name && tei_name.strip
      tei_size = tei_node.xpath('@size').text
      # TODO: ensure size is an integer?
      doc_hash[:vol_tei_size_is] = tei_size.strip if tei_size && tei_size.strip
    else
      logger.warn("couldn't find tei in contentMetadata object <resource> element: #{obj_node.to_xml}")
    end

    page_resource_nodes = content_md_doc.root.xpath('/contentMetadata/resource[@type="page"]')
    if page_resource_nodes.size == 0
      logger.warn("no page <resource> elements found in contentMetadata: #{content_md_doc.to_xml}")
    else
      last_page_node = page_resource_nodes.last
      page_label_nodes = page_resource_nodes.last.xpath('label')
      if page_label_nodes.size == 1
        page_label = page_label_nodes.first.text
        if page_label && !page_label.strip.empty?
          t = page_label.strip.gsub(/\s+/, ' ') 
          if t.match(/^Page (\d+)$/i)
            doc_hash[:total_pages_is] = $1
          else
            logger.warn("unable to parse highest page number from last page <resource> in contentMetadata: #{page_label}")
          end
        else
          logger.warn("no <label> value found for last page in contentMetadata: #{last_page_node.to_xml}")
        end
      else
        logger.warn("couldn't find <label> element in <resource> for highest page number in contentMetadata: #{last_page_node.to_xml}")
      end
    end
    doc_hash    
  end # content_md_hash

end