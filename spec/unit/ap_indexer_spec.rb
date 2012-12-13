# encoding: utf-8
require 'spec_helper'

describe ApIndexer do
  
  before(:all) do
    config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "ap_oai_test.yml")
    @indexer = ApIndexer.new(config_yml_path)
    @ap_druids = @indexer.druids
  end
  
  it "should get a list of AP druids via OAI" do
    @ap_druids.size.should > 80
    @ap_druids.size.should < 100
    @ap_druids.first.should =~ /^[a-z]{2}\d{3}[a-z]{2}\d{4}/
  end
  
  it "should get the right set" do
    pending "to be implemented"
  end
  
  it "should get the TEI for each AP druid" do
    pending "to be implemented"
  end
  
  it "should get the MODS for each AP druid" do
    pending "to be implemented"
  end
  
  it "should create a correct Solr doc" do
    pending "to be implemented"
  end

end