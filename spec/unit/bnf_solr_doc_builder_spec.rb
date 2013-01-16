require 'spec_helper'

describe BnfSolrDocBuilder do

  before(:all) do
    @fake_druid = 'oo000oo0000'
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
  end

  before(:each) do
    @hdor_client = double()
    @hdor_client.stub(:public_xml).with(@fake_druid).and_return(nil)
  end
  
  context "fields from /mods/titleInfo" do
    before(:all) do
      m = "<mods #{@ns_decl}>
      </mods>"
      # skip over Image fixe
      # keep estampe ->  document type; like doc type from AP
      @ng_mods = Nokogiri::XML(m)
    end
    before(:each) do
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods)      
      @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
    end

    m = "<mods #{@ns_decl}>
    <titleInfo>
        <title>Le Restaurateur embarass&#xE9; [Image fixe] : [estampe] / [non identifi&#xE9;]</title>
      </titleInfo>
      <titleInfo>
          <title>Duel au bois de Boulogne entre deux legislateurs MM Barnave et Cazales dans la matin&#xE9;e du 11 aoust 1790 [Image fixe] : les deux premiers coups partis sans effet, le sort accorda laprimaut&#xE9; a M. Barnave je serois d&#xE9;sol&#xE9; de vous tuer dit-il le coup part, frape au front M. Cazal&#xE8;s, la corne de son chapeau amortit le coup. M. Barnave avoit pour t&#xE9;moin M. Alex. la Meth et M. Cazal&#xE8;s M. S. Simon : [estampe] / [non identifi&#xE9;]</title>
      </titleInfo>
      <titleInfo>
          <title>M. Brignon [Image fixe] : cur&#xE9; de Dore-l'Eglise n&#xE9; &#xE0; Craponne en Languedoc en 1738 d&#xE9;put&#xE9; de Riom en Auvergne &#xE0; l'Assembl&#xE9;e nat.le de 1789 : [estampe] / Perrin del. . ; Courbe sc.</title>
        </titleInfo>
      <titleInfo>
          <title>Fusillades de Nantes [Image fixe] : [dessin] / [B&#xE9;ricourt]</title>
        </titleInfo>      
        <titleInfo>
          <title>[Exemplaires de l'Ami du Peuple tach&#xE9;s du sang de Marat] [Image fixe] / [non identifi&#xE9;]</title>
        </titleInfo>
        <titleInfo>
            <title>L.is Marie m.is d'Estourmel [Image fixe] : marechal de camp ez arm&#xE9;es du Roi commandeur de l'ordre ro.al mil.re et hosp.re de St Lasare n&#xE9; &#xE0; Susanne en Picardie le 11 mai 1744 d&#xE9;put&#xE9; de la noblesse du Cambr&#xE9;sis &#xE0; l'Assembl&#xE9;e nat.le de 1789 : [estampe] / Labadye del. . ; Courbe sc.</title>
          </titleInfo>
      <titleInfo>
          <title>M.L. Palmaert desservant de Mardyle [Image fixe] : ne a Petyan dans la Flandre Maritime en 1757 d&#xE9;put&#xE9; de Bailleul aux Etats g&#xE9;n&#xE9;r.x de 1789 : [estampe] / Labadye del. ; Le Tellier sculp.</title>
        </titleInfo>
    </mods>"

    context "facet (from 245e)" do
      
    end
    
    context "search (ignore 245def)" do
      
    end
    
    context "sort (ignore 245def)" do
      
    end

  end
  
end