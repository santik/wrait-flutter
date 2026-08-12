import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'feedback_model.dart';

Map<String, Object> buildFeedbackMetadata({
  required FeedbackDraft draft,
  required String appArea,
  required Locale locale,
  required TargetPlatform platform,
}) {
  final metadata = <String, Object>{
    'app_area': appArea,
    'platform': _platformName(platform),
    'locale': locale.toLanguageTag(),
    'feedback_category': draft.category.label,
  };

  if (draft.replyContact.trim().isNotEmpty) {
    metadata['reply_contact'] = draft.replyContact.trim();
  }

  return Map<String, Object>.unmodifiable(metadata);
}

String _platformName(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => 'android',
  TargetPlatform.iOS => 'ios',
  _ => 'unsupported',
};
