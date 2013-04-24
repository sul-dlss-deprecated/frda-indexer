# encoding: UTF-8
require 'spec_helper'

describe NormalizationHelper do
  
  include NormalizationHelper

  context "sentence_case" do
    it "should leave the first letter capitalized and make all other letters lowercase" do
      sentence_case("Dimanche 1er Décembre 1793").should == "Dimanche 1er décembre 1793"
      sentence_case("Séance au LUNDI 3 DÉCEMBRE 1792").should == "Séance au lundi 3 décembre 1792"
      sentence_case("Séance du dimanche 30 JUIN 1793").should == "Séance du dimanche 30 juin 1793"
      sentence_case("Noblesse du bailliage scondaire de Conches.").should == "Noblesse du bailliage scondaire de conches."
      sentence_case("PENSIONS AU-DESSOUS DE SIX CENTS LIVRES SEPTIÈME CLASSE. (Suite.)").should == "Pensions au-dessous de six cents livres septième classe. (suite.)"
    end
  end

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
        normalize_session_title('Procis-verbal de la cerhnonie de la Federation (1), du mereredi 14 juillet 1790').should == "Procis-verbal de la cerhnonie de la federation (1) du mereredi 14 juillet 1790"
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
    context "should correct OCR for months" do
      it "janvier" do
        normalize_session_title("1 jahvièr").should == "1 janvier"
        normalize_session_title("1 Janvier").should == "1 janvier"
        normalize_session_title("1 JANVIER").should == "1 janvier"
      end
      it "février" do
        # all okay?
      end
      it "mars" do
        # all okay?
      end
      it "avril" do
        # all okay?
      end
      it "mai" do
        normalize_session_title("1 mài").should == "1 mai"
      end
      it "juin" do
        # all okay?
      end
      it "juillet" do
        # all okay?
      end
      it "août" do
        normalize_session_title("1 aout").should == "1 août"
        normalize_session_title("1 aoUt").should == "1 août"
        normalize_session_title("1 AOUT").should == "1 août"
        normalize_session_title("1 aotit").should == "1 août"
        normalize_session_title("1 aôût").should == "1 août"
      end
      it "septembre" do
        normalize_session_title("1 septembrê").should == "1 septembre"
        normalize_session_title("1 septembre!").should == "1 septembre"
      end
      it "octobre" do
        normalize_session_title("1 oetobre ").should == "1 octobre"
        normalize_session_title("1 Octobre").should == "1 octobre"
        normalize_session_title("1 OCTOBRE'").should == "1 octobre"
        normalize_session_title("1 octobrè").should == "1 octobre"
      end
      it "novembre" do
        normalize_session_title("1 novémbre").should == "1 novembre"
        normalize_session_title("1 novembrè").should == "1 novembre"
        normalize_session_title("1 novèmbre").should == "1 novembre"
        normalize_session_title("1 Novembre").should == "1 novembre"
      end
      it "décembre" do
        normalize_session_title("1 décëmbre").should == "1 décembre"
        normalize_session_title("1 déçembre").should == "1 décembre"
        normalize_session_title("1 Décembre").should == "1 décembre"
        normalize_session_title("1 DÉCEMBRE").should == "1 décembre"
      end
    end
    it "should correct OCR for au" do
      normalize_session_title("Séance du lundi 31 décembre 1792, AU MATIN").should == "Séance du lundi 31 décembre 1792, au matin"
      normalize_session_title("Séance du vendredi 6 juillet 1792, aU matin").should == "Séance du vendredi 6 juillet 1792, au matin"
      normalize_session_title("Séance du lundi 18 juin 1792 aumatin").should == "Séance du lundi 18 juin 1792, au matin"
      normalize_session_title("Séance du mercredi 28 septembre 1791 ,aumatin").should == "Séance du mercredi 28 septembre 1791, au matin"
      normalize_session_title("Séance du jeudi 3 septembre 1789 ,au matin").should == "Séance du jeudi 3 septembre 1789, au matin"
      normalize_session_title("Séance du jeudi 22 mars 1792 ,au soir").should == "Séance du jeudi 22 mars 1792, au soir"
      normalize_session_title("Séance du lundi 18 juin 1792 ,[au soir").should == "Séance du lundi 18 juin 1792, au soir"
      normalize_session_title("Séance du lundi 4 avril 1791, ausoir").should == "Séance du lundi 4 avril 1791, au soir"
      normalize_session_title("Séance du mercredi 10 juillet 1793, au. soir").should == "Séance du mercredi 10 juillet 1793, au soir"
      normalize_session_title("Séance du lundi 18 juin 1792 aii soir").should == "Séance du lundi 18 juin 1792, au soir"
      normalize_session_title("Séance du samedi 14 août 1790, ail matin").should == "Séance du samedi 14 août 1790, au matin"
      normalize_session_title("Séance du mardi 5 juillet 1791 ait matin").should == "Séance du mardi 5 juillet 1791, au matin"
      normalize_session_title("Séance du lundi 18 juin 1792 au. soir").should == "Séance du lundi 18 juin 1792, au soir"
      normalize_session_title("Séance du jeudi 22 avril 1790, aù soir").should == "Séance du jeudi 22 avril 1790, au soir"
      normalize_session_title("Séance du vendredi 6 juillet 1792, au matin").should == "Séance du vendredi 6 juillet 1792, au matin"
      normalize_session_title("Séance du dimanche 24 août 1790, aw matin").should == "Séance du dimanche 24 août 1790, au matin"
      normalize_session_title("Séance du mardi 20 septembre 1791, ay soir").should == "Séance du mardi 20 septembre 1791, au soir"
      normalize_session_title("Séance du vendredi 31 déçembre 1790, ay matin").should == "Séance du vendredi 31 décembre 1790, au matin"
      normalize_session_title("Séance du lundi 18 juin 1792 du soir").should == "Séance du lundi 18 juin 1792, au soir"
      normalize_session_title("Séance du lundi 18 juin 1792 du matin").should == "Séance du lundi 18 juin 1792, au matin"
      normalize_session_title("Séance du lundi 27 juin 1791, lui matin").should == "Séance du lundi 27 juin 1791, au matin"
      normalize_session_title("Séance du lundi 18 juin 1792 m soir").should == "Séance du lundi 18 juin 1792, au soir"
      normalize_session_title("Séance du jeudi 29 mars 1792, oeu soir").should == "Séance du jeudi 29 mars 1792, au soir"
      normalize_session_title("Séance du jeudi 11 février 1790 otf soir").should == "Séance du jeudi 11 février 1790, au soir"
      normalize_session_title("Séance du jeudi 4 novembre 1790, ou soir").should == "Séance du jeudi 4 novembre 1790, au soir"
      normalize_session_title("Séance du samedi 17 juillet 1790, où soir").should == "Séance du samedi 17 juillet 1790, au soir"
      normalize_session_title("Lundi 9 septembre 1792, an soir").should == "Séance du lundi 9 septembre 1792, au soir"
      normalize_session_title("Séance du jeudi 18 avril 1793, cm matin. ").should == "Séance du jeudi 18 avril 1793, au matin"
