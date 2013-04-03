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
    @start_tei_body_div2_session = "#{@start_tei_body_div1}<div2 type=\"session\">"
    @end_div1_body_tei = "</div1></body></text></TEI.2>"
    @end_div2_body_tei = "</div2>#{@end_div1_body_tei}"
    @start_tei_back_div1 = "<TEI.2><text><back><div1 type=\"volume\" n=\"44\">"
    @end_div1_back_tei = "</div1></back></text></TEI.2>"
    @end_div2_back_tei = "</div2>#{@end_div1_back_tei}"
  end
  
  context "<div2> element" do
    context 'type="alpha"' do
      before(:all) do
        @start_tei_back_div2_alpha = "#{@start_tei_back_div1}<div2 type=\"alpha\">"
        @x = @start_tei_back_div2_alpha +
                "<pb n=\"5\" id=\"ns351vc7243_00_0001\"/>
                <p>blah blah</p>" + @end_div2_back_tei
      end
      it "should have a doc_type_ssim of 'liste'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ['liste']))
        @parser.parse(@x)
      end
    end
    context 'type="contents"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"contents\">
                <pb n=\"5\" id=\"ns351vc7243_00_0008\"/>
                <p>blah blah</p>
                <pb n=\"6\" id=\"ns351vc7243_00_0009\"/>" + @end_div2_body_tei
      end
      it "should have a doc_type_ssim of 'table des matières'" do
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
      it "should have a doc_type_ssim of 'errata, rapport, cahier, etc.'" do
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
      it "should have a doc_type_ssim of 'liste'" do
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
      it "should have a doc_type_ssim of 'introduction'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ['introduction']))
        @parser.parse(@x)
      end
    end
  end # <div2> element

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