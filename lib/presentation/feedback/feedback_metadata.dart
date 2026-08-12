import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:wiredash/wiredash.dart';

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

CustomizableWiredashMetaData applyFeedbackMetadata({
  required CustomizableWiredashMetaData metadata,
  required FeedbackDraft draft,
  required String appArea,
  required Locale locale,
  required TargetPlatform platform,
}) {
  final safeMetadata = buildFeedbackMetadata(
    draft: draft,
    appArea: appArea,
    locale: locale,
    platform: platform,
  );
  final replyContact = safeMetadata['reply_contact'];

  final explicitContact = replyContact is String ? replyContact : null;

  // Wiredash 2.6.1 drops customizable userEmail when the email prompt is
  // hidden while building the final feedback item. Keep the explicit contact
  // in userId as a non-email standard field as well as custom metadata.
  metadata.userEmail = explicitContact;
  metadata.userId = explicitContact;
  metadata.custom = safeMetadata;
  return metadata;
}

String _platformName(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => 'android',
  TargetPlatform.iOS => 'ios',
  _ => 'unsupported',
};
