class SupportedLanguage {
  const SupportedLanguage({required this.code, required this.displayName});

  final String code;
  final String displayName;
}

const supportedLanguages = <SupportedLanguage>[
  SupportedLanguage(code: 'en-US', displayName: 'English'),
  SupportedLanguage(code: 'nl-NL', displayName: 'Nederlands'),
  SupportedLanguage(code: 'ru-RU', displayName: 'Russkii'),
  SupportedLanguage(code: 'uk-UA', displayName: 'Ukrainska'),
  SupportedLanguage(code: 'de-DE', displayName: 'Deutsch'),
  SupportedLanguage(code: 'es-ES', displayName: 'Espanol'),
  SupportedLanguage(code: 'fr-FR', displayName: 'Francais'),
  SupportedLanguage(code: 'it-IT', displayName: 'Italiano'),
  SupportedLanguage(code: 'pl-PL', displayName: 'Polski'),
  SupportedLanguage(code: 'pt-PT', displayName: 'Portugues'),
  SupportedLanguage(code: 'tr-TR', displayName: 'Turkce'),
];

final supportedLanguageCodes = supportedLanguages
    .map((language) => language.code)
    .toSet();

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
