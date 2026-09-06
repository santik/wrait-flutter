class SupportedLanguage {
  const SupportedLanguage({required this.code, required this.displayName});

  final String code;
  final String displayName;
}

const supportedLanguages = <SupportedLanguage>[
  SupportedLanguage(code: 'bg', displayName: 'български'),
  SupportedLanguage(code: 'ca', displayName: 'català'),
  SupportedLanguage(code: 'cs', displayName: 'čeština'),
  SupportedLanguage(code: 'da', displayName: 'dansk'),
  SupportedLanguage(code: 'de', displayName: 'Deutsch'),
  SupportedLanguage(code: 'de-CH', displayName: 'Deutsch (Schweiz)'),
  SupportedLanguage(code: 'el', displayName: 'Ελληνικά'),
  SupportedLanguage(code: 'en', displayName: 'English'),
  SupportedLanguage(code: 'es', displayName: 'Español'),
  SupportedLanguage(code: 'et', displayName: 'eesti'),
  SupportedLanguage(code: 'fi', displayName: 'suomi'),
  SupportedLanguage(code: 'fr', displayName: 'français'),
  SupportedLanguage(code: 'hi', displayName: 'हिन्दी'),
  SupportedLanguage(code: 'hu', displayName: 'magyar'),
  SupportedLanguage(code: 'id', displayName: 'Bahasa Indonesia'),
  SupportedLanguage(code: 'it', displayName: 'italiano'),
  SupportedLanguage(code: 'ja', displayName: '日本語'),
  SupportedLanguage(code: 'ko', displayName: '한국어'),
  SupportedLanguage(code: 'lt', displayName: 'lietuvių'),
  SupportedLanguage(code: 'lv', displayName: 'latviešu'),
  SupportedLanguage(code: 'ms', displayName: 'Bahasa Melayu'),
  SupportedLanguage(code: 'nl', displayName: 'Nederlands'),
  SupportedLanguage(code: 'nl-BE', displayName: 'Vlaams'),
  SupportedLanguage(code: 'no', displayName: 'norsk'),
  SupportedLanguage(code: 'pl', displayName: 'polski'),
  SupportedLanguage(code: 'pt', displayName: 'português'),
  SupportedLanguage(code: 'ro', displayName: 'română'),
  SupportedLanguage(code: 'ru', displayName: 'русский'),
  SupportedLanguage(code: 'sk', displayName: 'slovenčina'),
  SupportedLanguage(code: 'sv', displayName: 'svenska'),
  SupportedLanguage(code: 'th', displayName: 'ไทย'),
  SupportedLanguage(code: 'tr', displayName: 'Türkçe'),
  SupportedLanguage(code: 'uk', displayName: 'українська'),
  SupportedLanguage(code: 'vi', displayName: 'Tiếng Việt'),
  SupportedLanguage(code: 'zh', displayName: '中文'),
];

// These regional tags were persisted by earlier app versions. Keep resolving
// them to their original canonical values so reading or retrying an existing
// entry does not rewrite its stored language tag.
const _legacySupportedLanguageAliases = <String, String>{
  'en-us': 'en-US',
  'nl-nl': 'nl-NL',
  'ru-ru': 'ru-RU',
  'uk-ua': 'uk-UA',
  'de-de': 'de-DE',
  'es-es': 'es-ES',
  'fr-fr': 'fr-FR',
  'it-it': 'it-IT',
  'pl-pl': 'pl-PL',
  'pt-pt': 'pt-PT',
  'tr-tr': 'tr-TR',
};

final supportedLanguageCodes = supportedLanguages
    .map((language) => language.code)
    .toSet();

String? supportedLanguageDisplayName(String? code) {
  final normalized = normalizeLocaleLikeLanguageCode(code);
  if (normalized == null) {
    return null;
  }

  for (final supportedLanguage in supportedLanguages) {
    if (supportedLanguage.code.toLowerCase() == normalized.toLowerCase()) {
      return supportedLanguage.displayName;
    }
  }

  final baseLanguage = normalized.split('-').first.toLowerCase();
  for (final supportedLanguage in supportedLanguages) {
    if (supportedLanguage.code.toLowerCase() == baseLanguage) {
      return supportedLanguage.displayName;
    }
  }

  return null;
}

String? sanitizeLanguageCode(String? code) {
  if (code == null) {
    return null;
  }

  final sanitized = code.trim().replaceAll('_', '-');
  if (sanitized.isEmpty) {
    return null;
  }

  return sanitized;
}

String? normalizeLocaleLikeLanguageCode(String? code) {
  final sanitized = sanitizeLanguageCode(code);
  if (sanitized == null) {
    return null;
  }

  final parts = sanitized.split('-');
  if (parts.length > 2) {
    return null;
  }

  final languageCode = parts.first;
  if (!_languageCodePattern.hasMatch(languageCode)) {
    return null;
  }

  if (parts.length == 1) {
    return languageCode.toLowerCase();
  }

  final countryCode = parts[1];
  if (!_countryCodePattern.hasMatch(countryCode)) {
    return null;
  }

  return '${languageCode.toLowerCase()}-${countryCode.toUpperCase()}';
}

String? resolveSupportedLanguageCode(String? code) {
  final normalized = normalizeLocaleLikeLanguageCode(code);
  if (normalized == null) {
    return null;
  }

  for (final supportedLanguage in supportedLanguages) {
    if (supportedLanguage.code.toLowerCase() == normalized.toLowerCase()) {
      return supportedLanguage.code;
    }
  }

  final legacyAlias = _legacySupportedLanguageAliases[normalized.toLowerCase()];
  if (legacyAlias != null) {
    return legacyAlias;
  }

  final baseLanguage = normalized.split('-').first.toLowerCase();
  for (final supportedLanguage in supportedLanguages) {
    if (supportedLanguage.code.split('-').first.toLowerCase() == baseLanguage) {
      return supportedLanguage.code;
    }
  }

  return null;
}

final _languageCodePattern = RegExp(r'^[A-Za-z]{2,3}$');
final _countryCodePattern = RegExp(r'^[A-Za-z]{2}$');
