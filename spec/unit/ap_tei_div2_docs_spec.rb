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
    context "div2 solr knows about all its pages" do
      it "image number" do
        pending "to be implemented"
#        :div2_first_page_ssi => '#{@druid}_00_0816',
      end
      it "page number" do
        pending "to be implemented"
      end
    end
    
    context "first page" do
      it "should know image id" do
        pending "to be implemented: session_seq_first_isim"
      end
      it "should know first text snippet" do
        pending "to be implemented"
      end
    end
    context "last page" do
      it "should know image id" do
        pending "to be implemented"
      end
      it "should know last text snippet" do
        pending "to be implemented"
      end
    end
  end 
  
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