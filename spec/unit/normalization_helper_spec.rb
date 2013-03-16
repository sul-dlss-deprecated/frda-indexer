# encoding: UTF-8
require 'spec_helper'

describe NormalizationHelper do
  
  include NormalizationHelper

  context "session title (date text) normalization" do
    it "should strip outer whitespace" do
      normalize_session_title(' Séance du mardi 29 décembre 1789  ').should == "Séance du mardi 29 décembre 1789"
    end    
    it "should correct Seance to Séance" do
      normalize_session_title('Seance du samedi 23 avril 1791').should == "Séance du samedi 23 avril 1791"
    end
    it "should correct Stance to Séance" do
      normalize_session_title('Stance du samedi 23 avril 1791').should == "Séance du samedi 23 avril 1791"
    end
    it "should deal well with preceding commas" do
      normalize_session_title('Séance du vendredi, 4 octobre 1793,').should == "Séance du vendredi, 4 octobre 1793"
    end
    it "should change any ' , ' to ', ' " do
      normalize_session_title('Séance du mardi 29 décembre 1789 , au matin').should == "Séance du mardi 29 décembre 1789, au matin"
    end
    it "should normalize internal whitespace" do
      normalize_session_title('Séance du   mardi 29 décembre 1789, au matin (1) ').should == "Séance du mardi 29 décembre 1789, au matin (1)"
    end    
    it "should remove outer parens and spaces" do
      normalize_session_title('( Dimanche 17 novembre 1793 )').should == "Dimanche 17 novembre 1793"
      normalize_session_title(' ( Dimanche, 29 décembre 1793 .)').should == "Dimanche, 29 décembre 1793"
      normalize_session_title('(Samedi 26 octobre 1793.)').should == "Samedi 26 octobre 1793"
      normalize_session_title('( Samedi 23 novembre 1793 ,)').should == "Samedi 23 novembre 1793"
      normalize_session_title("Jeudi, 19 décembre 1793 )").should == "Jeudi, 19 décembre 1793"
    end
    it "should remove preceding single quotes" do
      normalize_session_title("' Séance du dimanche 20 mai 1792").should == "Séance du dimanche 20 mai 1792"
      normalize_session_title("'Séance du jeudi 17 mai 1792 ").should == "Séance du jeudi 17 mai 1792"
    end
    it "should remove preceding hyphens" do
      normalize_session_title('- Séance du jeudi 10 mars 1791').should == "Séance du jeudi 10 mars 1791"
      normalize_session_title('-Séance du jeudi 9 août 1792, au matin').should == "Séance du jeudi 9 août 1792, au matin"
    end
    it "should deal with annoying reality" do
      normalize_session_title('Séance,  du jeudi 17 septembre 1789,. au matin.').should == "Séance, du jeudi 17 septembre 1789,. au matin"
      normalize_session_title('Mardi 11 septembre 1792, au soir. *').should == "Mardi 11 septembre 1792, au soir"
      normalize_session_title('Samedi 18 août 1792, au matin.').should == 'Samedi 18 août 1792, au matin'
      normalize_session_title('(, Samedi 7 décembre 1793 .")').should == "Samedi 7 décembre 1793"
    end
  end # session title 
  
  context "#remove_trailing_and_leading_characters" do
    it "should strip outer whitespace" do
      remove_trailing_and_leading_characters(' Séance du mardi 29 décembre 1789  ').should == "Séance du mardi 29 décembre 1789"
    end
    it "should remove beginning periods, colons, commas and other special characters" do
      remove_trailing_and_leading_characters('.foo').should == "foo"
      remove_trailing_and_leading_characters(',foo').should == "foo"
      remove_trailing_and_leading_characters(':foo').should == "foo"
      remove_trailing_and_leading_characters('«foo').should == "foo"
      remove_trailing_and_leading_characters('«.,:foo').should == "foo"
      remove_trailing_and_leading_characters(' . foo').should == "foo"
    end
    it "should remove any ending periods, colons or commas" do
      remove_trailing_and_leading_characters('foo.').should == "foo"
      remove_trailing_and_leading_characters('foo,').should == "foo"
      remove_trailing_and_leading_characters('foo:').should == "foo"
      remove_trailing_and_leading_characters('foo:,.').should == "foo"
      remove_trailing_and_leading_characters('foo . ').should == "foo"
    end
  end
  
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
  
  context "normalize_date" do
    before(:all) do
    end
    it "should log a warning for unparseable dates" do
      x = @start_tei_body_div2_session + 
          "<pb n=\"812\" id=\"tq360bc6948_00_0816\"/>
          <p>boo <date value=\"1792-999-02\">5 octobre 1793</date> ya</p>
          <pb n=\"813\" id=\"tq360bc6948_00_0817\"/>" + @end_div2_body_tei
      @logger.should_receive(:warn).with("Found <date> tag with unparseable date value: '1792-999-02' in page tq360bc6948_00_0816")
      @rsolr_client.should_receive(:add)
      @parser.parse(x)
    end
    it "should cope with day of 00" do
      @atd.normalize_date("1792-08-00").should == Date.parse('1792-08-01')
    end
    it "should cope with single digit days and months (no leading zero)" do
      @atd.normalize_date("1792-8-1").should == Date.parse('1792-08-01')
    end
    it "should cope with year only" do
      @atd.normalize_date("1792").should == Date.parse('1792-01-01')
    end
    it "should cope with year and month only" do
      @atd.normalize_date("1792-08").should == Date.parse('1792-08-01')
    end
    it "should cope with slashes in days area (trying to representing a range)" do
      @atd.normalize_date("1792-08-01/15/17").should == Date.parse('1792-08-01')
    end
    it "should cope with au in date" do
      @atd.normalize_date("1793-05-17 au 1793-06-02").should == Date.parse('1793-05-17')
    end
    it "should cope with spaces preceding or following hyphens" do
      @atd.normalize_date("1792 - 8 - 01").should == Date.parse('1792-08-01')
    end
  end # normalize_date

  context "speaker_normalization" do
     it "should correctly normalize speaker names with M, MM, initial capitilization and ending periods" do
       x = @start_tei_body_div2_session + 
           "<p><date value=\"2013-01-01\">pretending to care</date></p>
           <sp>
             <speaker>M- McRae:: </speaker>
             <p>bleah bleah</p>
           </sp> 
           <sp>
             <speaker>Mm. McRae, </speaker>
             <p>bleah bleah</p>
           </sp>            
           <sp>
             <speaker>M .McRae. </speaker>
             <p>bleah bleah</p>
           </sp> 
           <sp>
             <speaker>M . McRae. </speaker>
             <p>bleah bleah</p>
           </sp>                       
           <sp>
             <speaker>M McRae. </speaker>
             <p>bleah bleah</p>
           </sp>             
           <sp>
             <speaker>M'. McRae. </speaker>
             <p>bleah bleah</p>
           </sp>             
           <sp>
             <speaker>'M' McRae. </speaker>
             <p>bleah bleah</p>
           </sp>
           <sp>
             <speaker>m. Guadet</speaker>
             <p>blah blah</p>
           </sp>
           <sp>
             <speaker>M. nametobeuppercased</speaker>
             <p>blah blah</p>
           </sp>
           <sp>
             <speaker>m.NoSpace</speaker>
             <p>blah blah</p>
           </sp>
           <sp>
             <speaker>m.GuM.NamewithPeriodAtEndandm.InMiddleadet.</speaker>
             <p>blah blah</p>
           </sp>
           <sp>
              <speaker>' MM. ganltier-bianzat et de Choisenl-Praslin.</speaker>
           <p>hoo hah</p>
           </sp>
           <sp>
              <speaker>(Jacob Dupont</speaker>
           <p>hoo hah</p>
           </sp>                          
           <sp>
             <speaker>m. guadet</speaker>
             <p>blah blah</p>
           </sp>" + @end_div2_body_tei
       @rsolr_client.should_receive(:add).with(hash_including(:speaker_ssim => 
            ['McRae', 'Guadet', 'Nametobeuppercased','NoSpace','GuM.NamewithPeriodAtEndandm.InMiddleadet','Ganltier-bianzat et de Choisenl-Praslin','Jacob Dupont']))
       @parser.parse(x)
     end   
     it "should correctly normalize speaker names by removing trailing and leading periods and other indicated characters" do
       x = @start_tei_body_div2_session + 
           "<p><date value=\"2013-01-01\">pretending to care</date></p>
           <sp>
             <speaker>«M- «.McRae. </speaker>
             <p>bleah bleah</p>
           </sp> 
           <sp>
             <speaker>«««M- ...McRae. </speaker>
             <p>bleah bleah</p>
           </sp>            
           <sp>
             <speaker>Mm. .McRae........ </speaker>
             <p>bleah bleah</p>
           </sp>" + @end_div2_body_tei
       @rsolr_client.should_receive(:add).with(hash_including(:speaker_ssim => ['McRae']))
       @parser.parse(x)
     end      
     it "should correctly normalize speaker names by removing spaces around hypens and spaces after d'" do
       x = @start_tei_body_div2_session + 
           "<p><date value=\"2013-01-01\">pretending to care</date></p>
           <sp>
             <speaker>1e comte Midrabeau</speaker>
             <p>bleah bleah</p>
           </sp> 
           <sp>
             <speaker>McRae - d' lac</speaker>
             <p>bleah bleah</p>
           </sp> 
           <sp>
             <speaker>M. McRae- d'   lac</speaker>
             <p>bleah bleah</p>
           </sp>            
           <sp>
             <speaker>McRae -d'lac...</speaker>
             <p>bleah bleah</p>
           </sp>" + @end_div2_body_tei
       @rsolr_client.should_receive(:add).with(hash_including(:speaker_ssim => ["Le comte Midrabeau","McRae-d'lac"]))
       @parser.parse(x)
     end       
     it "should correctly normalize president speaker names alternates" do
       x = @start_tei_body_div2_session + 
           "<p><date value=\"2013-01-01\">pretending to care</date></p>
         <sp>
            <speaker>M. le Pr ésident .</speaker>
            <p>bleah bleah</p>
          </sp>
        <sp>
           <speaker>M. le Pr ésident :</speaker>
           <p>bleah bleah</p>
         </sp>
         <sp>
            <speaker>M. le Pr ésident Sieyès</speaker>
            <p>bleah bleah</p>
          </sp>
          <sp>
             <speaker>M. le Pr ésident de La Houssaye</speaker>
             <p>bleah bleah</p>
           </sp>
           <sp>
              <speaker>M. le Pr ésident répond</speaker>
              <p>bleah bleah</p>
            </sp>
            <sp>
               <speaker>M. le Pr ésident,</speaker>
               <p>bleah bleah</p>
             </sp>
     <sp>
        <speaker>M. le Pr ésident.</speaker>
        <p>bleah bleah</p>
      </sp>
      <sp>
         <speaker> M. le Pr ésident..</speaker>
         <p>bleah bleah</p>
       </sp>
       <sp>
          <speaker>M. le Pr ésident...</speaker>
          <p>bleah bleah</p>
        </sp>
        <sp>
           <speaker>M. le Pr ésident....</speaker>
           <p>bleah bleah</p>
         </sp>
         <sp>
         <speaker>M. le Pr ésldent.</speaker>
          <p>bleah bleah</p>
        </sp>
        <sp>
           <speaker>M. le President.</speaker>
           <p>bleah bleah</p>
         </sp>
         <sp>
            <speaker>le Pr ésident</speaker>
            <p>bleah bleah</p>
          </sp>
          <sp>
             <speaker>le Pr ésident,</speaker>
             <p>bleah bleah</p>
          </sp>
           <sp>
              <speaker>M. le pr ésident</speaker>
              <p>bleah bleah</p>
            </sp>
         <sp>
             <speaker>le Pr ésident.</speaker>
             <p>bleah bleah</p>
           </sp>                                                                                                                                                                                                                                                                              
          <sp>
             <speaker>le pr ésident</speaker>
             <p>bleah bleah</p>
           </sp> 
           <sp>
             <speaker>Le Preésident.</speaker>
             <p>bleah bleah</p>
           </sp>   
           <sp>
             <speaker>M. le pr ésident.</speaker>
             <p>bleah bleah</p>
           </sp>  
           <sp>
             <speaker>M. le Président</speaker>
             <p>bleah bleah</p>
           </sp>           
           <sp>
             <speaker>&gt;M. le Pr ésident</speaker>
             <p>bleah bleah</p>
           </sp>" + @end_div2_body_tei
       @rsolr_client.should_receive(:add).with(hash_including(:speaker_ssim => ['Le Président']))
       @parser.parse(x)
     end
  end

end