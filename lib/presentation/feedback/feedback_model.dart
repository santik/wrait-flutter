enum FeedbackCategory { bug, idea, confusing, praise }

extension FeedbackCategoryLabel on FeedbackCategory {
  String get label => switch (this) {
    FeedbackCategory.bug => 'Bug',
    FeedbackCategory.idea => 'Idea',
    FeedbackCategory.confusing => 'Confusing',
    FeedbackCategory.praise => 'Praise',
  };
}

class FeedbackDraft {
  const FeedbackDraft({
    required this.category,
    required this.replyContact,
    required this.message,
  });

  final FeedbackCategory category;
  final String replyContact;
  final String message;
}
