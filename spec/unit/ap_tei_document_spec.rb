# encoding: UTF-8
require 'spec_helper'

require 'time'

describe ApTeiDocument do
  before(:all) do
    @volume = '36'
    @druid = 'aa222bb4444'
    @atd = ApTeiDocument.new(nil, @druid, @volume)
    @parser = Nokogiri::XML::SAX::Parser.new(@atd)
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
  
  context "add_doc_to_solr" do
    # write @doc_hash to Solr and reinitialize @doc_hash, but only if the current page has content
    it "solr doc should always include volume context fields" do
      pending "to be implemented"
    end
    it "should not write a doc to solr if there was no indexed content in the page" do
      id = "blank_page"
      x = "<TEI.2><text><body>
                   <div1 type=\"volume\" n=\"20\">
                    <pb n=\"\" id=\"#{id}\"/>
                    <pb n=\"1\" id=\"pz516hw4711_00_0005\"/>
                  </div1></body></text></TEI.2>"
      RSolr::Client.any_instance.should_not_receive(:add).with(hash_including(id))
      @parser.parse(x)
    end
    it "should write a doc to solr if there was indexed content in the page" do
      pending "to be implemented"
      id = "non_blank_page"
      x = "<TEI.2><text><body>
                   <div1 type=\"volume\" n=\"20\">
                    <pb n=\"1\" id=\"#{id}\"/>
                    <div2 type=\"session\">
                     <p>La séance est ouverte à neuf heures du matin. </p>
                     <pb n=\"2\" id=\"next_page\"/>
                    </div2></div1></body></text></TEI.2>"
      RSolr::Client.any_instance.should_receive(:add).with(hash_including(id))
      @parser.parse(x)
    end
    it "should call init_doc_hash if it writes to solr" do
      pending "to be implemented"
    end
  end

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
  
  
end