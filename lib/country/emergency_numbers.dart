class EmergencyNumbers {
  EmergencyNumbers._();

  /// 默认急救号码（未匹配到国家编码时返回）
  static const String defaultNumber = '000';

  /// 国家编码 -> 急救电话 映射表
  static const Map<String, String> _data = {
    'AF': '112',   // Afghanistan
    'AL': '127',   // Albania
    'DZ': '14',    // Algeria
    'AS': '911',   // American Samoa
    'AD': '116',   // Andorra
    'AO': '112',   // Angola
    'AI': '911',   // Anguilla
    'AR': '911',   // Argentina
    'AM': '112',   // Armenia
    'AW': '911',   // Aruba
    'AU': '000',   // Australia
    'AT': '144',   // Austria
    'AZ': '103',   // Azerbaijan
    'BH': '999',   // Bahrain
    'BD': '999',   // Bangladesh
    'BB': '911',   // Barbados
    'BY': '103',   // Belarus
    'BE': '112',   // Belgium
    'BZ': '911',   // Belize
    'BJ': '112',   // Benin
    'BM': '911',   // Bermuda
    'BT': '112',   // Bhutan
    'BO': '911',   // Bolivia
    'BA': '124',   // Bosnia and Herzegovina
    'BW': '997',   // Botswana
    'BR': '192',   // Brazil
    'BN': '991',   // Brunei
    'BG': '112',   // Bulgaria
    'BF': '112',   // Burkina Faso
    'BI': '112',   // Burundi
    'KH': '119',   // Cambodia
    'CM': '119',   // Cameroon
    'CA': '911',   // Canada
    'CV': '130',   // Cape Verde
    'KY': '911',   // Cayman Islands
    'CF': '1220',  // Central African Republic
    'TD': '2251-4242', // Chad
    'CL': '131',   // Chile
    'CN': '120',   // China
    'CO': '123',   // Colombia
    'KM': '772-03-73', // Comoros
    'CK': '998',   // Cook Islands
    'CR': '911',   // Costa Rica
    'HR': '194',   // Croatia
    'CU': '104',   // Cuba
    'CY': '112',   // Cyprus
    'CZ': '155',   // Czech Republic
    'DK': '112',   // Denmark
    'DJ': '19',    // Djibouti
    'DM': '999',   // Dominica
    'DO': '911',   // Dominican Republic
    'EC': '911',   // Ecuador
    'EG': '123',   // Egypt
    'SV': '132',   // El Salvador
    'GQ': '115',   // Equatorial Guinea
    'ER': '114',   // Eritrea
    'EE': '112',   // Estonia
    'ET': '911',   // Ethiopia
    'FK': '112',   // Falkland Islands
    'FO': '112',   // Faroe Islands
    'FI': '112',   // Finland
    'FR': '15',    // France
    'GF': '112',   // French Guiana
    'PF': '112',   // French Polynesia
    'GA': '1300',  // Gabon
    'GE': '112',   // Georgia
    'DE': '112',   // Germany
    'GH': '193',   // Ghana
    'GI': '190',   // Gibraltar
    'GR': '166',   // Greece
    'GL': '112',   // Greenland
    'GD': '911',   // Grenada
    'GP': '112',   // Guadeloupe
    'GU': '911',   // Guam
    'GT': '128',   // Guatemala
    'GN': '18',    // Guinea
    'GW': '119',   // Guinea-Bissau
    'GY': '999',   // Guyana
    'HT': '116',   // Haiti
    'HN': '195',   // Honduras
    'HU': '104',   // Hungary
    'IS': '112',   // Iceland
    'IN': '112',   // India
    'ID': '112',   // Indonesia
    'IR': '115',   // Iran
    'IQ': '122',   // Iraq
    'IE': '999',   // Ireland
    'IL': '101',   // Israel
    'IT': '112',   // Italy
    'JM': '110',   // Jamaica
    'JP': '119',   // Japan
    'JO': '911',   // Jordan
    'KZ': '112',   // Kazakhstan
    'KE': '112',   // Kenya
    'KI': '999',   // Kiribati
    'KW': '112',   // Kuwait
    'KG': '103',   // Kyrgyzstan
    'LA': '195',   // Laos
    'LV': '112',   // Latvia
    'LB': '140',   // Lebanon
    'LS': '121',   // Lesotho
    'LR': '911',   // Liberia
    'LY': '193',   // Libya
    'LI': '144',   // Liechtenstein
    'LT': '112',   // Lithuania
    'LU': '113',   // Luxembourg
    'MG': '124',   // Madagascar
    'MW': '998',   // Malawi
    'MY': '994',   // Malaysia
    'MV': '102',   // Maldives
    'ML': '15',    // Mali
    'MT': '112',   // Malta
    'MH': '911',   // Marshall Islands
    'MQ': '112',   // Martinique
    'MR': '101',   // Mauritania
    'MU': '114',   // Mauritius
    'YT': '112',   // Mayotte
    'MX': '911',   // Mexico
    'FM': '911',   // Micronesia
    'MD': '112',   // Moldova
    'MC': '15',    // Monaco
    'MN': '105',   // Mongolia
    'ME': '124',   // Montenegro
    'MS': '911',   // Montserrat
    'MA': '15',    // Morocco
    'MZ': '117',   // Mozambique
    'MM': '999',   // Myanmar
    'NA': '211111', // Namibia
    'NR': '111',   // Nauru
    'NP': '102',   // Nepal
    'NL': '112',   // Netherlands
    'NC': '112',   // New Caledonia
    'NZ': '111',   // New Zealand
    'NI': '128',   // Nicaragua
    'NE': '15',    // Niger
    'NG': '112',   // Nigeria
    'KP': '119',   // North Korea
    'NO': '113',   // Norway
    'OM': '9999',  // Oman
    'PK': '115',   // Pakistan
    'PW': '911',   // Palau
    'PA': '911',   // Panama
    'PY': '911',   // Paraguay
    'PE': '911',   // Peru
    'PH': '911',   // Philippines
    'PL': '999',   // Poland
    'PT': '112',   // Portugal
    'PR': '911',   // Puerto Rico
    'QA': '999',   // Qatar
    'RE': '15',    // Reunion
    'RO': '112',   // Romania
    'RU': '103',   // Russia
    'RW': '912',   // Rwanda
    'LC': '911',   // Saint Lucia
    'PM': '112',   // Saint Pierre and Miquelon
    'WS': '999',   // Samoa
    'SM': '118',   // San Marino
    'ST': '112',   // Sao Tome and Principe
    'SA': '911',   // Saudi Arabia
    'SN': '18',    // Senegal
    'RS': '194',   // Serbia
    'SC': '151',   // Seychelles
    'SL': '999',   // Sierra Leone
    'SG': '995',   // Singapore
    'SK': '155',   // Slovakia
    'SI': '112',   // Slovenia
    'SB': '911',   // Solomon Islands
    'SO': '999',   // Somalia
    'ZA': '10 177', // South Africa
    'KR': '119',   // South Korea
    'SS': '999',   // South Sudan
    'ES': '112',   // Spain
    'LK': '110',   // Sri Lanka
    'SD': '999',   // Sudan
    'SR': '115',   // Suriname
    'SE': '112',   // Sweden
    'CH': '144',   // Switzerland
    'SY': '110',   // Syria
    'TW': '119',   // Taiwan
    'TJ': '112',   // Tajikistan
    'TZ': '114',   // Tanzania
    'TH': '1669',  // Thailand
    'TG': '8200',  // Togo
    'TO': '911',   // Tonga
    'TN': '198',   // Tunisia
    'TR': '112',   // Turkey
    'TM': '112',   // Turkmenistan
    'TV': '911',   // Tuvalu
    'UG': '911',   // Uganda
    'AE': '999',   // United Arab Emirates
    'GB': '999',   // United Kingdom
    'US': '911',   // United States
    'UY': '911',   // Uruguay
    'UZ': '101',   // Uzbekistan
    'VU': '911',   // Vanuatu
    'VE': '171',   // Venezuela
    'EH': '150',   // Western Sahara
    'YE': '191',   // Yemen
    'ZM': '992',   // Zambia
    'ZW': '994',   // Zimbabwe
    'HK': '999'
  };

  /// 根据国家编码获取急救电话号码
  ///
  /// [countryCode] ISO 3166-1 alpha-2 国家编码，如 'CN', 'US', 'JP'
  /// 大小写不敏感
  ///
  /// 返回对应的急救电话号码，未找到时返回 [defaultNumber] (000)
  ///
  /// 示例:
  /// ```dart
  /// EmergencyNumbers.getNumber('CN');  // '120'
  /// EmergencyNumbers.getNumber('us');  // '911'
  /// EmergencyNumbers.getNumber('XY');  // '000' (默认)
  /// ```
  static String getNumber(String countryCode) {
    return _data[countryCode.toUpperCase()] ?? defaultNumber;
  }

  /// 根据国家编码获取急救电话号码，未找到时返回 null
  ///
  /// [countryCode] ISO 3166-1 alpha-2 国家编码
  static String? getNumberOrNull(String countryCode) {
    return _data[countryCode.toUpperCase()];
  }

  /// 检查是否存在该国家编码的急救电话数据
  static bool hasCountry(String countryCode) {
    return _data.containsKey(countryCode.toUpperCase());
  }

  /// 获取所有支持的国家编码列表
  static List<String> get supportedCountryCodes => _data.keys.toList();
}