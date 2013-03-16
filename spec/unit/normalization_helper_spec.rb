# encoding: UTF-8
require 'spec_helper'

describe NormalizationHelper do
  
  include NormalizationHelper

  context "#normalize_session_title" do
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
     it "should remove leading and trailing perios" do
       normalize_speaker("m.GuM.NamewithPeriodAtEndandm.InMiddleadet.").should == "GuM.NamewithPeriodAtEndandm.InMiddleadet"
       normalize_speaker("Mm. .McRae........ ").should == "McRae"
     end
     it "should capitalize first letter after M and MM removed" do
       normalize_speaker("m. guadet").should == "Guadet"
       normalize_speaker("M. nametobeuppercased").should == "Nametobeuppercased"
       normalize_speaker("' MM. ganltier-bianzat et de Choisenl-Praslin.").should == "Ganltier-bianzat et de Choisenl-Praslin"
     end
     it "should remove leading open paren" do
       normalize_speaker("(Jacob Dupont").should == "Jacob Dupont"
     end
     it "should remove leading « and other indicated characters" do
       normalize_speaker("«M- «.McRae. ").should == "McRae"
       normalize_speaker("«««M- ...McRae. ").should == "McRae"
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
       normalize_speaker("M. le Pr ésident").should == 'Le Président'
       normalize_speaker(">M. le Président").should == 'Le Président'
     end
     it "should remove leading M, or MM," do
       normalize_speaker("M, D'André").should == "D'André"
       normalize_speaker("MM, de Noailles et Chabroud").should == "De Noailles et Chabroud"
     end
     it "should remove leading M*" do
       normalize_speaker("M* le Président").should == "Le Président"
     end
     it "should remove leading M*" do
       normalize_speaker("M; Garat").should == "Garat"
     end
  end # normalize speaker

end