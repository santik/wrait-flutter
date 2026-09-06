import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/domain/model/supported_language.dart';

void main() {
  group('normalizeLocaleLikeLanguageCode', () {
    test('sanitizes whitespace, separators, and casing', () {
      expect(normalizeLocaleLikeLanguageCode(' FR_fr '), 'fr-FR');
      expect(normalizeLocaleLikeLanguageCode('en'), 'en');
    });

    test('rejects non-locale-shaped values', () {
      expect(normalizeLocaleLikeLanguageCode('zh-Hans-CN'), isNull);
      expect(normalizeLocaleLikeLanguageCode('en-001'), isNull);
      expect(normalizeLocaleLikeLanguageCode('abcd'), isNull);
      expect(normalizeLocaleLikeLanguageCode('   '), isNull);
    });
  });

  group('resolveSupportedLanguageCode', () {
    test('contains all automatically detected languages with native names', () {
      expect(supportedLanguages, hasLength(35));
      expect(
        supportedLanguages
            .map((language) => '${language.code}:${language.displayName}')
            .toList(),
        [
          'bg:български',
          'ca:català',
          'cs:čeština',
          'da:dansk',
          'de:Deutsch',
          'de-CH:Deutsch (Schweiz)',
          'el:Ελληνικά',
          'en:English',
          'es:Español',
          'et:eesti',
          'fi:suomi',
          'fr:français',
          'hi:हिन्दी',
          'hu:magyar',
          'id:Bahasa Indonesia',
          'it:italiano',
          'ja:日本語',
          'ko:한국어',
          'lt:lietuvių',
          'lv:latviešu',
          'ms:Bahasa Melayu',
          'nl:Nederlands',
          'nl-BE:Vlaams',
          'no:norsk',
          'pl:polski',
          'pt:português',
          'ro:română',
          'ru:русский',
          'sk:slovenčina',
          'sv:svenska',
          'th:ไทย',
          'tr:Türkçe',
          'uk:українська',
          'vi:Tiếng Việt',
          'zh:中文',
        ],
      );
    });

    test('returns canonical code for exact supported value', () {
      for (final supportedLanguage in supportedLanguages) {
        expect(
          resolveSupportedLanguageCode(supportedLanguage.code),
          supportedLanguage.code,
        );
      }
    });

    test('normalizes case and underscores', () {
      expect(resolveSupportedLanguageCode('FR_fr'), 'fr-FR');
    });

    test('resolves base language to supported canonical value', () {
      expect(resolveSupportedLanguageCode('en'), 'en');
      expect(resolveSupportedLanguageCode('fr'), 'fr');
      expect(resolveSupportedLanguageCode(' pt '), 'pt');
    });

    test('preserves legacy regional tags used by existing records', () {
      expect(resolveSupportedLanguageCode('en-US'), 'en-US');
      expect(resolveSupportedLanguageCode('FR_fr'), 'fr-FR');
      expect(resolveSupportedLanguageCode('nl-NL'), 'nl-NL');
    });

    test('returns null for unsupported or blank values', () {
      expect(resolveSupportedLanguageCode(''), isNull);
      expect(resolveSupportedLanguageCode('zz-ZZ'), isNull);
      expect(resolveSupportedLanguageCode('zh-Hans-CN'), isNull);
      expect(resolveSupportedLanguageCode('en-001'), isNull);
      expect(resolveSupportedLanguageCode(null), isNull);
    });
  });
}
