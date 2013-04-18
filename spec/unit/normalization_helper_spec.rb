# encoding: UTF-8
require 'spec_helper'

describe NormalizationHelper do
  
  include NormalizationHelper

  context "#normalize_session_title" do
    it "should strip outer whitespace" do
      normalize_session_title(' Séance du mardi 29 décembre 1789  ').should == "Séance du mardi 29 décembre 1789"
    end
    it "should correct OCR errors/misspellings of Séance" do
      normalize_session_title('Seance du samedi 23 avril 1791').should == "Séance du samedi 23 avril 1791"
      normalize_session_title('Stance du samedi 23 avril 1791').should == "Séance du samedi 23 avril 1791"
      normalize_session_title('Sdance').should == "Séance"
      normalize_session_title('Sèance').should == "Séance"
      normalize_session_title('Sèdnce').should == "Séance"
      normalize_session_title('Séamce').should == "Séance"
      normalize_session_title('Séancç').should == "Séance"
      normalize_session_title('Séancé').should == "Séance"
      normalize_session_title('Séancê').should == "Séance"
      normalize_session_title('Séandê').should == "Séance"
      normalize_session_title('Séanee').should == "Séance"
      normalize_session_title('Séanoe').should == "Séance"
      normalize_session_title('Séante').should == "Séance"
      normalize_session_title('Séançe').should == "Séance"
      normalize_session_title('Sédnce').should == "Séance"
      normalize_session_title('Séânèê').should == "Séance"
      normalize_session_title('Sêancè').should == "Séance"
      normalize_session_title('seance').should == "Séance"
      normalize_session_title('sèance').should == "Séance"
      normalize_session_title('seanc.').should == "Séance"
      normalize_session_title('Sénce').should == "Séance"
      normalize_session_title('Séanè').should == "Séance"
      normalize_session_title('seané').should == "Séance"
      normalize_session_title('Sèattdé').should == "Séance"
      normalize_session_title('Séan ce').should == "Séance"
      normalize_session_title('Sécthôè').should == "Séance"
      normalize_session_title('Séyripe').should == "Séance"
      normalize_session_title('Sèance, du').should == "Séance du"
    end
    it "should correct OCR for du" do
      normalize_session_title('Séance dû lundi').should == 'Séance du lundi'
      normalize_session_title('Séance du, mardi').should == 'Séance du mardi'
      normalize_session_title('Séance du- jeudi').should == 'Séance du jeudi'
      normalize_session_title('Séance du. mardi').should == 'Séance du mardi'
      normalize_session_title('Séance du . mardi').should == 'Séance du mardi'
      normalize_session_title('Séance du . samedi').should == 'Séance du samedi'
      normalize_session_title('Séance au lundi').should == 'Séance du lundi'
      normalize_session_title('Séance da lundi').should == 'Séance du lundi'
      normalize_session_title('Séance dit lundi').should == 'Séance du lundi'
      normalize_session_title('Séance âu lundi').should == 'Séance du lundi'
    end
    context "should correct OCR for days of the week" do
      it "lundi" do
        normalize_session_title('Séance du Lundi').should == "Séance du lundi"
        normalize_session_title('Séance du luhdi').should == "Séance du lundi"
      end
      it "mardi" do
        normalize_session_title('Séance dumardi').should == "Séance du mardi"
        normalize_session_title('Séance du madi').should == "Séance du mardi"
        normalize_session_title('Séance du matdi').should == "Séance du mardi"
      end
      it "mercredi" do
        normalize_session_title('Séance du Mercredi').should == "Séance du mercredi"
        normalize_session_title('Séance du mercrredi').should == "Séance du mercredi"
        normalize_session_title('Séance du mereredi').should == "Séance du mercredi"
      end
      it "jeudi" do
        normalize_session_title('Séance du hindi').should == "Séance du jeudi"
        normalize_session_title('Séance du ieudi').should == "Séance du jeudi"
        normalize_session_title('Séance du jeudis').should == "Séance du jeudi"
        normalize_session_title('Séance du jèudi').should == "Séance du jeudi"
      end
      it "vendredi" do
        normalize_session_title('Séance du Vendredi').should == "Séance du vendredi"
        normalize_session_title('Séance du vendrcedi').should == "Séance du vendredi"
        normalize_session_title('Séance du vendredia').should == "Séance du vendredi"
        normalize_session_title('Séance du vendrèdi').should == "Séance du vendredi"
      end
      it "samedi" do
        normalize_session_title('Séance du Samedi').should == "Séance du samedi"
        normalize_session_title('Séance du samed').should == "Séance du samedi"
        normalize_session_title('Séance du saniedi').should == "Séance du samedi"
        normalize_session_title('Séance du smaedi').should == "Séance du samedi"
        normalize_session_title('Séance du ssamedi').should == "Séance du samedi"
      end
      it "dimanche" do
        normalize_session_title('Séance du Dimanche').should == "Séance du dimanche"
        normalize_session_title('Séance du dimanphe').should == "Séance du dimanche"
        normalize_session_title('Séance du dirnanche').should == "Séance du dimanche"
      end
      it "should separate digits smashed against days of the week" do
        normalize_session_title('Séance du lundi4').should == "Séance du lundi 4"
        normalize_session_title('Séance du mardi10').should == "Séance du mardi 10"
        normalize_session_title('Séance du mardi17').should == "Séance du mardi 17"
        normalize_session_title('Séance du samedi3').should == "Séance du samedi 3"
        normalize_session_title('Séance du dimanche10').should == "Séance du dimanche 10"
        normalize_session_title('Séance du dimanche26').should == "Séance du dimanche 26"
      end
    end # days of the week
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
      normalize_session_title('( Dimanche 17 novembre 1793 )').should == "Séance du dimanche 17 novembre 1793"
      normalize_session_title(' ( Dimanche, 29 décembre 1793 .)').should == "Séance du dimanche, 29 décembre 1793"
      normalize_session_title('(Samedi 26 octobre 1793.)').should == "Séance du samedi 26 octobre 1793"
      normalize_session_title('( Samedi 23 novembre 1793 ,)').should == "Séance du samedi 23 novembre 1793"
      normalize_session_title("Jeudi, 19 décembre 1793 )").should == "Séance du jeudi, 19 décembre 1793"
    end
    it "should remove preceding single quotes" do
      normalize_session_title("' Séance du dimanche 20 mai 1792").should == "Séance du dimanche 20 mai 1792"
      normalize_session_title("'Séance du jeudi 17 mai 1792 ").should == "Séance du jeudi 17 mai 1792"
    end
    it "should remove preceding hyphens" do
      normalize_session_title('- Séance du jeudi 10 mars 1791').should == "Séance du jeudi 10 mars 1791"
      normalize_session_title('-Séance du jeudi 9 août 1792, au matin').should == "Séance du jeudi 9 août 1792, au matin"
    end
    it "should skip ahead to 'Séance' if it starts 'présidence'" do
      normalize_session_title('PRÉSIDENCE DE M. DUPORT. Séance du mercredi 23 février 1791, au soir').should == 'Séance du mercredi 23 février 1791, au soir'
      normalize_session_title('Présidence de Billaud-Varenne. Séance du lundi matin 16 septembre 1793').should == 'Séance du lundi matin 16 septembre 1793'
      normalize_session_title('présidence de m. duport. Séance du mercredi 23 février 1791, au matin').should == 'Séance du mercredi 23 février 1791, au matin'
    end
    it "should start 'Séance du (dimanche)' not '(Dimanche)'" do
      normalize_session_title('Dimanche 17 novembre 1793').should == 'Séance du dimanche 17 novembre 1793'
      normalize_session_title('Lundi, 11 novembre 1793').should == 'Séance du lundi, 11 novembre 1793'
      normalize_session_title('Mardi 14 août 1792').should == 'Séance du mardi 14 août 1792'
      normalize_session_title('Mercredi 23 octobre 1793').should == 'Séance du mercredi 23 octobre 1793'
      normalize_session_title('Jeudi 28 novembre 1793').should == 'Séance du jeudi 28 novembre 1793'
      normalize_session_title('Vendredi 3 janvier 1794').should == 'Séance du vendredi 3 janvier 1794'
      normalize_session_title('Samedi 4 janvier 1794').should == 'Séance du samedi 4 janvier 1794'
    end
    
    it "should deal with annoying reality" do
      normalize_session_title('Séance,  du jeudi 17 septembre 1789,. au matin.').should == "Séance, du jeudi 17 septembre 1789,. au matin"
      normalize_session_title('Mardi 11 septembre 1792, au soir. *').should == "Séance du mardi 11 septembre 1792, au soir"
      normalize_session_title('Samedi 18 août 1792, au matin.').should == 'Séance du samedi 18 août 1792, au matin'
      normalize_session_title('(, Samedi 7 décembre 1793 .")').should == "Séance du samedi 7 décembre 1793"
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
  
  context "#normalize_date" do
    it "should cope with day of 00" do
      normalize_date("1792-08-00").should == Date.parse('1792-08-01')
    end
    it "should cope with single digit days and months (no leading zero)" do
      normalize_date("1792-8-1").should == Date.parse('1792-08-01')
    end
    it "should cope with year only" do
      normalize_date("1792").should == Date.parse('1792-01-01')
    end
    it "should cope with year and month only" do
      normalize_date("1792-08").should == Date.parse('1792-08-01')
    end
    it "should cope with slashes in days area (trying to representing a range)" do
      normalize_date("1792-08-01/15/17").should == Date.parse('1792-08-01')
    end
    it "should cope with au in date" do
      normalize_date("1793-05-17 au 1793-06-02").should == Date.parse('1793-05-17')
    end
    it "should cope with spaces preceding or following hyphens" do
      normalize_date("1792 - 8 - 01").should == Date.parse('1792-08-01')
    end
  end # normalize_date

  context "#normalize_speaker" do
     it "should remove leading M and MM" do
       normalize_speaker("M- McRae:: ").should == "McRae"
       normalize_speaker("Mm. McRae, ").should == "McRae"
       normalize_speaker("M .McRae. ").should == "McRae"
       normalize_speaker("M . McRae. ").should == "McRae"
       normalize_speaker("M McRae. ").should == "McRae"
       normalize_speaker("M'. McRae. ").should == "McRae"
       normalize_speaker("'M' McRae. ").should == "McRae"
       normalize_speaker("m. Guadet").should == "Guadet"
       normalize_speaker("m.NoSpace").should == "NoSpace"
     end
     it "should capitalize first letter after M and MM removed" do
       normalize_speaker("m. guadet").should == "Guadet"
       normalize_speaker("M. nametobeuppercased").should == "Nametobeuppercased"
       normalize_speaker("' MM. ganltier-bianzat et de Choisenl-Praslin.").should == "Ganltier-bianzat et de Choisenl-Praslin"
     end
     it "should remove leading and trailing periods" do
       normalize_speaker("m.GuM.NamewithPeriodAtEndandm.InMiddleadet.").should == "GuM.NamewithPeriodAtEndandm.InMiddleadet"
       normalize_speaker("Mm. .McRae........ ").should == "McRae"
     end
     it "should remove leading open paren" do
       normalize_speaker("(Jacob Dupont").should == "Jacob Dupont"
       normalize_speaker("(M. l'abbé Tridon").should == "L'abbé Tridon"
     end
     it "should remove leading « and other indicated characters" do
       normalize_speaker("«M- «.McRae. ").should == "McRae"
       normalize_speaker("«««M- ...McRae. ").should == "McRae"
       normalize_speaker("«««M- ...McRae. ").should == "McRae"
       normalize_speaker("'Tronchou").should == "Tronchou"
     end
     it "should remove spaces around hypens and spaces after d'" do
       normalize_speaker("McRae - d' lac").should == "McRae-d'lac"
       normalize_speaker("M. McRae- d'   lac").should == "McRae-d'lac"
       normalize_speaker("McRae -d'lac...").should == "McRae-d'lac"
     end
     it "should change leading 1e into Le" do
       normalize_speaker("1e comte Midrabeau").should == 'Le comte Midrabeau'
     end
     it "should normalize president speaker names alternates" do
       normalize_speaker("M. le Président .").should == 'Le Président'
       normalize_speaker("M. le Président :").should == 'Le Président'
       normalize_speaker("M. le Président Sieyès").should == 'Le Président'
       normalize_speaker("M. le Président de La Houssaye").should == 'Le Président'
       normalize_speaker("M. le Président répond").should == 'Le Président'
       normalize_speaker("M. le Président,").should == 'Le Président'
       normalize_speaker("M. le Président.").should == 'Le Président'
       normalize_speaker(" M. le Président..").should == 'Le Président'
       normalize_speaker("M. le Président...").should == 'Le Président'
       normalize_speaker("M. le Président....").should == 'Le Président'
       normalize_speaker("M. le Présldent.").should == 'Le Président'
       normalize_speaker("M. le President.").should == 'Le Président'
       normalize_speaker("le Président").should == 'Le Président'
       normalize_speaker("le Président,").should == 'Le Président'
       normalize_speaker("M. le président").should == 'Le Président'
       normalize_speaker("le Président.").should == 'Le Président'
       normalize_speaker("le président").should == 'Le Président'
       normalize_speaker("Le Preésident.").should == 'Le Président'
       normalize_speaker("M. le président.").should == 'Le Président'
       normalize_speaker(">M. le Président").should == 'Le Président'
       normalize_speaker("Le' Président").should == 'Le Président'
       normalize_speaker("Le-Président").should == 'Le Président'
       normalize_speaker("Le Présidant").should == 'Le Président'
       normalize_speaker("Le Présiden").should == 'Le Président'
       normalize_speaker("Le Présidtent").should == 'Le Président'
       normalize_speaker("Le Présidènt").should == 'Le Président'
       normalize_speaker("La Président").should == 'Le Président'
       normalize_speaker("Président").should == 'Le Président'
     end
     it "should remove leading M, or MM," do
       normalize_speaker("M, D'André").should == "D'André"
       normalize_speaker("MM, de Noailles et Chabroud").should == "De Noailles et Chabroud"
     end
     it "should remove leading M*" do
       normalize_speaker("M* le Président").should == "Le Président"
     end
     it "should remove leading M;" do
       normalize_speaker("M; Garat").should == "Garat"
     end
     it "should normalize to L'abbé" do
       normalize_speaker("L'abbe Gouttes").should == "L'abbé Gouttes"
       normalize_speaker("L'Abbé Sieyès").should == "L'abbé Sieyès"
       normalize_speaker("Labbé Gouttes").should == "L'abbé Gouttes"
     end
  end # normalize speaker

end