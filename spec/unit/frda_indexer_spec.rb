# encoding: utf-8
require 'spec_helper'

describe FrdaIndexer do
  
  before(:all) do
    config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "ap_oai_test.yml")
    @fi = FrdaIndexer.new(config_yml_path)
    require 'yaml'
    @yaml = YAML.load_file(config_yml_path)
  end
  
  describe "logging" do
    it "should write the log file to the directory indicated by log_dir" do
      @fi.logger.info("frda_indexer_spec logging test message")
      File.exists?(File.join(@yaml['log_dir'], @yaml['log_name'])).should == true
    end
  end
  
  context "index_ap" do
    it "should get a list of AP druids via OAI" do
      pending "to be implemented"
      harvestdor = double()
      harvestdor.should_receive(:harvest_ids)
      fi = FrdaIndexer.new
      fi.harvestdor = harvestdor
      fi.index_ap
      pending "to be implemented"
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
    
  end
  
end