# encoding: UTF-8
require 'spec_helper'

describe ApTeiDocument do
  before(:all) do
    @volume = 'Volume 36'
    @druid = 'aa222bb4444'
    @vol_constants_hash = { :vol_pdf_name_ss => 'aa222bb4444.pdf',
                            :vol_pdf_size_ls => 2218576614,
                            :vol_tei_name_ss => 'aa222bb4444.xml',
                            :vol_tei_size_is => 6885841,
                            :vol_total_pages_is => 806  }
    page_id_hash = { "#{@druid}_00_0001" => 1, 
                      "#{@druid}_00_0002" => 2, 
                      "#{@druid}_00_0805" => 805, 
                      "#{@druid}_00_0806" => 806}
    @rsolr_client = RSolr::Client.new('http://somewhere.org')
    @logger = Logger.new(STDOUT)
    @atd = ApTeiDocument.new(@rsolr_client, @druid, @volume, @vol_constants_hash, page_id_hash, @logger)
    @parser = Nokogiri::XML::SAX::Parser.new(@atd)
    @start_tei_body_div1 = "<TEI.2><text><body><div1 type=\"volume\" n=\"36\">"
    @start_tei_body_div2_session = "#{@start_tei_body_div1}<div2 type=\"session\">"
    @end_div1_body_tei = "</div1></body></text></TEI.2>"
    @end_div2_body_tei = "</div2>#{@end_div1_body_tei}"
    @start_tei_back_div1 = "<TEI.2><text><back><div1 type=\"volume\" n=\"44\">"
    @end_div1_back_tei = "</div1></back></text></TEI.2>"
    @end_div2_back_tei = "</div2>#{@end_div1_back_tei}"
  end

  context "start_document" do
    it "should call init_page_doc_hash" do
      @atd.should_receive(:init_page_doc_hash)
      x = "<TEI.2><teiHeader id='666'></TEI.2>"
      @parser.parse(x)
    end
  end
  
  context "init_page_doc_hash" do
    before(:all) do
      @x = "<TEI.2><teiHeader id='666'></teiHeader></TEI.2>"
    end
    it "should populate type_ssi field" do
      @parser.parse(@x)
      @atd.page_doc_hash[:type_ssi].should == ApTeiDocument::PAGE_TYPE
    end
    it "should call add_vol_fields_to_hash for page_doc_hash" do
      @atd.should_receive(:init_page_doc_hash).and_call_original
      @atd.should_receive(:add_vol_fields_to_hash).with({:type_ssi => ApTeiDocument::PAGE_TYPE})
      @parser.parse(@x)
    end
    it "should not populate doc_type_ssim if it is not in a div2" do
      @parser.parse(@x)
      @atd.page_doc_hash[:doc_type_ssim].should == nil
    end
    it "should populate doc_type_ssim if it is in a div2" do
      x = @start_tei_body_div2_session +
          "<pb n=\"5\" id=\"#{@druid}_00_0001\"/>
          <p>actual content</p>
          <pb n=\"6\" id=\"#{@druid}_00_0002\"/>" + @end_div2_body_tei
      @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => [ApTeiDocument::DIV2_TYPE['session']], :id => "#{@druid}_00_0001"))
      @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => [ApTeiDocument::DIV2_TYPE['session']], :id => "#{@druid}_00_0002"))
      @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssi => ApTeiDocument::DIV2_TYPE['session'], :id => "#{@druid}_div2_1"))
      @parser.parse(x)
    end
  end 

  context "add_page_doc_to_solr" do
    context "when page has no indexed content (<p>)" do
      it "pages in <front> section should go to Solr" do
        x = "<TEI.2><text><front>
              <div type=\"frontpiece\">
                  <pb n=\"\" id=\"#{@druid}_00_0001\"/>
                  <p>blah blah</p>
              </div>
              <div type=\"abstract\">
                  <pb n=\"ii\" id=\"#{@druid}_00_0002\"/>
              </div></front></text></TEI.2>"
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0001"))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0002"))
        @parser.parse(x)
      end
      it "blank page at beginning of <body> should go to Solr" do
        x = @start_tei_body_div1 +
               "<pb n=\"\" id=\"#{@druid}_00_0004\"/>
                <pb n=\"1\" id=\"#{@druid}_00_0005\"/>" + @end_div1_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0004"))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0005"))
        @parser.parse(x)
      end
      it "blank pages at end of <body> should go to Solr" do
        x = @start_tei_body_div1 +
                "<pb n=\"810\" id=\"#{@druid}_00_0813\"/>
                <p>blah blah</p>
                <pb n=\"811\" id=\"#{@druid}_00_0814\"/>
                <pb n=\"812\" id=\"#{@druid}_00_0815\"/>" + @end_div1_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0813"))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0814"))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0815"))
        @parser.parse(x)
      end
      it "blank page at beginning of <back> should go to Solr" do
        x = @start_tei_back_div1 +
                "<pb n=\"\" id=\"#{@druid}_00_0004\"/>
                <head>blah</head>
                <pb n=\"1\" id=\"#{@druid}_00_0005\"/>" + @end_div1_back_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0004"))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0005"))
        @parser.parse(x)
      end
      it "blank pages at end of <back> should go to Solr" do
        x = @start_tei_back_div1 +
                "<pb n=\"810\" id=\"#{@druid}_00_0813\"/>
                <p>blah blah</p>
                <pb n=\"811\" id=\"#{@druid}_00_0814\"/>
                <pb n=\"812\" id=\"#{@druid}_00_0815\"/>" + @end_div1_back_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0813"))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0814"))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0815"))
        @parser.parse(x)
      end
    end # when no indexed content
    context "when page has indexed content (<p>)" do
      context "in <body>" do
        before(:all) do
          @id = "#{@druid}_00_1234"
          @x = @start_tei_body_div1 +
                   "<pb n=\"1\" id=\"#{@id}\"/>
                   <div2 type=\"session\">
                     <p>La séance est ouverte à neuf heures du matin. </p>
                     <pb n=\"2\" id=\"#{@druid}_00_1235\"/>" + @end_div2_body_tei
        end
        it "should write the doc to Solr" do
          @rsolr_client.should_receive(:add).with(hash_including(:druid_ssi, :collection_ssi, :vol_num_ssi, :id => @id))
          @rsolr_client.should_receive(:add).at_least(1).times
          @parser.parse(@x)
        end
        it "should call init_page_doc_hash" do
          @atd.should_receive(:init_page_doc_hash).at_least(2).times.and_call_original
          @rsolr_client.should_receive(:add).at_least(1).times
          @parser.parse(@x)
        end
      end # in <body>
      context "in <back>" do
        it "pages in <back> section should write the doc to Solr" do
          x = @start_tei_back_div1 +
              "<pb n=\"813\" id=\"#{@druid}_00_0816\"/>
              <div2 type=\"contents\">
                <head>TABLE CHRONOLOGIQUE</head>
                <p>blah blah</p>
              </div2>
            </div1>
            <div1 type=\"volume\" n=\"14\">
              <pb n=\"814\" id=\"#{@druid}_00_0817\"/>" + @end_div1_back_tei
          @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0816"))
          @rsolr_client.should_receive(:add).at_least(1).times
          @parser.parse(x)
        end
        it "last page in <back> section should write the doc to Solr" do
          x = @start_tei_back_div1 +
            "<pb n=\"813\" id=\"#{@druid}_00_0816\"/>
              <div2 type=\"contents\">
                <head>TABLE CHRONOLOGIQUE</head>
                <p>blah blah</p>
              </div2>
            </div1>
            <div1 type=\"volume\" n=\"14\">
              <pb n=\"814\" id=\"#{@druid}_00_0817\"/>
              <div2 type=\"contents\">
                <head>TABLE CHRONOLOGIQUE</head>
                <p>blah blah</p>
              </div2>" + @end_div1_back_tei
          @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0816"))
          @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0817"))
          @rsolr_client.should_receive(:add).at_least(1).times
          @parser.parse(x)
        end        
      end # in <back>
    end # when indexed content
  end # add_page_doc_to_solr

  context "<pb> element" do
    before(:all) do
      @page_id = "#{@druid}_00_0813"
      @x = @start_tei_body_div2_session + 
            "<pb n=\"1\" id=\"#{@page_id}\"/>
             <p>La séance est ouverte à neuf heures du matin. </p>" + @end_div2_body_tei        
    end
    context "page_num_ssi" do
      it "should be present when <pb> has non-empty n attribute" do
        x = @start_tei_body_div2_session + 
              "<pb n=\"1\" id=\"#{@druid}_00_0813\"/>
               <p>La séance est ouverte à neuf heures du matin. </p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:page_num_ssi => '1'))
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser.parse(x)
      end
      it "should not be present when <pb> has empty n attribute" do
        x = @start_tei_body_div1 +
              "<div2 type=\"session\">
                  <pb n=\"\" id=\"#{@druid}_00_0001\"/>
                  <p>blah blah</p>" + @end_div2_body_tei 
        @rsolr_client.should_receive(:add).with(hash_not_including(:page_num_ssi))
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser.parse(x)
      end
      it "should not be present when <pb> has no n attribute" do
        x = @start_tei_body_div1 +
              "<div2 type=\"session\">
                  <pb id=\"#{@druid}_00_0001\"/>
                  <p>blah blah</p>" + @end_div2_body_tei 
        @rsolr_client.should_receive(:add).with(hash_not_including(:page_num_ssi))
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser.parse(x)
      end
    end # page_num_ssi
    context "page_sequence_isi" do
      before(:all) do
        page_id_hash = { "#{@druid}_00_0001" => 1, 
                          "#{@druid}_00_0005" => 7, 
                          "#{@druid}_00_0805" => 805, 
                          "#{@druid}_00_0806" => 806}
        @atd2 = ApTeiDocument.new(@rsolr_client, @druid, @volume, @vol_constants_hash, page_id_hash, @logger)
        @parser2 = Nokogiri::XML::SAX::Parser.new(@atd2)
      end
      it "should be derived from the page_id_hash passed in" do
        x = @start_tei_body_div2_session + 
              "<pb n=\"1\" id=\"#{@druid}_00_0005\"/>
               <p>La séance est ouverte à neuf heures du matin. </p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:page_sequence_isi => 7))
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser2.parse(x)
      end
      it "should not be present when page_id_hash has no matching value" do
        x = @start_tei_body_div2_session + 
              "<pb n=\"1\" id=\"#{@druid}_00_0002\"/>
               <p>La séance est ouverte à neuf heures du matin. </p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_not_including(:page_sequence_isi))
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser2.parse(x)
      end
    end
    it "image_id_ssm should be same as <pb> id attrib with .jp2 extension" do
      @rsolr_client.should_receive(:add).with(hash_including(:image_id_ssm => ["#{@page_id}.jp2"]))
      @rsolr_client.should_receive(:add).at_least(1).times
      @parser.parse(@x)
    end
    it "ocr_id_ss should be same as <pb> id attrib with _99_ replacing middle _00_ and .txt extension" do
      @rsolr_client.should_receive(:add).with(hash_including(:ocr_id_ss => "#{@druid}_99_0813.txt"))
      @rsolr_client.should_receive(:add).at_least(1).times
      @parser.parse(@x)
    end
    context "unexpected values" do
      it "should log an error if the druid in <pb> image id doesn't match the passed volume druid" do
        x = @start_tei_body_div1 +
              "<div2 type=\"session\">
                  <pb id=\"oo000oo0000_00_0001\"/>
                  <p>blah blah</p>" + @end_div2_body_tei 
        @logger.should_receive(:error).with("TEI for #{@druid} has <pb> element with incorrect druid: oo000oo0000_00_0001; continuing with given page id.")
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser.parse(x)
      end
      it "should log a warning if an image sequence number isn't an integer" do
        x = @start_tei_body_div1 +
              "<div2 type=\"session\">
                  <pb n=\"4\" id=\"#{@druid}_00_00a\"/>
                  <p>bleah bleah</p>" + @end_div2_body_tei 
        @logger.should_receive(:warn).with("Non-integer image sequence number: #{@druid}_00_00a; continuing with processing.")
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser.parse(x)
      end
      it "should log a warning if an image sequence number isn't consecutively higher than its predecessor" do
        x = @start_tei_body_div1 +
              "<div2 type=\"session\">
                  <pb n=\"4\" id=\"#{@druid}_00_0012\"/>
                  <p>blah blah</p>
                  <pb n=\"5\" id=\"#{@druid}_00_0011\"/>
                  <p>bleah bleah</p>" + @end_div2_body_tei 
        @logger.should_receive(:error).with("Image ids not consecutive in TEI: #{@druid}_00_0011 occurs after #{@druid}_00_0012; continuing with processing.")
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser.parse(x)
      end
      it "should log a warning if there is no page number after page numbers start" do
        x = @start_tei_body_div1 +
              "<div2 type=\"session\">
                  <pb n=\"3\" id=\"#{@druid}_00_0012\"/>
                  <p>blah blah</p>
                  <pb id=\"#{@druid}_00_0013\"/>
                  <p>bleah bleah</p>" + @end_div2_body_tei 
        @logger.should_receive(:warn).with("Missing printed page number in TEI for #{@druid}_00_0013; continuing with processing.")
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser.parse(x)
      end
      it "should not log a warning if there is no page number before the page numbers start" do
        x = @start_tei_body_div1 +
              "<div2 type=\"session\">
                  <pb n=\"\" id=\"#{@druid}_00_0012\"/>
                  <p>blah blah</p>
                  <pb n=\"3\" id=\"#{@druid}_00_0013\"/>
                  <p>bleah bleah</p>" + @end_div2_body_tei 
        @logger.should_not_receive(:warn).with("Missing page number in TEI for #{@druid}_00_0013; continuing with processing.")
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser.parse(x)
      end
      it "should log a warning if a numerical (printed) page number isn't consecutively higher than its predecessor" do
        x = @start_tei_body_div1 +
              "<div2 type=\"session\">
                  <pb n=\"4\" id=\"#{@druid}_00_0012\"/>
                  <p>blah blah</p>
                  <pb n=\"8\" id=\"#{@druid}_00_0013\"/>
                  <p>bleah bleah</p>" + @end_div2_body_tei 
        @logger.should_receive(:warn).with("Printed page numbers not consecutive in TEI: 8 (in image #{@druid}_00_0013) occurs after 4 (in image #{@druid}_00_0012); continuing with processing.")
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser.parse(x)
      end
    end
  end # <pb> element

  context "text_tiv (catchall field)" do
    before(:all) do
      @begin_body = @start_tei_body_div1 + "<pb n=\"810\" id=\"#{@druid}_00_0813\"/>"
      @end_body = "<pb n=\"811\" id=\"#{@druid}_00_0814\"/>" + @end_div1_body_tei
      @begin_back = @start_tei_back_div1 + "<pb n=\"810\" id=\"#{@druid}_00_0813\"/>"
      @end_back = "<pb n=\"811\" id=\"#{@druid}_00_0814\"/>" + @end_div1_back_tei
    end
    it "should not get content from <teiHeader>" do
      x = "<TEI.2><teiHeader type=\"text\" id=\"by423fb7614\">
        <fileDesc>
          <titleStmt>
            <title type=\"main\">ARCHIVES PARLEMENTAIRES</title>
            <author>MM. MAVIDAL</author>
          </titleStmt>
          <publicationStmt>
            <distributor>
              <address>
                <addrLine>blah</addrLine>
              </address>
            </distributor>
            <date>1900</date>
            <pubPlace>PARIS</pubPlace>
          </publicationStmt>
          <notesStmt>
            <note type=\"markup\">Additional markup added by Digital Divide Data, 20120701</note>
          </notesStmt>
          <sourceDesc>
            <p>Compiled from ARCHIVES PARLEMENTAIRES documents.</p>
          </sourceDesc>
        </fileDesc>
      </teiHeader>
      <text><body>
        <div1 type=\"volume\" n=\"14\">
          <pb n=\"814\" id=\"#{@druid}_00_0817\"/>
          <div2 type=\"contents\">
            <p>in body</p>
      #{@end_div2_body_tei}"
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'in body'))
      @rsolr_client.should_receive(:add).at_least(1).times
      @parser.parse(x)
    end
    it "should not get content from <front>" do
      x = "<TEI.2><text>
            <front>
              <div type=\"frontpiece\">
                  <pb n=\"\" id=\"#{@druid}_00_0001\"/>
                  <p>blah blah</p>
              </div>
              <div type=\"abstract\">
                  <pb n=\"ii\" id=\"#{@druid}_00_0002\"/>
                  <p>front content</p>
              </div>
            </front>
            <body>
              <div1 type=\"volume\" n=\"14\">
                <pb n=\"814\" id=\"#{@druid}_00_0003\"/>
                <div2 type=\"contents\">
                  <p>in body</p>
            #{@end_div2_body_tei}"
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'in body'))
      @rsolr_client.should_receive(:add).at_least(1).times
      @parser.parse(x)
    end
    it "should not include the contents of any attributes" do
      x = @begin_body + "<p>Art. 1<hi rend=\"superscript\">er</hi></p>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'Art. 1er', :id => "#{@druid}_00_0813"))
      @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0814"))
      @parser.parse(x)
      x = @begin_body + "<date value=\"2013-01-01\">pretending to care</date>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'pretending to care', :id => "#{@druid}_00_0813"))
      @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0814"))
      @parser.parse(x)
    end
    it "should include the contents of <p> element" do
      x = @begin_body + "<p>blather</p>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'blather', :id => "#{@druid}_00_0813"))
      @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0814"))
      @parser.parse(x)
    end
    it "should include the contents of <head> element" do
      x = @begin_body + "<head>MARDI 15 OCTOBRE 1793.</head>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'MARDI 15 OCTOBRE 1793.', :id => "#{@druid}_00_0813"))
      @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0814"))
      @parser.parse(x)
    end
    it "should include the contents of <speaker> element" do
      x = @begin_body + "<sp><speaker>M. Bréard.</speaker></sp>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'M. Bréard.', :id => "#{@druid}_00_0813"))
      @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0814"))
      @parser.parse(x)
    end
    it "should include the contents of <date> element" do
      x = @begin_body + "<date value=\"2013-01-01\">pretending to care</date>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'pretending to care', :id => "#{@druid}_00_0813"))
      @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0814"))
      @parser.parse(x)
    end
    it "should include the contents of <note> element" do
      x = @begin_body + "<note place=\"foot\">(1) shoes.</note>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => '(1) shoes.', :id => "#{@druid}_00_0813"))
      @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0814"))
      @parser.parse(x)
    end
    it "should include the contents of <hi> element" do
      x = @begin_body + "<p>Art. 1<hi>er.</hi>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'Art. 1er.', :id => "#{@druid}_00_0813"))
      @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0814"))
      @parser.parse(x)
    end
    it "should include the contents of <term> element" do
      x = @begin_body + "<p><term>Abbaye </term>(Prison de F).</p>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'Abbaye (Prison de F).', :id => "#{@druid}_00_0813"))
      @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0814"))
      @parser.parse(x)
    end
    it "should include the contents of <item> element" do
      x = @begin_body + "<list><item>item!</item></list>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'item!', :id => "#{@druid}_00_0813"))
      @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0814"))
      @parser.parse(x)
    end
    it "should include the contents of <signed> element" do
      x = @begin_body + "<signed>Signé : Remillat, à l'original. </signed>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => "Signé : Remillat, à l'original.", :id => "#{@druid}_00_0813"))
      @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0814"))
      @parser.parse(x)
    end
    it "should ignore <trailer>" do
      x = @begin_body + "<trailer>FIN DE L'INTRODUCTION.</trailer><p>blah</p>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => "blah", :id => "#{@druid}_00_0813"))
      @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_00_0814"))
      @parser.parse(x)
    end
  end # text_tiv field
   
  context "<div2> types in page docs" do
    shared_examples_for "solr doc for page with div2" do | div2_type |
      it "page doc should have doc_type_ssim of '#{div2_type}' and type_ssi of 'page'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => [div2_type], :type_ssi => ApTeiDocument::PAGE_TYPE))
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser.parse(@x)
      end
    end
    context 'type="session"' do
      before(:all) do
        @x = @start_tei_body_div2_session +
            "<pb n=\"5\" id=\"#{@druid}_00_0001\"/>
            <p>actual content</p>
            <pb n=\"6\" id=\"#{@druid}_00_0002\"/>" + @end_div2_body_tei
      end
      it_should_behave_like "solr doc for page with div2", ApTeiDocument::DIV2_TYPE['session'] 
    end
    context 'type="alpha"' do
      before(:all) do
        @x = "#{@start_tei_back_div1}<div2 type=\"alpha\">
                <pb n=\"5\" id=\"#{@druid}_00_0001\"/>
                <p>blah blah</p>
                <pb n=\"6\" id=\"#{@druid}_00_0002\"/>" + @end_div2_back_tei
      end
      it_should_behave_like "solr doc for page with div2", ApTeiDocument::DIV2_TYPE['alpha'] 
    end
    context 'type="contents"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"contents\">
                <pb n=\"5\" id=\"#{@druid}_00_0008\"/>
                <p>blah blah</p>
                <pb n=\"6\" id=\"#{@druid}_00_0009\"/>" + @end_div2_body_tei
      end
      it_should_behave_like "solr doc for page with div2", ApTeiDocument::DIV2_TYPE['contents'] 
    end
    context 'type="other"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"other\">
                <pb n=\"5\" id=\"#{@druid}_00_0001\"/>
                <p>blah blah</p>" + @end_div2_body_tei
      end
      it_should_behave_like "solr doc for page with div2", ApTeiDocument::DIV2_TYPE['other'] 
    end
    context 'type="table_alpha"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"table_alpha\">
                <pb n=\"5\" id=\"#{@druid}_00_0001\"/>
                <p>blah blah</p>" + @end_div2_body_tei
      end
      it_should_behave_like "solr doc for page with div2", ApTeiDocument::DIV2_TYPE['table_alpha'] 
    end
    context 'type="introduction"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"introduction\">
                <pb n=\"5\" id=\"#{@druid}_00_0001\"/>
                <p>blah blah</p>" + @end_div2_body_tei
      end
      it_should_behave_like "solr doc for page with div2", ApTeiDocument::DIV2_TYPE['introduction'] 
    end
  end # <div2> element
  
end