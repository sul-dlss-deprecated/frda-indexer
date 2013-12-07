# encoding: utf-8
require 'harvestdor-indexer'
require 'date'

require 'normalization_helper'

# Indexer for BnF Images data
#  Harvest BnfImages from DOR via harvestdor-indexer gem, then index it 
class BnfImagesIndexer < Harvestdor::Indexer

  include NormalizationHelper  

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
      begin
        start_time=Time.now
        logger.info("Beginning processing of #{druid}")
        doc_hash = {
          :id => druid, 
          :druid_ssi => druid,
          :type_ssi => TYPE_VAL,
          :collection_ssi => COLL_VAL,
          :result_group_ssi => COLL_VAL,
          :vol_ssort => '0000', # Images should sort first, ahead of all AP volumes
          :image_id_ssm => image_ids(druid)
        }
        mods_doc_hash = doc_hash_from_mods druid
        doc_hash.merge!(mods_doc_hash) if mods_doc_hash
        logger.info("Finished retrieving public metadata and parsing #{druid}, elapsed time: #{elapsed_time(start_time)} seconds")
        start_time_solr=Time.now
        solr_client.add(doc_hash)
        logger.info("Sent commit to Solr for #{druid}, elapsed time: #{elapsed_time(start_time_solr)} seconds")
        logger.info("Total index time for druid #{druid}: elapsed time: #{elapsed_time(start_time)} seconds")
        @success_count+=1
        # TODO: provide call to code to update DOR object's workflow datastream??
      rescue => e
        @error_count+=1
        logger.error "Failed to index #{druid}: #{e.message}"
        logger.error e.backtrace
      end
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
    
    pub_date = search_dates(smods_rec_obj, druid)
    doc_hash[:search_date_dtsim] = pub_date if pub_date
    
    doc_hash.merge!(phys_desc_field_hash(smods_rec_obj, druid))
    
    doc_hash.merge!(name_field_hash(smods_rec_obj, druid))
    
    doc_hash.merge!(subject_field_hash(smods_rec_obj, druid))
    
    all_text = smods_rec_obj.text.strip
    doc_hash[:text_tiv] = all_text.gsub(/\s+/, ' ') unless all_text.empty?

    doc_hash[:mods_xml] = smods_rec_obj.to_xml
    doc_hash
  end
  
  # get dates from originInfo/dateIssued in iso8601 zed format (YYYY-MM-DDThh:mm:ssZ), 
  #  log warnings for no dateIssued field, for no parseable dates, and for each unparseable date
  #  we count YYYY and [YYYY] (and [YYYY  and YYYY] as parseable)
  # @param [Stanford::Mods::Record] smods_rec_obj (for a particular druid)
  # @param [String] druid e.g. ab123cd4567 (for error reporting)
  # @return [Array<String>] originInfo/dateIssued values in iso8601 zed format (YYYY-MM-DDThh:mm:ssZ), 
  #   or nil if there are none that can be parsed into Date objects
  def search_dates smods_rec_obj, druid
    date_nodes = smods_rec_obj.origin_info.dateIssued
    if date_nodes.empty?
      logger.warn "#{druid} has no originInfo/dateIssued field"
      return nil      
    end

    result = []
    year_only = []
    date_nodes.each { |dn|
      raw_val = dn.text
      begin
        d = Date.parse(raw_val) if raw_val
        result << d.strftime('%FT%TZ') if d
      rescue => e
        if raw_val && raw_val.match(/^\[?(?:ca )?(\d{4})\]?$/i)
          year_only << $1
        else
          logger.warn "#{druid} has unparseable originInfo/dateIssued value: '#{dn.text}'"
          nil
        end
      end
    }
    results = result.compact.uniq

    year_only.compact.uniq.each { |year|
      if !results.detect { |date| date.match(Regexp.new("^#{year}")) }
        results << "#{year}-01-01T00:00:00Z"
      end
    }

    if results.empty?
      logger.warn "#{druid} has no parseable originInfo/dateIssued value"
      nil
    else
      results
    end
  end
  
  # create a Hash of Solr fields based on MODS top level <physicalDescription> fields
  # @param [Stanford::Mods::Record] smods_rec_obj (for a particular druid)
  # @param [String] druid e.g. ab123cd4567 (for error reporting)
  # @return [Hash<String, String>] with the Solr fields derived from the MODS top level <physicalDescription> fields
  def phys_desc_field_hash smods_rec_obj, druid
    doc_hash = {}
    phys_desc_nodeset = smods_rec_obj.physical_description if smods_rec_obj.physical_description
    unless phys_desc_nodeset.empty?
      # <form> maps to doc_type_ssi
      forms = phys_desc_nodeset.form.map {|n| n.text } if !phys_desc_nodeset.form.empty?
      if forms
        forms.each { |form|
          f = form.gsub(/\s+/, ' ').strip
          case f
            when /\A(Image fixe|Monnaie ou médaille|Objet)\z/i
              doc_hash[:doc_type_ssi] = f.downcase
              break # only want one value
          end
        }
      end

      # <extent> maps to medium_ssi
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
    doc_hash
  end
  
  # create a Hash of Solr fields based on MODS top level <name> fields
  # @param [Stanford::Mods::Record] smods_rec_obj (for a particular druid)
  # @param [String] druid e.g. ab123cd4567 (for error reporting)
  # @return [Hash<String, String>] with the Solr fields derived from the MODS top level <name> fields
  def name_field_hash smods_rec_obj, druid
    doc_hash = {}
    name_flds = [:collector_ssim, :artist_ssim]
    name_flds.each { |fld| doc_hash[fld] = [] }
    smods_rec_obj.plain_name.each { |name_node|
      # as of 2013-03-04, all roles for BnF Images are of type code
      if name_node.role && name_node.role.code
        name_node.role.code.each { |code| 
          if code && !code.empty?
            case code.strip
              when 'col', 'dnr'
                val = name_no_dates name_node
                doc_hash[:collector_ssim] << val if val
              when 'art', 'drm', 'egr', 'ill', 'scl'
                val = name_with_dates name_node
                doc_hash[:artist_ssim] << val if val
            end
          end
        }
      end
    }
    name_flds.each { |fld|
      doc_hash.delete(fld) if doc_hash[fld] && doc_hash[fld].empty?
    }
    doc_hash    
  end
  
  # @param [Nokogiri::XML::Node] name_node - a MODS <name> node
  # @return [String] the "[family], [given]" form of a name if  nameParts of type "family" and/or "given" are indicated; 
  #  otherwise returns all nameParts that are not of type "date" or "termsOfAddress", or nil if none
  def name_no_dates name_node
    if !name_node.family_name.empty?
      return name_node.given_name.empty? ? name_node.family_name.text : "#{name_node.family_name.text}, #{name_node.given_name.text}"
    elsif !name_node.given_name.empty?
      return name_node.given_name.text
    end
    names = name_node.namePart.map { |npn| npn.text unless npn.type_at == 'date' || npn.type_at == 'termsOfAddress'}.compact
    return names.join(' ') unless names.empty?
    nil
  end
  
  # @param [Nokogiri::XML::Node] name_node - a MODS <name> node
  # @return [String] the "[family], [given] ([date])" form of a name if nameParts of type "family" and/or "given" (and "date") are indicated; 
  #  otherwise returns all plain nameParts followed by " ([date])" if there is a namePart of type "date", or nil if none
  def name_with_dates name_node
    dates = name_node.namePart.map { |npn| npn.text if npn.type_at == 'date' }.compact
    date_str = ' (' + dates.first + ')' unless dates.empty?
    just_name = name_no_dates name_node
    if just_name
      return date_str ? just_name << date_str : just_name
    end
    nil
  end
  
  # create a Hash of Solr fields based on MODS <subject> fields
  # @param [Stanford::Mods::Record] smods_rec_obj (for a particular druid)
  # @param [String] druid e.g. ab123cd4567 (for error reporting)
  # @return [Hash<String, String>] with the Solr fields derived from the MODS <subject> fields
  def subject_field_hash smods_rec_obj, druid
    doc_hash = {}
    sub_flds = [:catalog_heading_etsimv, :catalog_heading_ftsimv, :speaker_ssim, :subject_name_ssim]
    sub_flds.each { |fld| doc_hash[fld] = [] }
    smods_rec_obj.subject.each { |subj_node|
      if subj_node.displayLabel && subj_node.displayLabel == 'Catalog heading'
        topics = subj_node.topic.map { |n| n.text } if !subj_node.topic.empty?
        if topics
          val = topics.join(' -- ')
          case subj_node.lang
            when "fre"
              doc_hash[:catalog_heading_ftsimv] << val if val
            when "eng"
              doc_hash[:catalog_heading_etsimv] << val if val
            else
              logger.warn("#{druid} has subject with @displayLabel 'Catalog heading' but @lang not 'fre' or 'eng': '#{subj_node.to_xml}'")
          end
        end
      end

      subj_node.name_el.each { |sub_name_node|
        if sub_name_node.type_at && sub_name_node.type_at == 'personal'
          # want non-date parts   (currently, Images have subject nameParts with explicit types of 'date' and 'termsOfAddress')
          parts = []
          toa = nil
          sub_name_node.namePart.each { |namePart|
            if namePart.type_at != 'date' && namePart.type_at != 'termsOfAddress'
              parts << normalize_speaker(namePart.text) unless namePart.text.empty?
            elsif namePart.type_at == 'termsOfAddress'
              toa = namePart.text
            end
          }
          speaker = parts.join(', ').strip unless parts.empty?
          speaker << " #{toa}" if speaker && !speaker.empty? && toa && !toa.empty?
          doc_hash[:speaker_ssim] << speaker if speaker && !speaker.empty?
        else
          parts = sub_name_node.namePart.map { |npn| npn.text unless npn.text.empty? }
          doc_hash[:subject_name_ssim] << parts.join(', ').strip unless parts.empty?
        end
      }
    } # each subject node
    
    sub_flds.each { |fld|  
      doc_hash.delete(fld) if doc_hash[fld] && doc_hash[fld].empty?
    }
    doc_hash
  end
  
  # Retrieve the image file ids from the contentMetadata: xpath  contentMetadata/resource[@type='image']/file/@id
  # @param [String] druid e.g. ab123cd4567
  # @return [Array<String>] the ids of the image files, without file type extension (e.g. 'W188_000002_300') or nil if none
  def image_ids druid
    ids = []
    cntmd = harvestdor_client.content_metadata druid
    if cntmd
      cntmd.root.xpath('./resource[@type="image"]/file/@id').each { |node|
        ids << node.text
      }
    else
      logger.warn("#{druid} did not retrieve any contentMetadata")
      return nil
    end
    if ids.empty?
      logger.warn("#{druid} did not find any image ids: #{cntmd.to_xml}")
      return nil
    end
    ids
  end

end
