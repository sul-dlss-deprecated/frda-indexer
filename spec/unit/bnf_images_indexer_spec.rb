# encoding: utf-8
require 'spec_helper'

describe BnfImagesIndexer do
  
  before(:all) do
    @config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "bnf_oai_test.yml")
    @indexer = BnfImagesIndexer.new(@config_yml_path)
    @hdor_client = @indexer.send(:harvestdor_client)
    @solr_client = @indexer.solr_client
    @fake_druid = 'oo000oo0000'
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
    @mods_xml = "<mods #{@ns_decl}><note>hi</note></mods>"
    @ng_mods_xml = Nokogiri::XML(@mods_xml)
    @content_md_start = "<contentMetadata objectId='#{@fake_druid}'>"
    @content_md_end = "</contentMetadata>"
  end
  
  context "index method" do
    before(:each) do
      @hdor_client.should_receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      @hdor_client.should_receive(:content_metadata).and_return(nil)
    end

    it "the druid should be the value of the :id and :druid_ssi fields" do
      @solr_client.should_receive(:add).with(hash_including(:id => @fake_druid, :druid_ssi => @fake_druid))
      @indexer.index(@fake_druid)
    end

    context "fields that are constants" do
      it ":collection_ssi should be 'Images de la Révolution française'" do
        @solr_client.should_receive(:add).with(hash_including(:collection_ssi => 'Images de la Révolution française'))
        @indexer.index(@fake_druid)
      end
      it ":type_ssi should be 'image'" do
        @solr_client.should_receive(:add).with(hash_including(:type_ssi => 'image'))
        @indexer.index(@fake_druid)
      end
      it ":result_group_ssi should be 'Images de la Révolution française'" do
        @solr_client.should_receive(:add).with(hash_including(:result_group_ssi => 'Images de la Révolution française'))
        @indexer.index(@fake_druid)
      end
    end
    
  end # index method

  context ":image_id_ssm field" do
    it "should be the value of image_ids method" do
      @hdor_client.should_receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><file id='W188_000001_300.jp2'/></resource>#{@content_md_end}")
      @hdor_client.should_receive(:content_metadata).with(@fake_druid).and_return(ng_xml)
      @indexer.should_receive(:image_ids).with(@fake_druid).and_call_original
      @solr_client.should_receive(:add).with(hash_including(:image_id_ssm => ['W188_000001_300.jp2']))
      @indexer.index(@fake_druid)
    end
  end

  context "fields from MODS" do
    before(:each) do
      @hdor_client.should_receive(:content_metadata).with(@fake_druid).at_most(:once).and_return(nil)      
    end
    it ":mods_xml" do
      @hdor_client.should_receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      @solr_client.should_receive(:add).with(hash_including(:mods_xml))
      @indexer.index(@fake_druid)
    end
    context "title fields" do
      it ":title_short_ftsi should be Stanford::Mods::Record.sw_short_title" do
        mods_xml = "<mods #{@ns_decl}><titleInfo><title>basic</title></titleInfo></mods>"
        @hdor_client.should_receive(:mods).with(@fake_druid).at_least(:twice).and_return(Nokogiri::XML(mods_xml))
        @solr_client.should_receive(:add).with(hash_including(:title_short_ftsi => @indexer.smods_rec(@fake_druid).sw_short_title))
        @indexer.index(@fake_druid)
      end
      it ":title_long_ftsi should be Stanford::Mods::Record.sw_full_title" do
        mods_xml = "<mods #{@ns_decl}><titleInfo><title>basic</title></titleInfo></mods>"
        @hdor_client.should_receive(:mods).with(@fake_druid).at_least(:twice).and_return(Nokogiri::XML(mods_xml))
        @solr_client.should_receive(:add).with(hash_including(:title_long_ftsi => @indexer.smods_rec(@fake_druid).sw_full_title))
        @indexer.index(@fake_druid)
      end
      it ":title_short_ftsi should be absent if the data is absent from the MODS record" do
        @hdor_client.should_receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        @solr_client.should_receive(:add).with(hash_not_including(:title_short_ftsi))
        @indexer.index(@fake_druid)
      end
      it ":title_long_ftsi should be absent if the data is absent from the MODS record" do
        @hdor_client.should_receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        @solr_client.should_receive(:add).with(hash_not_including(:title_long_ftsi))
        @indexer.index(@fake_druid)
      end
    end
    context ":genre_ssim" do
      it "should be the contents of the MODS <genre> fields" do
        mods_xml = "<mods #{@ns_decl}><genre>one</genre><genre>two</genre></mods>"
        @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods_xml))
        @solr_client.should_receive(:add).with(hash_including(:genre_ssim => ['one', 'two']))
        @indexer.index(@fake_druid)
      end
      it "should be absent if there are no <genre> fields in the MODS record" do
        @hdor_client.should_receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        @solr_client.should_receive(:add).with(hash_not_including(:genre_ssim))
        @indexer.index(@fake_druid)
      end
    end
    context "MODS <physicalDescription>" do
      before(:all) do
        @mods_pd = "<mods #{@ns_decl}>
                      <physicalDescription>
                        <form authority=\"gmd\">Image fixe</form>
                        <form authority=\"marccategory\">nonprojected graphic</form>
                        <form authority=\"marcsmd\">print</form>
                        <extent>1 est. : manière noire ; 51 x 37,5 cm (tr. c.)</extent>
                      </physicalDescription>
                    </mods>"
      end
      context ":doc_type_ssim" do
        it "should be the contents of the MODS <physicalDescription><form> fields" do
          @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(@mods_pd))
          @solr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ['Image fixe', 'nonprojected graphic', 'print']))
          @indexer.index(@fake_druid)
        end
        it "should be absent if there are no <physicalDescription> fields in the MODS record" do
          @hdor_client.should_receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
          @solr_client.should_receive(:add).with(hash_not_including(:doc_type_ssim))
          @indexer.index(@fake_druid)
        end
        it "should be absent if there are no <physicalDescription><form> fields in the MODS record" do
          mods_xml = "<mods #{@ns_decl}><physicalDescription><extent>basic</extent></physicalDescription></mods>"
          @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods_xml))
          @solr_client.should_receive(:add).with(hash_not_including(:doc_type_ssim))
          @indexer.index(@fake_druid)
        end
      end
      context ":medium_ssi" do
        it "should be the contents of the MODS <physicalDescription><extent> field between the colon and the semicolon" do
          @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(@mods_pd))
          @solr_client.should_receive(:add).with(hash_including(:medium_ssi => 'manière noire'))
          @indexer.index(@fake_druid)
        end
        it "should be absent if there are no <physicalDescription> fields in the MODS record" do
          @hdor_client.should_receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
          @solr_client.should_receive(:add).with(hash_not_including(:medium_ssi))
          @indexer.index(@fake_druid)
        end
        it "should be absent if there are no <physicalDescription><extent> fields in the MODS record" do
          mods_xml = "<mods #{@ns_decl}><physicalDescription><form>basic</form></physicalDescription></mods>"
          @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods_xml))
          @solr_client.should_receive(:add).with(hash_not_including(:medium_ssi))
          @indexer.index(@fake_druid)
        end
        it "should log a warning message if more than one <physicalDescription><extent> field is found" do
          mods = "<mods #{@ns_decl}>
                    <physicalDescription>
                      <extent>one : one ; one</extent>
                      <extent>two</extent>
                    </physicalDescription></mods>"
          @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
          @indexer.logger.should_receive(:warn).with(/^#{@fake_druid} did not retrieve any contentMetadata/)
          @indexer.logger.should_receive(:warn).with("#{@fake_druid} unexpectedly has multiple <physicalDescription><extent> fields; using first only for :medium_ssi")
          @solr_client.should_receive(:add).with(hash_including(:medium_ssi))
          @indexer.index(@fake_druid)
        end
        it "should log a warning message if <physicalDescription><extent> doesn't match regex" do
          mods = "<mods #{@ns_decl}>
                    <physicalDescription>
                      <extent>one</extent>
                    </physicalDescription></mods>"
          @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
          @indexer.logger.should_receive(:warn).with(/^#{@fake_druid} did not retrieve any contentMetadata/)
          @indexer.logger.should_receive(:warn).with("#{@fake_druid} has no :medium_ssi; MODS <physicalDescription><extent> has unexpected format: 'one'")
          @solr_client.should_receive(:add).with(hash_not_including(:medium_ssi))
          @indexer.index(@fake_druid)
        end
      end
    end # <physicalDescription>
    context "subjects" do
      context "<topic> displayLabel='Catalog heading'" do
        before(:all) do
          @mods_sub_cat_head = "<mods #{@ns_decl}>
                        <subject lang=\"fre\" displayLabel=\"Catalog heading\">
                          <topic>Archives et documents</topic>
                          <topic>Portraits</topic>
                          <topic>B</topic>
                        </subject>
                        <subject lang=\"eng\" displayLabel=\"Catalog heading\">
                          <topic>Archives and documents</topic>
                          <topic>Portraits</topic>
                          <topic>B</topic>
                        </subject>
                        <subject>
                          <topic>something</topic>
                        <subject>
                      </mods>"
        end
        it "should ignore <subject> without a displayLabel" do
          mods = "<mods #{@ns_decl}>
                    <subject lang='fre'>
                      <topic>one</topic>
                    </subject></mods>"
          @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
          @solr_client.should_receive(:add).with(hash_not_including(:catalog_heading_ftsimv, :catalog_heading_etsimv))
          @indexer.index(@fake_druid)
        end
        it "should ignore <subject> with a different displayLabel value" do
          mods = "<mods #{@ns_decl}>
                    <subject displayLabel='other'>
                      <topic>one</topic>
                    </subject></mods>"
          @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
          @solr_client.should_receive(:add).with(hash_not_including(:medium_ssi))
          @indexer.index(@fake_druid)
        end
        context "lang attribute" do
          it "lang='fre' :catalog_heading_ftsimv should combine the <topic> elements into a single string separated by ' -- ' " do
            @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(@mods_sub_cat_head))
            @solr_client.should_receive(:add).with(hash_including(:catalog_heading_ftsimv => ['Archives et documents -- Portraits -- B']))
            @indexer.index(@fake_druid)
          end
          it "lang='eng' :catalog_heading_etsimv should combine the lang='eng' <topic> elements into a single string separated by ' -- ' " do
            @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(@mods_sub_cat_head))
            @solr_client.should_receive(:add).with(hash_including(:catalog_heading_etsimv => ['Archives and documents -- Portraits -- B']))
            @indexer.index(@fake_druid)
          end
          it "should allow multiple catalog headings for a single language" do
            mods = "<mods #{@ns_decl}>
                          <subject lang=\"eng\" displayLabel=\"Catalog heading\">
                            <topic>eng1</topic>
                          </subject>
                          <subject lang=\"eng\" displayLabel=\"Catalog heading\">
                            <topic>eng2</topic>
                          </subject>
                        </mods>"
            @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
            @solr_client.should_receive(:add).with(hash_including(:catalog_heading_etsimv => ['eng1', 'eng2']))
            @indexer.index(@fake_druid)
          end
          it "should log a warning if it finds a lang other than 'eng' or 'fre'" do
            mods = "<mods #{@ns_decl}>
                      <subject lang=\"oth\" displayLabel=\"Catalog heading\">
                        <topic>one</topic>
                      </subject></mods>"
            @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
            @indexer.logger.should_receive(:warn).with(/^#{@fake_druid} did not retrieve any contentMetadata/)
            @indexer.logger.should_receive(:warn).with(/^#{@fake_druid} has subject with @displayLabel 'Catalog heading' but @lang not 'fre' or 'eng': '/)
            @solr_client.should_receive(:add).with(hash_not_including(:catalog_heading_ftsimv, :catalog_heading_etsimv))
            @indexer.index(@fake_druid)
          end
        end # lang attribute
        context "<name> in subject" do
          before(:all) do
            @mods_sub_name = "<mods #{@ns_decl}>
                          <subject>
                            <name type=\"personal\">
                              <namePart type=\"termsOfAddress\">term</namePart>
                              <namePart>Napoléon</namePart>
                              <namePart type=\"date\">1769-1821</namePart>
                            </name>
                          </subject>
                          <subject type=\"corporate\">
                            <name>
                              <namePart>corporate</namePart>
                            </name>
                          </subject>
                          <subject>
                            <name>
                              <namePart>untyped</namePart>
                              <namePart>part2</namePart>
                            </name>
                          </subject>
                        </mods>"
          end
          context ":speaker_ssim" do
            it "should be personal name, without dates or termsOfAddress" do
              @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(@mods_sub_name))
              @solr_client.should_receive(:add).with(hash_including(:speaker_ssim => ['Napoléon']))
              @indexer.index(@fake_druid)
            end
            it "should cope with family, given and untyped <namePart>" do
              mods = "<mods #{@ns_decl}>
                        <subject>
                          <name type=\"personal\">
                            <namePart type=\"termsOfAddress\">term</namePart>
                            <namePart type=\"family\">family</namePart>
                            <namePart type=\"given\">given</namePart>
                            <namePart type=\"date\">1769-1821</namePart>
                            <namePart>plain</namePart>
                          </name>
                        </subject>
                      </mods>"
              @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
              @solr_client.should_receive(:add).with(hash_including(:speaker_ssim => ['family, given, plain']))
              @indexer.index(@fake_druid)
            end
            it "there should be none if there is no subject personal name" do
              mods = "<mods #{@ns_decl}>
                        <subject type=\"corporate\">
                          <name>
                            <namePart>corporate</namePart>
                          </name>
                        </subject>
                        <subject>
                          <name>
                            <namePart>untyped</namePart>
                          </name>
                        </subject>
                      </mods>"
              @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
              @solr_client.should_receive(:add).with(hash_not_including(:speaker_ssim))
              @indexer.index(@fake_druid)
            end
            it "can have multiple values" do
              mods = "<mods #{@ns_decl}>
                        <subject>
                          <name type=\"personal\">
                            <namePart>plain1</namePart>
                          </name>
                        </subject>
                        <subject>
                          <name type=\"personal\">
                            <namePart>plain2</namePart>
                          </name>
                          <name type=\"personal\">
                            <namePart>plain3</namePart>
                          </name>
                        </subject>
                      </mods>"
              @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
              @solr_client.should_receive(:add).with(hash_including(:speaker_ssim => ['plain1', 'plain2', 'plain3']))
              @indexer.index(@fake_druid)
            end
            it "should normalize the name to match AP names" do
              pending "name normalization for images to be implemented"
            end
          end # :speaker_ssim
          context ":subject_name_ssim" do
            it ":subject_name_ssim should be any type other than personal name" do
              @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(@mods_sub_name))
              @solr_client.should_receive(:add).with(hash_including(:subject_name_ssim => ['corporate', 'untyped, part2']))
              @indexer.index(@fake_druid)
            end
            it "there should be none if there is no subject impersonal name" do
              mods = "<mods #{@ns_decl}>
                        <subject>
                          <name type=\"personal\">
                            <namePart>personal</namePart>
                          </name>
                        </subject>
                      </mods>"
              @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
              @solr_client.should_receive(:add).with(hash_not_including(:subject_name_ssim))
              @indexer.index(@fake_druid)
            end
            it "can have multiple values" do
              # already tested for above
            end
          end # :subject_name_ssim
        end # subject name
      end # subjects
      
      context "names" do
        before(:all) do
          @mods_sub_name = "<mods #{@ns_decl}>
                    <name type=\"personal\">
                      <namePart>Artist</namePart>
                      <role><roleTerm authority=\"marcrelator\" type=\"code\">art</roleTerm></role>
                    </name>
                    <name type=\"personal\">
                      <namePart>Collector</namePart>
                      <role><roleTerm authority=\"marcrelator\" type=\"code\">col</roleTerm></role>
                    </name>
                    <name type=\"personal\">
                      <namePart>Donor</namePart>
                      <role><roleTerm authority=\"marcrelator\" type=\"code\">dnr</roleTerm></role>
                    </name>
                    <name type=\"personal\">
                      <namePart>Draftsman</namePart>
                      <role><roleTerm authority=\"marcrelator\" type=\"code\">drm</roleTerm></role>
                    </name>
                    <name type=\"personal\">
                      <namePart>Engraver</namePart>
                      <role><roleTerm authority=\"marcrelator\" type=\"code\">egr</roleTerm></role>
                    </name>
                    <name type=\"personal\">
                      <namePart>Illustrator</namePart>
                      <role><roleTerm authority=\"marcrelator\" type=\"code\">ill</roleTerm></role>
                    </name>
                    <name type=\"personal\">
                      <namePart>Publisher</namePart>
                      <role><roleTerm authority=\"marcrelator\" type=\"code\">pbl</roleTerm></role>
                    </name>
                    <name type=\"personal\">
                      <namePart>Sculptor</namePart>
                      <role><roleTerm authority=\"marcrelator\" type=\"code\">scl</roleTerm></role>
                    </name>
                  </mods>"
          end
        context ":collector_ssim (roles: col, dnr)" do
          it "should be assigned for correct roles only" do
            @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(@mods_sub_name))
            @solr_client.should_receive(:add).with(hash_including(:collector_ssim => ['Collector', 'Donor']))
            @indexer.index(@fake_druid)
          end
          it "should do multiple values" do
            mods = "<mods #{@ns_decl}>
                      <name type=\"personal\">
                        <namePart>Vinck, Carl de</namePart>
                        <role><roleTerm authority=\"marcrelator\" type=\"code\">col</roleTerm></role>
                      </name>
                      <name type=\"personal\">
                        <namePart>Hennin, Michel</namePart>
                        <role><roleTerm authority=\"marcrelator\" type=\"code\">col</roleTerm></role>
                      </name>
                    </mods>"
            @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
            @solr_client.should_receive(:add).with(hash_including(:collector_ssim => ['Vinck, Carl de', 'Hennin, Michel']))
            @indexer.index(@fake_druid)
          end
          it "should use the right namePart pieces" do
            mods = "<mods #{@ns_decl}>
                      <name type=\"personal\" usage=\"primary\">
                        <namePart type=\"termsOfAddress\">term</namePart>
                        <namePart type=\"family\">family</namePart>
                        <namePart type=\"given\">given</namePart>
                        <namePart type=\"date\">1769-1821</namePart>
                        <namePart>plain</namePart>
                        <role><roleTerm authority=\"marcrelator\" type=\"code\">col</roleTerm></role>
                      </name>
                      <name type=\"personal\">
                        <namePart>Hennin, Michel</namePart>
                        <namePart type=\"date\">1777-1863</namePart>
                        <role><roleTerm authority=\"marcrelator\" type=\"code\">dnr</roleTerm></role>
                      </name>
                    </mods>"
            @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
            @solr_client.should_receive(:add).with(hash_including(:collector_ssim => ['family, given', 'Hennin, Michel']))
            @indexer.index(@fake_druid)
          end
          it "there should be none if there is no name with that role" do
            mods = "<mods #{@ns_decl}>
                      <name type=\"personal\">
                        <namePart>egr</namePart>
                        <role><roleTerm authority=\"marcrelator\" type=\"code\">egr</roleTerm></role>
                      </name>
                    </mods>"
            @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
            @solr_client.should_receive(:add).with(hash_not_including(:collector_ssim))
            @indexer.index(@fake_druid)
          end
          # as of 2013-03-04, all roles for BnF Images are of type code
          #it "should work for role code or text"
        end # collector_ssim
        context ":artist_ssim (roles: art, drm, egr, ill, scl)" do
          it "should be assigned for correct roles only" do
            @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(@mods_sub_name))
            @solr_client.should_receive(:add).with(hash_including(:artist_ssim => ['Artist', 'Draftsman', 'Engraver', 'Illustrator', 'Sculptor']))
            @indexer.index(@fake_druid)
          end
          it "should do multiple values" do
            mods = "<mods #{@ns_decl}>
                      <name type=\"personal\" usage=\"primary\">
                        <namePart>Morret, Jean Baptiste</namePart>
                        <role><roleTerm authority=\"marcrelator\" type=\"code\">egr</roleTerm></role>
                      </name>
                      <name type=\"personal\">
                        <namePart>Endner, Gustav Georg</namePart>
                        <role><roleTerm authority=\"marcrelator\" type=\"code\">egr</roleTerm></role>
                      </name>
                    </mods>"
            @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
            @solr_client.should_receive(:add).with(hash_including(:artist_ssim => ['Morret, Jean Baptiste', 'Endner, Gustav Georg']))
            @indexer.index(@fake_druid)
          end
          it "should use the right namePart pieces" do
            mods = "<mods #{@ns_decl}>
                      <name type=\"personal\" usage=\"primary\">
                        <namePart type=\"termsOfAddress\">term</namePart>
                        <namePart type=\"family\">family</namePart>
                        <namePart type=\"given\">given</namePart>
                        <namePart type=\"date\">date</namePart>
                        <namePart>plain</namePart>
                        <role><roleTerm authority=\"marcrelator\" type=\"code\">art</roleTerm></role>
                      </name>
                      <name type=\"personal\" usage=\"primary\">
                        <namePart>Endner, Gustav Georg</namePart>
                        <namePart type=\"termsOfAddress\">graveur</namePart>
                        <namePart type=\"date\">1754-1824</namePart>
                        <role><roleTerm authority=\"marcrelator\" type=\"code\">egr</roleTerm></role>
                      </name>
                      <name type=\"personal\" usage=\"primary\">
                        <namePart>plain</namePart>
                        <role><roleTerm authority=\"marcrelator\" type=\"code\">egr</roleTerm></role>
                      </name>
                    </mods>"
            @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
            @solr_client.should_receive(:add).with(hash_including(:artist_ssim => ['family, given (date)', 'Endner, Gustav Georg (1754-1824)', 'plain']))
            @indexer.index(@fake_druid)
          end
          it "there should be none if there is no name with that role" do
            mods = "<mods #{@ns_decl}>
                      <name type=\"personal\">
                        <namePart>col</namePart>
                        <role><roleTerm authority=\"marcrelator\" type=\"code\">col</roleTerm></role>
                      </name>
                    </mods>"
            @hdor_client.should_receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(mods))
            @solr_client.should_receive(:add).with(hash_not_including(:artist_ssim))
            @indexer.index(@fake_druid)
          end
          # as of 2013-03-04, all roles for BnF Images are of type code
          # it "should work for role code or text"
        end  # :artist_ssim
      end # names
       
