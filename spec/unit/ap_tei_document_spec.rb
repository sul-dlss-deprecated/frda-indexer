# encoding: UTF-8
require 'spec_helper'

require 'time'

describe ApTeiDocument do
  before(:all) do
    @volume = '36'
    @druid = 'aa222bb4444'
    @atd = ApTeiDocument.new(@druid, @volume)
    @parser = Nokogiri::XML::SAX::Parser.new(@atd)
  end
  
  context "initialize" do
    it "should set druid attribute" do
      @atd.druid.should == @druid
    end
    it "should set volume attribute" do
      @atd.volume.should == @volume
    end
  end 
   
  context "start_document" do
    it "should call init_doc_hash" do
      @atd.should_receive(:init_doc_hash).and_call_original
      x = "<TEI.2><teiHeader id='666'></TEI.2>"
      @parser.parse(x)
    end
  end
  
  context "init_doc_hash" do
    before(:all) do
      x = "<TEI.2><teiHeader id='666'></TEI.2>"
      @parser.parse(x)
    end
    it "should populate druid field" do
      @atd.doc_hash[:druid].should == @druid
    end
    it "should populate collection_si field" do
      @atd.doc_hash[:collection_si].should == ApTeiDocument::COLL_VAL
    end
    it "should populate volume_ssi field" do
      @atd.doc_hash[:volume_ssi].should == @volume
    end
    it "should get date fields in UTC form (1995-12-31T23:59:59Z)" do
      val = @atd.doc_hash[:date_start_dti]
      val.should end_with 'Z'
      Time.xmlschema(val).xmlschema.should == val # also ensures it doesn't throw parsing error
      val = @atd.doc_hash[:date_end_dti]
      val.should end_with 'Z'
      Time.xmlschema(val).xmlschema.should == val
    end
  end # init_doc_hash
  
  context "<text>" do
    context "<body>" do
      context '<div2 type="session">' do
        
      end
      context "<pb> (page break) element" do
        it "should write the previous page doc_hash to Solr" do
          pending "to be implemented"
        end
        context "reset doc_hash" do
          it "should zero out the page content fields" do
            pending "to be implemented"
          end
          it "should keep the current context fields" do
            pending "to be implemented"
          end
        end
      end
    end # <body>
  end # <text>
  
  context "add_doc_to_solr" do
    it "should always have a druid" do
      pending "to be implemented"
    end
    it "solr doc should always include volume context fields" do
      pending "to be implemented"
    end
    
  end
  
end