#      normalize_session_title("Séance du lundi 31 décembre 1792, s au soir").should == "Séance du lundi 31 décembre 1792 au soir"
    end
    it "should correct OCR for matin" do
      normalize_session_title("Séance du lundi 31 mai 1790 aumatin").should == "Séance du lundi 31 mai 1790, au matin"
      normalize_session_title("Séance du mercredi 28 septembre 1791 ,aumatin").should == "Séance du mercredi 28 septembre 1791, au matin"
      normalize_session_title("Séance du mardi 27 juin 1792 ,'au matin.").should == "Séance du mardi 27 juin 1792, au matin"
      normalize_session_title("Séance du leudi 26 août 1790, au *matin").should == "Séance du leudi 26 août 1790, au matin"
      normalize_session_title("Séance du lundi 31 mai 1790 au malin").should == "Séance du lundi 31 mai 1790, au matin"
      normalize_session_title("Séance du vendredi 6 juillet 1792, au malin").should == "Séance du vendredi 6 juillet 1792, au matin"
      normalize_session_title("Séance du mardi 27 juillet 1790 . au matin").should == "Séance du mardi 27 juillet 1790, au matin"
      normalize_session_title("Séance du lundi 31 mai 1790 au matinx").should == "Séance du lundi 31 mai 1790, au matin"
      normalize_session_title("Séance du jeudi 20 mai 1790, au matin\\ ").should == "Séance du jeudi 20 mai 1790, au matin"
      normalize_session_title("Séance du lundi 31 mai 1790 au matiti").should == "Séance du lundi 31 mai 1790, au matin"
      normalize_session_title("Séance du jeudi 29 septembre 1791, au Matin").should == "Séance du jeudi 29 septembre 1791, au matin"
      normalize_session_title("Séance du vendredi 20 mai 1791, au màtin").should == "Séance du vendredi 20 mai 1791, au matin"
      normalize_session_title("Séance du vendredi 21 juillet 1791 au matm").should == "Séance du vendredi 21 juillet 1791, au matin"
      normalize_session_title("Séance du lundi 18 juin 1792 au 'mâtin").should == "Séance du lundi 18 juin 1792, au matin"
      normalize_session_title("Séance du samedi 11 juin 1791, au mdtin").should == "Séance du samedi 11 juin 1791, au matin"
      normalize_session_title("Séance du mardi 13 fuillét 1790, au mutin").should == "Séance du mardi 13 fuillét 1790, au matin"
    end
    it "should correct OCR for soir" do
      normalize_session_title("Séance du lundi 31 mai 1790 au soirl").should == "Séance du lundi 31 mai 1790, au soir"
      normalize_session_title("Séance du lundi 31 mai 1790 au soîrl").should == "Séance du lundi 31 mai 1790, au soir"
      normalize_session_title("Séance du lundi 18 juin 1792 au sàir").should == "Séance du lundi 18 juin 1792, au soir"
      normalize_session_title("Séance du samedi 30 juillet 1791, au Sùir").should == "Séance du samedi 30 juillet 1791, au soir"
      normalize_session_title("Séance du lundi 11 oètobre 1790, au Sdlr").should == "Séance du lundi 11 oètobre 1790, au soir"
      normalize_session_title("Séance du jeudi 28 avril 1791, au S0ir(l").should == "Séance du jeudi 28 avril 1791, au soir"
      normalize_session_title("Séance du lundi 31 mai 1790 au soîr(l").should == "Séance du lundi 31 mai 1790, au soir"
      normalize_session_title("Séance du mardi 22 mars 1791, au sofr").should == "Séance du mardi 22 mars 1791, au soir"
      normalize_session_title("Séance du mardi 20 septembre 1791, au solr").should == "Séance du mardi 20 septembre 1791, au soir"
      normalize_session_title("Séance du lundi 31 mai 1790 au soif").should == "Séance du lundi 31 mai 1790, au soir"
      normalize_session_title("Séance du lundi 18 juin 1792 au soit").should == "Séance du lundi 18 juin 1792, au soir"
      normalize_session_title("Séance du mardi 30 novembre 1790, au snr").should == "Séance du mardi 30 novembre 1790, au soir"
      normalize_session_title("Séance du mardi 31 aôût 1790, au soî?'(l").should == "Séance du mardi 31 août 1790, au soir"
      normalize_session_title("Séance du mardi 9 août 1791, au loir").should == "Séance du mardi 9 août 1791, au soir"
      normalize_session_title("Séance du mardi 9 février 1790, au voir").should == "Séance du mardi 9 février 1790, au soir"
      normalize_session_title("Séance du jeudi 26 novembre 1789, au $oir").should == "Séance du jeudi 26 novembre 1789, au soir"
      normalize_session_title("Séance du lundi 31 mai 1790 ausoir").should == "Séance du lundi 31 mai 1790, au soir"
      normalize_session_title("Séance du vendredi 11 mai 1792, au soin").should == "Séance du vendredi 11 mai 1792, au soir"
    end
    context "punctuation and whitespace" do
      it "should deal well with preceding commas" do
        normalize_session_title('Séance du vendredi, 4 octobre 1793,').should == "Séance du vendredi 4 octobre 1793"
      end
      it "should change any ' , ' to ', ' " do
        normalize_session_title('Séance du mardi 29 décembre 1789 , au matin').should == "Séance du mardi 29 décembre 1789, au matin"
      end
      it "should normalize internal whitespace" do
        normalize_session_title('Séance du   mardi 29 décembre 1789, au matin (1) ').should == "Séance du mardi 29 décembre 1789, au matin"
      end    
      it "should remove outer parens and spaces" do
        normalize_session_title('( Dimanche 17 novembre 1793 )').should == "Séance du dimanche 17 novembre 1793"
        normalize_session_title(' ( Dimanche, 29 décembre 1793 .)').should == "Séance du dimanche 29 décembre 1793"
        normalize_session_title('(Samedi 26 octobre 1793.)').should == "Séance du samedi 26 octobre 1793"
        normalize_session_title('( Samedi 23 novembre 1793 ,)').should == "Séance du samedi 23 novembre 1793"
        normalize_session_title("Jeudi, 19 décembre 1793 )").should == "Séance du jeudi 19 décembre 1793"
      end
      it "should remove preceding single quotes" do
        normalize_session_title("' Séance du dimanche 20 mai 1792").should == "Séance du dimanche 20 mai 1792"
        normalize_session_title("'Séance du jeudi 17 mai 1792 ").should == "Séance du jeudi 17 mai 1792"
      end
      it "should remove preceding hyphens" do
        normalize_session_title('- Séance du jeudi 10 mars 1791').should == "Séance du jeudi 10 mars 1791"
        normalize_session_title('-Séance du jeudi 9 août 1792, au matin').should == "Séance du jeudi 9 août 1792, au matin"
      end
      it "should remove all »" do
        normalize_session_title("Séance du mardi 19 juillet 1791 » au matin").should == "Séance du mardi 19 juillet 1791, au matin"
      end
      it "should remove * " do
        normalize_session_title("Séance du mercredi 21 septembre 1791 * au matin").should == "Séance du mercredi 21 septembre 1791, au matin"
        normalize_session_title("Séance du vendredi 15 octobre 1790 * au soir").should == "Séance du vendredi 15 octobre 1790, au soir"
      end
      it "should remove all ." do
        normalize_session_title("Séance du jeudi 2 septembre 1790 , au. soir").should == "Séance du jeudi 2 septembre 1790, au soir"
        normalize_session_title("Séance du lundi 17 juin 1793 . au soir.").should == "Séance du lundi 17 juin 1793, au soir"
        normalize_session_title("Séance du jeudi 17 septembre 1789 ,. au matin").should == "Séance du jeudi 17 septembre 1789, au matin"
        normalize_session_title("Séance du mardi 11 janvier 1791 ., au matin").should == "Séance du mardi 11 janvier 1791, au matin"
        normalize_session_title("Séance du mardi 27 juillet 1790 . au matin").should == "Séance du mardi 27 juillet 1790, au matin"
        normalize_session_title("Séance du mercredi 2 JANVIER 17.93").should == "Séance du mercredi 2 janvier 1793"
        normalize_session_title("Séance du vendredi. 10 février 1792").should == "Séance du vendredi 10 février 1792"
        normalize_session_title("Séance. du mardi 27 juillet 1790, au soir").should == "Séance du mardi 27 juillet 1790, au soir"
      end
      it "should remove all ;" do
        normalize_session_title("Séance du jeudi 27 décembre 1792 ; au matin").should == "Séance du jeudi 27 décembre 1792, au matin"
      end
      it "should remove all '" do
        normalize_session_title("Séance du jeudi 3 mai 1792 ,' au matin").should == "Séance du jeudi 3 mai 1792, au matin"
        normalize_session_title("Séance du mardi 27 juin 1792 ,'au matin").should == "Séance du mardi 27 juin 1792, au matin"
        normalize_session_title("Séance du dimanche 28' juillet 1793").should == "Séance du dimanche 28 juillet 1793"
        normalize_session_title("Séance du jeudi 4 aout 1791, du 'mâtin").should == "Séance du jeudi 4 août 1791, au matin"
        normalize_session_title("Séance du samedi 5' décembre 1789, au soir").should == "Séance du samedi 5 décembre 1789, au soir"
      end
      it "should remove all [" do
        normalize_session_title("Séance du lundi 18 juin 1792 ,[au soir").should == "Séance du lundi 18 juin 1792, au soir"
      end
      it "should remove commas except those before au (matin|soir)" do
        normalize_session_title("Mercredi, 5 septembre 1792, au matin").should == "Séance du mercredi 5 septembre 1792, au matin"
        normalize_session_title("Samedi, 9 novembre 1793").should == "Séance du samedi 9 novembre 1793"
        normalize_session_title("Séance du dimanche, 31 mars 1793").should == "Séance du dimanche 31 mars 1793"
        normalize_session_title("Séance, au mercredi 21 décembre 1791 ").should == "Séance du mercredi 21 décembre 1791"
        normalize_session_title("Séance du vendredi, 4 octobre 1793").should == "Séance du vendredi 4 octobre 1793"
        normalize_session_title("Séance du jeudi 2 septembre 1790 , au. soir").should == "Séance du jeudi 2 septembre 1790, au soir"
        normalize_session_title("Du mercredi 9 septembre 1789 ,au matin").should == "Séance du mercredi 9 septembre 1789, au matin"
        normalize_session_title("Séance du jeudi 15 novembre 1192 ,au soir").should == "Séance du jeudi 15 novembre 1192, au soir"
      end
    end
    it "should only capitalize the first word" do
      normalize_session_title("Dimanche 1er Décembre 1793").should == "Séance du dimanche 1er décembre 1793"
      normalize_session_title("Séance au LUNDI 3 DÉCEMBRE 1792").should == "Séance du lundi 3 décembre 1792"
      normalize_session_title("Séance du dimanche 30 JUIN 1793").should == "Séance du dimanche 30 juin 1793"
    end
    it "should skip ahead to 'Séance' if it starts 'présidence'" do
      normalize_session_title('PRÉSIDENCE DE M. DUPORT. Séance du mercredi 23 février 1791, au soir').should == 'Séance du mercredi 23 février 1791, au soir'
      normalize_session_title('Présidence de Billaud-Varenne. Séance du lundi matin 16 septembre 1793').should == 'Séance du lundi matin 16 septembre 1793'
      normalize_session_title('présidence de m. duport. Séance du mercredi 23 février 1791, au matin').should == 'Séance du mercredi 23 février 1791, au matin'
    end
    it "should start 'Séance du (dimanche)' not '(Dimanche)'" do
      normalize_session_title('Dimanche 17 novembre 1793').should == 'Séance du dimanche 17 novembre 1793'
      normalize_session_title('Lundi, 11 novembre 1793').should == 'Séance du lundi 11 novembre 1793'
      normalize_session_title('Mardi 14 août 1792').should == 'Séance du mardi 14 août 1792'
      normalize_session_title('Mercredi 23 octobre 1793').should == 'Séance du mercredi 23 octobre 1793'
      normalize_session_title('Jeudi 28 novembre 1793').should == 'Séance du jeudi 28 novembre 1793'
      normalize_session_title('Vendredi 3 janvier 1794').should == 'Séance du vendredi 3 janvier 1794'
      normalize_session_title('Samedi 4 janvier 1794').should == 'Séance du samedi 4 janvier 1794'
    end
    it "should start 'Séance du ...' not 'Du ...'" do
      normalize_session_title('Du jeudi 10 juin 1790, au matin').should == 'Séance du jeudi 10 juin 1790, au matin'
      normalize_session_title("Du lundi 28 mai 1792").should == "Séance du lundi 28 mai 1792"
      normalize_session_title("Du mardi 29 mai 1792, au matin").should == "Séance du mardi 29 mai 1792, au matin"
      normalize_session_title("Du mercredi 30 mai 1792, au soir").should == "Séance du mercredi 30 mai 1792, au soir"
      normalize_session_title("Du mercredi 9 septembre 1789 ,au matin").should == "Séance du mercredi 9 septembre 1789, au matin"
      normalize_session_title("du vendredi 11 novèmbre 1791 .").should == "Séance du vendredi 11 novembre 1791"
    end
    context "should drop everything after the year" do
      it "plain" do
        normalize_session_title("Séance du dimanche 16 janvier 1791 (1)").should == "Séance du dimanche 16 janvier 1791"
        normalize_session_title("Séance du dimanche 24 octobre 1790 (i").should == "Séance du dimanche 24 octobre 1790"
        normalize_session_title("Séance du dimanche 6 février 1791 (I").should == "Séance du dimanche 6 février 1791"
        normalize_session_title("Séance du dimanche 7 février 1790 (t").should == "Séance du dimanche 7 février 1790"
        normalize_session_title("Séance du lundi 14 mars 1791 {1}").should == "Séance du lundi 14 mars 1791"
        normalize_session_title("Séance du lundi 18 octobre 1790 (2)").should == "Séance du lundi 18 octobre 1790"
        normalize_session_title("Séance du dimanche 12 mai 1793 . présidence de boyer-fonfrède, Président").should == "Séance du dimanche 12 mai 1793"
        normalize_session_title("Séance du dimanche 15 janvier 1792 PRÉSIDENCE DE M. DAVERHOULT (1)").should == "Séance du dimanche 15 janvier 1792"
        normalize_session_title("Séance du dimanche 22 septembre 1793 L'an II de la République française, une et indivisible").should == "Séance du dimanche 22 septembre 1793"
        normalize_session_title("Séance du jeudi 15 août 1793 l'an deuxième de la République française, une et indivisible").should == "Séance du jeudi 15 août 1793"
        normalize_session_title("Séance du dimanche 12 août 1792 . Suite de la séance permanente").should == "Séance du dimanche 12 août 1792"
        normalize_session_title("Dimanche 2 septembre 1792 ' Suite de la stance permanente").should == "Séance du dimanche 2 septembre 1792"
        normalize_session_title("Lundi 3 septembre 1792 Suite de la stance permanente").should == "Séance du lundi 3 septembre 1792"
        normalize_session_title("Séance du samedi 6 mars 1790, député dç BoUlogue-Sur-Mer, prête le serment patriotique qu'une absence forcée l'avait empêché de prêter Je 4 février").should == "Séance du samedi 6 mars 1790"
        normalize_session_title("Séance du dimanche 13 mai 1792 La séance est ouverte à 6 heures du soir. .1").should == "Séance du dimanche 13 mai 1792"
        normalize_session_title("Séance du dimanche 17 juillet 1791 La séance est ouverte à onze heures du malin").should == "Séance du dimanche 17 juillet 1791"
      end
      it "except 'au matin'" do
        normalize_session_title("Séance du 11 mai 1790, au matin (1)").should == "Séance du 11 mai 1790, au matin"
        normalize_session_title("Séance du 29 juillet 1790, au matin ( 1").should == "Séance du 29 juillet 1790, au matin"
        normalize_session_title("Séance du dimanche 23 octobre 1791, au matin. PRESIDENCE DE M. DUCASTEL").should == "Séance du dimanche 23 octobre 1791, au matin"
        normalize_session_title("Séance du jeudi 10 mars 1791, au matin (i").should == "Séance du jeudi 10 mars 1791, au matin"
        normalize_session_title("Séance du jeudi 11 mars 1790, au matin, (l)„").should == "Séance du jeudi 11 mars 1790, au matin"
        normalize_session_title("Séance du jeudi 13 mai 1790, au matin ,(1)").should == "Séance du jeudi 13 mai 1790, au matin"
        normalize_session_title("Séance du jeudi 14 juillet 1791, au matin (2)").should == "Séance du jeudi 14 juillet 1791, au matin"
        normalize_session_title("Séance du jeudi 22 avril 1790, au matin (Y").should == "Séance du jeudi 22 avril 1790, au matin"
        normalize_session_title("Séance du jeudi 9 juin 1791, au matin {1").should == "Séance du jeudi 9 juin 1791, au matin"
        normalize_session_title("Séance du lundi 15 juillet 1793, au matin.x").should == "Séance du lundi 15 juillet 1793, au matin"
        normalize_session_title("Séance du lundi 16 avril 1792, au matin. présidence de m. bigot de préameneu.-").should == "Séance du lundi 16 avril 1792, au matin"
        normalize_session_title("Séance du vendredi 21 septembre 1792, au matin tenue d'abord au chateau des Tuileries, puis a la salle du Man&amp;amp;ge, lieu ordinaire des Séancees de VAssembUe legislative").should == "Séance du vendredi 21 septembre 1792, au matin"
        normalize_session_title("Jeudi 16 août 1792, au matin. Suite de la séance permanente").should == "Séance du jeudi 16 août 1792, au matin"
        normalize_session_title("Séance du jeudi 20 mai 1790, au matin\\ 1").should == "Séance du jeudi 20 mai 1790, au matin"
        normalize_session_title("Séance du jeudi 3 février 1791 , au matin(1)").should == "Séance du jeudi 3 février 1791, au matin"
        normalize_session_title("Séance du jeudi 4 aout 1791, du 'mâtin (î").should == "Séance du jeudi 4 août 1791, au matin"
      end
      it "except 'au soir'" do
        normalize_session_title("Séance du 10 juin 1790, au soir (1)").should == "Séance du 10 juin 1790, au soir"
        normalize_session_title("Séance du dimanche 23 octobre 1791, au soir. PRESIDENCE DE M. DUCASTEL").should == "Séance du dimanche 23 octobre 1791, au soir"
        normalize_session_title("Séance du jeudi 10 décembre 1789, au soir (l").should == "Séance du jeudi 10 décembre 1789, au soir"
        normalize_session_title("Séance du jeudi 24 mars 1791, au soir(\\").should == "Séance du jeudi 24 mars 1791, au soir"
        normalize_session_title("Séance du jeudi 9 juin 1791, au soir (2)").should == "Séance du jeudi 9 juin 1791, au soir"
        normalize_session_title("Séance du lundi 17 juin 1793 . au soir. présidence de collot d'herbois, Président").should == "Séance du lundi 17 juin 1793, au soir"
        normalize_session_title("Séance du jeudi, 3 octobre 1798, au soir, l'an II de la République française une et indivisible").should == "Séance du jeudi 3 octobre 1798, au soir"
        normalize_session_title("Séance du lundi 17 septembre 1792, au soir. Suite de la séance permanente").should == "Séance du lundi 17 septembre 1792, au soir"
        normalize_session_title("Séance du lundi 24 octobre 1791, au soir. PRESIDENCE DE M. DUGASTEL").should == "Séance du lundi 24 octobre 1791, au soir"
        normalize_session_title("Séance du jeudi 13 juin 1793, au soir présidence de mallarmé").should == "Séance du jeudi 13 juin 1793, au soir"
        normalize_session_title("Séance du jeudi 24 mars 1791, au soir(\\").should == "Séance du jeudi 24 mars 1791, au soir"
        normalize_session_title("Séance du jeudi 29 septembre 1791, au soir( 1").should == "Séance du jeudi 29 septembre 1791, au soir"
        normalize_session_title("Séance du jeudi 4 août 1791, au soir(l").should == "Séance du jeudi 4 août 1791, au soir"
        normalize_session_title("Séance du mercredi 11 août 1790, au soir( 1").should == "Séance du mercredi 11 août 1790, au soir"
        normalize_session_title("Séance du samedi 18 septembre 1790, au soir (1), au soir (1)").should == "Séance du samedi 18 septembre 1790, au soir"
        normalize_session_title("Séance du jeudi 29 septembre 1791, au soir( 1").should == "Séance du jeudi 29 septembre 1791, au soir"
        normalize_session_title("Séance du jeudi 24 mars 1791, au soir(\\").should == "Séance du jeudi 24 mars 1791, au soir"
      end
    end
    
    it "should deal with annoying reality" do
      normalize_session_title('Séance,  du jeudi 17 septembre 1789,. au matin.').should == "Séance du jeudi 17 septembre 1789, au matin"
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