=begin
      :date_issued_ssim  #  originInfo_dateIssued_sim,    subject_temporal_sim  ?  <note>Date de creation??
      :date_issued_dtsim
      :search_date  YYYYMMDD   or dt or i?
      :facet_date YYYYMM   i or s or ???

      :text_tiv => smods_rec.text  # anything else here?
=end
    end # fields from MODS

# FIXME:  adjust solrconfig facets, qf and pf lists;  schema copyfields

  end # doc_hash_from_mods
  
  context "image_ids method" do
    it "should be nil if there are no <resource> elements in the contentMetadata" do
      ng_xml = Nokogiri::XML("#{@content_md_start}#{@content_md_end}")
      @hdor_client.should_receive(:content_metadata).with(@fake_druid).and_return(ng_xml)
      @indexer.image_ids(@fake_druid).should == nil
    end
    it "should ignore <resource> elements with attribute type other than 'image'" do
      ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='blarg'><file id='foo'/></resource>#{@content_md_end}")
      @hdor_client.should_receive(:content_metadata).with(@fake_druid).and_return(ng_xml)
      @indexer.image_ids(@fake_druid).should == nil
    end
    it "should be ignore all but <file> element children of the image resource element" do
      ng_xml = ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><label id='foo'>bar</label></resource>#{@content_md_end}")
      @hdor_client.should_receive(:content_metadata).with(@fake_druid).and_return(ng_xml)
      @indexer.image_ids(@fake_druid).should == nil
    end
    it "should be nil if there are no id elements on file elements" do
      ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><file/></resource>#{@content_md_end}")
      @hdor_client.should_receive(:content_metadata).with(@fake_druid).and_return(ng_xml)
      @indexer.image_ids(@fake_druid).should == nil
    end
    it "should be an Array of size one if there is a single <resource><file id='something'> in the content metadata" do
      ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><file id='foo'/></resource>#{@content_md_end}")
      @hdor_client.should_receive(:content_metadata).with(@fake_druid).and_return(ng_xml)
      @indexer.image_ids(@fake_druid).should == ['foo']
    end
    it "should be the same size as the number of <resource><file id='something'> in the content metadata" do
      ng_xml = Nokogiri::XML("#{@content_md_start}
            <resource type='image'><file id='foo'/></resource>
            <resource type='image'><file id='bar'/></resource>#{@content_md_end}")
      @hdor_client.should_receive(:content_metadata).with(@fake_druid).and_return(ng_xml)
      @indexer.image_ids(@fake_druid).should == ['foo', 'bar']
    end
    it "endings of .jp2 should not be stripped" do
      ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><file id='W188_000001_300.jp2'/></resource>#{@content_md_end}")
      @hdor_client.should_receive(:content_metadata).with(@fake_druid).and_return(ng_xml)
      @indexer.image_ids(@fake_druid).should == ['W188_000001_300.jp2']
    end
  end # image_ids method  
  
end