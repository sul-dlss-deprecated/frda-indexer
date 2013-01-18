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
    it "page before <body> section should not go to Solr" do
      x = "<TEI.2><text><front>
            <div type=\"frontpiece\">
                <pb n=\"\" id=\"ns351vc7243_00_0001\"/> 
                <p>ARCHIVES PARLEMENTAIRES </p>
            </div>
            <div type=\"abstract\">
                <pb n=\"ii\" id=\"ns351vc7243_00_0002\"/>
            </div></front></text></TEI.2>"
      RSolr::Client.any_instance.should_not_receive(:add).with(hash_including(:id => 'ns351vc7243_00_0001'))
      @parser.parse(x)
    end
    it "should not write a doc to Solr if there was no indexed content in the page" do
      id = "blank_page"
      x = "<TEI.2><text><body>
             <div1 type=\"volume\" n=\"20\">
              <pb n=\"\" id=\"#{id}\"/>
              <pb n=\"1\" id=\"pz516hw4711_00_0005\"/>
            </div1></body></text></TEI.2>"
      RSolr::Client.any_instance.should_not_receive(:add).with(hash_including(:id => id))
      @parser.parse(x)
    end
    context "when page has indexed content" do
      before(:all) do
        @id = "non_blank_page"
        @x = "<TEI.2><text><body>
               <div1 type=\"volume\" n=\"20\">
                <pb n=\"1\" id=\"#{@id}\"/>
                <div2 type=\"session\">
                 <p>La séance est ouverte à neuf heures du matin. </p>
                 <pb n=\"2\" id=\"next_page\"/>
                </div2></div1></body></text></TEI.2>"        
      end
      it "should write a doc to Solr" do
        pending "to be implemented"
        exp_flds = [{:id => @id}, :druid, :collection_si, :volume_ssi, :date_start_dti, :date_end_dti]
        RSolr::Client.any_instance.should_receive(:add).with(hash_including(exp_flds))
        @parser.parse(@x)
      end
      it "should call init_doc_hash" do
        pending "to be implemented"
        @atd.should_receive(:init_doc_hash)
        @parser.parse(@x)
      end
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