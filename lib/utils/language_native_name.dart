/// 把后端返回的英文语言名（如 "Chinese"）映射为该语言本身的文字（如 "中文"）。
///
/// 后端 `Language.language` 返回的是英文名称；在面向用户的选择列表里更友好的是
/// 显示语言自身的写法。未命中映射时回退为原始英文名，保证不丢内容。
String nativeLanguageName(String? englishName) {
  if (englishName == null) return '';
  final name = englishName.trim();
  return _nativeNames[name.toLowerCase()] ?? name;
}

const Map<String, String> _nativeNames = {
  'english': 'English',
  'chinese': '中文',
  'mandarin': '中文',
  'simplified chinese': '简体中文',
  'traditional chinese': '繁體中文',
  'cantonese': '廣東話',
  'korean': '한국어',
  'japanese': '日本語',
  'indonesian': 'Indonesia',
  'malay': 'Bahasa Melayu',
  'greek': 'Ελληνικά',
  'spanish': 'Español',
  'french': 'Français',
  'german': 'Deutsch',
  'italian': 'Italiano',
  'portuguese': 'Português',
  'russian': 'Русский',
  'arabic': 'العربية',
  'hindi': 'हिन्दी',
  'vietnamese': 'Tiếng Việt',
  'thai': 'ไทย',
  'tagalog': 'Tagalog',
  'filipino': 'Filipino',
  'dutch': 'Nederlands',
  'turkish': 'Türkçe',
  'polish': 'Polski',
  'ukrainian': 'Українська',
  'persian': 'فارسی',
  'farsi': 'فارسی',
  'bengali': 'বাংলা',
  'punjabi': 'ਪੰਜਾਬੀ',
  'tamil': 'தமிழ்',
  'telugu': 'తెలుగు',
  'urdu': 'اردو',
  'hebrew': 'עברית',
  'swedish': 'Svenska',
  'norwegian': 'Norsk',
  'danish': 'Dansk',
  'finnish': 'Suomi',
  'czech': 'Čeština',
  'romanian': 'Română',
  'hungarian': 'Magyar',
  'nepali': 'नेपाली',
  'burmese': 'မြန်မာ',
  'khmer': 'ខ្មែរ',
  'lao': 'ລາວ',
  'mongolian': 'Монгол',
  'sinhala': 'සිංහල',
};