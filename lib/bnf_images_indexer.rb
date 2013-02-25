# encoding: utf-8
require 'harvestdor-indexer'

# Indexer for BnF Images data
#  Harvest BnfImages from DOR via harvestdor-indexer gem, then index it 
class BnfImagesIndexer < Harvestdor::Indexer

  COLL_VAL = "Images de la Révolution française"
  # value used in rails app for choosing correct object type display 
  TYPE_VAL = "image"


  # create Solr doc for the druid and add it to Solr, unless it is on the blacklist.  
  #  NOTE: don't forget to send commit to Solr, either once at end (already in harvest_and_index), or for each add, or ...
  # @param [String] druid e.g. ab123cd4567
  def index druid
    if blacklist.include?(druid)
      logger.info("BnF Images Druid #{druid} is on the blacklist and will have no Solr doc created")
    else
      logger.info("About to prep #{druid}")

      doc_hash = {
        :id => druid, 
        :druid_ssi => druid,
        :type_ssi => TYPE_VAL,
        :collection_ssi => COLL_VAL,
        :image_id_ssm => image_ids(druid)
      }
      mods_doc_hash = doc_hash_from_mods druid
      doc_hash.merge!(mods_doc_hash) if mods_doc_hash
      
      solr_client.add(doc_hash)
      logger.info("Added doc for #{druid} to Solr")
      # TODO: update DOR object's workflow datastream??
    end
  end
  
  # Create a Hash representing a Solr doc, with all MODS related fields populated.
  # @param [String] druid e.g. ab123cd4567
  # @return [Hash] Hash representing the Solr document
  def doc_hash_from_mods druid
    smods_rec_obj = smods_rec(druid)
    doc_hash = {}
    doc_hash[:title_short_ftsi] = smods_rec_obj.sw_short_title if smods_rec_obj.sw_short_title
    doc_hash[:title_long_ftsi] = smods_rec_obj.sw_full_title if smods_rec_obj.sw_full_title
    doc_hash[:genre_ssim] = smods_rec_obj.genre.map {|n| n.text } if smods_rec_obj.genre && !smods_rec_obj.genre.empty?
    phys_desc_nodeset = smods_rec_obj.physical_description if smods_rec_obj.physical_description
    if phys_desc_nodeset
      doc_hash[:doc_type_ssim] = phys_desc_nodeset.form.map {|n| n.text } if !phys_desc_nodeset.form.empty?
      extents = phys_desc_nodeset.extent.map {|n| n.text} if !phys_desc_nodeset.extent.empty?
      if extents && extents.size > 1
        logger.warn("#{druid} unexpectedly has multiple <physicalDescription><extent> fields; using first only for :medium_ssi")
      end
      if extents
        full_str = extents.first
        desired = full_str[/.*\:(.*?);.*/, 1]
        if desired
          doc_hash[:medium_ssi] = desired.strip
        else
          logger.warn("#{druid} has no :medium_ssi; MODS <physicalDescription><extent> has unexpected format: '#{full_str}'")
        end
      end
    end
=begin    
    doc_hash = { 
      :speaker_ssim => '', #-> subject name e.g. bg698df3242
      :collector_ssim => '', # name w role col, or dnr
      :artist_ssim => '', # name w role art, egr, ill, scl, drm
      
      :catalog_heading_ftsimv => '', # use double hyphen separator;  subject browse hierarchical subjects  fre
      :catalog_heading_etsimv => '', # use double hyphen separator;  subject browse hierarchical subjects  english
      
#          dates -> originInfo_dateIssued_sim,    subject_temporal_sim  ?
    
      :text_tiv => smods_rec_obj.text,  # anything else here?      
    }
=end
    doc_hash[:mods_xml] = smods_rec_obj.to_xml
    doc_hash
  end
  
  # Retrieve the image file ids from the contentMetadata: xpath  contentMetadata/resource[@type='image']/file/@id
  #  but with jp2 file extension stripped off.
  # @param [String] druid e.g. ab123cd4567
  # @return [Array<String>] the ids of the image files, without file type extension (e.g. 'W188_000002_300')
  def image_ids druid
    ids = []
    cntmd = @harvestdor_client.content_metadata druid
    if cntmd
      cntmd.xpath('./resource[@type="image"]/file/@id').each { |node|
        ids << node.text
      }
    end
    return nil if ids.empty?
    ids
  end

end
