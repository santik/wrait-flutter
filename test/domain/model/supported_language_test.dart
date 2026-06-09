import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/domain/model/supported_language.dart';

void main() {
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
    });

    test('returns null for unsupported or blank values', () {
      expect(resolveSupportedLanguageCode(''), isNull);
      expect(resolveSupportedLanguageCode('zz-ZZ'), isNull);
      expect(resolveSupportedLanguageCode(null), isNull);
    });
  });
}
