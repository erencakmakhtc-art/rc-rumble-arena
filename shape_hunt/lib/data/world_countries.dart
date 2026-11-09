/// Kayit ekranindaki ulke secimi icin genis liste.
///
/// Her ulke: ISO kodu -> (Turkce ad, emoji bayrak). Emoji bayraklar
/// bolge-gosterge harflerinden olusur ve neredeyse tum platformlarda
/// dogru render edilir; boylece 190+ ulkeyi elle bayrak cizmeden
/// listeleyebiliyoruz.
///
/// NOT: Skor tablosundaki 9 ozel-cizim bayrakli ulke (countries.dart)
/// ayri durur; orasi mock veri icindir. Burasi kullanicinin kendi
/// ulkesini sectigi tam listedir.
class WorldCountry {
  final String code;
  final String name;
  final String flag;
  const WorldCountry(this.code, this.name, this.flag);
}

/// Iki harfli ulke kodundan emoji bayrak uretir (TR -> Turkiye bayragi).
String flagEmoji(String code) {
  if (code.length != 2) return '🏳️';
  const base = 0x1F1E6; // regional indicator 'A'
  final cc = code.toUpperCase();
  final a = base + (cc.codeUnitAt(0) - 65);
  final b = base + (cc.codeUnitAt(1) - 65);
  return String.fromCharCode(a) + String.fromCharCode(b);
}

/// Turkce ada gore siralanmis genis ulke listesi.
final List<WorldCountry> kWorldCountries = () {
  final list = _raw.entries.map((e) => WorldCountry(e.key, e.value, flagEmoji(e.key))).toList();
  list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
}();

WorldCountry? worldCountryOf(String? code) {
  if (code == null) return null;
  for (final c in kWorldCountries) {
    if (c.code == code) return c;
  }
  return null;
}

