# encoding: UTF-8
require 'spec_helper'

require 'time'

describe ApTeiDocument do
  before(:all) do
    @volume = 'Volume 36'
    @druid = 'aa222bb4444'
    @rsolr_client = RSolr::Client.new('http://somewhere.org')
    @logger = Logger.new(STDOUT)
    @atd = ApTeiDocument.new(@rsolr_client, @druid, @volume, @logger)
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
                <head>blah</head>
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
        exp_flds = {:speaker_ssim => ['M. Guadet'], :spoken_text_ftsimv => ['M. Guadet blah blah']}
        @rsolr_client.should_receive(:add).with(hash_including(exp_flds))
        @parser.parse(@x)
      end
      it "should create field with String value for a single valued field" do
        exp_flds = {:doc_type_ssi => 'séance'}
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
        exp_flds = {:speaker_ssim => ['M. Guadet', 'M. McRae'], :spoken_text_ftsimv => ['M. Guadet blah blah', 'M. McRae bleah bleah']}
        @rsolr_client.should_receive(:add).with(hash_including(exp_flds))
        @parser.parse(@x)
      end
      it "should log a warning if the field isn't multivalued" do
        x = @start_tei_body_div2_session + 
            "<pb n=\"813\" id=\"tq360bc6948_00_0816\"/>
            <p>blah blah</p>
          </div2>
          <div2 type=\"table_alpha\">
            <p>blah blah</p>
          </div2>" + @end_div2_body_tei
        @logger.should_receive(:warn).with("Solr field doc_type_ssi is single-valued (first value: séance), but got an IGNORED additional value: liste")
        @parser.parse(x)
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
    context "page_num_ss" do
      it "should be present when <pb> has non-empty n attribute" do
        x = @start_tei_body_div2_session + 
              "<pb n=\"1\" id=\"something\"/>
               <p>La séance est ouverte à neuf heures du matin. </p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:page_num_ss => '1'))
        @parser.parse(x)
      end
      it "should not be present when <pb> has empty n attribute" do
        x = @start_tei_body_div1 +
              "<div2 type=\"session\">
                  <pb n=\"\" id=\"ns351vc7243_00_0001\"/>
                  <p>blah blah</p>" + @end_div2_body_tei 
        @rsolr_client.should_receive(:add).with(hash_not_including(:page_num_ss))
        @parser.parse(x)
      end
      it "should not be present when <pb> has no n attribute" do
        x = @start_tei_body_div1 +
              "<div2 type=\"session\">
                  <pb id=\"ns351vc7243_00_0001\"/>
                  <p>blah blah</p>" + @end_div2_body_tei 
        @rsolr_client.should_receive(:add).with(hash_not_including(:page_num_ss))
        @parser.parse(x)
      end
    end # page_num_ss
    it "image_id_ss should be same as <pb> id attrib with .jp2 extension" do
      @rsolr_client.should_receive(:add).with(hash_including(:image_id_ss => "#{@page_id}.jp2"))
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
      it "should have a page_doc_type of 'séance'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssi => "séance"))
        @parser.parse(@x)
      end
      context "session_govt_ssi" do
        it "should take the value of the first <head> element after <div2>" do
          pending "to be implemented"
          x = @start_tei_body_div2_session + "<head>CONVENTION NATIONALE</head>" + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_including(:session_govt_ssi => "CONVENTION NATIONALE"))
          @parser.parse(x)
        end
        it "should ignore subsequent <head> elements, even if allcaps" do
          pending "to be implemented"
          x = @start_tei_body_div2_session + 
                "<head>CONVENTION NATIONALE</head>
                <head>PRÉSIDENCE DE M. MERLIN</head>" + @end_div2_body_tei
          @rsolr_client.should_receive(:add).with(hash_not_including(:session_govt_ssi => "PRÉSIDENCE DE M. MERLIN"))
          @parser.parse(x)
        end
        it "should strip whitespace" do
          x = "<head>ASSEMBLÉE NATIONALE LÉGISLATIVE. </head>"
          pending "to be implemented"
        end
        it "should ignore whitespace before first <head> or <p>" do
          pending "to be implemented"
        end
        it "should put the value into French titlecase (from allcaps)" do
          pending "to be implemented"
        end
        it "should find the value if it is in <p> instead of <head>" do
          x = @start_tei_body_div2_session +
          "<p>ASSEMBLÉE NATIONALE LÉGISLATIVE. </p>" + @end_div2_body_tei
          
          pending "to be implemented"
        end
      end
    end
    context 'type="contents"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"contents\">
                <pb n=\"5\" id=\"ns351vc7243_00_0008\"/>
                <p>blah blah</p>
                <pb n=\"6\" id=\"ns351vc7243_00_0009\"/>" + @end_div2_body_tei
      end
      it "should have a doc_type_si of 'table des matières'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssi => 'table des matières'))
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
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssi => 'errata, rapport, cahier, etc.'))
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
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssi => 'liste'))
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
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssi => 'liste'))
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
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssi => 'introduction'))
        @parser.parse(@x)
      end
    end
  end # <div2> element

  context "<sp> element" do
    context "speaker_ssim" do
      it "should be present if there is a non-empty <speaker> element" do
        x = @start_tei_body_div2_session +
            "<sp>
               <speaker>M. Guadet</speaker>
               <p>,secrétaire, donne lecture du procès-verbal de la séance ... </p>
            </sp>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:speaker_ssim => ['M. Guadet']))
        @parser.parse(x)
      end
      it "should have multiple values for multiple speakers" do
        x = @start_tei_body_div2_session + 
            "<sp>
              <speaker>M. Guadet</speaker>
              <p>blah blah</p>
            </sp>
            <p>hoo hah</p>
            <sp>
              <speaker>M. McRae</speaker>
              <p>bleah bleah</p>
            </sp>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:speaker_ssim => ['M. Guadet', 'M. McRae']))
        @parser.parse(x)
      end
      it "should not be present if there is an empty <speaker> element" do
        x = @start_tei_body_div2_session + 
            "<sp>
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
    end # speaker_ssim

    context "spoken_text_ftsimv" do
      before(:each) do
        @x = @start_tei_body_div2_session +
            "<p>before</p>
            <sp>
               <speaker>M. Guadet</speaker>
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
        @rsolr_client.should_receive(:add).with(hash_including(:spoken_text_ftsimv => ['M. Guadet blah blah ...', 'M. Guadet bleah bleah ...']))
        @parser.parse(@x)
      end
      it "should not include <p> text outside an <sp>" do
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_ftsimv => ['before']))
        @parser.parse(@x)
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_ftsimv => ['middle']))
        @parser.parse(@x)
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_ftsimv => ['after']))
        @parser.parse(@x)
      end
      it "should not include <p> text when there is no speaker " do
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_ftsimv => ['no speaker']))
        @parser.parse(@x)
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_ftsimv => ['also no speaker']))
        @parser.parse(@x)
      end
    end # spoken_text_ftsimv

    it "should log a warning when it finds direct non-whitespace text content in <sp> tag" do
      x = @start_tei_body_div2_session +
          "<pb n=\"2\" id=\"ns351vc7243_00_0001\"/>
          <sp>
             <speaker>M. Guadet</speaker>
             <p>blah blah ... </p>
             mistake
          </sp>" + @end_div2_body_tei
      @logger.should_receive(:warn).with("Found <sp> tag with direct text content: 'mistake' in page ns351vc7243_00_0001")
      @rsolr_client.should_receive(:add)
      @parser.parse(x)
    end
  end # <sp> element
    
end