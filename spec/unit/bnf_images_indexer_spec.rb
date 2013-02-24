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
    @mods_xml = "<mods #{@ns_decl}><note>hi</note></mods>"
    @ng_mods_xml = Nokogiri::XML(@mods_xml)
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
    
  end # index method

  context ":image_id_ssm field" do
    it "should be the value of image_ids method" do
      @hdor_client.should_receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      @content_md_start = "<contentMetadata objectId='#{@fake_druid}'>"
      @content_md_end = "</contentMetadata>"
      ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><file id='W188_000001_300.jp2'/></resource>#{@content_md_end}")
      @hdor_client.should_receive(:content_metadata).with(@fake_druid).and_return(ng_xml.root)
      @indexer.should_receive(:image_ids).with(@fake_druid).and_call_original
      @solr_client.should_receive(:add).with(hash_including(:image_id_ssm => ['W188_000001_300.jp2']))
      @indexer.index(@fake_druid)
    end
  end

  context "fields from mods" do
    before(:each) do
      @hdor_client.should_receive(:content_metadata).with(@fake_druid).at_least(:once).and_return(nil)      
    end
    it ":mods_xml" do
      @hdor_client.should_receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      @solr_client.should_receive(:add).with(hash_including(:mods_xml))
      @indexer.index(@fake_druid)
    end
    context "title fields" do
      it ":title_short_ftsi should be Stanford::Mods::Record.sw_short_title" do
        mods_xml = "<mods #{@ns_decl}><titleInfo><title>basic</title></titleInfo></mods>"
        @hdor_client.should_receive(:mods).with(@fake_druid).at_least(:twice).and_return(Nokogiri::XML(mods_xml))
        @solr_client.should_receive(:add).with(hash_including(:title_short_ftsi => @indexer.smods_rec(@fake_druid).sw_short_title))
        @indexer.index(@fake_druid)
      end
      it ":title_long_ftsi should be Stanford::Mods::Record.sw_full_title" do
        mods_xml = "<mods #{@ns_decl}><titleInfo><title>basic</title></titleInfo></mods>"
        @hdor_client.should_receive(:mods).with(@fake_druid).at_least(:twice).and_return(Nokogiri::XML(mods_xml))
        @solr_client.should_receive(:add).with(hash_including(:title_long_ftsi => @indexer.smods_rec(@fake_druid).sw_full_title))
        @indexer.index(@fake_druid)
      end
      it ":title_short_ftsi should be absent if the data is absent from the MODS record" do
        @hdor_client.should_receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        @solr_client.should_receive(:add).with(hash_not_including(:title_short_ftsi))
        @indexer.index(@fake_druid)
      end
      it ":title_long_ftsi should be absent if the data is absent from the MODS record" do
        @hdor_client.should_receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        @solr_client.should_receive(:add).with(hash_not_including(:title_long_ftsi))
        @indexer.index(@fake_druid)
      end
    end
    context ":genre_ssim" do
      it "should be the contents of the MODS <genre> fields" do
        mods_xml = "<mods #{@ns_decl}><genre>one</genre><genre>two</genre></mods>"
        @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods_xml))
        @solr_client.should_receive(:add).with(hash_including(:genre_ssim => ['one', 'two']))
        @indexer.index(@fake_druid)
      end
      it "should be absent if there are no <genre> fields in the MODS record" do
        @hdor_client.should_receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        @solr_client.should_receive(:add).with(hash_not_including(:genre_ssim))
        @indexer.index(@fake_druid)
      end
    end
    context "MODS <physicalDescription>" do
      before(:each) do
        @mods_pd = "<mods #{@ns_decl}>
                      <physicalDescription>
                        <form authority=\"gmd\">Image fixe</form>
                        <form authority=\"marccategory\">nonprojected graphic</form>
                        <form authority=\"marcsmd\">print</form>
                        <extent>1 est. : manière noire ; 51 x 37,5 cm (tr. c.)</extent>
                      </physicalDescription></mods>"
      end
      context ":doc_type_ssim" do
        it "should be the contents of the MODS <physicalDescription><form> fields" do
          @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(@mods_pd))
          @solr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ['Image fixe', 'nonprojected graphic', 'print']))
          @indexer.index(@fake_druid)
        end
        it "should be absent if there are no <physicalDescription> fields in the MODS record" do
          @hdor_client.should_receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
          @solr_client.should_receive(:add).with(hash_not_including(:doc_type_ssim))
          @indexer.index(@fake_druid)
        end
        it "should be absent if there are no <physicalDescription><form> fields in the MODS record" do
          mods_xml = "<mods #{@ns_decl}><physicalDescription><extent>basic</extent></physicalDescription></mods>"
          @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods_xml))
          @solr_client.should_receive(:add).with(hash_not_including(:medium_ssi))
          @indexer.index(@fake_druid)
        end
      end
      context ":medium_ssi" do
        it "should be the contents of the MODS <physicalDescription><extent> field between the colon and the semicolon" do
          @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(@mods_pd))
          @solr_client.should_receive(:add).with(hash_including(:medium_ssi => 'manière noire'))
          @indexer.index(@fake_druid)
        end
        it "should be absent if there are no <physicalDescription> fields in the MODS record" do
          @hdor_client.should_receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
          @solr_client.should_receive(:add).with(hash_not_including(:medium_ssi))
          @indexer.index(@fake_druid)
        end
        it "should be absent if there are no <physicalDescription><extent> fields in the MODS record" do
          mods_xml = "<mods #{@ns_decl}><physicalDescription><form>basic</form></physicalDescription></mods>"
          @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods_xml))
          @solr_client.should_receive(:add).with(hash_not_including(:medium_ssi))
          @indexer.index(@fake_druid)
        end
      end
    end # <physicalDescription>

=begin    
          :speaker_ssim => '', #-> subject name e.g. bg698df3242
          :collector_ssim => '', # name w role col, or dnr
          :artist_ssim => '', # name w role art, egr, ill, scl, drm

          :doc_type_ssim => '', # physicalDescription/form 
          :medium_ssi => '', #  physicalDescription_extent_sim  -  between colon and semicolon

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