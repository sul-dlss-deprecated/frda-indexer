# encoding: UTF-8
require 'spec_helper'

require 'time'

describe ApTeiDocument do
  before(:all) do
    @volume = 'Volume 36'
    @druid = 'aa222bb4444'
    @vol_constants_hash = { :vol_pdf_name_ss => 'aa222bb4444.pdf',
                            :vol_pdf_size_ls => 2218576614,
                            :vol_tei_name_ss => 'aa222bb4444.xml',
                            :vol_tei_size_is => 6885841,
                            :vol_total_pages_is => 806  }
    @page_id_hash = { 'aa222bb4444_00_0001' => 1, 
                      'aa222bb4444_00_0002' => 2, 
                      'aa222bb4444_00_0805' => 805, 
                      'aa222bb4444_00_0806' => 806}
    @rsolr_client = RSolr::Client.new('http://somewhere.org')
    @logger = Logger.new(STDOUT)
    @atd = ApTeiDocument.new(@rsolr_client, @druid, @volume, @vol_constants_hash, @page_id_hash, @logger)
    @parser = Nokogiri::XML::SAX::Parser.new(@atd)
    @start_tei_body_div1 = "<TEI.2><text><body><div1 type=\"volume\" n=\"36\">"
    @start_tei_body_div2_session = @start_tei_body_div1 + "<div2 type=\"session\">"
    @end_div1_body_tei = "</div1></body></text></TEI.2>"
    @end_div2_body_tei = "</div2>#{@end_div1_body_tei}"
    @start_tei_back_div1 = "<TEI.2><text><back><div1 type=\"volume\" n=\"44\">"
    @end_div1_back_tei = "</div1></back></text></TEI.2>"
    @end_div2_back_tei = "</div2>#{@end_div1_back_tei}"
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
      x = "<TEI.2><teiHeader id='666'></teiHeader></TEI.2>"
      @parser.parse(x)
    end
    it "should populate druid_ssi field" do
      @atd.doc_hash[:druid_ssi].should == @druid
    end
    it "should populate collection_ssi field" do
      @atd.doc_hash[:collection_ssi].should == ApTeiDocument::COLL_VAL
    end
    it "should populate vol_num_ssi field" do
      @atd.doc_hash[:vol_num_ssi].should == @volume.sub(/^Volume /i, '')
      @atd.doc_hash[:vol_num_ssi].should == '36'
    end
    it "should populate vol_title_ssi" do
      @atd.doc_hash[:vol_title_ssi].should == VOL_TITLES[@volume.sub(/^Volume /i, '')]
    end
    it "should get volume date fields in UTC form (1995-12-31T23:59:59Z)" do
      val = @atd.doc_hash[:vol_date_start_dti]
      val.should end_with 'Z'
      Time.xmlschema(val).xmlschema.should == val # also ensures it doesn't throw parsing error
      val = @atd.doc_hash[:vol_date_end_dti]
      val.should end_with 'Z'
      Time.xmlschema(val).xmlschema.should == val
    end
    it "should populate type_ssi field" do
      @atd.doc_hash[:type_ssi].should == ApTeiDocument::PAGE_TYPE
    end
    it "should populate vol_pdf fields" do
      @atd.doc_hash[:vol_pdf_name_ss].should == 'aa222bb4444.pdf'
      @atd.doc_hash[:vol_pdf_size_ls].should == 2218576614
    end
    it "should populate vol_tei fields" do
      @atd.doc_hash[:vol_tei_name_ss].should == 'aa222bb4444.xml'
      @atd.doc_hash[:vol_tei_size_is].should == 6885841
    end
    it "should populate vol_total_pages_is field" do
      @atd.doc_hash[:vol_total_pages_is].should == 806
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
      it "blank page at beginning of <body> should not go to Solr" do
        x = @start_tei_body_div1 +
               "<pb n=\"\" id=\"pz516hw4711_00_0004\"/>
                <pb n=\"1\" id=\"pz516hw4711_00_0005\"/>" + @end_div1_body_tei
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'pz516hw4711_00_0004'))
        @parser.parse(x)
      end
      it "blank pages at end of <body> should not go to Solr" do
        x = @start_tei_body_div1 +
                "<pb n=\"810\" id=\"tq360bc6948_00_0813\"/>
                <p>blah blah</p>
                <pb n=\"811\" id=\"tq360bc6948_00_0814\"/>
                <pb n=\"812\" id=\"tq360bc6948_00_0815\"/>" + @end_div1_body_tei
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0814'))
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0815'))
        @parser.parse(x)
      end
      it "blank page at beginning of <back> should not go to Solr" do
        x = @start_tei_back_div1 +
                "<pb n=\"\" id=\"pz516hw4711_00_0004\"/>
                <head>blah</head>
                <pb n=\"1\" id=\"pz516hw4711_00_0005\"/>" + @end_div1_back_tei
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'pz516hw4711_00_0004'))
        @parser.parse(x)
      end
      it "blank pages at end of <back> should not go to Solr" do
        x = @start_tei_back_div1 +
                "<pb n=\"810\" id=\"tq360bc6948_00_0813\"/>
                <p>blah blah</p>
                <pb n=\"811\" id=\"tq360bc6948_00_0814\"/>
                <pb n=\"812\" id=\"tq360bc6948_00_0815\"/>" + @end_div1_back_tei
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0814'))
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0815'))
        @parser.parse(x)
      end
    end # when no indexed content
    context "when page has indexed content (<p>)" do
      context "in <body>" do
        before(:all) do
          @id = "non_blank_page"
          @x = @start_tei_body_div1 +
                   "<pb n=\"1\" id=\"#{@id}\"/>
                   <div2 type=\"session\">
                     <p>La séance est ouverte à neuf heures du matin. </p>
                     <pb n=\"2\" id=\"next_page\"/>" + @end_div2_body_tei
        end
        it "should write the doc to Solr" do
          @rsolr_client.should_receive(:add).with(hash_including(:druid_ssi, :collection_ssi, :vol_num_ssi, :id => @id))
          @parser.parse(@x)
        end
        it "should call init_doc_hash" do
          @atd.should_receive(:init_doc_hash).at_least(2).times.and_call_original
          @rsolr_client.should_receive(:add)
          @parser.parse(@x)
        end
      end # in <body>
      context "in <back>" do
        it "pages in <back> section should NOT write the doc to Solr" do
          x = @start_tei_back_div1 +
              "<pb n=\"813\" id=\"tq360bc6948_00_0816\"/>
              <div2 type=\"contents\">
                <head>TABLE CHRONOLOGIQUE</head>
                <p>blah blah</p>
              </div2>
            </div1>
            <div1 type=\"volume\" n=\"14\">
              <pb n=\"814\" id=\"tq360bc6948_00_0817\"/>" + @end_div1_back_tei
          @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0816'))
          @parser.parse(x)
        end
        it "last page in <back> section should NOT write the doc to Solr" do
          x = @start_tei_back_div1 +
            "<pb n=\"813\" id=\"tq360bc6948_00_0816\"/>
              <div2 type=\"contents\">
                <head>TABLE CHRONOLOGIQUE</head>
                <p>blah blah</p>
              </div2>
            </div1>
            <div1 type=\"volume\" n=\"14\">
              <pb n=\"814\" id=\"tq360bc6948_00_0817\"/>
              <div2 type=\"contents\">
                <head>TABLE CHRONOLOGIQUE</head>
                <p>blah blah</p>
              </div2>" + @end_div1_back_tei
          @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0816'))
          @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0817'))
          @parser.parse(x)
        end        
      end # in <back>
    end # when indexed content
  end # add_doc_to_solr
  
  context "add_value_to_doc_hash" do
    context "field doesn't exist in doc_hash yet" do
      before(:all) do
        @x = @start_tei_body_div2_session + 
            "<pb n=\"813\" id=\"tq360bc6948_00_0816\"/>
            <sp>
              <speaker>M. Guadet</speaker>
              <p>blah blah</p>
            </sp>" + @end_div2_body_tei
      end
      it "should create field with Array [value] for a multivalued field - ending in m or mv" do
        exp_flds = {:speaker_ssim => ['Guadet'], :spoken_text_timv => ['Guadet-|-blah blah']}
        @rsolr_client.should_receive(:add).with(hash_including(exp_flds))
        @parser.parse(@x)
      end
      it "should create field with String value for a single valued field" do
        exp_flds = {:doc_type_ssim => ['séance']}
        @rsolr_client.should_receive(:add).with(hash_including(exp_flds))
        @parser.parse(@x)
      end
    end # field doesn't exist yet
    context "field already exists in doc_hash" do
      before(:all) do
        @x = @start_tei_body_div2_session + 
            "<sp>
              <speaker>M. Guadet</speaker>
              <p>blah blah</p>
            </sp>
            <sp>
              <speaker>M. McRae</speaker>
              <p>bleah bleah</p>
            </sp>" + @end_div2_body_tei
      end
      it "should add the value to the doc_hash Array for the field for multivalued field - ending in m or mv" do
        exp_flds = {:speaker_ssim => ['Guadet', 'McRae'], :spoken_text_timv => ['Guadet-|-blah blah', 'McRae-|-bleah bleah']}
        @rsolr_client.should_receive(:add).with(hash_including(exp_flds))
        @parser.parse(@x)
      end
    end # field already exists
  end # add_value_to_doc_hash

  context "<pb> element" do
    before(:all) do
      @page_id = 'tq360bc6948_00_0813'
      @x = @start_tei_body_div2_session + 
            "<pb n=\"1\" id=\"#{@page_id}\"/>
             <p>La séance est ouverte à neuf heures du matin. </p>" + @end_div2_body_tei        
    end
    context "page_num_ssi" do
      it "should be present when <pb> has non-empty n attribute" do
        x = @start_tei_body_div2_session + 
              "<pb n=\"1\" id=\"something\"/>
               <p>La séance est ouverte à neuf heures du matin. </p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:page_num_ssi => '1'))
        @parser.parse(x)
      end
      it "should not be present when <pb> has empty n attribute" do
        x = @start_tei_body_div1 +
              "<div2 type=\"session\">
                  <pb n=\"\" id=\"ns351vc7243_00_0001\"/>
                  <p>blah blah</p>" + @end_div2_body_tei 
        @rsolr_client.should_receive(:add).with(hash_not_including(:page_num_ssi))
        @parser.parse(x)
      end
      it "should not be present when <pb> has no n attribute" do
        x = @start_tei_body_div1 +
              "<div2 type=\"session\">
                  <pb id=\"ns351vc7243_00_0001\"/>
                  <p>blah blah</p>" + @end_div2_body_tei 
        @rsolr_client.should_receive(:add).with(hash_not_including(:page_num_ssi))
        @parser.parse(x)
      end
    end # page_num_ssi
    context "page_sequence_isi" do
      before(:all) do
        @page_id_hash = { 'aa222bb4444_00_0001' => 1, 
                          'aa222bb4444_00_0005' => 7, 
                          'aa222bb4444_00_0805' => 805, 
                          'aa222bb4444_00_0806' => 806}
        @atd2 = ApTeiDocument.new(@rsolr_client, @druid, @volume, @vol_constants_hash, @page_id_hash, @logger)
        @parser2 = Nokogiri::XML::SAX::Parser.new(@atd2)
      end
      it "should be derived from the page_id_hash passed in" do
        x = @start_tei_body_div2_session + 
              "<pb n=\"1\" id=\"aa222bb4444_00_0005\"/>
               <p>La séance est ouverte à neuf heures du matin. </p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:page_sequence_isi => 7))
        @parser2.parse(x)
      end
      it "should not be present when page_id_hash has no matching value" do
        x = @start_tei_body_div2_session + 
              "<pb n=\"1\" id=\"aa222bb4444_00_0002\"/>
               <p>La séance est ouverte à neuf heures du matin. </p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_not_including(:page_sequence_isi))
        @parser2.parse(x)
      end
    end
    it "image_id_ssm should be same as <pb> id attrib with .jp2 extension" do
      @rsolr_client.should_receive(:add).with(hash_including(:image_id_ssm => ["#{@page_id}.jp2"]))
      @parser.parse(@x)
    end
    it "ocr_id_ss should be same as <pb> id attrib with _99_ replacing middle _00_ and .txt extension" do
      @rsolr_client.should_receive(:add).with(hash_including(:ocr_id_ss => "tq360bc6948_99_0813.txt"))
      @parser.parse(@x)
    end
  end # <pb> element

  context "<div2> element" do
    context 'type="session"' do
      before(:all) do
        @x = @start_tei_body_div2_session +
            "<p>actual content</p>" + @end_div2_body_tei
      end
      it "should have doc_type_ssim of 'séance'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ["séance"]))
        @parser.parse(@x)
      end
      
      context "date" do
        before(:all) do
          @dx = @start_tei_body_div2_session + 
              "<pb n=\"812\" id=\"tq360bc6948_00_0816\"/>
              <head>CONVENTION NATIONALE </head>
              <p>Séance du samedi <date value=\"1793-10-05\">5 octobre 1793</date>. </p>
              <p>L'an II de la République Française une et indivisible </p>
              <pb n=\"813\" id=\"tq360bc6948_00_0817\"/>" + @end_div2_body_tei
        end
        it "should log a warning if it doesn't find a <date> element before an <sp> element" do
          x = @start_tei_body_div2_session + 
              "<pb n=\"812\" id=\"tq360bc6948_00_0816\"/>
              <sp>
                <speaker>M. Guadet</speaker>
                <p>blah blah</p>
              </sp>
              <pb n=\"813\" id=\"tq360bc6948_00_0817\"/>" + @end_div2_body_tei
          @logger.should_receive(:warn).with("Didn't find <date> tag before <sp> for session in page tq360bc6948_00_0816")
          @rsolr_client.should_receive(:add)
          @parser.parse(x)
        end

        context "value attribute" do
          it "should be the value attribute of the first <date> element after <div2>" do
            @rsolr_client.should_receive(:add).with(hash_including(:session_date_val_ssim => ["1793-10-05"]))
            @parser.parse(@dx)
          end
          it "should ignore subsequent <date> elements and log a warning" do
            x = @start_tei_body_div2_session + 
                "<pb n=\"812\" id=\"tq360bc6948_00_0816\"/>
                <p>Séance du samedi <date value=\"1793-10-05\">5 octobre 1793</date>. </p>
                <p><date value=\"2013-01-01\">pretending to care</date></p>
                <pb n=\"813\" id=\"tq360bc6948_00_0817\"/>" + @end_div2_body_tei
            @rsolr_client.should_receive(:add).with(hash_including(:session_date_dtsim => ["1793-10-05T00:00:00Z"]))
            @parser.parse(x)
          end
          it "should transform the value into UTC Zulu format" do
            @rsolr_client.should_receive(:add).with(hash_including(:session_date_dtsim => ["1793-10-05T00:00:00Z"]))
            @parser.parse(@dx)
          end
        end # date value
        
        context "full text value of date from surrounding element" do
          it "should get the text from a surrounding <p> element" do
            # <p>Séance du samedi <date value=\"1793-10-05\">5 octobre 1793</date>. </p>
            @rsolr_client.should_receive(:add).with(hash_including(:session_date_ftsimv => ["Séance du samedi 5 octobre 1793"]))
            @parser.parse(@dx)
          end
          it "should ignore text from other <p> elements" do
            x = @start_tei_body_div2_session + 
                "<pb n=\"812\" id=\"tq360bc6948_00_0816\"/>
                <p>la</p>
                <p>Séance du <date value=\"1792-04-19\">jeudi 19 avril 1792</date>, au soir, </p>
                <p>gah</p>
                <pb n=\"813\" id=\"tq360bc6948_00_0817\"/>" + @end_div2_body_tei
            @rsolr_client.should_receive(:add).with(hash_including(:session_date_ftsimv => ['Séance du jeudi 19 avril 1792, au soir']))
            @parser.parse(x)
          end
          it "should only get the first date's surrounding text" do
            x = @start_tei_body_div2_session + 
                "<pb n=\"812\" id=\"tq360bc6948_00_0816\"/>
                <p>Séance du samedi <date value=\"1793-10-05\">5 octobre 1793</date>. </p>
                <p><date value=\"2013-01-01\">pretending to care</date></p>
                <pb n=\"813\" id=\"tq360bc6948_00_0817\"/>" + @end_div2_body_tei
            @rsolr_client.should_receive(:add).with(hash_including(:session_date_ftsimv => ["Séance du samedi 5 octobre 1793"]))
            @parser.parse(x)
          end
          it "should get the text from a surrounding <p> element when there is no preceding text" do
            x = @start_tei_body_div2_session + 
                "<pb n=\"812\" id=\"tq360bc6948_00_0816\"/>
                <p><date value=\"1792-09-20\">Jeudi 20 septembre 1792</date>, au soir.</p>
                <pb n=\"813\" id=\"tq360bc6948_00_0817\"/>" + @end_div2_body_tei
            @rsolr_client.should_receive(:add).with(hash_including(:session_date_ftsimv => ["Jeudi 20 septembre 1792, au soir"]))
            @parser.parse(x)
          end
          it "should call normalize_session_title" do
            @atd.should_receive(:normalize_session_title).and_call_original
            @rsolr_client.should_receive(:add).with(hash_including(:session_date_ftsimv => ["Séance du samedi 5 octobre 1793"]))
            @parser.parse(@dx)
          end
          it "should work for multiple sessions in a page" do
            x = @start_tei_body_div2_session + 
                "<pb n=\"812\" id=\"tq360bc6948_00_0816\"/>
                <p>first <date value=\"1793-10-05\">one</date>. </p>
                </div2>
                <div2 type=\"session\">
                  <p>another <date value=\"2013-01-01\">one</date></p>
                <pb n=\"813\" id=\"tq360bc6948_00_0817\"/>" + @end_div2_body_tei
            @rsolr_client.should_receive(:add).with(hash_including(:session_date_ftsimv => ["first one", "another one"]))
            @parser.parse(x)
          end

          it "should get the text from a surrounding <head> element" do
            # <head>SÉANCE DU VINGT-DEUXIÈME JOUR DU PREMIER MOIS DE L'AN II (DIMANCHE <date
            # <head>présidence de m. le franc de pompignaf, archevêque de vienne.Séance du <date
            pending "to be implemented if we have a lot of bad values due to this"
            x = @start_tei_body_div2_session + 
                "<pb n=\"812\" id=\"tq360bc6948_00_0816\"/>
                <head>Séance du <date value=\"1792-04-19\">jeudi 19 avril 1792</date>, au soir, </head>
                <pb n=\"813\" id=\"tq360bc6948_00_0817\"/>" + @end_div2_body_tei
            @rsolr_client.should_receive(:add).with(hash_including(:session_date_ftsimv => ["Séance du jeudi 19 avril 1792, au soir"]))
            @parser.parse(x)
          end
        end # full text value
      end # session date
      
      context "session_seq_first_isim" do
        before(:all) do
          @page_id_hash = { 'tq360bc6948_00_0813' => 815, 
                            'tq360bc6948_00_0814' => 888, 
                            'tq360bc6948_00_0815' => 899}
          @atd2 = ApTeiDocument.new(@rsolr_client, @druid, @volume, @vol_constants_hash, @page_id_hash, @logger)
          @parser2 = Nokogiri::XML::SAX::Parser.new(@atd2)
        end
        it "should be the first page sequence number in the session, for all pages in the session" do
          x = @start_tei_body_div2_session + 
                "<pb n=\"810\" id=\"tq360bc6948_00_0813\"/>
                <head>CONVENTION NATIONALE</head>
                <p>blah blah</p>
                <pb n=\"811\" id=\"tq360bc6948_00_0814\"/>
                <p>blah blah</p>
                <pb n=\"812\" id=\"tq360bc6948_00_0815\"/>" + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_including(:session_seq_first_isim => [815])).twice
          @parser2.parse(x)
        end
        it "should change when the session changes" do
          x = @start_tei_body_div2_session + 
                "<pb n=\"810\" id=\"tq360bc6948_00_0813\"/>
                <head>CONVENTION NATIONALE</head>
                <p>first <date value=\"1793-10-05\">one</date>. </p>
                <p>blah blah</p>
                </div2>
                <div2 type=\"session\">
                <head>CONVENTION NATIONALE</head>
                <p>second <date value=\"1793-10-06\">one</date>. </p>
                <p>blah blah</p>
                <pb n=\"811\" id=\"tq360bc6948_00_0814\"/>
                <p>blah blah</p>
                <pb n=\"812\" id=\"tq360bc6948_00_0815\"/>" + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_including(:session_seq_first_isim => [815]))
          @rsolr_client.should_receive(:add).with(hash_including(:session_seq_first_isim => [815, 888]))
          @parser2.parse(x)
        end
      end
      
      context "session_govt_ssim" do
        it "should take the value of the first <head> element after <div2>" do
          x = @start_tei_body_div2_session + 
                "<pb n=\"810\" id=\"tq360bc6948_00_0813\"/>
                <head>CONVENTION NATIONALE</head>
                <p>blah blah</p>
                <pb n=\"811\" id=\"tq360bc6948_00_0814\"/>" + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_including(:session_govt_ssim => ["CONVENTION NATIONALE"]))
          @parser.parse(x)
        end
        it "should ignore subsequent <head> elements, even if allcaps" do
          x = @start_tei_body_div2_session + 
                "<pb n=\"810\" id=\"tq360bc6948_00_0813\"/>
                <head>CONVENTION NATIONALE</head>
                <head>PRESIDENCE DE M. MERLIN</head>
                <p>blah blah</p>
                <pb n=\"811\" id=\"tq360bc6948_00_0814\"/>" + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_not_including(:session_govt_ssim => ["PRESIDENCE DE M. MERLIN"]))
          @parser.parse(x)
        end
        it "should strip whitespace and punctuation" do
          x = @start_tei_body_div2_session + 
                "<pb n=\"810\" id=\"tq360bc6948_00_0813\"/>
                <head> 
                ASSEMBLÉE NATIONALE LÉGISLATIVE. </head>
                <p>blah blah</p>
                <pb n=\"811\" id=\"tq360bc6948_00_0814\"/>" + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_including(:session_govt_ssim => ["ASSEMBLÉE NATIONALE LÉGISLATIVE"]))
          @parser.parse(x)
        end
        it "should ignore whitespace before first <head> or <p>" do
          x = @start_tei_body_div2_session + 
                "<pb n=\"810\" id=\"tq360bc6948_00_0813\"/>
                
                <head>CONVENTION NATIONALE</head>
                <p>blah blah</p>
                <pb n=\"811\" id=\"tq360bc6948_00_0814\"/>" + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_including(:session_govt_ssim => ["CONVENTION NATIONALE"]))
          @parser.parse(x)
        end
        it "should find the value if it is in <p> instead of <head>" do
          x = @start_tei_body_div2_session + 
                "<pb n=\"810\" id=\"tq360bc6948_00_0813\"/>
                <p>ASSEMBLÉE NATIONALE LÉGISLATIVE. </p>
                <p>blah blah</p>
                <pb n=\"811\" id=\"tq360bc6948_00_0814\"/>" + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_including(:session_govt_ssim => ["ASSEMBLÉE NATIONALE LÉGISLATIVE"]))
          @parser.parse(x)
        end
        it "should not have leftover text from preceding elements" do
          x = @start_tei_body_div1 + 
                "<pb n=\"810\" id=\"tq360bc6948_00_0813\"/>
                <p>blah blah</p>
                <div2 type=\"session\">
                <head>CONVENTION NATIONALE</head>
                <p>blah blah</p>
                <pb n=\"811\" id=\"tq360bc6948_00_0814\"/>" + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_including(:session_govt_ssim => ["CONVENTION NATIONALE"]))
          @parser.parse(x)
        end
      end # session_govt_ssim
      it "should put the session specific fields in every page in the session" do
        x = @start_tei_body_div2_session + 
              "<pb n=\"810\" id=\"tq360bc6948_00_0813\"/>
              <head>CONVENTION NATIONALE</head>
              <p>Séance du samedi <date value=\"1793-10-05\">5 octobre 1793</date>. </p>
              <p>blah</p>
              <pb n=\"811\" id=\"tq360bc6948_00_0814\"/>
              <p>bleh</p>
              <pb n=\"812\" id=\"tq360bc6948_00_0815\"/>" + @end_div2_body_tei
        exp_hash_fields = { :session_govt_ssim => ["CONVENTION NATIONALE"],
                            :session_date_dtsim => ["1793-10-05T00:00:00Z"],
                            :session_date_ftsimv => ["Séance du samedi 5 octobre 1793"] }
        @rsolr_client.should_receive(:add).with(hash_including(exp_hash_fields)).twice
        @parser.parse(x)
      end
    end # type session
    
    context 'type="contents"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"contents\">
                <pb n=\"5\" id=\"ns351vc7243_00_0008\"/>
                <p>blah blah</p>
                <pb n=\"6\" id=\"ns351vc7243_00_0009\"/>" + @end_div2_body_tei
      end
      it "should have a doc_type_si of 'table des matières'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ['table des matières']))
        @parser.parse(@x)
      end
    end
    context 'type="other"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"other\">
                <pb n=\"5\" id=\"ns351vc7243_00_0001\"/>
                <p>blah blah</p>" + @end_div2_body_tei
      end
      it "should have a doc_type_si of 'errata, rapport, cahier, etc.'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ['errata, rapport, cahier, etc.']))
        @parser.parse(@x)
      end
    end
    context 'type="table_alpha"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"table_alpha\">
                <pb n=\"5\" id=\"ns351vc7243_00_0001\"/>
                <p>blah blah</p>" + @end_div2_body_tei
      end
      it "should have a doc_type_si of 'liste'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ['liste']))
        @parser.parse(@x)
      end
    end
    context 'type="alpha"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"alpha\">
                <pb n=\"5\" id=\"ns351vc7243_00_0001\"/>
                <p>blah blah</p>" + @end_div2_body_tei
      end
      it "should have a doc_type_si of 'liste'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ['liste']))
        @parser.parse(@x)
      end
    end
    context 'type="introduction"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"introduction\">
                <pb n=\"5\" id=\"ns351vc7243_00_0001\"/>
                <p>blah blah</p>" + @end_div2_body_tei
      end
      it "should have a doc_type_si of 'introduction'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ['introduction']))
        @parser.parse(@x)
      end
    end
  end # <div2> element

  context "<sp> element" do
    context "speaker_ssim" do
      it "should be present if there is a non-empty <speaker> element" do
        x = @start_tei_body_div2_session +
            "<p><date value=\"2013-01-01\">pretending to care</date></p>
            <sp>
               <speaker>m. Guadet</speaker>
               <p>,secrétaire, donne lecture du procès-verbal de la séance ... </p>
            </sp>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:speaker_ssim => ['Guadet']))
        @parser.parse(x)
      end
      it "should have multiple values for multiple speakers" do
        x = @start_tei_body_div2_session + 
            "<p><date value=\"2013-01-01\">pretending to care</date></p>
            <sp>
              <speaker>m. Guadet</speaker>
              <p>blah blah</p>
            </sp>
            <p>hoo hah</p>
            <sp>
              <speaker>M. McRae.</speaker>
              <p>bleah bleah</p>
            </sp>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:speaker_ssim => ['Guadet', 'McRae']))
        @parser.parse(x)
      end     
      it "should not be present if there is an empty <speaker> element" do
        x = @start_tei_body_div2_session + 
            "<p><date value=\"2013-01-01\">pretending to care</date></p>
            <sp>
               <speaker></speaker>
               <speaker/>
               <p>,secrétaire, donne lecture du procès-verbal de la séance ... </p>
             </sp>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_not_including(:speaker_ssim))
        @parser.parse(x)
      end
      it "should not be present if there is no <speaker> element" do
        x = @start_tei_body_div2_session + 
            "<p>La séance est ouverte à neuf heures du matin. </p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_not_including(:speaker_ssim))
        @parser.parse(x)
      end
      it "should not have duplicate values" do
        x = @start_tei_body_div2_session + 
            "<p><date value=\"2013-01-01\">pretending to care</date></p>
            <sp>
              <speaker>M. McRae.</speaker>
              <p>blah blah</p>
            </sp>
            <sp>
              <speaker>M. McRae.</speaker>
              <p>bleah bleah</p>
            </sp>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:speaker_ssim => ['McRae']))
        @parser.parse(x)
      end
    end # speaker_ssim

    context "spoken_text_timv" do
      before(:each) do
        @x = @start_tei_body_div2_session +
            "<p>before</p>
            <p><date value=\"2013-01-01\">pretending to care</date></p>
            <sp>
               <speaker>M. Guadet.</speaker>
               <p>blah blah ... </p>
               <p>bleah bleah ... </p>
            </sp>
            <p>middle</p>
            <sp>
              <p>no speaker</p>
            </sp>
            <sp>
              <speaker/>
              <p>also no speaker</p>
            </sp>
            <p>after</p>" + @end_div2_body_tei
      end
      it "should have a separate value, starting with the speaker, for each <p> inside a single <sp>" do
        @rsolr_client.should_receive(:add).with(hash_including(:spoken_text_timv => ['Guadet-|-blah blah ...', 'Guadet-|-bleah bleah ...']))
        @parser.parse(@x)
      end
      it "should not include <p> text outside an <sp>" do
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_timv => ['before']))
        @parser.parse(@x)
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_timv => ['middle']))
        @parser.parse(@x)
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_timv => ['after']))
        @parser.parse(@x)
      end
      it "should not include <p> text when there is no speaker " do
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_timv => ['no speaker']))
        @parser.parse(@x)
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_timv => ['also no speaker']))
        @parser.parse(@x)
      end
    end # spoken_text_timv
  end # <sp> element
    
  context "text_tiv (catchall field)" do
    before(:all) do
      @begin_body = @start_tei_body_div1 + "<pb n=\"810\" id=\"tq360bc6948_00_0813\"/>"
      @end_body = "<pb n=\"811\" id=\"tq360bc6948_00_0814\"/>" + @end_div1_body_tei
      @begin_back = @start_tei_back_div1 + "<pb n=\"810\" id=\"tq360bc6948_00_0813\"/>"
      @end_back = "<pb n=\"811\" id=\"tq360bc6948_00_0814\"/>" + @end_div1_back_tei
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
          <pb n=\"814\" id=\"tq360bc6948_00_0817\"/>
          <div2 type=\"contents\">
            <p>in body</p>
      #{@end_div2_body_tei}"
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'in body'))
      @parser.parse(x)
    end
    it "should not get content from <front>" do
      x = "<TEI.2><text>
            <front>
              <div type=\"frontpiece\">
                  <pb n=\"\" id=\"ns351vc7243_00_0001\"/>
                  <p>blah blah</p>
              </div>
              <div type=\"abstract\">
                  <pb n=\"ii\" id=\"ns351vc7243_00_0002\"/>
                  <p>front content</p>
              </div>
            </front>
            <body>
              <div1 type=\"volume\" n=\"14\">
                <pb n=\"814\" id=\"tq360bc6948_00_0817\"/>
                <div2 type=\"contents\">
                  <p>in body</p>
            #{@end_div2_body_tei}"
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'in body'))
      @parser.parse(x)
    end
    it "should not include the contents of any attributes" do
      x = @begin_body + "<p>Art. 1<hi rend=\"superscript\">er</hi></p>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'Art. 1er'))
      @parser.parse(x)
      x = @begin_body + "<date value=\"2013-01-01\">pretending to care</date>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'pretending to care'))
      @parser.parse(x)
    end
    it "should include the contents of <p> element" do
      x = @begin_body + "<p>blather</p>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'blather'))
      @parser.parse(x)
    end
    it "should include the contents of <head> element" do
      x = @begin_body + "<head>MARDI 15 OCTOBRE 1793.</head>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'MARDI 15 OCTOBRE 1793.'))
      @parser.parse(x)
    end
    it "should include the contents of <speaker> element" do
      x = @begin_body + "<sp><speaker>M. Bréard.</speaker></sp>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'M. Bréard.'))
      @parser.parse(x)
    end
    it "should include the contents of <date> element" do
      x = @begin_body + "<date value=\"2013-01-01\">pretending to care</date>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'pretending to care'))
      @parser.parse(x)
