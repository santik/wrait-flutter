import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/presentation/main/main_screen_stats.dart';

void main() {
  test('formats zero entries with zero active days', () {
    final stats = buildMainScreenStats(const <Entry>[]);

    expect(stats.entryCount, 0);
    expect(stats.activeDays, 0);
    expect(stats.displayText, '0 entries - 0 days');
  });

  test('keeps plural wording for singular values', () {
    final stats = buildMainScreenStats([
      Entry(
        id: 1,
        rawTranscript: 'hello',
        isDraft: false,
        language: 'en-US',
        createdAt: DateTime(2026, 6, 13, 9).millisecondsSinceEpoch,
        wordCount: 1,
      ),
    ]);

    expect(stats.displayText, '1 entries - 1 days');
  });

  test('includes draft and finalized entries in the count', () {
    final entries = [
      Entry(
        id: 1,
        rawTranscript: 'draft',
        isDraft: true,
        language: 'en-US',
        createdAt: DateTime(2026, 6, 13, 9).millisecondsSinceEpoch,
        wordCount: 1,
      ),
      Entry(
        id: 2,
        rawTranscript: 'final',
        isDraft: false,
        language: 'en-US',
        createdAt: DateTime(2026, 6, 13, 10).millisecondsSinceEpoch,
        wordCount: 1,
      ),
    ];

    final stats = buildMainScreenStats(entries);
    expect(stats.entryCount, 2);
  });

  test('counts unique local calendar dates', () {
    final stats = buildMainScreenStats([
      Entry(
        id: 1,
        rawTranscript: 'one',
        isDraft: false,
        language: 'en-US',
        createdAt: DateTime(2026, 6, 13, 9).millisecondsSinceEpoch,
        wordCount: 1,
      ),
      Entry(
        id: 2,
        rawTranscript: 'two',
        isDraft: true,
        language: 'en-US',
        createdAt: DateTime(2026, 6, 13, 22).millisecondsSinceEpoch,
        wordCount: 1,
      ),
      Entry(
        id: 3,
        rawTranscript: 'three',
        isDraft: false,
        language: 'en-US',
        createdAt: DateTime(2026, 6, 14, 8).millisecondsSinceEpoch,
        wordCount: 1,
      ),
    ]);

    expect(stats.activeDays, 2);
    expect(stats.displayText, '3 entries - 2 days');
  });
}
