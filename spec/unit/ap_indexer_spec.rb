# encoding: utf-8
require 'spec_helper'

describe ApIndexer do
  
  before(:all) do
    @config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "ap_oai_test.yml")
    @indexer = ApIndexer.new(@config_yml_path)
    @hdor_client = @indexer.send(:harvestdor_client)
    @fake_druid = 'oo000oo0000'
    @vol_str = 'Volume 36'
    @im_ng = Nokogiri::XML("<identityMetadata><objectLabel>#{@vol_str}</objectLabel></identityMetadata>")
  end
  
  context "index method" do
    before(:all) do
      @atd = ApTeiDocument.new(@indexer.solr_client, @fake_client, @vol_str, {}, {}, @indexer.logger)
      @parser = Nokogiri::XML::SAX::Parser.new(@atd)
      @ng_pub_xml = Nokogiri::XML("<publicObject>
                                    <contentMetadata>
                                      <resource type=\"object\" sequence=\"1\">
                                        <label>Object 1</label>
                                      </resource>
                                    </contentMetadata>
                                  </publicObject>")
    end
    before(:each) do
      @indexer.should_receive(:druids).and_return(['1', '2', '3'])
    end

    it "should initialize an ApTeiDocument and do SAX parse of TEI for each druid" do
      OpenURI.should_receive(:open_uri).with(any_args).at_least(3).times.and_return('<TEI.2>fa</TEI.2>') 
      Nokogiri::XML::SAX::Parser.should_receive(:new).with(an_instance_of(ApTeiDocument)).exactly(3).times.and_return(@parser)
      @parser.should_receive(:parse).at_least(3).times
      @indexer.should_receive(:public_xml).exactly(3).times.and_return(@ng_pub_xml)
      @indexer.should_receive(:volume).at_least(3).times.and_return("1")
      @indexer.solr_client.should_receive(:commit).at_least(3).times
      @indexer.harvest_and_index
    end
    it "should call :commit on solr_client for each druid" do
      OpenURI.should_receive(:open_uri).with(any_args).at_least(3).times.and_return('<TEI.2>la</TEI.2>')
      @indexer.should_receive(:public_xml).exactly(3).times.and_return(@ng_pub_xml)
      @indexer.should_receive(:volume).at_least(3).times.and_return("1")
      @indexer.solr_client.should_receive(:commit).at_least(3).times
      @indexer.harvest_and_index
    end    
  end

  context "harvests the right stuff", :integration => true do
    before(:all) do
      @ap_druids = @indexer.druids
      @druid1 = @ap_druids.first
    end
    it "should get a list of AP druids via OAI" do
      @ap_druids.size.should > 80
      @ap_druids.size.should < 100
      @druid1.should =~ /^[a-z]{2}\d{3}[a-z]{2}\d{4}/
    end
    it "should get the right set (per identityMetadata)" do
      @hdor_client.identity_metadata(@druid1).to_s.should =~ /Archives Parlementaires/
    end
    it "should get the right set (per collection id)" do
      @hdor_client.rdf(@druid1).remove_namespaces!.root.xpath('//isMemberOfCollection/@resource').text.should == 'info:fedora/druid:jh957jy1101'
    end    
  end

  context "volume method" do
    it "should get the identityMetadata via the harvestdor client" do
      @hdor_client.should_receive(:identity_metadata).with(@fake_druid).and_return(@im_ng)
      @indexer.volume(@fake_druid)
    end
    it "should get the volume from the identityMetadata objectLabel" do
      @hdor_client.should_receive(:identity_metadata).with(@fake_druid).and_return(@im_ng)
      @indexer.volume(@fake_druid).should == @vol_str
    end
  end
  
  context "tei method" do
    it "should get the tei from the digital stacks" do
      require 'yaml'
      yaml = YAML.load_file(@config_yml_path)
      url = "#{yaml['stacks']}/file/druid:#{@fake_druid}/#{@fake_druid}.xml"
      OpenURI.should_receive(:open_uri).with(URI.parse(url))
      @indexer.tei(@fake_druid)
    end
    it "should write a message to the log if it doesn't find the tei" do
      @indexer.logger.should_receive(:error).with('error while retrieving tei at https://stacks.stanford.edu/file/druid:oo000oo0000/oo000oo0000.xml -- 404 Not Found')
      @indexer.tei(@fake_druid)
    end
    it "should return empty TEI if it doesn't find the tei" do
      @indexer.logger.should_receive(:error)
      @indexer.tei(@fake_druid).should == "<TEI.2/>"
    end
  end
  
  context "public_xml - fields from it and methods pertaining to it" do
    before(:all) do
      @id_md_xml = "<identityMetadata><objectId>druid:#{@fake_druid}</objectId></identityMetadata>"
      @pdf_name = "bg262qk2288.pdf"
      @pdf_size = "2218576614"
      @tei_name = "bg262qk2288.xml"
      @tei_size = "6885841"
      @last_page_num = "806"
      @cntnt_md_xml = "<contentMetadata type=\"book\" objectId=\"bg262qk2288\">
                        <resource type=\"object\" sequence=\"1\" id=\"bg262qk2288_1\">
                          <label>Object 1</label>
                          <file id=\"#{@pdf_name}\" mimetype=\"application/pdf\" size=\"#{@pdf_size}\"> </file>
                          <file id=\"bg262qk2288.rtf\" mimetype=\"text/rtf\" size=\"13093220\"> </file>
                          <file id=\"#{@tei_name}\" mimetype=\"application/xml\" size=\"#{@tei_size}\">  </file>
                        </resource>
                        <resource type=\"page\" sequence=\"2\" id=\"bg262qk2288_2\">
                          <label>Page 1</label>
                          <file id=\"bg262qk2288_99_0001.txt\" mimetype=\"text/plain\" size=\"27\">  </file>
                          <file id=\"bg262qk2288_00_0001.jp2\" mimetype=\"image/jp2\" size=\"2037015\">
                            <imageData width=\"2645\" height=\"4063\"/>
                          </file>
                        </resource>
                        <resource type=\"page\" sequence=\"3\" id=\"bg262qk2288_3\">
                          <label>Page 2</label>
                          <file id=\"bg262qk2288_99_0002.txt\" mimetype=\"text/plain\" size=\"77\"> </file>
                          <file id=\"bg262qk2288_00_0002.jp2\" mimetype=\"image/jp2\" size=\"2037227\">
                            <imageData width=\"2645\" height=\"4063\"/>
                          </file>
                        </resource>
                        <resource type=\"page\" sequence=\"806\" id=\"bg262qk2288_806\">
                          <label>Page 805</label>
                          <file id=\"bg262qk2288_99_0805.txt\" mimetype=\"text/plain\" size=\"6367\"> </file>
                          <file id=\"bg262qk2288_00_0805.jp2\" mimetype=\"image/jp2\" size=\"2037621\">
                            <imageData width=\"2645\" height=\"4063\"/>
                          </file>
                        </resource>
                        <resource type=\"page\" sequence=\"807\" id=\"bg262qk2288_807\">
                          <label>Page #{@last_page_num}</label>
                          <file id=\"bg262qk2288_99_0806.txt\" mimetype=\"text/plain\" size=\"1011\"> </file>
                          <file id=\"bg262qk2288_00_0806.jp2\" mimetype=\"image/jp2\" size=\"2037375\">
                            <imageData width=\"2645\" height=\"4063\"/>
                          </file>
                        </resource>
                      </contentMetadata>"
      @pub_xml = "<publicObject id='druid:#{@fake_druid}'>#{@id_md_xml}#{@cntnt_md_xml}</publicObject>"
      @ng_pub_xml = Nokogiri::XML(@pub_xml)
    end
    context "#page_id_hash" do
      before(:all) do
        @page_id_hash = @indexer.page_id_hash(Nokogiri::XML(@cntnt_md_xml))
      end
      it "should be populated properly" do
        @page_id_hash.size.should == 4
        @page_id_hash.should == {'bg262qk2288_00_0001' => 1, 'bg262qk2288_00_0002' => 2, 'bg262qk2288_00_0805' => 805, 'bg262qk2288_00_0806' => 806}
      end
    end
    context "#vol_constants_hash" do
      before(:all) do
        @result_hash = @indexer.vol_constants_hash Nokogiri::XML(@cntnt_md_xml)
      end
      it "should populate :vol_pdf_name_ss field" do
        @result_hash[:vol_pdf_name_ss].should == @pdf_name
      end
      it "should populate :vol_pdf_size_is field" do
        @result_hash[:vol_pdf_size_is].should == @pdf_size.to_i
      end
      it "should populate :vol_tei_name_ss field" do
        @result_hash[:vol_tei_name_ss].should == @tei_name
      end
      it "should populate :vol_tei_size_is field" do
        @result_hash[:vol_tei_size_is].should == @tei_size.to_i
      end
      it "should populate :total_pages_is field" do
        @result_hash[:vol_total_pages_is].should == @last_page_num.to_i
      end
      it "should log warning if an expected value is missing" do
        pending "spec to be implemented"
      end
      it "should log warning if pdf size doesn't have an integer value" do
        cntnt_md_xml = "<contentMetadata type=\"book\" objectId=\"bg262qk2288\">
                          <resource type=\"object\" sequence=\"1\" id=\"bg262qk2288_1\">
                            <label>Object 1</label>
                            <file id=\"#{@pdf_name}\" mimetype=\"application/pdf\" size=\"foo\"> </file>
                            <file id=\"#{@tei_name}\" mimetype=\"application/xml\" size=\"#{@tei_size}\">  </file>
                          </resource>
                          <resource type=\"page\" sequence=\"2\" id=\"bg262qk2288_2\">
                            <label>Page 1</label>
                            <file id=\"bg262qk2288_00_0001.jp2\" mimetype=\"image/jp2\" size=\"2037015\" />
                          </resource>
                        </contentMetadata>"
        @indexer.logger.should_receive(:warn).with('bad value for PDF size: \'foo\'')
        @indexer.vol_constants_hash Nokogiri::XML(cntnt_md_xml)
      end
      it "should log warning if tei size doesn't have an integer value" do
        cntnt_md_xml = "<contentMetadata type=\"book\" objectId=\"bg262qk2288\">
                          <resource type=\"object\" sequence=\"1\" id=\"bg262qk2288_1\">
                            <label>Object 1</label>
                            <file id=\"#{@pdf_name}\" mimetype=\"application/pdf\" size=\"#{@pdf_size}\"> </file>
                            <file id=\"#{@tei_name}\" mimetype=\"application/xml\" size=\"bar\">  </file>
                          </resource>
                          <resource type=\"page\" sequence=\"2\" id=\"bg262qk2288_2\">
                            <label>Page 1</label>
                            <file id=\"bg262qk2288_00_0001.jp2\" mimetype=\"image/jp2\" size=\"2037015\" />
                          </resource>
                        </contentMetadata>"
        @indexer.logger.should_receive(:warn).with('bad value for TEI size: \'bar\'')
        @indexer.vol_constants_hash Nokogiri::XML(cntnt_md_xml)
      end
      it "should log warning if pdf size doesn't have an integer value" do
        cntnt_md_xml = "<contentMetadata type=\"book\" objectId=\"bg262qk2288\">
                          <resource type=\"object\" sequence=\"1\" id=\"bg262qk2288_1\">
                            <label>Object 1</label>
                            <file id=\"#{@pdf_name}\" mimetype=\"application/pdf\" size=\"#{@pdf_size}\"> </file>
                            <file id=\"#{@tei_name}\" mimetype=\"application/xml\" size=\"#{@tei_size}\">  </file>
                          </resource>
                          <resource type=\"page\" sequence=\"2\" id=\"bg262qk2288_2\">
                            <label>Page i</label>
                            <file id=\"bg262qk2288_99_0001.txt\" mimetype=\"text/plain\" size=\"27\">  </file>
                            <file id=\"bg262qk2288_00_0001.jp2\" mimetype=\"image/jp2\" size=\"2037015\">
                              <imageData width=\"2645\" height=\"4063\"/>
                            </file>
                          </resource>
                        </contentMetadata>"
        @indexer.logger.should_receive(:warn).with('Unable to parse integer page number from <resource><label> in contentMetadata: \'Page i\'')
        @indexer.vol_constants_hash Nokogiri::XML(cntnt_md_xml)
      end
    end # content_md_hash
    
  end # public_xml
  
end