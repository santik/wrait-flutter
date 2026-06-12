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
    test('returns canonical code for exact supported value', () {
      expect(resolveSupportedLanguageCode('en-US'), 'en-US');
    });

    test('normalizes case and underscores', () {
      expect(resolveSupportedLanguageCode('FR_fr'), 'fr-FR');
    });

    test('resolves base language to supported canonical value', () {
      expect(resolveSupportedLanguageCode('en'), 'en-US');
      expect(resolveSupportedLanguageCode('fr'), 'fr-FR');
      expect(resolveSupportedLanguageCode(' pt '), 'pt-PT');
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