#      x = @begin_back + "<date value=\"2013-01-01\">pretending to care</date>" + @end_back
#      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'pretending to care'))
#      @parser.parse(x)
    end
    it "should include the contents of <note> element" do
      x = @begin_body + "<note place=\"foot\">(1) shoes.</note>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => '(1) shoes.'))
      @parser.parse(x)
#      x = @begin_back + "<note place=\"foot\">(1) shoes.</note>" + @end_back
#      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => '(1) shoes.'))
#      @parser.parse(x)
    end
    it "should include the contents of <hi> element" do
      x = @begin_body + "<p>Art. 1<hi>er.</hi>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'Art. 1er.'))
      @parser.parse(x)
    end
    it "should include the contents of <term> element" do
      x = @begin_body + "<p><term>Abbaye </term>(Prison de F).</p>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'Abbaye (Prison de F).'))
      @parser.parse(x)
    end
    it "should include the contents of <item> element" do
      x = @begin_body + "<list><item>item!</item></list>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'item!'))
      @parser.parse(x)
    end
    it "should include the contents of <signed> element" do
      x = @begin_body + "<signed>Signé : Remillat, à l'original. </signed>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => "Signé : Remillat, à l'original."))
      @parser.parse(x)
    end
    it "should ignore <trailer>" do
      x = @begin_body + "<trailer>FIN DE L'INTRODUCTION.</trailer><p>blah</p>" + @end_body
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => "blah"))
      @parser.parse(x)
    end
  end

  context "parsing warnings" do
    it "should log a warning when it finds direct non-whitespace text content in a wrapper element" do
      x = @start_tei_body_div2_session +
          "<pb n=\"2\" id=\"ns351vc7243_00_0001\"/>
          <p><date value=\"2013-01-01\">pretending to care</date></p>
          <sp>
             <speaker>M. Guadet.</speaker>
             <p>blah blah ... </p>
             mistake
          </sp>" + @end_div2_body_tei
      @logger.should_receive(:warn).with("Found <sp> tag with direct text content: 'mistake' in page ns351vc7243_00_0001")
      @rsolr_client.should_receive(:add)
      @parser.parse(x)
    end
    it "should log a warning for direct non-whitespace text children of <pb>" do
      x = @start_tei_body_div2_session + 
          "<pb n=\"812\" id=\"tq360bc6948_00_0816\">
          <p>foo</p>
          mistake
          </pb>
          <pb n=\"813\" id=\"tq360bc6948_00_0817\"/>" + @end_div2_body_tei
      @logger.should_receive(:warn).with("Found <pb> tag with direct text content: 'mistake' in page tq360bc6948_00_0816")
      @rsolr_client.should_receive(:add)
      @parser.parse(x)
    end
    it "should log a warning for direct non-whitespace text children when not last" do
      x = @start_tei_body_div2_session + 
          "<pb n=\"812\" id=\"tq360bc6948_00_0816\"/>
          <list>
          <head>bar</head>
          <item>1</item>
          mistake
          <item>2</item>
          </list>
          <pb n=\"813\" id=\"tq360bc6948_00_0817\"/>" + @end_div2_body_tei
      @logger.should_receive(:warn).with("Found <list> tag with direct text content: 'mistake' in page tq360bc6948_00_0816")
      @rsolr_client.should_receive(:add)
      @parser.parse(x)
    end
  end
  
end