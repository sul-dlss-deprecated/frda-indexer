# encoding: utf-8
require 'spec_helper'

describe ApIndexer do
  
  before(:all) do
    config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "ap_oai_test.yml")
    @indexer = ApIndexer.new(config_yml_path)
    @ap_druids = @indexer.druids
    @druid1 = @ap_druids.first    
  end
  
  it "should get a list of AP druids via OAI" do
    @ap_druids.size.should > 80
    @ap_druids.size.should < 100
    @druid1.should =~ /^[a-z]{2}\d{3}[a-z]{2}\d{4}/
  end
  
  it "should get the right set (per identityMetadata)" do
    @indexer.harvestdor_client.identity_metadata(@druid1).to_s.should =~ /Archives Parlementaires/
  end
  
  it "should get the right set (per collection id)" do
    @indexer.harvestdor_client.rdf(@druid1).remove_namespaces!.root.xpath('//isMemberOfCollection/@resource').text.should == 'info:fedora/druid:jh957jy1101'
  end

  it "should get the MODS for each AP druid" do
    mods = @indexer.mods(@druid1)
    mods.should be_kind_of(Nokogiri::XML::Document)
    mods.root.name.should == 'mods'
    mods.root.namespace.href.should == Harvestdor::MODS_NAMESPACE
    mods.root.xpath('/m:mods/m:titleInfo/m:title', {'m'=>Harvestdor::MODS_NAMESPACE}).text.should =~ /Archives Parlementaires/i
  end
  
  context "TEI" do
    it "tei method should call digital_stacks method on harvestdor_client" do
      pending "to be implemented"
    end
    
    it "should get the TEI for each AP druid" do
      pending "to be implemented"
    end
  end
  
  it "should create a correct Solr doc" do
    pending "to be implemented"
  end

end