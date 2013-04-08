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
                            :vol_total_pages_is => 806 }
    @page_id_hash = { 'aa222bb4444_00_0001' => 1, 
                      'aa222bb4444_00_0002' => 2, 
                      'aa222bb4444_00_0805' => 805, 
                      'aa222bb4444_00_0806' => 806 }
    @rsolr_client = RSolr::Client.new('http://somewhere.org')
    @logger = Logger.new(STDOUT)
    @atd = ApTeiDocument.new(@rsolr_client, @druid, @volume, @vol_constants_hash, @page_id_hash, @logger)
    @parser = Nokogiri::XML::SAX::Parser.new(@atd)
    @start_tei_body = "<TEI.2><text><body>"
    @start_tei_body_div1 = @start_tei_body+ "<div1 type=\"volume\" n=\"36\">"
    @start_tei_body_div2_session = @start_tei_body_div1 + "<div2 type=\"session\">"
    @end_div1_body_tei = "</div1></body></text></TEI.2>"
    @end_div2_body_tei = "</div2>#{@end_div1_body_tei}"
    @start_tei_back = "<TEI.2><text><back>"
    @start_tei_back_div1 = @start_tei_back + "<div1 type=\"volume\" n=\"36\">"
    @end_div1_back_tei = "</div1></back></text></TEI.2>"
    @end_div2_back_tei = "</div2>#{@end_div1_back_tei}"
    @session_type = ApTeiDocument::DIV2_TYPE['session']
    @page_type = ApTeiDocument::PAGE_TYPE
  end

  context "init_div2_doc_hash" do
    before(:all) do
      @x = @start_tei_body_div2_session +
          "<pb n=\"5\" id=\"#{@druid}_00_0001\"/>
          <p>actual content</p>
          <pb n=\"6\" id=\"#{@druid}_00_0002\"/>" + @end_div2_body_tei
    end
    it "should populate id field" do
      @rsolr_client.should_receive(:add).at_least(1).times
      @parser.parse(@x)
      @atd.div2_doc_hash[:id].should == "#{@druid}_div2_1"
    end
    it "should populate type_ssi field" do
      @rsolr_client.should_receive(:add).at_least(1).times
      @parser.parse(@x)
      @atd.div2_doc_hash[:type_ssi].should == @session_type
    end
    it "should call add_vol_fields_to_hash for div2_doc_hash" do
      @rsolr_client.should_receive(:add).at_least(1).times
      @atd.should_receive(:init_div2_doc_hash).and_call_original
      @atd.should_receive(:add_vol_fields_to_hash).with(hash_including(:type_ssi => @page_type)).at_least(2).times
      @atd.should_receive(:add_vol_fields_to_hash).with(hash_including(:type_ssi => @session_type, :doc_type_ssi => @session_type))
      @parser.parse(@x)
    end
    it "should populate doc_type_ssim" do
      @rsolr_client.should_receive(:add).at_least(1).times
      @atd.should_receive(:init_div2_doc_hash).and_call_original
      @parser.parse(@x)
      @atd.div2_doc_hash[:doc_type_ssi].should == @session_type
    end
  end 

  context "<div2> element" do
    it "start of <div2> element should call init_div2_doc_hash" do
      x = @start_tei_body_div2_session +
          "<p>actual content</p>" + @end_div1_body_tei
      @atd.should_receive(:init_div2_doc_hash)
      @parser.parse(x)
    end
    it "end of <div2> element should not call init_div2_doc_hash" do
      x = @start_tei_body_div1 +
          "<p>actual content</p>" + @end_div2_body_tei
      @atd.should_not_receive(:init_div2_doc_hash)
      @parser.parse(x)
    end
    it "end of <div2> element should call add_div2_doc_to_solr" do
      x = @start_tei_body_div2_session +
          "<p>actual content</p>" + @end_div2_body_tei
      @atd.should_receive(:add_div2_doc_to_solr)
      @rsolr_client.should_receive(:add)
      @parser.parse(x)
    end
    it "start of <div2> element should not call add_div2_doc_to_solr" do
      x = @start_tei_body_div2_session +
          "<p>actual content</p>" + @end_div1_body_tei
      @atd.should_not_receive(:add_div2_doc_to_solr)
      @parser.parse(x)
    end
    it "multiple <div2> elements create multiple div2 docs" do
      x = @start_tei_body_div2_session +
          "  <p>actual content</p>
          </div2>
          <div2 type=\"session\">
            <p>more</p>" + @end_div2_body_tei
      @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1", :type_ssi => 'séance'))
      @rsolr_client.should_receive(:add).with(hash_including(:type_ssi => @page_type))
      @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_2", :type_ssi => 'séance'))
      @parser.parse(x)
    end
    
    shared_examples_for "doc for div2 type" do | div2_type |
      it "div2 doc should have doc_type_ssi and type_ssi of '#{div2_type}'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => [div2_type], :type_ssi => @page_type))
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssi => div2_type, :type_ssi => div2_type))
        @parser.parse(@x)
      end
    end
    
    context 'type="session"' do
      before(:all) do
        @x = @start_tei_body_div2_session + 
            "<pb n=\"812\" id=\"#{@druid}_00_0816\"/>
            <head>CONVENTION NATIONALE </head>
            <p>Séance du samedi <date value=\"1793-10-05\">5 octobre 1793</date>. </p>
            <p>L'an II de la République Française une et indivisible </p>
            <sp>
              <speaker>M. Guadet</speaker>
              <p>blah blah</p>
            </sp>" + @end_div2_body_tei
      end
      it_should_behave_like "doc for div2 type", ApTeiDocument::DIV2_TYPE['session']
      
      # NOTE:  many session field specifics are tested in ap-tei_doc_session_spec
      it "div2 doc should have session fields when it's a session" do
        @rsolr_client.should_receive(:add).with(hash_including(
          :doc_type_ssi => @session_type,
          :session_date_val_ssi => "1793-10-05",
          :session_date_dtsi => "1793-10-05T00:00:00Z",
          :session_title_ftsi => 'Séance du samedi 5 octobre 1793',
          :session_date_title_ssi => "1793-10-05-|-Séance du samedi 5 octobre 1793",
          :session_govt_ssi =>  "CONVENTION NATIONALE"))
        @rsolr_client.should_receive(:add).with(hash_including(:type_ssi => @page_type))
        @parser.parse(@x)
      end
      
      it "should include speaker_ssim when appropriate" do
        # this is tested in ap_tei_doc_session_spec
      end
      
      context "spoken text" do
        it "should include spoken_text_ssim when appropriate" do
          # this is tested in ap_tei_doc_session_spec
        end
        it "should be able to search spoken text across page breaks", :integration => true do
          pending "to be implemented as an integration test"
        end
      end
      
      context "unspoken text" do
        it "should include <p> session text when there is no speaker" do
          page_id = "#{@druid}_00_0816"
          x = @start_tei_body_div2_session +
                "<pb n=\"812\" id=\"#{page_id}\"/>
                <p>before</p>
                <p><date value=\"2013-01-01\">session title</date></p>
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
          @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => [
                        "before", 
                        "middle", 
                        "no speaker", 
                        "also no speaker", 
                        "after"], :id => page_id))
          @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => [
                        "#{page_id}-|-before", 
                        "#{page_id}-|-middle", 
                        "#{page_id}-|-no speaker", 
                        "#{page_id}-|-also no speaker", 
                        "#{page_id}-|-after"], :id => "#{@druid}_div2_1"))
          @parser.parse(x)
        end
      end
    end # type session
    
    context 'type="alpha"' do
      before(:all) do
        @x = "#{@start_tei_back_div1}<div2 type=\"alpha\">
                <pb n=\"5\" id=\"#{@druid}_00_0001\"/>
                <p>blah blah</p>" + @end_div2_back_tei
      end
      it_should_behave_like "doc for div2 type", ApTeiDocument::DIV2_TYPE['alpha'] 
      it "shouldn't have session fields" do
        @rsolr_client.should_not_receive(:add).with(hash_including(:session_date_dtsi))
        @parser.parse(@x)
      end
    end
    context 'type="contents"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"contents\">
                <pb n=\"5\" id=\"#{@druid}_00_0008\"/>
                <p>blah blah</p>
                <pb n=\"6\" id=\"#{@druid}_00_0009\"/>" + @end_div2_body_tei
      end
      it_should_behave_like "doc for div2 type", ApTeiDocument::DIV2_TYPE['contents'] 
    end
    context 'type="other"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"other\">
                <pb n=\"5\" id=\"#{@druid}_00_0001\"/>
                <p>blah blah</p>" + @end_div2_body_tei
      end
      it_should_behave_like "doc for div2 type", ApTeiDocument::DIV2_TYPE['other'] 
    end
    context 'type="table_alpha"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"table_alpha\">
                <pb n=\"5\" id=\"#{@druid}_00_0001\"/>
                <p>blah blah</p>" + @end_div2_body_tei
      end
      it_should_behave_like "doc for div2 type", ApTeiDocument::DIV2_TYPE['table_alpha'] 
    end
    context 'type="introduction"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"introduction\">
                <pb n=\"5\" id=\"#{@druid}_00_0001\"/>
                <p>blah blah</p>" + @end_div2_body_tei
      end
      it_should_behave_like "doc for div2 type", ApTeiDocument::DIV2_TYPE['introduction'] 
    end
  end # <div2> element
  
  context "div2 solr doc pages_ssim" do
    
    context "opening <div2> tag" do
      context "first <div2> in <div1>" do
        it "<pb> just before <div1> (<body>)" do
          x = @start_tei_body + 
              "<pb n=\"1\" id=\"#{@druid}_00_0007\"/>
              <div1 type=\"volume\" n=\"36\">
                <head>ARCHIVES PARLEMENTAIRES </head>
                <head>RÉPUBLIQUE FRANÇAISE </head>
                  <div2 type=\"table_alpha\">
                  <p>something</p>" + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                          :pages_ssim => ["#{@druid}_00_0007-|-1"]))
          @parser.parse(x)
        end
        it "<pb> just before <div1> (<back>)" do
          x = @start_tei_back +
                "<pb n=\"\" id=\"#{@druid}_00_0742\"/>
                <div1 type=\"volume\" n=\"36\">
                  <head>ARCHIVES PARLEMENTAIRES </head>
                  <head>PREMIÈRE SÉRIE </head>
                  <div2 type=\"contents\">
                    <head>TABLE CHRONOLOGIQUE DU TOME L </head>" + @end_div2_back_tei
          @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                          :pages_ssim => ["#{@druid}_00_0742-|-"]))
          @parser.parse(x)
        end
        it "<pb> before </front><div1>" do
          x = "<TEI.2><text><front>
                  <pb n=\"iv\" id=\"#{@druid}_00_0004\"/>
                </front>
                <body>
                  <div1 type=\"volume\" n=\"2\">
                    <head>ARCHIVES PARLEMENTAIRES </head>
                    <div2 type=\"other\">
                      <head>SÉNÉCHAUSSÉE D'ANGOUMOIS </head>
                      <pb n=\"1\" id=\"#{@druid}_00_0005\"/>
                      <div3 type=\"other\">
                        <head>CAHIER</head>
                        <head>more</head>
                        <p>stuff</p>
                      </div3>" + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                          :pages_ssim => ["#{@druid}_00_0005-|-1"]))
          @parser.parse(x)
        end
        it "<pb> just after <div1> and just before <div2>" do
          x = @start_tei_body_div1 + "  
                <pb n=\"III\" id=\"#{@druid}_00_0004\"/>
                <div2 type=\"other\">
                <head>LOUKMENT DBS DÉPUTÉS AUX ÉTATS GÉNÉRAUX. </head>" + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                          :pages_ssim => ["#{@druid}_00_0004-|-III"]))
          @parser.parse(x)
        end
        it "<pb> just after <div1> before <div2> introduction" do
          x = @start_tei_body_div1 +
              "<pb n=\"19\" id=\"#{@druid}_00_0025\"/>
               <div2 type=\"introduction\">
                 <head>INTRODUCTION</head>
                 <p>blah</p>" + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                         :pages_ssim => ["#{@druid}_00_0025-|-19"]))
          @parser.parse(x)
        end
        it "<pb> just after <div1> and before div1 <head>" do
          x = @start_tei_body + 
              "<div1 type=\"volume\" n=\"36\">
                <pb n=\"1\" id=\"#{@druid}_00_0007\"/>
                <head>ARCHIVES PARLEMENTAIRES </head>
                <head>RÉPUBLIQUE FRANÇAISE </head>
                  <div2 type=\"table_alpha\">
                  <p>something</p>" + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                          :pages_ssim => ["#{@druid}_00_0007-|-1"]))
          @parser.parse(x)
        end
        it "multiple <pb> in <div1> before <div2> contents" do
          x = @start_tei_back_div1 
              "<pb n=\"767\" id=\"#{@druid}_00_0771\"/>
                <head>TABLE </head>
                <head>CHRONOLOGIQUE, ALPHABÉTIQUE ET ANALYTIQUE </head>
                <head>DU TOME XVI</head>
                <pb n=\"\" id=\"#{@druid}_00_0772\"/>
                <pb n=\"\" id=\"#{@druid}_00_0773\"/>
                <head>ARCHIVES PARLEMENTAIRES </head>
                <head>PREMIÈRE SÉRIE </head>
                <div2 type=\"contents\">
                  <head>TABLE CHRONOLOGIQUE </head>" + @end_div2_back_tei
          @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                          :pages_ssim => ["#{@druid}_00_0773-|-"]))
          @parser.parse(x)
        end
        it "<pb> just before <div2>" do
          x = @start_tei_body + 
              "<div1 type=\"volume\" n=\"36\">
                <head>ARCHIVES PARLEMENTAIRES </head>
                <head>RÉPUBLIQUE FRANÇAISE </head>
                <pb n=\"1\" id=\"#{@druid}_00_0007\"/>
                  <div2 type=\"table_alpha\">
                  <p>something</p>" + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                          :pages_ssim => ["#{@druid}_00_0007-|-1"]))
          @parser.parse(x)
        end
        it "<pb> just after <div2>" do
          x = @start_tei_body_div1 + 
              "<div2 type=\"other\">
                <pb n=\"1\" id=\"#{@druid}_00_0007\"/>
                <p>Compte rendu du Moniteur universel (1). </p>"  + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                          :pages_ssim => ["#{@druid}_00_0007-|-1"]))
          @parser.parse(x)
        end
      end # first <div2> in <div1>

      it "<pb> just after <div2> table_alpha" do
        x = @start_tei_body_div1 + 
            "<div2 type=\"table_alpha\">
              <pb n=\"1\" id=\"#{@druid}_00_0007\"/>
              <head>LISTE </head>
              <head>DES NOMS ET QUALITÉS DE MESSIEURS LES DÉPUTÉS ET SUPPLÉANTS </head>
              <head>A L'ASSEMBLÉE NATIONALE, </head>
              <head>DRESSÉE PAR ORDRE ALPHABÉTIQUE DE SÉNÉCHAUSSÉES ET BAILLIAGES. </head>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                        :pages_ssim => ["#{@druid}_00_0007-|-1"]))
        @parser.parse(x)
      end
      it "<pb> just after <div2> other simple" do
        x = @start_tei_body_div1 + 
            "<div2 type=\"other\">
              <pb n=\"778\" id=\"#{@druid}_00_0781\"/>
              <p>orphelins des citoyens tués à la guerre (19 septembre 1792, t. L, p. 146). </p>
              <p><term>Ouvriers des ports</term>. Rapport de Grégoire sur leurs salaires (t. L, p. 659 et
                suiv.). — Rapport de Granet (de Toulon) sur le même objet (p. 661 et suiv.). </p>
            </div2>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                       :pages_ssim => ["#{@druid}_00_0781-|-778"]))
        @parser.parse(x)
      end
      it "<pb> just after <div2> other with <term>" do
        x = @start_tei_back_div1 + 
            "<div2 type=\"other\">
              <pb n=\"770\" id=\"#{@druid}_00_0776\"/>
              <p><term>Hugo,</term>blah</p>
              <p><term>Huguet</term>blah</p>
            </div2>" + @end_div2_back_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                       :pages_ssim => ["#{@druid}_00_0776-|-770"]))
        @parser.parse(x)
      end
      it "<pb> just after <div2> other with <head>" do
        x = @start_tei_body_div1 + 
            "<div2 type=\"other\">
              <pb n=\"64\" id=\"#{@druid}_00_0068\"/>
              <head>SÉNÉCHAUSSÉE D'ARMAGNAC, </head>
              <head>LECTOURE ET ISLE-JOURDAIN </head>
              <div3 type=\"other\">
                <head>CAHIER DES DOLÉANCES</head>
              </div3>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                       :pages_ssim => ["#{@druid}_00_0068-|-64"]))
        @parser.parse(x)
      end
      it "<pb> after <div2> other head" do
        x = @start_tei_body + 
            "<pb n=\"46\" id=\"#{@druid}_00_0050\"/>
            <div1>
            <div2>
              <p>blah</p>
            </div2>
            <div2 type=\"other\">
              <head>VICOMTE DE COUZERANS </head>
              <pb n=\"47\" id=\"#{@druid}_00_0051\"/>
              <p>Nota. Les cahiers du clergé</p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                       :pages_ssim => ["#{@druid}_00_0050-|-46",
                                        "#{@druid}_00_0051-|-47"]))
        @parser.parse(x)
      end
      it "<pb> after <div2> session headings as <p>" do
        x = @start_tei_back_div1 +
            "<div2 type=\"other\">
              <pb n=\"706\" id=\"#{@druid}_00_0710\"/>
              <p>blah
            </div2>
            <div2 type=\"session\">
              <head>CONVENTION NATIONALE. </head>
              <p>Sénce du<date value=\"1793-01-10\"> jeudi 10 janvier 1793</date>, AU MATIN. </p>
              <p>PRÉSIDENCE DE TREILUARD, président. </p>
              <p>La séance est ouverte à dix heures trois quarts du matin.</p>
              <pb n=\"707\" id=\"#{@druid}_00_0711\"/>
              <p> blah</p>" + @end_div2_back_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                       :pages_ssim => ["#{@druid}_00_0710-|-706"]))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_2",
                       :pages_ssim => ["#{@druid}_00_0710-|-706", "#{@druid}_00_0711-|-707"]))
        @parser.parse(x)
      end
      it "<pb> after <div2> session headings as <head>" do
        x = @start_tei_body_div1 + 
            "<pb n=\"67\" id=\"#{@druid}_00_0070\"/>
            <div2 type=\"other\">
              <p>blah
            </div2>
            <div2 type=\"session\">
              <head>CONVENTION NATIONALE.</head>
              <head> Séance du <date value=\"1793-02-21\">jeudi 21 février 1793</date>, au soir. </head>
              <head>PRÉSIDENCE DE BRÉARD, président.</head>
              <p> La séance est ouverte aTsept heures çïu soir.</p>
              <pb n=\"68\" id=\"#{@druid}_00_0071\"/>
              <p> blah</p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                       :pages_ssim => ["#{@druid}_00_0070-|-67"]))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_2",
                       :pages_ssim => ["#{@druid}_00_0070-|-67", "#{@druid}_00_0071-|-68"]))
        @parser.parse(x)
      end
      it "<pb> after <div2> alpha first <term>" do
        x = @start_tei_body_div1 + 
            "<pb n=\"706\" id=\"#{@druid}_00_0771\"/>
            <div2 type=\"alpha\">
             <head>K</head>
             <p><term>Kauffmann,</term> blah</p>
             <p><term>Kytspotter,</term> bleah </p>
            </div2>
            <div2 type=\"alpha\">
              <head>L </head>
              <p><term>Labeste,</term> député des communes du bailliage de Reims.</p>
              <!-- this one is what we're testing -->
              <pb n=\"707\" id=\"#{@druid}_00_0772\"/>
              <p>Répond à l'appel général (t. VIII, p. 97). </p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                       :pages_ssim => ["#{@druid}_00_0771-|-706"]))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_2",
                       :pages_ssim => ["#{@druid}_00_0771-|-706", "#{@druid}_00_0772-|-707"]))
        @parser.parse(x)
      end
      it "<pb> after <div2> alpha first <term>" do
        x = @start_tei_body_div1 + 
            "<pb n=\"767\" id=\"#{@druid}_00_0770\"/>
            <div2 type=\"alpha\">
              <head>K</head>
              <p><term>Kauffmann,</term> blah</p>
              <p><term>Kytspotter,</term> bleah </p>
            </div2>
            <div2 type=\"alpha\">
              <head>E </head>
              <p><term>Eaux de Paris</term>. blah. </p>
              <p><term>École des Ponts et Chaussées</term>. Somme mise à la dis-</p>
              <!-- testing this one -->
              <pb n=\"768\" id=\"#{@druid}_00_0771\"/>
              <p>magasins nationaux (16 septembre 1792, t. L, p. 62). </p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                       :pages_ssim => ["#{@druid}_00_0770-|-767"]))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_2",
                       :pages_ssim => ["#{@druid}_00_0770-|-767", "#{@druid}_00_0771-|-768"]))
        @parser.parse(x)
      end
    end # opening <div2> tag
    
    context "multiple pages in a div2" do
      it "pages_ssim" do
        x = @start_tei_body_div1 +
              "<pb n=\"100\" id=\"#{@druid}_00_0110\"/>
              <p>before</p>
              <pb n=\"101\" id=\"#{@druid}_00_0111\"/>
              <p>before2</p>
              <div2 type=\"session\">
                <p><date value=\"2013-01-01\">session title</date></p>
                <sp>
                   <speaker>M. Guadet.</speaker>
                   <p>blah blah ... </p>
                   <p>bleah bleah ... </p>
                </sp>
                <p>middle</p>
                <pb n=\"102\" id=\"#{@druid}_00_0112\"/>
                <sp>
                  <p>no speaker</p>
                </sp>
                <pb n=\"103\" id=\"#{@druid}_00_0113\"/>
                <sp>
                  <speaker/>
                  <p>also no speaker</p>
                </sp>
                <div3 type=\"other\">
                <p>here</p>
                <pb n=\"104\" id=\"#{@druid}_00_0114\"/>
                <p>after</p>
                </div3>
              </div2>
              <p>after2</p>
              <pb n=\"105\" id=\"#{@druid}_00_0115\"/>" + @end_div1_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                        :pages_ssim => ["#{@druid}_00_0111-|-101",
                                        "#{@druid}_00_0112-|-102",
                                        "#{@druid}_00_0113-|-103",
                                        "#{@druid}_00_0114-|-104"]))
        @parser.parse(x)
      end
      it "paging withing type other terms" do
        x = @start_tei_body_div1 + 
            "<pb n=\"711\" id=\"#{@druid}_00_0776\"/>
            <div2 type=\"other\">
              <p><term>Luynes</term>blah</p>
              <pb n=\"712\" id=\"#{@druid}_00_0777\"/>
              <p><term>Luynes</term>hoo ha</p>
            </div2>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                       :pages_ssim => ["#{@druid}_00_0776-|-711", "#{@druid}_00_777-|-712"]))
        @parser.parse(x)
      end
    end
    
    context "closing </div2> tag variants" do
      it "<pb> just before closing </div2>" do
        x = @start_tei_body_div1 + 
            "<pb n=\"234\" id=\"#{@druid}_00_0299\"/>
            <div2 type=\"other\">
              <p>délibérations seraient reprises d'un instant à l'autre.</p>
              <pb n=\"235\" id=\"#{@druid}_00_0300\"/>
            </div2>
            <div2 type=\"session\">
              <p><date value=\"2013-01-01\">session title</date></p>
              <p>stuff</p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                       :pages_ssim => ["#{@druid}_00_0299-|-234"]))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_2",
                       :pages_ssim => ["#{@druid}_00_0300-|-235"]))
        @parser.parse(x)
      end
      it "<pb> just before closing sp for session" do
        x = @start_tei_body_div1 + 
            "<pb n=\"307\" id=\"#{@druid}_00_0372\"/>
            <div2 type=\"session\">
              <p><date value=\"2013-01-01\">session title</date></p>
              <sp>
                <speaker>M. Guadet.</speaker>
                <p>gobble</p>
                <pb n=\"308\" id=\"#{@druid}_00_0373\"/>
              </sp>
            </div2>
            <div2 type=\"session\">
              <p><date value=\"2013-01-01\">session title</date></p>
              <p>blah blah ... </p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                       :pages_ssim => ["#{@druid}_00_0372-|-307"]))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_2",
                       :pages_ssim => ["#{@druid}_00_0373-|-308"]))
        @parser.parse(x)
      end
      it "<pb> not just before closing sp for session" do
        x = @start_tei_body_div1 + 
            "<pb n=\"197\" id=\"#{@druid}_00_0201\"/>
            <div2 type=\"other\">
              <sp>
                <speaker>someone</speaker>
                <p>something</p>
                <pb n=\"198\" id=\"#{@druid}_00_0202\"/>
                <p>(La séance est levée à trois heures.) </p>
              </sp>
            </div2>
            <div2 type=\"session\">
              <p><date value=\"2013-01-01\">session title</date></p>
              <p>blah blah ... </p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                       :pages_ssim => ["#{@druid}_00_0201-|-197", "#{@druid}_00_0202-|-198"]))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_2",
                       :pages_ssim => ["#{@druid}_00_0202-|-198"]))
        @parser.parse(x)
      end
      it "<pb> after <div2> before <div1> end of <body>" do
        x = @start_tei_body_div1 + 
              "<pb n=\"\" id=\"#{@druid}_00_0723\"/>
              <div2 type=\"other\">
                <p>blah</p>
              </div2>
              <pb n=\"\" id=\"#{@druid}_00_0724\"/>
            </div1>
          </body>
          <back>
            <div1 type=\"volume\" n=\"36\">
              <head>ARCHIVES PARLEMENTAIRES </head>
              <head>PREMIERE SERIE </head>
              <div2 type=\"contents\">
                <head>TABLE CHRONOLOGIQUE DU TOME LXXYI </head>" + @end_div2_back_tei
          @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                          :pages_ssim => ["#{@druid}_00_0723-|-"]))
          @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_2",
                          :pages_ssim => ["#{@druid}_00_0724-|-"]))
          @parser.parse(x)
      end
      it "<pb> just after <back>" do
        x = @start_tei_body_div1 + 
                "<pb n=\"\" id=\"#{@druid}_00_0742\"/>
                <div2 type=\"other\">
                  <p>stuff</p>
                </div2>
              </div1>
            </body>
            <back>
              <pb n=\"\" id=\"#{@druid}_00_0743\"/>
              <div1 type=\"volume\" n=\"36\">
                <div2 type=\"other\">
                  <p>foo</p>" + @end_div2_back_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                        :pages_ssim => ["#{@druid}_00_0742-|-"]))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_2",
                        :pages_ssim => ["#{@druid}_00_0743-|-"]))
        @parser.parse(x)
      end
    end # closing tag

    context "pages spanning mult div2" do
      it "<pb> between <div2> other" do
        x = @start_tei_body_div1 + 
            "<pb n=\"100\" id=\"#{@druid}_00_0110\"/>
            <div2 type=\"other\">
              <p>me</p>
              <p>first</p>
            </div2>
            <pb n=\"101\" id=\"#{@druid}_00_0111\"/>
            <div2 type=\"other\">
              <p>second</p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                        :pages_ssim => ["#{@druid}_00_0110-|-100"]))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_2",
                        :pages_ssim => ["#{@druid}_00_0111-|-101"]))
        @parser.parse(x)
      end
      it "page across </div2> simple" do
        x = @start_tei_body_div1 + 
            "<div2 type=\"other\">
              <pb n=\"748\" id=\"#{@druid}_00_0754\"/>
              <p>one</p>
            </div2>
            <div2 type=\"alpha\">
              <p>two</p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                       :pages_ssim => ["#{@druid}_00_0754-|-748"]))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_2",
                       :pages_ssim => ["#{@druid}_00_0754-|-748"]))
        @parser.parse(x)
      end
      it "page across div2 other" do
        x = @start_tei_body_div1 + 
            "<div2 type=\"other\">
              <pb n=\"100\" id=\"#{@druid}_00_0110\"/>
              <p>me</p>
              <pb n=\"101\" id=\"#{@druid}_00_0111\"/>
              <p>first</p>
            </div2>
            <div2 type=\"other\">
              <p>second</p>
              <pb n=\"102\" id=\"#{@druid}_00_0112\"/>
              <p>last</p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                        :pages_ssim => ["#{@druid}_00_0110-|-100",
                                        "#{@druid}_00_0111-|-101"]))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_2",
                        :pages_ssim => ["#{@druid}_00_0111-|-101",
                                        "#{@druid}_00_0112-|-102"]))
        @parser.parse(x)
      end
      it "page across div2 alpha" do
        x = @start_tei_body_div1 + 
            "<div2 type=\"other\">
              <pb n=\"713\" id=\"#{@druid}_00_0778\"/>
              <p><term>Luynes</term>blah</p>
            </div2>
            <div2 type=\"alpha\">
              <p><term>blah</term>blah</p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                        :pages_ssim => ["#{@druid}_00_0778-|-713"]))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_2",
                        :pages_ssim => ["#{@druid}_00_0778-|-713"]))
        @parser.parse(x)
      end
      it "page across div2 type other with speaker" do
        x = @start_tei_body_div1 + 
             "<pb n=\"8\" id=\"#{@druid}_00_0012\"/>
             <div2 type=\"other\">
               <sp>
                 <speaker>M. de Cazalès.</speaker>
                 <p>Je pense qu'il faut ajourner</p>
                 <pb n=\"9\" id=\"#{@druid}_00_0013\"/>
                 <p>à deux jours toute discussion sur la question qui vous est soumise par</p>
               </sp>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                       :pages_ssim => ["#{@druid}_00_0012-|-8"]))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_2",
                       :pages_ssim => ["#{@druid}_00_0012-|-8",
                                       "#{@druid}_00_0013-|-9"]))
        @parser.parse(x)
      end
    end # pages spanning multiple div2
    
    context "with div3" do
      it "content in last div3 page" do
        x = @start_tei_body_div1 + 
            "<div2 type=\"other\">
              <pb n=\"101\" id=\"#{@druid}_00_0111\"/>
              <p>blah</p>
              <div3 type=\"other\">
                <head>CAHIER</head>
                <pb n=\"102\" id=\"#{@druid}_00_0112\"/>
                <p>content</p>
              </div3>
            </div2>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                        :pages_ssim => ["#{@druid}_00_0111-|-101",
                                        "#{@druid}_00_0112-|-102"]))
        @parser.parse(x)
      end
      it "empty page before div3" do
        x = @start_tei_body_div1 + 
            "<pb n=\"\" id=\"#{@druid}_00_0673\"/>
            <div2 type=\"other\">
              <head>SÉNÉCHAUSSÉE D'AGEN</head>
              <pb n=\"\" id=\"#{@druid}_00_0674\"/>
              <div3 type=\"other\">
                <pb n=\"\" id=\"#{@druid}_00_0675\"/>
                <head>CAHIER</head>
                <p>blah</p>
              </div3"> + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                        :pages_ssim => ["#{@druid}_00_0673-|-",
                                        "#{@druid}_00_0674-|-",
                                        "#{@druid}_00_0675-|-"]))
        @parser.parse(x)
      end
      it "<pb> just before closing </div3></div2>" do
        @x = @start_tei_body_div1 +
              "<pb n=\"101\" id=\"#{@druid}_00_0111\"/>
              <div2 type=\"other\">
                <pb n=\"102\" id=\"#{@druid}_00_0112\"/>
                <p>here</p>
                <div3 type=\"other\">
                  <p>here</p>
                  <p>after</p>
                  <pb n=\"103\" id=\"#{@druid}_00_0113\"/>
                </div3>
              </div2>
              <div2 type=\"other\">
              <p>after2</p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                        :pages_ssim => ["#{@druid}_00_0111-|-101",
                                        "#{@druid}_00_0112-|-102",
                                        "#{@druid}_00_0113-|-103"]))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_2",
                        :pages_ssim => ["#{@druid}_00_0113-|-103"]))
        @parser.parse(x)
      end
      it "<pb> just between closing div3 and div2" do
        x = @start_tei_body_div1 + 
            "<pb n=\"316\" id=\"#{@druid}_00_0320\"/>
            <div2 type=\"other\">
              <div3 type=\"other\">
                <p>stuff</p>
              </div3>
              <pb n=\"317\" id=\"#{@druid}_00_0321\"/>
            </div2>
            <div2 type=\"session\">
              <p><date value=\"2013-01-01\">session title</date></p>
              <p>blah blah ... </p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                       :pages_ssim => ["#{@druid}_00_0320-|-316"]))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_2",
                       :pages_ssim => ["#{@druid}_00_0321-|-317"]))
        @parser.parse(x)
      end
    end
    
    context "empty pages" do
      it "within a div2" do
        x = @start_tei_body_div1 + 
            "<div2 type=\"other\">
              <pb n=\"101\" id=\"#{@druid}_00_0111\"/>
              <pb n=\"102\" id=\"#{@druid}_00_0112\"/>
              <p>content</p>
              <pb n=\"103\" id=\"#{@druid}_00_0113\"/>
            </div2>
            <pb n=\"104\" id=\"#{@druid}_00_0114\"/>
            <div2 type=\"session\">" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                        :pages_ssim => ["#{@druid}_00_0111-|-101",
                                        "#{@druid}_00_0112-|-102",
                                        "#{@druid}_00_0113-|-103"]))
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_2",
                        :pages_ssim => ["#{@druid}_00_0114-|-104"]))
        @parser.parse(x)
      end
      it "at end of div2" do
        x = @start_tei_back_div1 + 
            "<div2 type=\"other\">
               <pb n=\"\" id=\"#{@druid}_00_0813\"/>
               <p>Paris. — Rup. PAUL DUPONT (Thouzellier, Dr), 4, ru© du Bouloi. 3.8.1911. (Cl.) .</p>
               <pb n=\"\" id=\"#{@druid}_00_0814\"/>
               <pb n=\"\" id=\"#{@druid}_00_0815\"/>
               <pb n=\"\" id=\"#{@druid}_00_0816\"/>" + @end_div2_back_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                       :pages_ssim => ["#{@druid}_00_0813-|-",
                                       "#{@druid}_00_0814-|-",
                                       "#{@druid}_00_0815-|-",
                                       "#{@druid}_00_0816-|-"]))
        @parser.parse(x)
      end
      it "after list" do
        x = @start_tei_back_div1 + 
            "<div2 type=\"other\">
            <pb n=\"\" id=\"#{@druid}_00_0736\"/>
              <list>
                <item>M. Gouges-Cartou, mémoire sur les subsistances.....................,................ 651 </item>
                <item>fin de la table chronologique du tome viii. </item>
              </list>
              <pb n=\"\" id=\"#{@druid}_00_0737\"/>
              <pb n=\"\" id=\"#{@druid}_00_0738\"/>" + @end_div2_back_tei
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
                       :pages_ssim => ["#{@druid}_00_0736-|-",
                                       "#{@druid}_00_0737-|-",
                                       "#{@druid}_00_0738-|-"]))
        @parser.parse(x)
      end
    end # empty pages
  end # div2 knows its pages

  it "should know first text snippet" do
    # grab first x chars of text_tiv?
    pending "to be implemented"
  end
  it "should know last text snippet" do
    # grab last x chars of text_tiv?
    pending "to be implemented"
  end
  
  context "add_div2_doc_to_solr" do
    before(:all) do
      @x = @start_tei_body_div2_session +
          "<pb n=\"5\" id=\"#{@druid}_00_0001\"/>
          <p>actual content</p>
          <pb n=\"6\" id=\"#{@druid}_00_0002\"/>" + @end_div2_body_tei
    end
    it "div2 solr doc should have an id" do
      @rsolr_client.should_receive(:add).at_least(1).times
      @parser.parse(@x)
      @atd.div2_doc_hash[:id].should == "#{@druid}_div2_1"
    end
    it "div2 solr doc should have volume fields" do
      @rsolr_client.should_receive(:add).at_least(1).times
      @parser.parse(@x)
      @atd.div2_doc_hash[:druid_ssi].should == @druid
      @atd.div2_doc_hash[:collection_ssi].should == ApTeiDocument::COLL_VAL
      @atd.div2_doc_hash[:vol_num_ssi].should == @volume.sub(/^Volume /i, '')
      @atd.div2_doc_hash[:vol_num_ssi].should == '36'
      @atd.div2_doc_hash[:vol_title_ssi].should == VOL_TITLES[@volume.sub(/^Volume /i, '')]
      @atd.div2_doc_hash[:vol_date_start_dti].should end_with 'Z'
      @atd.div2_doc_hash[:vol_date_end_dti].should end_with 'Z'
      @atd.div2_doc_hash[:vol_pdf_name_ss].should == 'aa222bb4444.pdf'
      @atd.div2_doc_hash[:vol_pdf_size_ls].should == 2218576614
      @atd.div2_doc_hash[:vol_tei_name_ss].should == 'aa222bb4444.xml'
      @atd.div2_doc_hash[:vol_tei_size_is].should == 6885841
      @atd.div2_doc_hash[:vol_total_pages_is].should == 806
    end
    it "div2 solr doc should have div2 fields" do
      @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => [@session_type], :type_ssi => @page_type))
      @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssi => @session_type, :type_ssi =>  @session_type))
      @parser.parse(@x)
    end
    it "div2 solr doc should have catch all text fields" do
      @rsolr_client.should_receive(:add).with(hash_including(:type_ssi => @page_type))
      @rsolr_client.should_receive(:add).with(hash_including(:type_ssi => @session_type, :text_tiv => 'actual content'))
      @parser.parse(@x)
    end    
  end # add_div2_doc_to_solr
  
  it "unspoken_text field" do
    # see ap_tei_unspoken_text_spec
  end
  
  context "text_tiv (catchall field)" do
    it "should not include the contents of any attributes" do
      x = @start_tei_body_div2_session + "<p>Art. 1<hi rend=\"superscript\">er</hi></p>" + @end_div2_body_tei
      @rsolr_client.should_receive(:add).with(hash_including(:type_ssi => @page_type))
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'Art. 1er', :id => "#{@druid}_div2_1"))
      @parser.parse(x)
      x = @start_tei_body_div2_session + "<date value=\"2013-01-01\">pretending to care</date>" + @end_div2_body_tei
      @rsolr_client.should_receive(:add).with(hash_including(:type_ssi => @page_type))
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'pretending to care', :id => "#{@druid}_div2_1"))
      @parser.parse(x)
    end
    it "should include the contents of <p> element" do
      x = @start_tei_body_div2_session + "<p>blather</p>" + @end_div2_body_tei
      @rsolr_client.should_receive(:add).with(hash_including(:type_ssi => @page_type))
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'blather', :id => "#{@druid}_div2_1"))
      @parser.parse(x)
    end
    it "should include the contents of <head> element" do
      x = @start_tei_body_div2_session + "<head>MARDI 15 OCTOBRE 1793.</head>" + @end_div2_body_tei
      @rsolr_client.should_receive(:add).with(hash_including(:type_ssi => @page_type))
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'MARDI 15 OCTOBRE 1793.', :id => "#{@druid}_div2_1"))
      @parser.parse(x)
    end
    it "should include the contents of <speaker> element" do
      x = @start_tei_body_div2_session + "<sp><speaker>M. Bréard.</speaker></sp>" + @end_div2_body_tei
      @rsolr_client.should_receive(:add).with(hash_including(:type_ssi => @page_type))
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'M. Bréard.', :id => "#{@druid}_div2_1"))
      @parser.parse(x)
    end
    it "should include the contents of <date> element" do
      x = @start_tei_body_div2_session + "<date value=\"2013-01-01\">pretending to care</date>" + @end_div2_body_tei
      @rsolr_client.should_receive(:add).with(hash_including(:type_ssi => @page_type))
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'pretending to care', :id => "#{@druid}_div2_1"))
      @parser.parse(x)
    end
    it "should include the contents of <note> element" do
      x = @start_tei_body_div2_session + "<note place=\"foot\">(1) shoes.</note>" + @end_div2_body_tei
      @rsolr_client.should_receive(:add).with(hash_including(:type_ssi => @page_type))
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => '(1) shoes.', :id => "#{@druid}_div2_1"))
      @parser.parse(x)
    end
    it "should include the contents of <hi> element" do
      x = @start_tei_body_div2_session + "<p>Art. 1<hi>er.</hi></p>" + @end_div2_body_tei
      @rsolr_client.should_receive(:add).with(hash_including(:type_ssi => @page_type))
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'Art. 1er.', :id => "#{@druid}_div2_1"))
      @parser.parse(x)
    end
    it "should include the contents of <term> element" do
      x = @start_tei_body_div2_session + "<p><term>Abbaye </term>(Prison de F).</p>" + @end_div2_body_tei
      @rsolr_client.should_receive(:add).with(hash_including(:type_ssi => @page_type))
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'Abbaye (Prison de F).', :id => "#{@druid}_div2_1"))
      @parser.parse(x)
    end
    it "should include the contents of <item> element" do
      x = @start_tei_body_div2_session + "<list><item>item!</item></list>" + @end_div2_body_tei
      @rsolr_client.should_receive(:add).with(hash_including(:type_ssi => @page_type))
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => 'item!', :id => "#{@druid}_div2_1"))
      @parser.parse(x)
    end
    it "should include the contents of <signed> element" do
      x = @start_tei_body_div2_session + "<signed>Signé : Remillat, à l'original. </signed>" + @end_div2_body_tei
      @rsolr_client.should_receive(:add).with(hash_including(:type_ssi => @page_type))
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => "Signé : Remillat, à l'original.", :id => "#{@druid}_div2_1"))
      @parser.parse(x)
    end
    it "should ignore <trailer>" do
      x = @start_tei_body_div2_session + "<trailer>FIN DE L'INTRODUCTION.</trailer><p>blah</p>" + @end_div2_body_tei
      @rsolr_client.should_receive(:add).with(hash_including(:type_ssi => @page_type))
      @rsolr_client.should_receive(:add).with(hash_including(:text_tiv => "blah", :id => "#{@druid}_div2_1"))
      @parser.parse(x)
    end
  end # text_tiv field
  
end 
