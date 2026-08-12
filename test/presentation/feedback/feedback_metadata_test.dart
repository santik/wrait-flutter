import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/presentation/feedback/feedback_metadata.dart';
import 'package:wrait/presentation/feedback/feedback_model.dart';

void main() {
  test('builds only the allowlisted metadata fields', () {
    final metadata = buildFeedbackMetadata(
      draft: const FeedbackDraft(
        category: FeedbackCategory.bug,
        replyContact: 'Signal: wrait-test',
      ),
      appArea: 'main',
      locale: const Locale('en', 'US'),
      platform: TargetPlatform.android,
    );

    expect(metadata, {
      'app_area': 'main',
      'platform': 'android',
      'locale': 'en-US',
      'feedback_category': 'Bug',
      'reply_contact': 'Signal: wrait-test',
    });
    expect(metadata.keys, isNot(contains('userId')));
    expect(metadata.keys, isNot(contains('device_id')));
    expect(metadata.keys, isNot(contains('transcript')));
    expect(metadata.keys, isNot(contains('audio_path')));
    expect(metadata.keys, isNot(contains('entry_id')));
  });

  test('omits blank contact and trims non-empty contact', () {
    final metadata = buildFeedbackMetadata(
      draft: const FeedbackDraft(
        category: FeedbackCategory.praise,
        replyContact: '  contact text  ',
      ),
      appArea: 'main',
      locale: const Locale('nl', 'NL'),
      platform: TargetPlatform.iOS,
    );
    final blankMetadata = buildFeedbackMetadata(
      draft: const FeedbackDraft(
        category: FeedbackCategory.idea,
        replyContact: '   ',
      ),
      appArea: 'main',
      locale: const Locale('en', 'US'),
      platform: TargetPlatform.android,
    );

    expect(metadata['reply_contact'], 'contact text');
    expect(blankMetadata.containsKey('reply_contact'), isFalse);
  });

  test('uses a neutral platform value outside supported mobile platforms', () {
    final metadata = buildFeedbackMetadata(
      draft: const FeedbackDraft(
        category: FeedbackCategory.idea,
        replyContact: '',
      ),
      appArea: 'main',
      locale: const Locale('en', 'US'),
      platform: TargetPlatform.macOS,
    );

    expect(metadata['platform'], 'unsupported');
  });
}
