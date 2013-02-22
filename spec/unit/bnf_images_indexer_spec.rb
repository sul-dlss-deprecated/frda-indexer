# encoding: utf-8
require 'spec_helper'

describe BnfImagesIndexer do
  
  before(:all) do
    @config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "bnf_oai_test.yml")
    @indexer = BnfImagesIndexer.new(@config_yml_path)
    @hdor_client = @indexer.send(:harvestdor_client)
    @solr_client = @indexer.solr_client
    @fake_druid = 'oo000oo0000'
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
    @ng_mods_xml = Nokogiri::XML("<mods #{@ns_decl}><note>hi</note></mods>")
  end
  
  context "index method" do
    before(:each) do
      @hdor_client.should_receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      @hdor_client.should_receive(:content_metadata).and_return(nil)
    end

    it "the druid should be the value of the :id and :druid_ssi fields" do
      @solr_client.should_receive(:add).with(hash_including(:id => @fake_druid, :druid_ssi => @fake_druid))
      @indexer.index(@fake_druid)
    end

    context "fields that are constants" do
      it ":collection_ssi should be Images de la Révolution française" do
        @solr_client.should_receive(:add).with(hash_including(:collection_ssi => 'Images de la Révolution française'))
        @indexer.index(@fake_druid)
      end
      it ":type_ssi should be 'image'" do
        @solr_client.should_receive(:add).with(hash_including(:type_ssi => 'image'))
        @indexer.index(@fake_druid)
      end
    end
    
#    context ":image_id_ssm field" do
#      it "should be the value of image_ids method" do
#        ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><file id='W188_000001_300.jp2'/></resource>#{@content_md_end}")
#        @hdor_client.should_receive(:content_metadata).with(@fake_druid).and_return(ng_xml.root)
#        @solr_client.should_receive(:add).with(hash_including(:image_id_ssm => ['W188_000001_300.jp2']))
#        @indexer.index(@fake_druid)
#      end
#    end

  end # index method

  context "fields from mods" do
    it ":mods_xml" do
      pending "to be implemented"
    end
=begin    
          :speaker_ssim => '', #-> subject name e.g. bg698df3242
          :collector_ssim => '', # name w role col, or dnr
          :artist_ssim => '', # name w role art, egr, ill, scl, drm

          :doc_type_ssim => '', # physicalDescription/form 
          :medium_ssi => '', #  physicalDescription_extent_sim  -  between colon and semicolon
          :genre_ssim => smods_rec.genre,

          :catalog_heading_ftsimv => '', # use double hyphen separator;  subject browse hierarchical subjects  fre
          :catalog_heading_etsimv => '', # use double hyphen separator;  subject browse hierarchical subjects  english

          :title_short_ssi => smods_rec.sw_short_title,
          :title_long_ssi => smods_rec.sw_full_title,

          :date_issued_ssim  #  originInfo_dateIssued_sim,    subject_temporal_sim  ?  <note>Date de creation??
          :date_issued_dtsim

          :text_tiv => smods_rec.text  # anything else here?
          :mods_xml 
=end    
  end # doc_hash_from_mods
  
  context "image_ids method" do
    before(:all) do
      @content_md_start = "<contentMetadata objectId='#{@fake_druid}'>"
      @content_md_end = "</contentMetadata>"
    end
    it "should be nil if there are no <resource> elements in the contentMetadata" do
      ng_xml = Nokogiri::XML("#{@content_md_start}#{@content_md_end}")
      @hdor_client.should_receive(:content_metadata).with(@fake_druid).and_return(ng_xml.root)
      @indexer.image_ids(@fake_druid).should == nil
    end
    it "should ignore <resource> elements with attribute type other than 'image'" do
      ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='blarg'><file id='foo'/></resource>#{@content_md_end}")
      @hdor_client.should_receive(:content_metadata).with(@fake_druid).and_return(ng_xml.root)
      @indexer.image_ids(@fake_druid).should == nil
    end
    it "should be ignore all but <file> element children of the image resource element" do
      ng_xml = ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><label id='foo'>bar</label></resource>#{@content_md_end}")
      @hdor_client.should_receive(:content_metadata).with(@fake_druid).and_return(ng_xml.root)
      @indexer.image_ids(@fake_druid).should == nil
    end
    it "should be nil if there are no id elements on file elements" do
      ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><file/></resource>#{@content_md_end}")
      @hdor_client.should_receive(:content_metadata).with(@fake_druid).and_return(ng_xml.root)
      @indexer.image_ids(@fake_druid).should == nil
    end
    it "should be an Array of size one if there is a single <resource><file id='something'> in the content metadata" do
      ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><file id='foo'/></resource>#{@content_md_end}")
      @hdor_client.should_receive(:content_metadata).with(@fake_druid).and_return(ng_xml.root)
      @indexer.image_ids(@fake_druid).should == ['foo']
    end
    it "should be the same size as the number of <resource><file id='something'> in the content metadata" do
      ng_xml = Nokogiri::XML("#{@content_md_start}
            <resource type='image'><file id='foo'/></resource>
            <resource type='image'><file id='bar'/></resource>#{@content_md_end}")
      @hdor_client.should_receive(:content_metadata).with(@fake_druid).and_return(ng_xml.root)
      @indexer.image_ids(@fake_druid).should == ['foo', 'bar']
    end
    it "endings of .jp2 should not be stripped" do
      ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><file id='W188_000001_300.jp2'/></resource>#{@content_md_end}")
      @hdor_client.should_receive(:content_metadata).with(@fake_druid).and_return(ng_xml.root)
      @indexer.image_ids(@fake_druid).should == ['W188_000001_300.jp2']
    end
  end # image_ids method  
  
end