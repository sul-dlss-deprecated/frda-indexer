require 'logger'

require 'harvestdor'
require 'stanford-mods'
#require 'mods_fields'

# Class to build the Hash representing a Solr document for a particular Bnf object
class BnfSolrDocBuilder

  # The druid of the BnF item
  attr_reader :druid
  # Stanford::Mods::Record 
  attr_reader :smods_rec
  attr_reader :logger

  # @param [String] druid of BnF object, e.g. ab123cd4567
  # @param [Harvestdor::Client] harvestdor client used to get mods and public_xml
  # @param [Logger] logger for indexing messages
  def initialize(druid, harvestdor_client, logger)
    @druid = druid
    @harvestdor_client = harvestdor_client
    @logger = logger
    @smods_rec = smods_rec
  end
  
  # Create a Hash representing the Solr doc to be written to Solr, based on MODS and public_xml
  # @return [Hash] Hash representing the Solr document
  def doc_hash
    doc_hash = {
      :id => @druid, 
      :modsxml => "#{@smods_rec.to_xml}",
    }
    
    doc_hash.merge!(doc_hash_from_mods) if doc_hash_from_mods
    
    doc_hash
  end
  
  
  # Create a Hash representing a Solr doc, with all MODS related fields populated.
  # @return [Hash] Hash representing the Solr document
  def doc_hash_from_mods
    doc_hash = { 
      
      :title_ftsim => @smods_rec.sw_full_title,
      :title_fti => @smods_rec.sw_sort_title,
      
      # title fields
      :title_245a_search => @smods_rec.sw_short_title,
      :title_245_search => @smods_rec.sw_full_title,
      :title_variant_search => @smods_rec.sw_addl_titles,
      :title_sort => @smods_rec.sw_sort_title,
      :title_245a_display => @smods_rec.sw_short_title,
      :title_display => @smods_rec.sw_full_title,
      :title_full_display => @smods_rec.sw_full_title,
      
      # author fields
      :author_1xx_search => @smods_rec.sw_main_author,
      :author_7xx_search => @smods_rec.sw_addl_authors,
      :author_person_facet => @smods_rec.sw_person_authors,
      :author_other_facet => @smods_rec.sw_impersonal_authors,
      :author_sort => @smods_rec.sw_sort_author,
      :author_corp_display => @smods_rec.sw_corporate_authors,
      :author_meeting_display => @smods_rec.sw_meeting_authors,
      :author_person_display => @smods_rec.sw_person_authors,
      :author_person_full_display => @smods_rec.sw_person_authors,
      
      # subject search fields
      :topic_search => topic_search, 
      :geographic_search => geographic_search,
      :subject_other_search => subject_other_search, 
      :subject_other_subvy_search => subject_other_subvy_search,
      :subject_all_search => subject_all_search, 
      :topic_facet => topic_facet,
      :geographic_facet => geographic_facet,
      :era_facet => era_facet,

      :physical =>  @smods_rec.term_values([:physical_description, :extent]),
      :url_suppl => @smods_rec.term_values([:related_item, :location, :url]),

      # is access_condition_display still needed?
      :access_condition_display => @smods_rec.term_values(:accessCondition),
      # remaining: go through all MODS elements (per MODS spec, not wiki doc)
    }
    
    # all_search
    
    doc_hash
  end
  
  
  # return the MODS for the druid as a Stanford::Mods::Record object
  # @return [Stanford::Mods::Record] created from the MODS xml for the druid
  def smods_rec
    if @mods_rec.nil?
      ng_doc = @harvestdor_client.mods @druid
      raise "Empty MODS metadata for #{druid}: #{ng_doc.to_xml}" if ng_doc.root.xpath('//text()').empty?
      @mods_rec = Stanford::Mods::Record.new
      @mods_rec.from_nk_node(ng_doc.root)
    end
    @mods_rec
  end
  
end # SolrDocBuilder class