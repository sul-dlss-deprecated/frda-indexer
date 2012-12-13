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

  it "should initialize the harvestdor_client from the config" do
    @fi.harvestdor_client.should be_an_instance_of(Harvestdor::Client)
    @fi.harvestdor_client.config.default_set.should == @yaml['default_set']
  end
  
  it "druids method should call druids_via_oai method on harvestdor_client" do
    @fi.harvestdor_client.should_receive(:druids_via_oai)
    @fi.druids
  end
  
  it "mods method should call mods method on harvestdor_client" do
    @fi.harvestdor_client.should_receive(:mods).with('oo000oo0000')
    @fi.mods('oo000oo0000')
  end
  
end