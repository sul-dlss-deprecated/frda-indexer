# encoding: UTF-8
require 'spec_helper'

require 'time'

describe ApTeiDocument do
  before(:all) do
    @volume = '36'
    @druid = 'aa222bb4444'
    @rsolr_client = RSolr::Client.new('http://somewhere.org')
    @atd = ApTeiDocument.new(@rsolr_client, @druid, @volume)
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
    it "should populate volume_title_ssi" do
      @atd.doc_hash[:volume_title_ssi].should == 'Tome 36 : Du 11 décembre 1791 au 1er janvier 1792'
    end
    it "should get volume date fields in UTC form (1995-12-31T23:59:59Z)" do
      val = @atd.doc_hash[:date_start_dti]
      val.should end_with 'Z'
      Time.xmlschema(val).xmlschema.should == val # also ensures it doesn't throw parsing error
      val = @atd.doc_hash[:date_end_dti]
      val.should end_with 'Z'
      Time.xmlschema(val).xmlschema.should == val
    end
  end # init_doc_hash
  
  context "add_doc_to_solr" do
    context "when page has no indexed content (<p>)" do
      it "pages in <front> section should not go to Solr" do
        x = "<TEI.2><text><front>
              <div type=\"frontpiece\">
                  <pb n=\"\" id=\"ns351vc7243_00_0001\"/>
                  <p>blah blah</p>
              </div>
              <div type=\"abstract\">
                  <pb n=\"ii\" id=\"ns351vc7243_00_0002\"/>
              </div></front></text></TEI.2>"
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'ns351vc7243_00_0001'))
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'ns351vc7243_00_0002'))
        @parser.parse(x)
      end
      it "blank page at beginning of body should not go to Solr" do
        x = "<TEI.2><text><body>
               <div1 type=\"volume\" n=\"20\">
                <pb n=\"\" id=\"pz516hw4711_00_0004\"/>
                <head>blah</head>
                <pb n=\"1\" id=\"pz516hw4711_00_0005\"/>
              </div1></body></text></TEI.2>"
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'pz516hw4711_00_0004'))
        @parser.parse(x)
      end
      it "blank page at end of body should not go to Solr" do
        x = "<TEI.2><text><body>
                <pb n=\"810\" id=\"tq360bc6948_00_0813\"/>
                <p>blah blah</p>
                <pb n=\"811\" id=\"tq360bc6948_00_0814\"/>
                <pb n=\"812\" id=\"tq360bc6948_00_0815\"/>
              </div1></body></text></TEI.2>"
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0814'))
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0815'))
        @parser.parse(x)
      end
      it "pages in <back> section should not go to Solr" do
        x = "<TEI.2><text><back>
          <div1 type=\"volume\" n=\"14\">
            <pb n=\"813\" id=\"tq360bc6948_00_0816\"/>
            <div2 type=\"contents\">
              <head>TABLE CHRONOLOGIQUE</head>
              <p>blah blah</p>
            </div2>
          </div1>
          <div1 type=\"volume\" n=\"14\">
              <pb n=\"814\" id=\"tq360bc6948_00_0817\"/>
          </div1></back></text></TEI.2>"
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0816'))
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0817'))
        @parser.parse(x)
      end
    end # when no indexed content
    context "when page has indexed content (<p>)" do
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
      it "should write the doc to Solr" do
        @rsolr_client.should_receive(:add).with(hash_including(:druid, :collection_si, :volume_ssi, :date_start_dti, :date_end_dti, :id => @id))
        @parser.parse(@x)
      end
      it "should call init_doc_hash" do
        @atd.should_receive(:init_doc_hash).twice.and_call_original
        @rsolr_client.should_receive(:add)
        @parser.parse(@x)
      end
    end # when indexed content
  end # add_doc_to_solr

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