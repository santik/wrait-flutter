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

String? resolveSupportedLanguageCode(String? code) {
  if (code == null) {
    return null;
  }

  final sanitized = code.trim().replaceAll('_', '-');
  if (sanitized.isEmpty) {
    return null;
  }

  for (final supportedLanguage in supportedLanguages) {
    if (supportedLanguage.code.toLowerCase() == sanitized.toLowerCase()) {
      return supportedLanguage.code;
    }
  }

  final baseLanguage = sanitized.split('-').first.toLowerCase();
  for (final supportedLanguage in supportedLanguages) {
    if (supportedLanguage.code.split('-').first.toLowerCase() == baseLanguage) {
      return supportedLanguage.code;
    }
  }

  return null;
}
