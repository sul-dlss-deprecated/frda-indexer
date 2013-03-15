# encoding: UTF-8
require 'spec_helper'

describe NormalizationHelper do
  
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
           <p>hoo hah</p>
           <sp>
             <speaker>m. guadet</speaker>
             <p>blah blah</p>
           </sp>" + @end_div2_body_tei
       @rsolr_client.should_receive(:add).with(hash_including(:speaker_ssim => 
            ['McRae', 'Guadet', 'Nametobeuppercased','NoSpace','GuM.NamewithPeriodAtEndandm.InMiddleadet']))
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
       @rsolr_client.should_receive(:add).with(hash_including(:speaker_ssim => ["McRae-d'lac"]))
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
             <speaker>M. le Pr ésident</speaker>
             <p>bleah bleah</p>
           </sp>" + @end_div2_body_tei
       @rsolr_client.should_receive(:add).with(hash_including(:speaker_ssim => ['Le Président']))
       @parser.parse(x)
     end
  end

end