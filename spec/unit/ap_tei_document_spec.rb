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
      val = @atd.doc_hash[:vol_date_start_dti]
      val.should end_with 'Z'
      Time.xmlschema(val).xmlschema.should == val # also ensures it doesn't throw parsing error
      val = @atd.doc_hash[:vol_date_end_dti]
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
      it "blank page at beginning of <body> should not go to Solr" do
        x = "<TEI.2><text><body>
               <div1 type=\"volume\" n=\"20\">
                <pb n=\"\" id=\"pz516hw4711_00_0004\"/>
                <head>blah</head>
                <pb n=\"1\" id=\"pz516hw4711_00_0005\"/>
              </div1></body></text></TEI.2>"
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'pz516hw4711_00_0004'))
        @parser.parse(x)
      end
      it "blank pages at end of <body> should not go to Solr" do
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
      it "blank page at beginning of <back> should not go to Solr" do
        x = "<TEI.2><text><back>
               <div1 type=\"volume\" n=\"20\">
                <pb n=\"\" id=\"pz516hw4711_00_0004\"/>
                <head>blah</head>
                <pb n=\"1\" id=\"pz516hw4711_00_0005\"/>
              </div1></back></text></TEI.2>"
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'pz516hw4711_00_0004'))
        @parser.parse(x)
      end
      it "blank pages at end of <back> should not go to Solr" do
        x = "<TEI.2><text><back>
                <pb n=\"810\" id=\"tq360bc6948_00_0813\"/>
                <p>blah blah</p>
                <pb n=\"811\" id=\"tq360bc6948_00_0814\"/>
                <pb n=\"812\" id=\"tq360bc6948_00_0815\"/>
              </div1></back></text></TEI.2>"
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0814'))
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0815'))
        @parser.parse(x)
      end
    end # when no indexed content
    context "when page has indexed content (<p>)" do
      context "in <body>" do
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
          @rsolr_client.should_receive(:add).with(hash_including(:druid, :collection_si, :volume_ssi, :vol_date_start_dti, :vol_date_end_dti, :id => @id))
          @parser.parse(@x)
        end
        it "should call init_doc_hash" do
          @atd.should_receive(:init_doc_hash).twice.and_call_original
          @rsolr_client.should_receive(:add)
          @parser.parse(@x)
        end
      end # in <body>
      context "in <back>" do
        it "pages in <back> section should write the doc to Solr" do
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
          @rsolr_client.should_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0816'))
          @parser.parse(x)
        end
        it "last page in <back> section should write the doc to Solr" do
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
              <div2 type=\"contents\">
                <head>TABLE CHRONOLOGIQUE</head>
                <p>blah blah</p>
              </div2>
            </div1></back></text></TEI.2>"            
            @rsolr_client.should_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0816'))
           @rsolr_client.should_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0817'))
          @parser.parse(x)
        end        
      end # in <back>
      it "should have a vol_page_ss" do
        pending "to be implemented"
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
    context "<back>" do
      before(:all) do
           x = "<TEI.2><text><back>
           <back>
            <div1 type=\"volume\" n=\"36\">
             <pb n=\"\" id=\"wb029sv4796_00_0751\"/>

             <head>ARCHIVES PARLEMENTAIRES </head>
             <head>PREMIÈRE SÉRIE </head>
             <div2 type=\"contents\">
              <head>TABLE CHRONOLOGIQUE DU TOME XXXVI </head>
              <head>TOME TRENTE-SIXIÈME (DU 11 DÉCEMBRE 1191 AU lor JANVIER 1792). </head>
              <p>Pages. </p>
              <list>
               <head>11 DÉCEMBRE 1791. </head>

               <item>Assemblée nationale législative. — Lecture de pé- titions, lettres et adresses
                diverses............ 1</item>
             </list>
             <list>
              <head>13 DÉCEMBRE 1791</head>
              <item>Séance du matin.</item>
              <item>Assemblée nationale législative. — Motions d'or-
               dre................................................... 42 </item>
             </list>
             <list>
              <head>Séance du soir. </head>
              <item>Assemblée nationale législative. — Lecture des lettres, pétitions et adresses
               diverses.......... 75 </item>
             </list>
             </div2>
           </div1>
           <div1 type=\"volume\" n=\"36\">
            <pb n=\"\" id=\"wb029sv4796_00_0760\"/>

            <head>ARCHIVES PARLEMENTAIRES </head>
            <head>PREMIÈRE SÉRIE </head>
            <head>TABLE ALPHABÉTIQUE ET ANALYTIQUE DU TOME TRENTE-SIXIÈME. (DO 11 DÉCEMBRE 1791 AD 1<hi
              rend=\"superscript\">er</hi> JANVIER 1792) </head>
           <div2 type=\"alpha\">
            <head>W </head>
            <p><term>Wimpfen</term> (Général de). — Voir Princes français. </p>
            <p><term>Worms</term> (Ville). Le magistrat annonce à la municipalité de Strasbourg qu'il a
             requis M. de Condé de quitter la ville (30 décembre 1791, t. XXXVI, p. 666). </p>
            <p><term>Wurtemberg</term>. Réponse du duc à la notification de l'acceptation de 1 acte
             constitutionnel par Louis XVI (24 décembre 1791, t. XXXVI, p. 350). </p>
            <pb n=\"793\" id=\"wb029sv4796_00_0797\"/>
           </div2>
               <div2 type=\"alpha\">
                <head>Y </head>
                <p><term>Yonne</term> (Département de 1'). </p>
                <p>Administrateurs. — Demandent à être entendus à la barre (20 décembre 1791, t. XXXVI, p.
                 222).— Sont admis, présentent une adresse de dévouement et une demande de dégrèvement (ibid.
                 p. 278 et suiv.) ; — réponse du Président (ibid. p. 279). </p>
                <p>Volontaires. — Plaintes sur la lenteur de l'équipement (18 décembre 1791, t. XXXVI, p. 231);
                 — renvoi au comité militaire (ibid.). </p>
                <p>fin de la table alphabétique èt analytiquê du tome xxxvi.</p>
               </div2>
              </div1>
             </back>
            </text>
           </TEI.2>"
      end
    end # <back>
  end # <text>
  
  
end