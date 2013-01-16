# encoding: UTF-8
require 'spec_helper'

describe ApTeiDocument do
  before(:all) do
    @atd = ApTeiDocument.new
    @parser = Nokogiri::XML::SAX::Parser.new(@atd)
  end
  context "<teiHeader>" do
    before(:all) do
      @druid = "wb029sv4796"
      @volume
      x = "<TEI.2>
       <teiHeader type=\"text\" id=\"#{@druid}\">
        <fileDesc>
         <titleStmt>
          <title type=\"main\">ARCHIVES PARLEMENTAIRES</title>
          <author>M. J. MAVIDAL </author>
          <author> M. E. LAURENT</author>
          <author>MM. E. TONNIER</author>
         </titleStmt>
         <publicationStmt>
          <distributor>
           <address>
            <addrLine>SOCIÉTÉ D'IMPRIMERIE ET LIBRAIRIE ADMINISTRATIVES ET DES CHEMINS DE FER PAUL DUPONT</addrLine>
            <addrLine>4, RUEJEAN -JACQUES-ROUSSEAU , 4</addrLine>
          </address>
          </distributor>
          <date>1891</date>
          <pubPlace>PARIS</pubPlace>
         </publicationStmt>
         <notesStmt>
          <note type=\"markup\">Additional markup added by Digital Divide Data, 20120701</note>
         </notesStmt>
         <sourceDesc>
          <p>Compiled from ARCHIVES PARLEMENTAIRES documents.</p>
         </sourceDesc>
        </fileDesc>
       </teiHeader>
       </TEI.2>"
       @parser.parse(x)
    end
    it "should set collection_si to COLL_VAL constant" do
      @atd.collection_si.should == ApTeiDocument::COLL_VAL
    end
    context "volume value" do
      it "should set volume to TEI.2/body/div1[@type='volume']/@n" do
        pending
        vol = '666'
        x = "<TEI.2><body><div1 type=\"volume\" n=\"#{vol}\"/></body></TEI.2>"
        @parser.parse(x)
        @atd.volume.should == vol
      end
    end
    it "should populate the volume context solr fields" do
      pending
      @atd.druid.should == @druid
      @atd.volume_ssi.should == '36'
      ApTeiDocument::VOL_CONTEXT_FIELDS.each { |fld| @atd.send(fld.to_sym).should_not == nil}
    end
    it "should set druid to TEI.2/teiHeader/@id" do
      @atd.druid.should == @druid
      druid = 'ae123io4567'
      x = "<TEI.2><teiHeader type=\"text\" id=\"#{druid}\"></TEI.2>"
      @parser.parse(x)
      @atd.druid.should == druid
    end
    context "volume solr doc" do
      
      solr_doc = "<doc><!-- volume document -->
          <field name=\"id\">wb029sv4796_volume</field> <!--/TEI.2/body/div1/@type -->
          <field name=\"collection_si\">Archives parlementaires</field>      
          <field name=\"content_type_ssi\">volume</field> <!--/TEI.2/body/div1/@type -->
          <field name=\"type_ssi\">volume</field> <!--/TEI.2/body/div1/@type -->
          <field name=\"volume_ssi\">36</field> <!-- /TEI.2/body/div1[@type=\"volume\"]/@n   or   /@number??  -->
          <!-- /TEI.2/teiHeader -->
          <field name=\"druid\">wb029sv4796</field>  <!-- @id -->
          <!-- /TEI.2/teiHeader/fileDesc/titleStmt -->
          <field name=\"vol_title_main_ftsi\">ARCHIVES PARLEMENTAIRES</field>  <!-- title[@type=main] -->
          <field name=\"vol_author_ssim\">M. J. MAVIDAL </field> <!-- author -->
          <field name=\"vol_author_ssim\"> M E. LAURENT </field>
          <field name=\"vol_author_ssim\">MM. E. TONNIER</field>
          <field name=\"vol_author_ssim\">C. PIONNIER</field>
          <!-- /TEI.2/teiHeader/fileDesc/publicationStmt -->
          <field name=\"distributor_addr_fts\">SOCIÉTÉ D'IMPRIMERIE ET LIBRAIRIE ADMINISTRATIVES ET DES CHEMINS DE FER PAUL DUPONT 4, RUEJEAN -JACQUES-ROUSSEAU , 4</field> <!-- distributor/address/addrLine(s) -->
          <field name=\"vol_date_ssi\">1891</field> <!-- date -->
          <field name=\"pub_place_ssi\">PARIS</field> <!-- pubPlace -->
          <!-- /TEI.2/teiHeader/fileDesc/notesStmt -->
          <field name=\"markup_note_etsim\">Additional markup added by Digital Divide Data, 20120701</field>  <!-- note[@type=markup] -->
          <field name=\"markup_date_ssi\">20120701</field> <!-- parsed from end of markup note -->
          <!-- /TEI.2/teiHeader/fileDesc/sourceDesc -->
          <field name=\"source_desc_tsim\">Compiled from ARCHIVES PARLEMENTAIRES documents.</field>  <!-- sourceDesc/p -->
          <!-- /TEI.1/body/div1[@type=volume] -->
          <field name=\"title_ftsim\">ARCHIVES PARLEMENTAIRES </field>  <!-- /TEI.2/body/div1/head -->
          <field name=\"title_ftsim\">RÈGNE DE LOUIS XVI </field>  
      </doc>"
      it "should have a druid field" do
        pending "to be implemented"
      end
      it "id field should be (druid)_volume" do
        pending "to be implemented"
      end
    end
  end
  it "solr doc should always include volume context fields" do
    pending "to be implemented"
  end
  context "<text>" do
    context "<front>" do

    end
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

    end
    context "<back>" do
      
    end
    
  end
end