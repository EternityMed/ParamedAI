/// Parses GenUI JSON responses from LLM output.
/// Ported from backend/app/core/prompt_builder.py PromptBuilder.parse_genui_response().
import 'dart:convert';

class GenUIParser {
  /// Extract and parse GenUI JSON from raw LLM output.
  ///
  /// Handles:
  /// - JSON wrapped in ```json ... ``` code blocks
  /// - Raw JSON objects `{ ... }`
  /// - Plain text fallback with WarningCard
  ///
  /// Returns `{text: String, widgets: List<Map>}` matching ApiClient.chat() format.
  Map<String, dynamic> parse(String responseText) {
    final trimmed = responseText.trim();

    // Try to extract JSON from markdown code blocks first
    final codeBlockMatch =
        RegExp(r'```(?:json)?\s*\n?(.*?)\n?```', dotAll: true)
            .firstMatch(trimmed);

    String? jsonStr;
    if (codeBlockMatch != null) {
      jsonStr = codeBlockMatch.group(1)?.trim();
    } else {
      // Try to find raw JSON object in the response
      final jsonMatch =
          RegExp(r'\{.*\}', dotAll: true).firstMatch(trimmed);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(0)?.trim();
      }
    }

    if (jsonStr == null || jsonStr.isEmpty) {
      // No JSON found — return as plain text
      return {
        'text': trimmed,
        'widgets': <Map<String, dynamic>>[],
      };
    }

    try {
      final parsed = jsonDecode(jsonStr);

      if (parsed is Map<String, dynamic>) {
        final text = parsed['text'] as String? ?? '';
        final rawWidgets = parsed['widgets'] as List? ?? [];

        // Validate widget structure
        final validatedWidgets = <Map<String, dynamic>>[];
        for (final widget in rawWidgets) {
          if (widget is Map<String, dynamic> && widget.containsKey('type')) {
            // Normalize: merge top-level fields and explicit "data".
            // LLMs may nest under "data", put fields flat, or mix both.
            // Top-level fields (excluding "type"/"data") are collected first,
            // then explicit "data" fields override — so "data" wins on conflict.
            final data = <String, dynamic>{
              for (final e in widget.entries)
                if (e.key != 'type' && e.key != 'data') e.key: e.value,
              if (widget['data'] is Map<String, dynamic>)
                ...(widget['data'] as Map<String, dynamic>),
            };
            validatedWidgets.add({
              'type': widget['type'],
              'data': data,
            });
          }
        }

        return {
          'text': text,
          'widgets': validatedWidgets,
        };
      }

      // Parsed but not a map
      return {
        'text': trimmed,
        'widgets': <Map<String, dynamic>>[],
      };
    } on FormatException {
      // JSON parsing failed — return text with a warning widget
      return {
        'text': trimmed,
        'widgets': <Map<String, dynamic>>[
          {
            'type': 'WarningCard',
            'data': {
              'title': 'Response Format Warning',
              'message':
                  'AI response could not be parsed as structured data. Displaying raw text.',
              'severity': 'INFO',
              'action': 'Review the text response above.',
            },
          },
        ],
      };
    }
  }
}
