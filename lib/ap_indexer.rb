require 'harvestdor-indexer'

# Indexer for Archives Parlementaires data
#  Harvest AP info from DOR via harvestdor-indexer gem, then index it 
class ApIndexer < Harvestdor::Indexer

  # create Solr doc for the druid and add it to Solr, unless it is on the blacklist.  
  #  NOTE: don't forget to send commit to Solr, either once at end (already in harvest_and_index), or for each add, or ...
  def index druid
    if blacklist.include?(druid)
      logger.info("AP Druid #{druid} is on the blacklist and will have no Solr doc created")
    else
      vol = volume(druid)
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
  # @param [String] druid we are seeking the volume number for this druid
  # @return [String] the volume number for the druid, per the identity from the public_xml
  def volume druid
    idmd = harvestdor_client.identity_metadata(druid)
    idmd.root.xpath('objectLabel').text.strip
  end
  
  # get the TEI for the AP volume via the digital stacks.  
  # @return [String] the TEI as a String
  def tei druid
    url = "#{config.stacks}/file/druid:#{druid}/#{druid}.xml"
    open(url)
  rescue Exception => e
    logger.error("error while retrieving tei at #{url} -- #{e.message}")
    "<TEI.2/>"
  end
  
end