const Map<String, String> _raw = {
  'AF': 'Afganistan', 'DE': 'Almanya', 'US': 'ABD', 'AD': 'Andorra', 'AO': 'Angola',
  'AG': 'Antigua ve Barbuda', 'AR': 'Arjantin', 'AL': 'Arnavutluk', 'AZ': 'Azerbaycan',
  'AU': 'Avustralya', 'AT': 'Avusturya', 'BS': 'Bahamalar', 'BH': 'Bahreyn',
  'BD': 'Bangladeş', 'BB': 'Barbados', 'BE': 'Belçika', 'BZ': 'Belize', 'BJ': 'Benin',
  'BY': 'Belarus', 'BT': 'Butan', 'BO': 'Bolivya', 'BA': 'Bosna-Hersek',
  'BW': 'Botsvana', 'BR': 'Brezilya', 'BN': 'Brunei', 'BG': 'Bulgaristan',
  'BF': 'Burkina Faso', 'BI': 'Burundi', 'CV': 'Cabo Verde', 'DZ': 'Cezayir',
  'CZ': 'Çekya', 'CN': 'Çin', 'DJ': 'Cibuti', 'TD': 'Çad', 'DK': 'Danimarka',
  'DO': 'Dominik Cumhuriyeti', 'DM': 'Dominika', 'EC': 'Ekvador',
  'GQ': 'Ekvator Ginesi', 'SV': 'El Salvador', 'ID': 'Endonezya', 'ER': 'Eritre',
  'AM': 'Ermenistan', 'EE': 'Estonya', 'ET': 'Etiyopya', 'FJ': 'Fiji',
  'CI': 'Fildişi Sahili', 'PH': 'Filipinler', 'FI': 'Finlandiya', 'FR': 'Fransa',
  'GA': 'Gabon', 'GM': 'Gambiya', 'GH': 'Gana', 'GN': 'Gine', 'GW': 'Gine-Bissau',
  'GD': 'Grenada', 'GT': 'Guatemala', 'GY': 'Guyana', 'ZA': 'Güney Afrika',
  'KR': 'Güney Kore', 'SS': 'Güney Sudan', 'GE': 'Gürcistan', 'HT': 'Haiti',
  'IN': 'Hindistan', 'HR': 'Hırvatistan', 'NL': 'Hollanda', 'HN': 'Honduras',
  'IQ': 'Irak', 'GB': 'İngiltere', 'IR': 'İran', 'IE': 'İrlanda', 'ES': 'İspanya',
  'IL': 'İsrail', 'SE': 'İsveç', 'CH': 'İsviçre', 'IT': 'İtalya', 'IS': 'İzlanda',
  'JM': 'Jamaika', 'JP': 'Japonya', 'KH': 'Kamboçya', 'CM': 'Kamerun',
  'CA': 'Kanada', 'ME': 'Karadağ', 'QA': 'Katar', 'KZ': 'Kazakistan', 'KE': 'Kenya',
  'CY': 'Kıbrıs', 'KG': 'Kırgızistan', 'KI': 'Kiribati', 'CO': 'Kolombiya',
  'KM': 'Komorlar', 'CG': 'Kongo', 'CD': 'Demokratik Kongo', 'CR': 'Kosta Rika',
  'XK': 'Kosova', 'KW': 'Kuveyt', 'KP': 'Kuzey Kore', 'MK': 'Kuzey Makedonya',
  'CU': 'Küba', 'LA': 'Laos', 'LS': 'Lesotho', 'LV': 'Letonya', 'LR': 'Liberya',
  'LY': 'Libya', 'LI': 'Lihtenştayn', 'LT': 'Litvanya', 'LB': 'Lübnan',
  'LU': 'Lüksemburg', 'HU': 'Macaristan', 'MG': 'Madagaskar', 'MW': 'Malavi',
  'MV': 'Maldivler', 'MY': 'Malezya', 'ML': 'Mali', 'MT': 'Malta', 'MA': 'Fas',
  'MH': 'Marshall Adaları', 'MX': 'Meksika', 'EG': 'Mısır', 'FM': 'Mikronezya',
  'MD': 'Moldova', 'MC': 'Monako', 'MN': 'Moğolistan', 'MR': 'Moritanya',
  'MU': 'Mauritius', 'MZ': 'Mozambik', 'MM': 'Myanmar', 'NA': 'Namibya',
  'NR': 'Nauru', 'NP': 'Nepal', 'NE': 'Nijer', 'NG': 'Nijerya', 'NI': 'Nikaragua',
  'NO': 'Norveç', 'CF': 'Orta Afrika Cumhuriyeti', 'UZ': 'Özbekistan',
  'PK': 'Pakistan', 'PW': 'Palau', 'PA': 'Panama', 'PG': 'Papua Yeni Gine',
  'PY': 'Paraguay', 'PE': 'Peru', 'PL': 'Polonya', 'PT': 'Portekiz', 'RO': 'Romanya',
  'RW': 'Ruanda', 'RU': 'Rusya', 'WS': 'Samoa', 'SM': 'San Marino',
  'ST': 'Sao Tome ve Principe', 'SN': 'Senegal', 'SC': 'Seyşeller', 'RS': 'Sırbistan',
  'SL': 'Sierra Leone', 'SG': 'Singapur', 'SK': 'Slovakya', 'SI': 'Slovenya',
  'SB': 'Solomon Adaları', 'SO': 'Somali', 'LK': 'Sri Lanka', 'SD': 'Sudan',
  'SR': 'Surinam', 'SA': 'Suudi Arabistan', 'SY': 'Suriye', 'CL': 'Şili',
  'TJ': 'Tacikistan', 'TZ': 'Tanzanya', 'TH': 'Tayland', 'TW': 'Tayvan',
  'TG': 'Togo', 'TO': 'Tonga', 'TT': 'Trinidad ve Tobago', 'TN': 'Tunus',
  'TR': 'Türkiye', 'TM': 'Türkmenistan', 'TV': 'Tuvalu', 'UG': 'Uganda',
  'UA': 'Ukrayna', 'OM': 'Umman', 'UY': 'Uruguay', 'JO': 'Ürdün', 'VU': 'Vanuatu',
  'VA': 'Vatikan', 'VE': 'Venezuela', 'VN': 'Vietnam', 'YE': 'Yemen',
  'NZ': 'Yeni Zelanda', 'GR': 'Yunanistan', 'ZM': 'Zambiya', 'ZW': 'Zimbabve',
};
