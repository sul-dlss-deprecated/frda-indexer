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
      @atd = ApTeiDocument.new(@indexer.solr_client, @fake_client, @vol_str, @indexer.logger)
      @parser = Nokogiri::XML::SAX::Parser.new(@atd)
    end
    before(:each) do
      @indexer.should_receive(:druids).and_return(['1', '2', '3'])
      @hdor_client.should_receive(:identity_metadata).with('1').and_return(@im_ng)
      @hdor_client.should_receive(:identity_metadata).with('2').and_return(@im_ng)
      @hdor_client.should_receive(:identity_metadata).with('3').and_return(@im_ng)
    end

    it "should initialize an ApTeiDocument and do SAX parse of TEI for each druid" do
      OpenURI.should_receive(:open_uri).with(any_args).exactly(3).times.and_return('<TEI.2/>') 
      Nokogiri::XML::SAX::Parser.should_receive(:new).with(an_instance_of(ApTeiDocument)).exactly(3).times.and_return(@parser)
      @parser.should_receive(:parse).at_least(3).times
      @indexer.solr_client.should_receive(:commit).at_least(3).times
      @indexer.harvest_and_index
    end
    it "should call :commit on solr_client for each druid" do
      OpenURI.should_receive(:open_uri).with(any_args).exactly(3).times.and_return('<TEI.2/>')
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
  
end