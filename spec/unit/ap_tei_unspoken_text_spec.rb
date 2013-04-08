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
    @start_tei_body_div1 = "<TEI.2><text><body><div1 type=\"volume\" n=\"36\">"
    @start_tei_body_div2_session = @start_tei_body_div1 + "<div2 type=\"session\">"
    @end_div1_body_tei = "</div1></body></text></TEI.2>"
    @end_div2_body_tei = "</div2>#{@end_div1_body_tei}"
    @start_tei_back_div1 = "<TEI.2><text><back><div1 type=\"volume\" n=\"44\">"
    @end_div1_back_tei = "</div1></back></text></TEI.2>"
    @end_div2_back_tei = "</div2>#{@end_div1_back_tei}"
    @session_type = ApTeiDocument::DIV2_TYPE['session']
    @page_type = ApTeiDocument::PAGE_TYPE
    @page_id = "#{@druid}_00_0002"
    @start_session_doc = @start_tei_body_div2_session + "<pb n=\"5\" id=\"#{@page_id}\"/>"
  end

  context "prefix" do
    before(:all) do
      @start_session_doc =  @start_tei_body_div1 + "<div2 type=\"other\"><pb n=\"5\" id=\"#{@page_id}\"/>"
      @x = @start_session_doc + "<p>blather</p>" + @end_div2_body_tei
    end
    it "should start with page_id for div2 docs" do
      @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["#{@page_id}-|-blather"], :id => "#{@druid}_div2_1"))
      @rsolr_client.should_receive(:add).with(hash_including(:id => @page_id))
      @parser.parse(@x)
    end
    it "should not start with page_id for page docs" do
      @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1"))
      @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["blather"], :id => @page_id))
      @parser.parse(@x)
    end
  end
  
  it "search unspoken text across page breaks (across <p>???)", :integration => true do
    pending "to be implemented as an integration test"
  end
  
  context "unspoken_text field" do
    it "should include <p> session text when there is no speaker" do
      x = @start_tei_body_div1 + "<div2 type=\"other\">
            <pb n=\"812\" id=\"#{@page_id}\"/>
            <p>before</p>
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
      @rsolr_client.should_receive(:add).with(hash_including(:id => @page_id, 
            :unspoken_text_timv => ["before", 
                                    "pretending to care",
                                    "middle", 
                                    "no speaker", 
                                    "also no speaker", 
                                    "after"]))
      @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1", 
            :unspoken_text_timv => ["#{@page_id}-|-before", 
                                    "#{@page_id}-|-pretending to care",
                                    "#{@page_id}-|-middle", 
                                    "#{@page_id}-|-no speaker", 
                                    "#{@page_id}-|-also no speaker", 
                                    "#{@page_id}-|-after"]))
      @parser.parse(x)
    end
    context "div3" do
      before(:all) do
        @page_id = "#{@druid}_00_0001"
        @x = @start_tei_body_div1 + "<div2 type=\"other\">
              <pb n=\"5\" id=\"#{@page_id}\"/>
              <p>actual content</p>
              <div3 type=\"annexe\">
                <head>ANNEXES</head>
                <head>à la séance de VAssemblée nationale du <date value=\"1789-11-12\">12 novembre 1789</date>.</head>
                <p>première annexe. </p>
                <p>Mémoire sur le projet de détruire les corps religieux, par des Dominicains. </p>
                <p>Il n'est pas pos</p></div3>" + @end_div2_body_tei
      end
      it "should have a separate value for each <p> inside a single <div3>" do
        @rsolr_client.should_receive(:add).with(hash_including(:id => "#{@druid}_div2_1",
              :unspoken_text_timv => ["#{@page_id}-|-actual content", 
                                      "#{@page_id}-|-ANNEXES",
                                      "#{@page_id}-|-à la séance de VAssemblée nationale du 12 novembre 1789",
                                      "#{@page_id}-|-première annexe.", 
                                      "#{@page_id}-|-Mémoire sur le projet de détruire les corps religieux, par des Dominicains.", 
                                      "#{@page_id}-|-Il n'est pas pos"]))
        @rsolr_client.should_receive(:add).with(hash_including(:id => @page_id,
              :unspoken_text_timv => ["actual content",
                                      "ANNEXES",
                                      "à la séance de VAssemblée nationale du 12 novembre 1789",
                                      "première annexe.", 
                                      "Mémoire sur le projet de détruire les corps religieux, par des Dominicains.", 
                                      "Il n'est pas pos"]))
        @parser.parse(@x)
      end
    end
    
    context "when shouldn't it include a head element?" do
      it "when it's a session government heading" do
        x = @start_session_doc + "<head>CONVENTION NATIONALE</head><head>yes</head>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["#{@page_id}-|-yes"],
                                                                :session_govt_ssi => 'CONVENTION NATIONALE',
                                                                :id => "#{@druid}_div2_1"))
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["yes"], 
                                                                :session_govt_ssim => ['CONVENTION NATIONALE'],
                                                                :id => @page_id))
        @parser.parse(x)
      end
    end
    context "when shouldn't it include a p element?" do
      it "when it's a session title" do
        x = @start_session_doc + "<p>nope<date value=\"2013-01-01\">nope</date>nope</p><p>yes</p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["#{@page_id}-|-yes"],
                                                                :session_title_ftsi => 'nope nope nope',
                                                                :id => "#{@druid}_div2_1"))
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["yes"], 
                                                                :session_title_ftsim => ['nope nope nope'],
                                                                :id => @page_id))
        @parser.parse(x)
      end
    end
    context "when shouldn't it include a date element?" do
      it "when it's part of a session title" do
        x = @start_session_doc + "<p>foo<date value=\"2013-01-01\">nope</date></p><p>yes</p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["#{@page_id}-|-yes"], 
                                                                :session_title_ftsi => 'foo nope',
                                                                :id => "#{@druid}_div2_1"))
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["yes"], 
                                                                :session_title_ftsim => ['foo nope'],
                                                                :id => @page_id))
        @parser.parse(x)
      end
    end
    
    context "what is included" do
      before(:all) do
        @start_doc =  @start_tei_body_div1 + "<div2 type=\"other\"><pb n=\"5\" id=\"#{@page_id}\"/>"
      end
      it "should include the contents of <p> element" do
        x = @start_doc + "<p>blather</p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["#{@page_id}-|-blather"], :id => "#{@druid}_div2_1"))
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["blather"], :id => @page_id))
        @parser.parse(x)
      end
      it "should include the contents of <head> element" do
        x = @start_doc + "<head>MARDI 15 OCTOBRE 1793.</head>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["#{@page_id}-|-MARDI 15 OCTOBRE 1793."], :id => "#{@druid}_div2_1"))
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["MARDI 15 OCTOBRE 1793."], :id => @page_id))
        @parser.parse(x)
      end
      it "should include the contents of <date> element" do
        x = @start_doc + "<p>blah</p><date value=\"2013-01-01\">pretending to care</date>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["#{@page_id}-|-blah","#{@page_id}-|-pretending to care"], :id => "#{@druid}_div2_1"))
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["blah", "pretending to care"], :id => @page_id))
        @parser.parse(x)
      end
      it "should include the contents of <note> element" do
        x = @start_doc + "<note place=\"foot\">(1) shoes.</note>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["#{@page_id}-|-(1) shoes."], :id => "#{@druid}_div2_1"))
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["(1) shoes."], :id => @page_id))
        @parser.parse(x)
      end
      it "should include the contents of <hi> element" do
        x = @start_doc + "<p>Art. 1<hi>er.</hi></p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["#{@page_id}-|-Art. 1er."], :id => "#{@druid}_div2_1"))
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["Art. 1er."], :id => @page_id))
        @parser.parse(x)
      end
      it "should include the contents of <item> element" do
        x = @start_doc + "<list><item>item!</item></list>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["#{@page_id}-|-item!"], :id => "#{@druid}_div2_1"))
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["item!"], :id => @page_id))
        @parser.parse(x)
      end
      it "should include the contents of <signed> element" do
        x = @start_doc + "<signed>Signé : Remillat, à l'original. </signed>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["#{@page_id}-|-Signé : Remillat, à l'original."], :id => "#{@druid}_div2_1"))
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["Signé : Remillat, à l'original."], :id => @page_id))
        @parser.parse(x)
      end
      
      it "should not include the contents of any attributes" do
        x = @start_doc + "<p>Art. 1<hi rend=\"superscript\">er</hi></p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["#{@page_id}-|-Art. 1er"], :id => "#{@druid}_div2_1"))
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["Art. 1er"], :id => @page_id))
        @parser.parse(x)
        x = @start_doc + "<date value=\"2013-01-01\">pretending to care</date>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["#{@page_id}-|-pretending to care"], :id => "#{@druid}_div2_1"))
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["pretending to care"], :id => @page_id))
        @parser.parse(x)
      end
      it "should NOT include the contents of <speaker> element" do
        x = @start_doc + "<sp><speaker>M. Bréard.</speaker></sp>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_not_including(:unspoken_text_timv => ["#{@page_id}-|-M. Bréard."], :id => "#{@druid}_div2_1"))
        @rsolr_client.should_receive(:add).with(hash_not_including(:unspoken_text_timv => ["M. Bréard."], :id => @page_id))
        @parser.parse(x)
      end
      it "should NOT include the contents of <term> element" do
        x = @start_doc + "<p><term>Abbaye </term>(Prison de F).</p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_not_including(:unspoken_text_timv => ["#{@page_id}-|-Abbaye (Prison de F)."], :id => "#{@druid}_div2_1"))
        @rsolr_client.should_receive(:add).with(hash_not_including(:unspoken_text_timv => ["Abbaye (Prison de F)."], :id => @page_id))
        @parser.parse(x)
      end
      it "should ignore <trailer>" do
        x = @start_doc + "<trailer>FIN DE L'INTRODUCTION.</trailer><p>blah</p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["#{@page_id}-|-blah"], :id => "#{@druid}_div2_1"))
        @rsolr_client.should_receive(:add).with(hash_including(:unspoken_text_timv => ["blah"], :id => @page_id))
        @parser.parse(x)
      end
    end # what is included
  end # unspoken text field

end