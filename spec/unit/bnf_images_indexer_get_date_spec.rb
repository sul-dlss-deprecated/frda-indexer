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
    @content_md_start = "<contentMetadata objectId='#{@fake_druid}'>"
    @content_md_end = "</contentMetadata>"
  end
  before(:each) do
    @hdor_client.should_receive(:content_metadata).and_return(nil)
  end
  
  context "priority order" do
    it "should take date from originInfo if it can" do
      pending "to be implemented"
    end
    it "should take from subect temporal if no originInfo" do
      pending "to be implemented"
    end
    it "should take from note date de creation if no originInfo or temporal" do
      pending "to be implemented"
    end
    it "should take from artist dates if no other is avail" do
      pending "to be implemented"
    end
  end
  
  context "from originInfo" do
    before(:all) do
      @mods_sub_cat_head = "<mods #{@ns_decl}>
                    <originInfo>
                        <dateIssued>[ca 1799]</dateIssued>
                        <dateIssued encoding=\"marc\">1799</dateIssued>
                        <dateIssued encoding=\"marc\">1799</dateIssued>
                      </originInfo>
                      <originInfo>
                          <dateIssued>[1790]</dateIssued>
                          <dateIssued encoding=\"marc\">1790</dateIssued>
                        </originInfo>
                        <originInfo>
                            <dateIssued>April 1 1797</dateIssued>
                            <dateIssued encoding=\"marc\">1797</dateIssued>
                          </originInfo>
                          <originInfo>
                              <dateIssued>May 9, 1795</dateIssued>
                              <dateIssued encoding=\"marc\">1795</dateIssued>
                            </originInfo>
                      <originInfo>
                      </originInfo>
                  </mods>"
    end
    # search_date_dtsim    1791-12-11T00:00:00Z
    it "should choose the most granular date even if it's not marc encoding" do
      mods = "<mods #{@ns_decl}>
                <originInfo>
                  <dateIssued>April 1 1797</dateIssued>
                  <dateIssued encoding=\"marc\">1797</dateIssued>
                </originInfo>
              </mods>"
      @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
      @solr_client.should_receive(:add).with(hash_including(:search_date_dtsim => '1797-04-01T00:00:00Z'))
      @indexer.index(@fake_druid)
    end
    it "should deal with year only (no month or day) if that's the best we've got" do
      pending "to be implemented"
    end
    it "should choose the marc date for the year only?" do
      pending "to be implemented"
      # marc – This value identifies formatted according to MARC 21 rules in field 008/07-14 for dates of publication/issuance. 
      # Thus, this would only apply to the attribute in <dateIssued>. 
      # Examples include: YYYY (for year), MMDD (for month and day), 
      # 19uu (MARC convention showing unknown digits in a year date), 
      # 9999 (MARC convention showing that the end year date has not occurred or is not known). 
      # See Legal Characters section under field 008/06 of MARC Bibliographic
      #  (from http://www.loc.gov/standards/mods/userguide/generalapp.html#list)
    end
    
    # parses!
    # le 1er septembre 1791
    it "should remove square brackets" do
      pending "to be implemented"
    end
    it "should remove trailing period" do
      pending "to be implemented"
    end
    it "should remove preceding Anno" do
      pending "to be implemented"
      # Anno 1803 -> if no marc one  (also anno)
    end
    # [Entre 1789 et 1791] -> if no marc one
    # [entre 1500 et 1599]
    # [1782] -> if no marc one  (missing open bracket)
    # [ca 1798]  -> if no marc one (missing open bracket)
    it "should print a WARN error when it can't parse a date (and there isn't another one it CAN parse?)" do
      pending "to be implemented"
    end
    it "should print a WARN when there is no originInfo date" do
      pending "to be implemented"
    end    
  end
end