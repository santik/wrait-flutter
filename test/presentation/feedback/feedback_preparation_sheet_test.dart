import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/presentation/feedback/feedback_model.dart';
import 'package:wrait/presentation/feedback/feedback_preparation_sheet.dart';

void main() {
  testWidgets(
    'collects a category, arbitrary contact text, and privacy acknowledgement',
    (tester) async {
      FeedbackDraft? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await showFeedbackPreparationDialog(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Bug'), findsOneWidget);
      expect(find.text('Idea'), findsOneWidget);
      expect(find.text('Confusing'), findsOneWidget);
      expect(find.text('Praise'), findsOneWidget);
      expect(find.byKey(feedbackPrivacyCopyKey), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(feedbackContinueButtonKey))
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('Bug'));
      await tester.enterText(
        find.byKey(feedbackContactFieldKey),
        'not-an-email',
      );
      await tester.tap(find.byKey(feedbackContinueButtonKey));
      await tester.pumpAndSettle();

      expect(result?.category, FeedbackCategory.bug);
      expect(result?.replyContact, 'not-an-email');
    },
  );

  testWidgets('cancel closes without returning a draft', (tester) async {
    FeedbackDraft? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showFeedbackPreparationDialog(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byKey(feedbackPrivacyCopyKey), findsNothing);
  });
}
