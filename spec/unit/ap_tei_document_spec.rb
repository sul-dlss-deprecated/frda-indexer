# encoding: UTF-8
require 'spec_helper'

require 'time'

describe ApTeiDocument do
  before(:all) do
    @volume = 'Volume 36'
    @druid = 'aa222bb4444'
    vol_constants_hash = { :vol_pdf_name_ss => 'aa222bb4444.pdf',
                            :vol_pdf_size_ls => 2218576614,
                            :vol_tei_name_ss => 'aa222bb4444.xml',
                            :vol_tei_size_is => 6885841,
                            :vol_total_pages_is => 806  }
    page_id_hash = { 'aa222bb4444_00_0001' => 1, 
                      'aa222bb4444_00_0002' => 2, 
                      'aa222bb4444_00_0805' => 805, 
                      'aa222bb4444_00_0806' => 806}
    @rsolr_client = RSolr::Client.new('http://somewhere.org')
    @logger = Logger.new(STDOUT)
    @atd = ApTeiDocument.new(@rsolr_client, @druid, @volume, vol_constants_hash, page_id_hash, @logger)
    @parser = Nokogiri::XML::SAX::Parser.new(@atd)
    @start_tei_body_div1 = "<TEI.2><text><body><div1 type=\"volume\" n=\"36\">"
    @start_tei_body_div2_session = "#{@start_tei_body_div1}<div2 type=\"session\">"
    @end_div1_body_tei = "</div1></body></text></TEI.2>"
    @end_div2_body_tei = "</div2>#{@end_div1_body_tei}"
  end
  
  context "add_vol_fields_to_hash" do
    before(:all) do
      x = "<TEI.2><teiHeader id='666'></teiHeader></TEI.2>"
      @parser.parse(x)
      @hash = {}
      @atd.add_vol_fields_to_hash(@hash)
      @vol_num = @volume.sub(/^Volume /i, '')
    end
    it "should populate druid_ssi field" do
      @hash[:druid_ssi].should == @druid
    end
    it "should populate collection_ssi field" do
      @hash[:collection_ssi].should == ApTeiDocument::COLL_VAL
    end
    it "should populate vol_ssort" do
      @hash[:vol_ssort].should == VOL_SORT[@vol_num]
      @hash[:vol_ssort].should == '0360'
    end
    it "should populate result_group_ssort" do
      @hash[:result_group_ssort].should == VOL_SORT[@vol_num] + '-|-' + VOL_TITLES[@vol_num]
      @hash[:result_group_ssort].should == "0360-|-#{VOL_TITLES[@vol_num]}"
    end
    it "should populate vol_num_ssi field" do
      @hash[:vol_num_ssi].should == @vol_num
      @hash[:vol_num_ssi].should == '36'
    end
    it "should populate vol_title_ssi" do
      @hash[:vol_title_ssi].should == VOL_TITLES[@vol_num]
    end
    it "should get volume date fields in UTC form (1995-12-31T23:59:59Z)" do
      val = @hash[:vol_date_start_dti]
      val.should end_with 'Z'
      Time.xmlschema(val).xmlschema.should == val # also ensures it doesn't throw parsing error
      val = @hash[:vol_date_end_dti]
      val.should end_with 'Z'
      Time.xmlschema(val).xmlschema.should == val
    end
    it "should populate vol_pdf fields" do
      @hash[:vol_pdf_name_ss].should == 'aa222bb4444.pdf'
      @hash[:vol_pdf_size_ls].should == 2218576614
    end
    it "should populate vol_tei fields" do
      @hash[:vol_tei_name_ss].should == 'aa222bb4444.xml'
      @hash[:vol_tei_size_is].should == 6885841
    end
    it "should populate vol_total_pages_is field" do
      @hash[:vol_total_pages_is].should == 806
    end
  end # add_vol_fields_to_hash
  
  context "add_field_value_to_hash" do
    before(:each) do
      @hash = {}
    end
    context "field doesn't exist in hash" do
      it "should create field with String value for a single valued field" do
        @atd.add_field_value_to_hash(:foo_ssi, 'val', @hash)
        @hash[:foo_ssi].should == 'val'
      end
      it "should create field with Array [value] for a field ending in m (multivalued)" do
        @atd.add_field_value_to_hash(:foo_ssim, 'val', @hash)
        @hash[:foo_ssim].should == ['val']
      end
      it "should create field with Array [value] for a field ending in mv (multivalued with term vector)" do
        @atd.add_field_value_to_hash(:foo_timv, 'val', @hash)
        @hash[:foo_timv].should == ['val']
      end
    end 
    context "field already exists in hash" do
      it "should add the value to the Array of values for a field ending in m" do
        @hash[:foo_tim] = ['val']
        @atd.add_field_value_to_hash(:foo_tim, 'val2', @hash)
        @hash[:foo_tim].should == ['val', 'val2']
      end
      it "should add the value to the Array of values for a field ending in mv" do
        @hash[:foo_timv] = ['val']
        @atd.add_field_value_to_hash(:foo_timv, 'val2', @hash)
        @hash[:foo_timv].should == ['val', 'val2']
      end
      it "should log a warning when a single valued field gets another value" do
        @hash[:foo_ti] = 'val'
        @logger.should_receive(:warn).with("Solr field foo_ti is single-valued (first value: val), but got an IGNORED additional value: val2")
        @atd.add_field_value_to_hash(:foo_ti, 'val2', @hash)
      end
    end 
  end # add_field_value_to_hash
  
  context "parsing warnings" do
    it "should log a warning when it finds direct non-whitespace text content in a wrapper element" do
      x = @start_tei_body_div2_session +
          "<pb n=\"2\" id=\"#{@druid}_00_0001\"/>
          <p><date value=\"2013-01-01\">pretending to care</date></p>
          <sp>
             <speaker>M. Guadet.</speaker>
             <p>blah blah ... </p>
             mistake
          </sp>" + @end_div2_body_tei
      @logger.should_receive(:warn).with("Found <sp> tag with direct text content: 'mistake' in page #{@druid}_00_0001")
      @rsolr_client.should_receive(:add).at_least(1).times
      @parser.parse(x)
    end
    it "should log a warning for direct non-whitespace text children of <pb>" do
      x = @start_tei_body_div2_session + 
          "<pb n=\"812\" id=\"#{@druid}_00_0816\">
          <p>foo</p>
          mistake
          </pb>
          <pb n=\"813\" id=\"#{@druid}_00_0817\"/>" + @end_div2_body_tei
      @logger.should_receive(:warn).with("Found <pb> tag with direct text content: 'mistake' in page #{@druid}_00_0816")
      @rsolr_client.should_receive(:add).at_least(1).times
      @parser.parse(x)
    end
    it "should log a warning for direct non-whitespace text children when not last" do
      x = @start_tei_body_div2_session + 
          "<pb n=\"812\" id=\"#{@druid}_00_0816\"/>
          <list>
          <head>bar</head>
          <item>1</item>
          mistake
          <item>2</item>
          </list>
          <pb n=\"813\" id=\"#{@druid}_00_0817\"/>" + @end_div2_body_tei
      @logger.should_receive(:warn).with("Found <list> tag with direct text content: 'mistake' in page #{@druid}_00_0816")
      @rsolr_client.should_receive(:add).at_least(1).times
      @parser.parse(x)
    end
  end
  
end