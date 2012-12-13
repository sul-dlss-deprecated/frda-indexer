# encoding: utf-8
require 'spec_helper'

describe FrdaIndexer do
  
  before(:all) do
    config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "ap_oai_test.yml")
    @fi = FrdaIndexer.new(config_yml_path)
  end
  
  describe "OAI harvesting" do
    it "should get the druids from OAI per values in the yml file" do
      druids = @fi.druids
      druids.should be_an_instance_of(Array)
      druids.size.should > 80
      druids.first.should =~ /^[a-z]{2}\d{3}[a-z]{2}\d{4}/
    end
  end

end