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
  
  before(:each) do
    @hdor_client.should_receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
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
  end
  

  context ":image_id field" do
    
  end
  
  
 context "fields from and methods pertaining to contentMetadata" do
    before(:all) do
      @cntnt_md_type = 'image'
      @cntnt_md_xml = "<contentMetadata type='#{@cntnt_md_type}' objectId='#{@fake_druid}'></contentMetadata>"
      @pub_xml = "<publicObject id='druid:#{@fake_druid}'>#{@cntnt_md_xml}</publicObject>"
      @ng_pub_xml = Nokogiri::XML(@pub_xml)
    end
    before(:each) do
      @hdor_client = double()
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      @hdor_client.stub(:public_xml).with(@fake_druid).and_return(@ng_pub_xml)
      @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
    end

    it "content_md should get the contentMetadata from the public_xml" do
      content_md = @sdb.send(:content_md)
      content_md.should be_an_instance_of(Nokogiri::XML::Element)
      content_md.name.should == 'contentMetadata'
# NOTE:  the below isn't working -- probably due to Nokogiri attribute bug introduced      
  #    content_md.should be_equivalent_to(@cntnt_md_xml)
    end

    it "dor_content_type should be the value of the type attribute on the contentMetadata element" do
      @sdb.send(:dor_content_type).should == @cntnt_md_type
    end

    context "image_ids" do
      before(:all) do
        @content_md_start = "<contentMetadata objectId='#{@fake_druid}'>"
        @content_md_end = "</contentMetadata>"
      end
      before(:each) do
        @hdor_client = double()
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        @hdor_client.stub(:public_xml).with(@fake_druid).and_return(nil)
        @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
      end
      it "should be nil if there are no <resource> elements in the contentMetadata" do
        ng_xml = Nokogiri::XML("#{@content_md_start}#{@content_md_end}")
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.image_ids.should == nil
      end
      it "should ignore <resource> elements with attribute type other than 'image'" do
        ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='blarg'><file id='foo'/></resource>#{@content_md_end}")
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.image_ids.should == nil
      end
      it "should be ignore all but <file> element children of the image resource element" do
        ng_xml = ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><label id='foo'>bar</label></resource>#{@content_md_end}")
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.image_ids.should == nil
      end
      it "should be nil if there are no id elements on file elements" do
        ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><file/></resource>#{@content_md_end}")
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.image_ids.should == nil
      end
      it "should be an Array of size one if there is a single <resource><file id='something'> in the content metadata" do
        ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><file id='foo'/></resource>#{@content_md_end}")
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.image_ids.should == ['foo']
      end
      it "should be the same size as the number of <resource><file id='something'> in the content metadata" do
        ng_xml = Nokogiri::XML("#{@content_md_start}
              <resource type='image'><file id='foo'/></resource>
              <resource type='image'><file id='bar'/></resource>#{@content_md_end}")
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.image_ids.should == ['foo', 'bar']
      end
      it "endings of .jp2 should not be stripped" do
        ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><file id='W188_000001_300.jp2'/></resource>#{@content_md_end}")
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.image_ids.should == ['W188_000001_300.jp2']
      end
    end

  end # fields from and methods pertaining to contentMetadata
  
  
end