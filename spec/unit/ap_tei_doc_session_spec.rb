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
  end

  context "<div2> element" do
    context 'type="session"' do
      before(:all) do
        @x = @start_tei_body_div2_session +
            "<p>actual content</p>" + @end_div2_body_tei
      end
      it "should have doc_type_ssim of 'séance'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ["séance"]))
        @rsolr_client.should_receive(:add).at_least(1).times
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
          @rsolr_client.should_receive(:add).at_least(1).times
          @parser.parse(x)
        end

        context "value attribute" do
          it "should be the value attribute of the first <date> element after <div2>" do
            @rsolr_client.should_receive(:add).with(hash_including(:session_date_val_ssim => ["1793-10-05"]))
            @rsolr_client.should_receive(:add).at_least(1).times
            @parser.parse(@dx)
          end
          it "should ignore subsequent <date> elements and log a warning" do
            x = @start_tei_body_div2_session + 
                "<pb n=\"812\" id=\"tq360bc6948_00_0816\"/>
                <p>Séance du samedi <date value=\"1793-10-05\">5 octobre 1793</date>. </p>
                <p><date value=\"2013-01-01\">pretending to care</date></p>
                <pb n=\"813\" id=\"tq360bc6948_00_0817\"/>" + @end_div2_body_tei
            @rsolr_client.should_receive(:add).with(hash_including(:session_date_dtsim => ["1793-10-05T00:00:00Z"]))
            @rsolr_client.should_receive(:add).at_least(1).times
            @parser.parse(x)
          end
          it "should transform the value into UTC Zulu format" do
            @rsolr_client.should_receive(:add).with(hash_including(:session_date_dtsim => ["1793-10-05T00:00:00Z"]))
            @rsolr_client.should_receive(:add).at_least(1).times
            @parser.parse(@dx)
          end
          it "pages should only have their own session values" do
            x = @start_tei_body_div2_session + 
                "<pb id=\"tq360bc6948_00_0816\"/>
                <p>first <date value=\"1793-10-05\">one</date></p>
                <pb id=\"tq360bc6948_00_0817\"/>
                <p>blah</p>
                </div2>
                <pb id=\"tq360bc6948_00_0818\"/>
                <div2 type=\"session\">
                <p>second <date value=\"1793-10-06\">one</date></p>
                <pb id=\"tq360bc6948_00_0819\"/>
                <p>bleah</p>
                </div2>
                <div2 type=\"session\">
                <p>third <date value=\"1793-10-07\">one</date></p>
                <pb id=\"tq360bc6948_00_0820\"/>
                <p>bleah</p>
                </div2>
                <pb id=\"tq360bc6948_00_0821\"/>
                <div2 type=\"session\">
                <p>fourth <date value=\"1793-10-08\">one</date></p>
                <pb id=\"tq360bc6948_00_0865\"/>" + @end_div2_body_tei
            @rsolr_client.should_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0816', :session_title_ftsim => ["first one"]))
            @rsolr_client.should_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0817', :session_title_ftsim => ["first one"]))
            @rsolr_client.should_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0818', :session_title_ftsim => ["second one"]))
            @rsolr_client.should_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0819', :session_title_ftsim => ["second one", "third one"]))
            @rsolr_client.should_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0820', :session_title_ftsim => ["third one"]))
            @rsolr_client.should_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0821', :session_title_ftsim => ["fourth one"]))
            @rsolr_client.should_receive(:add).at_least(1).times
            @parser.parse(x)
          end
        end # date value
        
        context "session_title is text from element surrounding date (+ date text)" do
          it "should get the text from a surrounding <p> element" do
            # <p>Séance du samedi <date value=\"1793-10-05\">5 octobre 1793</date>. </p>
            @rsolr_client.should_receive(:add).with(hash_including(:session_title_ftsim => ["Séance du samedi 5 octobre 1793"]))
            @rsolr_client.should_receive(:add).at_least(1).times
            @parser.parse(@dx)
          end
          it "should ignore text from other <p> elements" do
            x = @start_tei_body_div2_session + 
                "<pb n=\"812\" id=\"tq360bc6948_00_0816\"/>
                <p>la</p>
                <p>Séance du <date value=\"1792-04-19\">jeudi 19 avril 1792</date>, au soir, </p>
                <p>gah</p>
                <pb n=\"813\" id=\"tq360bc6948_00_0817\"/>" + @end_div2_body_tei
            @rsolr_client.should_receive(:add).with(hash_including(:session_title_ftsim => ['Séance du jeudi 19 avril 1792, au soir']))
            @rsolr_client.should_receive(:add).at_least(1).times
            @parser.parse(x)
          end
          it "should only get the first date's surrounding text" do
            x = @start_tei_body_div2_session + 
                "<pb n=\"812\" id=\"tq360bc6948_00_0816\"/>
                <p>Séance du samedi <date value=\"1793-10-05\">5 octobre 1793</date>. </p>
                <p><date value=\"2013-01-01\">pretending to care</date></p>
                <pb n=\"813\" id=\"tq360bc6948_00_0817\"/>" + @end_div2_body_tei
            @rsolr_client.should_receive(:add).with(hash_including(:session_title_ftsim => ["Séance du samedi 5 octobre 1793"]))
            @rsolr_client.should_receive(:add).at_least(1).times
            @parser.parse(x)
          end
          it "should get the text from a surrounding <p> element when there is no preceding text" do
            x = @start_tei_body_div2_session + 
                "<pb n=\"812\" id=\"tq360bc6948_00_0816\"/>
                <p><date value=\"1792-09-20\">Jeudi 20 septembre 1792</date>, au soir.</p>
                <pb n=\"813\" id=\"tq360bc6948_00_0817\"/>" + @end_div2_body_tei
            @rsolr_client.should_receive(:add).with(hash_including(:session_title_ftsim => ["Jeudi 20 septembre 1792, au soir"]))
            @rsolr_client.should_receive(:add).at_least(1).times
            @parser.parse(x)
          end
          it "should call normalize_session_title" do
            @atd.should_receive(:normalize_session_title).and_call_original
            @rsolr_client.should_receive(:add).with(hash_including(:session_title_ftsim => ["Séance du samedi 5 octobre 1793"]))
            @rsolr_client.should_receive(:add).at_least(1).times
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
            @rsolr_client.should_receive(:add).with(hash_including(:session_title_ftsim => ["first one", "another one"]))
            @rsolr_client.should_receive(:add).at_least(1).times
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
            @rsolr_client.should_receive(:add).with(hash_including(:session_title_ftsim => ["Séance du jeudi 19 avril 1792, au soir"]))
            @rsolr_client.should_receive(:add).at_least(1).times
            @parser.parse(x)
          end
        end # session_title
         
        context "session_date_title_ssim" do
          it "should be (session_date_dtsim) -|- (session_title)" do
            x = @start_tei_body_div2_session + 
                "<pb n=\"812\" id=\"tq360bc6948_00_0816\"/>
                <p>Séance du samedi <date value=\"1793-10-05\">5 octobre 1793</date>. </p>
                <pb n=\"813\" id=\"tq360bc6948_00_0817\"/>" + @end_div2_body_tei
            @rsolr_client.should_receive(:add).with(hash_including(:session_date_title_ssim => ["1793-10-05-|-Séance du samedi 5 octobre 1793"]))
            @rsolr_client.should_receive(:add).at_least(1).times
            @parser.parse(x)
          end
        end
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
          @rsolr_client.should_receive(:add).at_least(1).times
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
          @rsolr_client.should_receive(:add).at_least(1).times
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
          @rsolr_client.should_receive(:add).at_least(1).times
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
          @rsolr_client.should_receive(:add).at_least(1).times
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
          @rsolr_client.should_receive(:add).at_least(1).times
          @parser.parse(x)
        end
        it "should ignore whitespace before first <head> or <p>" do
          x = @start_tei_body_div2_session + 
                "<pb n=\"810\" id=\"tq360bc6948_00_0813\"/>
                
                <head>CONVENTION NATIONALE</head>
                <p>blah blah</p>
                <pb n=\"811\" id=\"tq360bc6948_00_0814\"/>" + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_including(:session_govt_ssim => ["CONVENTION NATIONALE"]))
          @rsolr_client.should_receive(:add).at_least(1).times
          @parser.parse(x)
        end
        it "should find the value if it is in <p> instead of <head>" do
          x = @start_tei_body_div2_session + 
                "<pb n=\"810\" id=\"tq360bc6948_00_0813\"/>
                <p>ASSEMBLÉE NATIONALE LÉGISLATIVE. </p>
                <p>blah blah</p>
                <pb n=\"811\" id=\"tq360bc6948_00_0814\"/>" + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_including(:session_govt_ssim => ["ASSEMBLÉE NATIONALE LÉGISLATIVE"]))
          @rsolr_client.should_receive(:add).at_least(1).times
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
          @rsolr_client.should_receive(:add).at_least(1).times
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
                            :session_title_ftsim => ["Séance du samedi 5 octobre 1793"] }
        @rsolr_client.should_receive(:add).with(hash_including(exp_hash_fields)).twice
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser.parse(x)
      end
    end # type session    
  end # <div2> element

  it "should log a warning for unparseable dates" do
    x = @start_tei_body_div2_session + 
        "<pb n=\"812\" id=\"tq360bc6948_00_0816\"/>
        <p>boo <date value=\"1792-999-02\">5 octobre 1793</date> ya</p>
        <pb n=\"813\" id=\"tq360bc6948_00_0817\"/>" + @end_div2_body_tei
    @logger.should_receive(:warn).with("Found <date> tag with unparseable date value: '1792-999-02' in page tq360bc6948_00_0816")
    @rsolr_client.should_receive(:add).at_least(1).times
    @parser.parse(x)
  end

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
        @rsolr_client.should_receive(:add).at_least(1).times
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
        @rsolr_client.should_receive(:add).at_least(1).times
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
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser.parse(x)
      end
      it "should not be present if there is no <speaker> element" do
        x = @start_tei_body_div2_session + 
            "<p>La séance est ouverte à neuf heures du matin. </p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_not_including(:speaker_ssim))
        @rsolr_client.should_receive(:add).at_least(1).times
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
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser.parse(x)
      end
      it "should call normalize_speaker" do
        x = @start_tei_body_div2_session + 
            "<p><date value=\"2013-01-01\">pretending to care</date></p>
            <sp>
              <speaker>&gt;M. le Président</speaker>
              <p>bleah bleah</p>
            </sp>" + @end_div2_body_tei
        @atd.should_receive(:normalize_speaker).and_call_original
        @rsolr_client.should_receive(:add).with(hash_including(:speaker_ssim => ['Le Président']))
        @rsolr_client.should_receive(:add).at_least(1).times
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
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser.parse(@x)
      end
      it "should not include <p> text outside an <sp>" do
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_timv => ['before']))
        @rsolr_client.should_receive(:add)
        @parser.parse(@x)
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_timv => ['middle']))
        @rsolr_client.should_receive(:add)
        @parser.parse(@x)
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_timv => ['after']))
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser.parse(@x)
      end
      it "should not include <p> text when there is no speaker " do
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_timv => ['no speaker']))
        @rsolr_client.should_receive(:add)
        @parser.parse(@x)
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_timv => ['also no speaker']))
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser.parse(@x)
      end
      it "should not include <p> text past </sp> element" do
        x = @start_tei_body_div2_session +
            "<p><date value=\"2013-01-01\">pretending to care</date></p>
            <sp>
               <speaker>M. Guadet.</speaker>
               <p>blah blah ... </p>
               <p>bleah bleah ... </p>
            </sp>
            <p>after</p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:spoken_text_timv => ['Guadet-|-blah blah ...', 'Guadet-|-bleah bleah ...']))
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser.parse(@x)
      end
      it "should not include <p> text past </sp> element", :jira => 'FRDA-107' do
        x = @start_tei_body_div2_session +
            "<p><date value=\"2013-01-01\">pretending to care</date></p>
            <sp>
               <speaker>M. Guadet.</speaker>
               <p>blah blah ... </p>
               <p>bleah bleah ... </p>
            </sp>
            <div3 type=\"annexe\">
              <head>PREMIÈRE ANNEXE (1)</head>
                <p>after</p>
            </div3>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:spoken_text_timv => ['Guadet-|-blah blah ...', 'Guadet-|-bleah bleah ...']))
        @rsolr_client.should_receive(:add).at_least(1).times
        @parser.parse(@x)
      end
    end # spoken_text_timv
  end # <sp> element
  
end