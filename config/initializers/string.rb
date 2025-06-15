class String < Object
  ##
  # Use when write to IO stream is broken w/ exception like "Encoding::UndefinedConversionError: "\xE2" from ASCII-8BIT to UTF-8"
  def encode_to_utf8
    self.encode 'UTF-8', invalid: :replace, undef: :replace, replace: '?'
  end

  def encode_to_ascii
    self.encode 'ASCII', 'UTF-8', undef: :replace, replace: ' '
  end

  def uri
    URI(self)
  end

  def to_keyword_name
    self.class.sanitize_keyword_name(self)
  end

  def valid_keyword_name?
    self.class.valid_keyword_name?(self)
  end

  def to_sanitized_keyword_name
    self.class.sanitize_keyword_name(self)
  end

  WORD_BREAK_REGEXP = /[\s:()|\[\]\/,]+/ # other than \b

  def split_to_title_words
    self.split(WORD_BREAK_REGEXP).delete_if(&:blank?)
  end

  ##
  # General raw string wrapper of matching words
  # @options
  #   :prefix default ''
  #   :postfix default ''
  #   :word_break [Boolean] default false; pattern match must have word breaks around
  def wrap_matches(keywords_to_match, options= {})
    final_string = self.clone
    word_break = ( options[:word_break] == true )
    rcond = keywords_to_match.split_to_title_words.join('|')
    if word_break
      rcond = '\b(' + rcond + ')\b'
    else
      rcond = '(' + rcond + ')'
    end
    r = Regexp.new(rcond, Regexp::IGNORECASE)
    final_string.gsub(r, "#{options[:prefix]}\\1#{options[:postfix]}")
  end

  def word_combos
    combos = [self]
    words = split_to_title_words
    0.upto(words.size - 1) do|starting_i|
      next if words[starting_i].match( /\A\W+/i )
      0.upto(words.size - starting_i - 1) do|add_i|
        next if words[starting_i + add_i].match(/\A\W+/)
        combos << words[starting_i..(starting_i + add_i)].join(' ')
      end
    end
    combos
  end

  EMAIL_REGEXP = /\b([^@\.]|[^@\.]([^@\s]*)[^@\.])@([^@\s]+\.)+[^@\s]+\b/

  def valid_email?
    self =~ EMAIL_REGEXP
  end

  PHONE_NUMBER_REGEXP = /\b(\+)?(\d{2,3}[\s\-]*)?\d{3}[\s\-]*\d{3,4}[\s\-]?\d{4}\b/

  ##
  # Minimize multiple spaces in between characters.
  def compact
    return '' if blank?
    self.strip.gsub(/[^\.]([\s]{2,})/, ' ')
  end

  ##
  # Downcase, strip, compact in between spaces.  This way is easier to compare words only.
  # @return <String> stripped version
  def strip_naked
    return '' if blank?
    self.downcase.strip.gsub(/[^\.]([\s]{2,})/, ' ')
  end

  ##
  # More than strip_naked: downcase, strip non-alphanumeric characters, compact and undscore spaces.
  def to_underscore_id
    self.downcase.gsub(/([\W_]+)/, ' ').strip.compact.gsub(/([\s_]+)/, '_' )
  end

  ##
  # Count of replacement character would be @total_count_of_characters - 2
  def censored_middle(total_count_of_characters = 6, replacement_character = '*')
    # Ensure that count_of_replace is not negative
    count_of_replace = [0, [total_count_of_characters - 2, self.size - 2].min].max

    # Handling for strings shorter than 3 characters to avoid index out of bounds
    if self.size <= 2
      self # Return the string as is if it's too short to be censored
    else
      # Construct the censored string
      [self[0], replacement_character * count_of_replace, self[-1]].join('')
    end
  end

  def censor_email(email, replacement_character = '*')
    # Split the email into local part and domain part
    local, domain = email.split('@')

    # Check if the local part has enough characters to be censored
    if local.size <= 2
      email # Return the email as is if the local part is too short to be censored
    else
      # Determine the number of characters to replace
      count_of_replace = [0, [local.size - 2, 6].min].max

      # Build the censored local part
      censored_local = [local[0], replacement_character * count_of_replace, local[-1]].join('')

      # Combine the censored local part with the domain
      "#{censored_local}@#{domain}"
    end
  end

  COUNTRY_CODES = {
    'AF'=>'Afghanistan',
    'AL'=>'Albania',
    'DZ'=>'Algeria',
    'AS'=>'American Samoa',
    'AD'=>'Andorra',
    'AO'=>'Angola',
    'AI'=>'Anguilla',
    'AQ'=>'Antarctica',
    'AG'=>'Antigua And Barbuda',
    'AR'=>'Argentina',
    'AM'=>'Armenia',
    'AW'=>'Aruba',
    'AU'=>'Australia',
    'AT'=>'Austria',
    'AZ'=>'Azerbaijan',
    'BS'=>'Bahamas',
    'BH'=>'Bahrain',
    'BD'=>'Bangladesh',
    'BB'=>'Barbados',
    'BY'=>'Belarus',
    'BE'=>'Belgium',
    'BZ'=>'Belize',
    'BJ'=>'Benin',
    'BM'=>'Bermuda',
    'BT'=>'Bhutan',
    'BO'=>'Bolivia',
    'BA'=>'Bosnia And Herzegovina',
    'BW'=>'Botswana',
    'BV'=>'Bouvet Island',
    'BR'=>'Brazil',
    'IO'=>'British Indian Ocean Territory',
    'BN'=>'Brunei',
    'BG'=>'Bulgaria',
    'BF'=>'Burkina Faso',
    'BI'=>'Burundi',
    'KH'=>'Cambodia',
    'CM'=>'Cameroon',
    'CA'=>'Canada',
    'CV'=>'Cape Verde',
    'KY'=>'Cayman Islands',
    'CF'=>'Central African Republic',
    'TD'=>'Chad',
    'CL'=>'Chile',
    'CN'=>'China',
    'CX'=>'Christmas Island',
    'CC'=>'Cocos (Keeling) Islands',
    'CO'=>'Columbia',
    'KM'=>'Comoros',
    'CG'=>'Congo',
    'CK'=>'Cook Islands',
    'CR'=>'Costa Rica',
    'CI'=>'Cote D\'Ivorie (Ivory Coast)',
    'HR'=>'Croatia (Hrvatska)',
    'CU'=>'Cuba',
    'CY'=>'Cyprus',
    'CZ'=>'Czech Republic',
    'CD'=>'Democratic Republic Of Congo (Zaire)',
    'DK'=>'Denmark',
    'DJ'=>'Djibouti',
    'DM'=>'Dominica',
    'DO'=>'Dominican Republic',
    'TP'=>'East Timor',
    'EC'=>'Ecuador',
    'EG'=>'Egypt',
    'SV'=>'El Salvador',
    'GQ'=>'Equatorial Guinea',
    'ER'=>'Eritrea',
    'EE'=>'Estonia',
    'ET'=>'Ethiopia',
    'FK'=>'Falkland Islands (Malvinas)',
    'FO'=>'Faroe Islands',
    'FJ'=>'Fiji',
    'FI'=>'Finland',
    'FR'=>'France',
    'FX'=>'France, Metropolitan',
    'GF'=>'French Guinea',
    'PF'=>'French Polynesia',
    'TF'=>'French Southern Territories',
    'GA'=>'Gabon',
    'GM'=>'Gambia',
    'GE'=>'Georgia',
    'DE'=>'Germany',
    'GH'=>'Ghana',
    'GI'=>'Gibraltar',
    'GR'=>'Greece',
    'GL'=>'Greenland',
    'GD'=>'Grenada',
    'GP'=>'Guadeloupe',
    'GU'=>'Guam',
    'GT'=>'Guatemala',
    'GN'=>'Guinea',
    'GW'=>'Guinea-Bissau',
    'GY'=>'Guyana',
    'HT'=>'Haiti',
    'HM'=>'Heard And McDonald Islands',
    'HN'=>'Honduras',
    'HK'=>'Hong Kong',
    'HU'=>'Hungary',
    'IS'=>'Iceland',
    'IN'=>'India',
    'ID'=>'Indonesia',
    'IR'=>'Iran',
    'IQ'=>'Iraq',
    'IE'=>'Ireland',
    'IL'=>'Israel',
    'IT'=>'Italy',
    'JM'=>'Jamaica',
    'JP'=>'Japan',
    'JO'=>'Jordan',
    'KZ'=>'Kazakhstan',
    'KE'=>'Kenya',
    'KI'=>'Kiribati',
    'KW'=>'Kuwait',
    'KG'=>'Kyrgyzstan',
    'LA'=>'Laos',
    'LV'=>'Latvia',
    'LB'=>'Lebanon',
    'LS'=>'Lesotho',
    'LR'=>'Liberia',
    'LY'=>'Libya',
    'LI'=>'Liechtenstein',
    'LT'=>'Lithuania',
    'LU'=>'Luxembourg',
    'MO'=>'Macau',
    'MK'=>'Macedonia',
    'MG'=>'Madagascar',
    'MW'=>'Malawi',
    'MY'=>'Malaysia',
    'MV'=>'Maldives',
    'ML'=>'Mali',
    'MT'=>'Malta',
    'MH'=>'Marshall Islands',
    'MQ'=>'Martinique',
    'MR'=>'Mauritania',
    'MU'=>'Mauritius',
    'YT'=>'Mayotte',
    'MX'=>'Mexico',
    'FM'=>'Micronesia',
    'MD'=>'Moldova',
    'MC'=>'Monaco',
    'MN'=>'Mongolia',
    'MS'=>'Montserrat',
    'MA'=>'Morocco',
    'MZ'=>'Mozambique',
    'MM'=>'Myanmar (Burma)',
    'NA'=>'Namibia',
    'NR'=>'Nauru',
    'NP'=>'Nepal',
    'NL'=>'Netherlands',
    'AN'=>'Netherlands Antilles',
    'NC'=>'New Caledonia',
    'NZ'=>'New Zealand',
    'NI'=>'Nicaragua',
    'NE'=>'Niger',
    'NG'=>'Nigeria',
    'NU'=>'Niue',
    'NF'=>'Norfolk Island',
    'KP'=>'North Korea',
    'MP'=>'Northern Mariana Islands',
    'NO'=>'Norway',
    'OM'=>'Oman',
    'PK'=>'Pakistan',
    'PW'=>'Palau',
    'PA'=>'Panama',
    'PG'=>'Papua New Guinea',
    'PY'=>'Paraguay',
    'PE'=>'Peru',
    'PH'=>'Philippines',
    'PN'=>'Pitcairn',
    'PL'=>'Poland',
    'PT'=>'Portugal',
    'PR'=>'Puerto Rico',
    'QA'=>'Qatar',
    'RE'=>'Reunion',
    'RO'=>'Romania',
    'RU'=>'Russia',
    'RW'=>'Rwanda',
    'SH'=>'Saint Helena',
    'KN'=>'Saint Kitts And Nevis',
    'LC'=>'Saint Lucia',
    'PM'=>'Saint Pierre And Miquelon',
    'VC'=>'Saint Vincent And The Grenadines',
    'SM'=>'San Marino',
    'ST'=>'Sao Tome And Principe',
    'SA'=>'Saudi Arabia',
    'SN'=>'Senegal',
    'SC'=>'Seychelles',
    'SL'=>'Sierra Leone',
    'SG'=>'Singapore',
    'SK'=>'Slovak Republic',
    'SI'=>'Slovenia',
    'SB'=>'Solomon Islands',
    'SO'=>'Somalia',
    'ZA'=>'South Africa',
    'GS'=>'South Georgia And South Sandwich Islands',
    'KR'=>'South Korea',
    'ES'=>'Spain',
    'LK'=>'Sri Lanka',
    'SD'=>'Sudan',
    'SR'=>'Suriname',
    'SJ'=>'Svalbard And Jan Mayen',
    'SZ'=>'Swaziland',
    'SE'=>'Sweden',
    'CH'=>'Switzerland',
    'SY'=>'Syria',
    'TW'=>'Taiwan',
    'TJ'=>'Tajikistan',
    'TZ'=>'Tanzania',
    'TH'=>'Thailand',
    'TG'=>'Togo',
    'TK'=>'Tokelau',
    'TO'=>'Tonga',
    'TT'=>'Trinidad And Tobago',
    'TN'=>'Tunisia',
    'TR'=>'Turkey',
    'TM'=>'Turkmenistan',
    'TC'=>'Turks And Caicos Islands',
    'TV'=>'Tuvalu',
    'UG'=>'Uganda',
    'UA'=>'Ukraine',
    'AE'=>'United Arab Emirates',
    'UK'=>'United Kingdom',
    'US'=>'United States',
    'UM'=>'United States Minor Outlying Islands',
    'UY'=>'Uruguay',
    'UZ'=>'Uzbekistan',
    'VU'=>'Vanuatu',
    'VA'=>'Vatican City (Holy See)',
    'VE'=>'Venezuela',
    'VN'=>'Vietnam',
    'VG'=>'Virgin Islands (British)',
    'VI'=>'Virgin Islands (US)',
    'WF'=>'Wallis And Futuna Islands',
    'EH'=>'Western Sahara',
    'WS'=>'Western Samoa',
    'YE'=>'Yemen',
    'YU'=>'Yugoslavia',
    'ZM'=>'Zambia',
    'ZW'=>'Zimbabwe'
  }

  def to_country_code
    COUNTRY_CODES.key(self.titleize)
  end


  ##
  # Class methods

  REDUNDANT_PREFIXES_REGEXP = /^(a|available|about|applicable|appropriate|choose|chosen|for|get|with|the|suggeste?d?|product|item)\b/i

  def self.sanitize_keyword_name(name = '')
    name.gsub(REDUNDANT_PREFIXES_REGEXP, '').split(':').first.to_s.gsub(/([()\[\],"]+)/, '').strip
  end


end
