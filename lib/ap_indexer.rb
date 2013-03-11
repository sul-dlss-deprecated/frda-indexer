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
      vol = volume pub_xml_ng_doc
      content_md_doc = content_metadata pub_xml_ng_doc
      page_id_hash = page_id_hash content_md_doc
      vol_constants_hash = vol_constants_hash content_md_doc      
      
      saxdoc = ApTeiDocument.new(solr_client, druid, vol, vol_constants_hash, logger)
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
  def volume pub_xml_ng_doc
    idmd = identity_metadata pub_xml_ng_doc
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
  
  # creates a Hash mapping each page_id to its Page number
  # @param [Nokogiri::XML::Document] content_md_doc the contentMetadata for a DOR object
  # @return [Hash<String, String>] key page id (e.g. "bg262qk2288_00_0003"), value Page sequence number (e.g. "3")
  def page_id_hash content_md_doc
    page_id_hash = {}
    page_resource_nodes = content_md_doc.root.xpath('/contentMetadata/resource[@type="page"]')
    logger.warn("no page <resource> elements found in contentMetadata: #{content_md_doc.to_xml}") if page_resource_nodes.empty?
    page_resource_nodes.each { |p_node|
      # for each resource, get the id and the page number
      page_id_hash[page_id(p_node)] = page_num(p_node)
    }
    page_id_hash
  end
  
  # create a Hash of Solr fields based on contentMetadata in public xml
  # @param [Nokogiri::XML::Document] content_md_doc the contentMetadata for a DOR object
  # @return [Hash<String, String>] with the Solr fields derived from the contentMetadata
  def vol_constants_hash content_md_doc
    doc_hash = {}
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
    if page_resource_nodes.size > 0
      last_page_node = page_resource_nodes.last
      doc_hash[:vol_total_pages_is] = page_num last_page_node
    else
      logger.warn("no page <resource> elements found in contentMetadata: #{content_md_doc.to_xml}")
    end
    doc_hash    
  end # content_md_hash
   
  # Given a <resource> element for a page from contentMetadata, return the page sequence number as parsed from <label>
  # @param [Nokogiri::XML::Node] page_resource_node a representation of a <resource> from contentMetadata with type="page"
  # @return [String] the number of the page, derived from <label> child element of <resource>
  def page_num page_resource_node
    page_label_nodes = page_resource_node.xpath('label')
    if page_label_nodes.size == 1
      page_label_val = page_label_nodes.first.text
      if page_label_val && !page_label_val.strip.empty?
        t = page_label_val.strip.gsub(/\s+/, ' ')
        if t.match(/^Page (\d+)$/i)
          return $1
        else
          logger.warn("unable to parse page number from <resource><label> in contentMetadata: #{page_label_val}")
        end
      else
        logger.warn("no <label> value found for page <resource> in contentMetadata: #{page_resource_node.to_xml}")
      end
    else
      logger.warn("couldn't find <label> element in <resource> for page in contentMetadata: #{page_resource_node.to_xml}")
    end
    nil
  end 

  # the id of the page image file, without the .jp2 extension
  # @param [Nokogiri::XML::Node] page_resource_node a representation of a <resource> from contentMetadata with type="page"
  # @return [String] the id of the page, derived from <file> id attribute (e.g. "bg262qk2288_00_0003" from "bg262qk2288_00_0003.jp2")
  def page_id page_resource_node
    image_id_nodes = page_resource_node.xpath('file[@mimetype="image/jp2"]/@id')
    if image_id_nodes.size == 1
      full_id = image_id_nodes.first.text
      if full_id && !full_id.strip.empty?
        t = full_id.strip.gsub(/\s+/, ' ')
        if t.match(/^(.+).jp2$/i)
          return $1
        else
          logger.warn("unable to parse page id from <file> in contentMetadata: #{full_id}")
        end
      else
        logger.warn("no @id attribute found for page <file> in contentMetadata: #{image_id_nodes.first.to_xml}")
      end
    else
      logger.warn("couldn't find jp2 <file> element in <resource> for page in contentMetadata: #{page_resource_node.to_xml}")
    end
    nil
  end

end