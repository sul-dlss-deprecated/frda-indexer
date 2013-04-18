# encoding: UTF-8

module NormalizationHelper
  
  # turns the String representation of the date to a Date object.  
  #  Logs a warning message if it can't parse the date string.
  # @param [String] date_str a String representation of a date
  # @return [Date] a Date object
  def normalize_date date_str
    begin
      norm_date = date_str.gsub(/ +\- +/, '-')
      norm_date.gsub!(/-00$/, '-01')
      norm_date.concat('-01-01') if norm_date.match(/^\d{4}$/)
      norm_date.concat('-01') if norm_date.match(/^\d{4}\-\d{2}$/)
      Date.parse(norm_date)
    rescue
      @logger.warn("Found <date> tag with unparseable date value: '#{date_str}' in page #{page_doc_hash[:id]}") if @in_body || @in_back
      nil
    end
  end

  # normalize the session title (date) text by 
  #  removing trailing and leading chars
  #  changing any " , "  to ", "
  #  changing "Stance" to "Séance"
  #  changing "Seance" to "Séance"
  def normalize_session_title session_title
    remove_trailing_and_leading_characters session_title
    # outer parens
    session_title.gsub! /\A\(/, ''
    session_title.gsub!(/\)\z/, '') if !session_title.match(/\(\d\)\z/) 
    remove_trailing_and_leading_characters session_title
    session_title.gsub! /\A[-]/, ''   # more leading chars
    session_title.gsub! /[*"]\z/, ''   # more trailing chars
    remove_trailing_and_leading_characters session_title
    session_title.gsub! /\s,\s/, ', '
    # 'Séance' 
    session_title.gsub! /\AS[éeèêdt][aâd][nm][cçdeèot][çeéèê]/i, 'Séance' # 6 letter variants
    session_title.gsub! /\AS[eé]a?nc?[eèé]/i, 'Séance'  # 5 letter variants corrected
    session_title.gsub! 'seanc', 'Séance'  # 5 letter variants corrected
    session_title.gsub! 'Sèattdé', 'Séance'
    session_title.gsub! 'Séan ce', 'Séance'
    session_title.gsub! 'Sécthôè', 'Séance'
    session_title.gsub! 'Séyripe', 'Séance'
    # skip ahead to 'Séance' if it starts 'présidence'
    session_title.gsub! /\APrésidence.*Séance/i, 'Séance'
    # Séance du
    session_title.gsub! /\ASéance,? [daâ][uûa]/, 'Séance du'
    session_title.gsub! /\ASéance du[\.\-,] /, 'Séance du '
    session_title.gsub! /\ASéance du \. /, 'Séance du '
    session_title.gsub! /\ASéance dit /, 'Séance du '
    # days of the week
    session_title.gsub! /\ASéance du lu[nh]di/i, 'Séance du lundi'
    session_title.gsub! /\ASéance du ?ma[rt]?di/i, 'Séance du mardi'
    session_title.gsub! /\ASéance du mer[ce]r?redi/i, 'Séance du mercredi'
    session_title.gsub! /\ASéance du [hij][eèi][un]dis?/i, 'Séance du jeudi'
    session_title.gsub! /\ASéance du vendrc?[eè]dia?/i, 'Séance du vendredi'
    session_title.gsub! /\ASéance du samedi?/i, 'Séance du samedi'
    session_title.gsub! 'Séance du saniedi', 'Séance du samedi'
    session_title.gsub! 'Séance du smaedi', 'Séance du samedi'
    session_title.gsub! 'Séance du ssamedi', 'Séance du samedi'
    session_title.gsub! /\ASéance du di(rn|m)an[cp]he/i, 'Séance du dimanche'
    # adjust if it starts with a day of the week
    session_title.gsub! /\ADimanche/i, 'Séance du dimanche'
    session_title.gsub! /\ALundi/i, 'Séance du lundi'
    session_title.gsub! /\AMardi/i, 'Séance du mardi'
    session_title.gsub! /\AMercredi/i, 'Séance du mercredi'
    session_title.gsub! /\AJeudi/i, 'Séance du jeudi'
    session_title.gsub! /\AVendredi/i, 'Séance du vendredi'
    session_title.gsub! /\ASamedi/i, 'Séance du samedi'
    # separate digits smashed against day of the week
    session_title.gsub! /\ASéance du (lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche)(\d)/i, 'Séance du \1 \2'
    # au matin
    session_title.gsub! /(.*?) [',\. \*\[]*([dao][uùwy][\.]? ?[\*']?m[aâàdu][lt]i[nf]).*/i, '\1 au matin'
    # au soir
    session_title.gsub! /(.*?) [',\. \*\[]*([dao][uùwy][\.]? ?[slv$][odàù0][iîfl][rft\?]).*/i, '\1 au soir'
    session_title.gsub! /(.*?) (au ?snr).*/i, '\1 au soir'
    # 3 letter OCR for au
    session_title.gsub! /(.*?) [alo][euit][ufilt] (matin|soir)/i, '\1 au \2'
    # remove anything after the year, unless it's au matin or au soir
    if session_title.match(/(.*\d{4}[,\.]* (au matin|au soir)).*/i)
      session_title.gsub! /(.*?\d{4}[,\.]* (au matin|au soir)).*/i, '\1'
    else
      session_title.gsub! /(.*\d{4}).*/i, '\1'
    end
    # normalize remaing whitespace
    session_title.gsub! /\s+/, ' '
    session_title
  end
  
  def normalize_speaker name
    remove_trailing_and_leading_characters(name) # first pass
    name.sub! /\Am{1,2}'?[. -;]/i,'' # lop off beginning m and mm type cases (case insensitive) and other random bits of characters
    name.sub! /\s*[\-]\s*/,'-' # remove spaces around hyphens
    name.sub! /[d][']\s+/,"d'" # remove spaces after d'
    name.gsub! '1e','Le' # flip a 1e to Le
    remove_trailing_and_leading_characters(name) # second pass after other normalizations
    name[0]=name[0].capitalize # capitalize first letter
    name.sub! /\AL\'?abb[eé]/i, "L'abbé"
    name="Le Président" if president_alternates.include?(name) # this should come last so we complete all other normalization
    return name
  end
  
  def president_alternates
      [
        "Le President",
        "Le président",
        "Le Preésident",
        "Le Préesident",                
        "Le Président Sieyès",
        "Le Président de La Houssaye",
        "Le Président répond",
        "Le Présldent",
        "Le' Président",
        "Le-Président",
        "Le Présidant",
        "Le Présiden",
        "Le Présidtent",
        "Le Présidènt",
        "La Président",
        "Président",
      ]
  end  
  
  def remove_trailing_and_leading_characters name
    name.strip! # strip leading and trailing spaces
    name.sub! /\A['\(\)><«\.:,]+/, '' # lop off any beginning periods, colons, commas and other special characters
    name.sub! /[\.,:]+\z/, '' # lop off any ending periods, colons or commas
    name.strip!
    name
  end
end
