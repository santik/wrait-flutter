import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:wiredash/wiredash.dart';

import 'feedback_metadata.dart';
import 'feedback_model.dart';
import 'feedback_preparation_sheet.dart';

enum FeedbackLaunchStatus { submitted, cancelled, unavailable, failed }

class FeedbackLaunchResult {
  const FeedbackLaunchResult(this.status);

  final FeedbackLaunchStatus status;
}

typedef WiredashFlowLauncher =
    Future<bool> Function({
      required BuildContext context,
      required FeedbackDraft draft,
      required String appArea,
    });

abstract interface class FeedbackService {
  Future<FeedbackLaunchResult> open(
    BuildContext context, {
    required String appArea,
  });
}

class WiredashFeedbackService implements FeedbackService {
  WiredashFeedbackService({required this.isConfigured, this.launchFlow});

  final bool isConfigured;
  final WiredashFlowLauncher? launchFlow;
  FeedbackDraft? _pendingDraft;
  Future<FeedbackLaunchResult>? _openInFlight;

  @override
  Future<FeedbackLaunchResult> open(
    BuildContext context, {
    required String appArea,
  }) {
    final existingRequest = _openInFlight;
    if (existingRequest != null) {
      return existingRequest;
    }

    late final Future<FeedbackLaunchResult> request;
    request = _openInternal(context, appArea: appArea).whenComplete(() {
      if (identical(_openInFlight, request)) {
        _openInFlight = null;
      }
    });
    _openInFlight = request;
    return request;
  }

  Future<FeedbackLaunchResult> _openInternal(
    BuildContext context, {
    required String appArea,
  }) async {
    final draft = await showFeedbackPreparationDialog(
      context,
      initialDraft: _pendingDraft,
    );

    if (draft == null) {
      _pendingDraft = null;
      return const FeedbackLaunchResult(FeedbackLaunchStatus.cancelled);
    }

    if (!context.mounted) {
      return const FeedbackLaunchResult(FeedbackLaunchStatus.cancelled);
    }

    _pendingDraft = draft;
    final controller = launchFlow == null ? Wiredash.maybeOf(context) : null;
    if (!isConfigured || (launchFlow == null && controller == null)) {
      return const FeedbackLaunchResult(FeedbackLaunchStatus.unavailable);
    }

    try {
      final submitted = launchFlow != null
          ? await launchFlow!(context: context, draft: draft, appArea: appArea)
          : await _launchWiredash(
              controller: controller!,
              context: context,
              draft: draft,
              appArea: appArea,
            );

      if (submitted) {
        _pendingDraft = null;
        developer.log(
          'Feedback submission succeeded.',
          name: 'FeedbackService',
        );
        return const FeedbackLaunchResult(FeedbackLaunchStatus.submitted);
      }

      _pendingDraft = null;
      return const FeedbackLaunchResult(FeedbackLaunchStatus.cancelled);
    } catch (error, stackTrace) {
      developer.log(
        'Feedback submission failed.',
        name: 'FeedbackService',
        error: error,
        stackTrace: stackTrace,
      );
      return const FeedbackLaunchResult(FeedbackLaunchStatus.failed);
    }
  }

  Future<bool> _launchWiredash({
    required WiredashController controller,
    required BuildContext context,
    required FeedbackDraft draft,
    required String appArea,
  }) async {
    final locale = Localizations.localeOf(context);
    final platform = defaultTargetPlatform;
    final result = await controller.show(
      inheritMaterialTheme: true,
      options: WiredashFeedbackOptions(
        labels: const [],
        email: EmailPrompt.hidden,
        screenshot: ScreenshotPrompt.hidden,
        collectMetaData: (metadata) {
          final safeMetadata = buildFeedbackMetadata(
            draft: draft,
            appArea: appArea,
            locale: locale,
            platform: platform,
          );
          metadata.custom = safeMetadata;
          return metadata;
        },
      ),
    );
    return result.hasSubmittedFeedback;
  }
}
