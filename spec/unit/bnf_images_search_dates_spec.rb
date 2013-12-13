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
    @unparseable_date = '1.er messidor 2.me année Rép'
    @smr = Stanford::Mods::Record.new
  end
  
  context "search_dates" do
    it "date should be in iso8601 zed format (YYYY-MM-DDThh:mm:ssZ)" do
      mods = "<mods #{@ns_decl}>
                <originInfo>
                  <dateIssued>April 1 1797</dateIssued>
                </originInfo>
              </mods>"
      @smr.from_str(mods)
      @indexer.search_dates(@smr, @fake_druid).should == ['1797-04-01T00:00:00Z']
    end
    it "should work for 4 digit year values" do
      mods = "<mods #{@ns_decl}>
                <originInfo>
                  <dateIssued encoding=\"marc\">1799</dateIssued>
                  <dateIssued>1797</dateIssued>
                </originInfo>
              </mods>"
      @smr.from_str(mods)
      @indexer.search_dates(@smr, @fake_druid).should == ['1799-01-01T00:00:00Z', '1797-01-01T00:00:00Z']
    end
    it "should work for 4 digit year values with brackets" do
      mods = "<mods #{@ns_decl}>
                <originInfo>
                  <dateIssued>[1781]</dateIssued>
                  <dateIssued>[1782</dateIssued>
                  <dateIssued>1783]</dateIssued>
                </originInfo>
              </mods>"
      @smr.from_str(mods)
      @indexer.search_dates(@smr, @fake_druid).should == ['1781-01-01T00:00:00Z', '1782-01-01T00:00:00Z', '1783-01-01T00:00:00Z']
    end
    it "should work for [ca yyyy] pattern" do
      mods = "<mods #{@ns_decl}>
                <originInfo>
                  <dateIssued>[ca 1790]</dateIssued>
                </originInfo>
                <originInfo>
                  <dateIssued>[Ca 1791]</dateIssued>
                </originInfo>
              </mods>"
      @smr.from_str(mods)
      @indexer.search_dates(@smr, @fake_druid).should == ['1790-01-01T00:00:00Z', '1791-01-01T00:00:00Z']
    end
    it "should work for ca yyyy] pattern" do
      mods = "<mods #{@ns_decl}>
                <originInfo>
                  <dateIssued>ca 1796]</dateIssued>
                </originInfo>
              </mods>"
      @smr.from_str(mods)
      @indexer.search_dates(@smr, @fake_druid).should == ['1796-01-01T00:00:00Z']
    end
    it "should work for [Entre yyyy et yyyy] pattern" do
      mods = "<mods #{@ns_decl}>
                <originInfo>
                  <dateIssued>entre 1745 et 1796]</dateIssued>
                  <dateIssued>[entre 1785 et 1786]</dateIssued>
                  <dateIssued>[Entre 1789 et 1791]</dateIssued>
                </originInfo>
              </mods>"
      @smr.from_str(mods)
      @indexer.search_dates(@smr, @fake_druid).should == ['1745-01-01T00:00:00Z', '1785-01-01T00:00:00Z', '1789-01-01T00:00:00Z']
    end
    it "should work for [yyyy ou yyyy] pattern" do
      mods = "<mods #{@ns_decl}>
                <originInfo>
                  <dateIssued>[1791 ou 1792]</dateIssued>
                </originInfo>
              </mods>"
      @smr.from_str(mods)
      @indexer.search_dates(@smr, @fake_druid).should == ['1791-01-01T00:00:00Z', '1792-01-01T00:00:00Z']
    end
    it "should work for [yyyy ?]' pattern" do
      mods = "<mods #{@ns_decl}>
                <originInfo>
                  <dateIssued>[1792 ?]</dateIssued>
                </originInfo>
              </mods>"
      @smr.from_str(mods)
      @indexer.search_dates(@smr, @fake_druid).should == ['1792-01-01T00:00:00Z']
    end
    it "should work for [yyyy-yyyy] pattern" do
      mods = "<mods #{@ns_decl}>
                <originInfo>
                  <dateIssued>[1720-1738]</dateIssued>
                </originInfo>
              </mods>"
      @smr.from_str(mods)
      @indexer.search_dates(@smr, @fake_druid).should == ['1720-01-01T00:00:00Z']
    end
    
    it "should not include duplicate dates" do
      mods = "<mods #{@ns_decl}>
                <originInfo>
                  <dateIssued>April 1 1797</dateIssued>
                  <dateIssued>April 1 1797</dateIssued>
                </originInfo>
              </mods>"
      @smr.from_str(mods)
      @indexer.search_dates(@smr, @fake_druid).should == ['1797-04-01T00:00:00Z']
    end
    it "should have a value for every parseable non-duplicated value in MODS" do
      mods = "<mods #{@ns_decl}>
                <originInfo>
                  <dateIssued>April 1 1797</dateIssued>
                  <dateIssued encoding=\"marc\">1797</dateIssued>
                  <dateIssued>April 1 1797</dateIssued>
                  <dateIssued>Feb.y 5 1793</dateIssued>
                </originInfo>
              </mods>"
      @smr.from_str(mods)
      @indexer.search_dates(@smr, @fake_druid).should == ['1797-04-01T00:00:00Z', '1793-02-05T00:00:00Z']
    end
    context "should not have spurious current year dates" do
      it "from random text and year 1798" do
        mods = "<mods #{@ns_decl}>
                  <originInfo>
                    <dateIssued>Jan.y. thes.et 1798</dateIssued>
                    <dateIssued encoding=\"marc\">1798</dateIssued>
                  </originInfo>
                </mods>"
        @smr.from_str(mods)
        @indexer.search_dates(@smr, @fake_druid).should == ['1798-01-01T00:00:00Z']
      end
      it "from text and year in brackets [1792]" do
        mods = "<mods #{@ns_decl}>
                  <originInfo>
                    <dateIssued>3 Jannary [1792]</dateIssued>
                    <dateIssued>January 22th [1800]</dateIssued>
                    <dateIssued encoding=\"marc\">1792</dateIssued>
                  </originInfo>
                </mods>"
        @smr.from_str(mods)
        @indexer.search_dates(@smr, @fake_druid).should == ['1792-01-01T00:00:00Z']
      end
      it "from month only" do
        mods = "<mods #{@ns_decl}>
                  <originInfo>
                    <dateIssued>Feb</dateIssued>
                    <dateIssued encoding=\"marc\">1793</dateIssued>
                  </originInfo>
                </mods>"
        @smr.from_str(mods)
        @indexer.search_dates(@smr, @fake_druid).should == ['1793-01-01T00:00:00Z']
      end
      it "from randome text and day and year" do
        mods = "<mods #{@ns_decl}>
                  <originInfo>
                    <dateIssued>mis au jour le 26 juillet 1794</dateIssued>
                    <dateIssued encoding=\"marc\">1794</dateIssued>
                  </originInfo>
                </mods>"
        @smr.from_str(mods)
        @indexer.search_dates(@smr, @fake_druid).should == ['1794-01-01T00:00:00Z']
      end
    end
    it "should return nil if there are no values" do
      mods = "<mods #{@ns_decl}><note>hi</note></mods>"
      @smr.from_str(mods)
      @indexer.logger.should_receive(:warn)
      @indexer.search_dates(@smr, @fake_druid).should == nil
    end

    context "log messages" do
      it "should print a WARN error when it can't parse a date (and there isn't another one it CAN parse?)" do
        mods = "<mods #{@ns_decl}>
                  <originInfo>
                    <dateIssued>#{@unparseable_date}</dateIssued>
                    <dateIssued>April 1 1797</dateIssued>
                  </originInfo>
                </mods>"
        @smr.from_str(mods)
        @indexer.logger.should_receive(:warn).with("#{@fake_druid} has unparseable originInfo/dateIssued value: '#{@unparseable_date}'")
        @indexer.search_dates(@smr, @fake_druid).should == ['1797-04-01T00:00:00Z']
      end
      it "should print a WARN when none of the originInfo/dateIssued values are parseable" do
        mods = "<mods #{@ns_decl}>
                  <originInfo>
                    <dateIssued>#{@unparseable_date}</dateIssued>
                  </originInfo>
                </mods>"
        @smr.from_str(mods)
        @indexer.logger.should_receive(:warn).with("#{@fake_druid} has unparseable originInfo/dateIssued value: '#{@unparseable_date}'")
        @indexer.logger.should_receive(:warn).with("#{@fake_druid} has no parseable originInfo/dateIssued value")
        @indexer.search_dates(@smr, @fake_druid).should == nil
      end
      it "should print a WARN when there is no originInfo date" do
        mods = "<mods #{@ns_decl}><note>hi</note></mods>"
        @smr.from_str(mods)
        @indexer.logger.should_receive(:warn).with("#{@fake_druid} has no originInfo/dateIssued field")
        @indexer.search_dates(@smr, @fake_druid).should == nil
      end
    end # log messages
  end # search_date

  context "in doc hash" do
    before(:each) do
      @hdor_client.should_receive(:content_metadata).and_return(nil)
    end
    
    it "search_date_dtsim should be in iso8601 zed format (YYYY-MM-DDThh:mm:ssZ)" do
      mods = "<mods #{@ns_decl}>
                <originInfo>
                  <dateIssued>April 1 1797</dateIssued>
                </originInfo>
              </mods>"
      @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
      @solr_client.should_receive(:add).with(hash_including(:search_date_dtsim => ['1797-04-01T00:00:00Z']))
      @indexer.index(@fake_druid)
    end
    it "should choose the most granular date even if it's not marc encoding" do
      mods = "<mods #{@ns_decl}>
                <originInfo>
                  <dateIssued>April 1 1797</dateIssued>
                  <dateIssued encoding=\"marc\">1797</dateIssued>
                </originInfo>
              </mods>"
      @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
      @solr_client.should_receive(:add).with(hash_including(:search_date_dtsim => ['1797-04-01T00:00:00Z']))
      @indexer.index(@fake_druid)
    end
    context "sort_date_dti" do
      it "if no search dates, it should be nil" do
        mods = "<mods #{@ns_decl}><note>hi</note></mods>"
        @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
        @solr_client.should_receive(:add).with(hash_not_including(:sort_date_dti))
        @indexer.index(@fake_druid)
      end
      it "if single search date, it should be the same" do
        mods = "<mods #{@ns_decl}>
                  <originInfo>
                    <dateIssued>April 1 1797</dateIssued>
                  </originInfo>
                </mods>"
        @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
        @solr_client.should_receive(:add).with(hash_including(:sort_date_dti => '1797-04-01T00:00:00Z'))
        @indexer.index(@fake_druid)
      end
      it "if multiple search dates, it should be the earliest one" do
        mods = "<mods #{@ns_decl}>
                  <originInfo>
                    <dateIssued>April 1 1797</dateIssued>
                    <dateIssued encoding=\"marc\">1797</dateIssued>
                    <dateIssued>April 1 1797</dateIssued>
                    <dateIssued>Feb.y 5 1793</dateIssued>
                  </originInfo>
                </mods>"
        @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
        @solr_client.should_receive(:add).with(hash_including(:sort_date_dti => '1793-02-05T00:00:00Z'))
        @indexer.index(@fake_druid)
      end
    end # sort_date_dti
  end # in doc hash

end