import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:langchain/langchain.dart';

import 'models.dart';

const _authorUser = 'user';
const _authorAI = 'model';

/// Messages mapper.
extension ChatMessagesMapper on List<ChatMessage> {
  /// Coverts a list of messages.
  List<Content> toContentList() {
    return map(
      (final message) => switch (message) {
        SystemChatMessage() => throw UnsupportedError(
            'Google AI does not support system messages at the moment. '
            'Attach your system message in the human message.',
          ),
        final HumanChatMessage msg => Content(
            _authorUser,
            _mapHumanChatMessageContentParts(msg.content),
          ),
        final AIChatMessage aiChatMessage => Content(
            _authorAI,
            [
              TextPart(aiChatMessage.content),
            ],
          ),
        final CustomChatMessage customChatMessage => Content(
            customChatMessage.role,
            [
              TextPart(customChatMessage.content),
            ],
          ),
        FunctionChatMessage() => throw UnsupportedError(
            'Google AI does not support function messages',
          ),
      },
    ).toList(growable: false);
  }

  List<Part> _mapHumanChatMessageContentParts(
    final ChatMessageContent content,
  ) {
    return switch (content) {
      final ChatMessageContentText c => [TextPart(c.text)],
      final ChatMessageContentImage c => [
        if (c.mimeType != null)
          DataPart(c.mimeType!, base64.decode(c.data)),
      ],
      final ChatMessageContentMultiModal c => c.parts
          .map(
            (final p) => switch (p) {
              final ChatMessageContentText c => TextPart(c.text),
              final ChatMessageContentImage c => DataPart(
                  c.mimeType!,
                  base64.decode(c.data),
                ),
              ChatMessageContentMultiModal() => throw UnsupportedError(
                  'Cannot have multimodal content in multimodal content',
                ),
            },
          )
          .toList(growable: false),
    };
  }
}

/// Generation mapper.
extension GenerateContentResponseMapper on GenerateContentResponse {
  /// Converts generation
  ChatResult toChatResult(final String id, final String model) {
    return ChatResult(
      id: id,
      generations: _mapGenerations(),
      usage: LanguageModelUsage(
        // totalTokens: candidates.map((final c) => c.tokenCount ?? 0).sum ?? 0,
        // totalTokens: 18,
      ),
      modelOutput: {
        'model': model,
        'block_reason': promptFeedback?.blockReason?.name,
      },
    );
  }

  List<ChatGeneration> _mapGenerations() {
    return candidates
        .map(
          (final candidate) => ChatGeneration(
            AIChatMessage(
              content: candidate.content.parts
                  .whereType<TextPart>()
                  .map((final p) => p.text)
                  .whereNotNull()
                  .join('\n'),
            ),
            generationInfo: {
              // 'index': candidate.index,
              'finish_reason': candidate.finishReason?.name,
            },
          ),
        )
        .toList(growable: false);
  }
}

/// Safety settings mapper.
extension SafetySettingsMapper on List<ChatGoogleGenerativeAISafetySetting> {
  /// Converts safety settings.
  List<SafetySetting> toSafetySettings() {
    return map(
      (final setting) => SafetySetting(
        switch (setting.category) {
          ChatGoogleGenerativeAISafetySettingCategory.harmCategoryUnspecified =>
            HarmCategory.unspecified,
          ChatGoogleGenerativeAISafetySettingCategory.harmCategoryHarassment =>
            HarmCategory.harassment,
          ChatGoogleGenerativeAISafetySettingCategory.harmCategoryHateSpeech =>
            HarmCategory.hateSpeech,
          ChatGoogleGenerativeAISafetySettingCategory
                .harmCategorySexuallyExplicit =>
            HarmCategory.sexuallyExplicit,
          ChatGoogleGenerativeAISafetySettingCategory
                .harmCategoryDangerousContent =>
            HarmCategory.dangerousContent,
          _ => throw UnsupportedError('Unsupported harm category'),
        },
        switch (setting.threshold) {
          ChatGoogleGenerativeAISafetySettingThreshold
                .harmBlockThresholdUnspecified =>
            HarmBlockThreshold.unspecified,
          ChatGoogleGenerativeAISafetySettingThreshold.blockLowAndAbove =>
            HarmBlockThreshold.low,
          ChatGoogleGenerativeAISafetySettingThreshold.blockMediumAndAbove =>
            HarmBlockThreshold.medium,
          ChatGoogleGenerativeAISafetySettingThreshold.blockOnlyHigh =>
            HarmBlockThreshold.high,
          ChatGoogleGenerativeAISafetySettingThreshold.blockNone =>
            HarmBlockThreshold.none,
        },
      ),
    ).toList(growable: false);
  }
}
