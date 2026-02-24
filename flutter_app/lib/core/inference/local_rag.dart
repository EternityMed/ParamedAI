/// Keyword-based local RAG for offline protocol retrieval.
///
/// Loads bundled protocol JSON files from assets and matches user queries
/// against protocol keywords to provide relevant context for on-device inference.
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// A loaded protocol with its searchable metadata.
class Protocol {
  final String name;
  final List<String> keywords;
  final List<Map<String, String>> sections;

  const Protocol({
    required this.name,
    required this.keywords,
    required this.sections,
  });

  /// Full content text for injection into the prompt.
  String get contentText {
    final buffer = StringBuffer();
    buffer.writeln('# $name');
    for (final section in sections) {
      buffer.writeln('## ${section['title']}');
      buffer.writeln(section['content']);
      buffer.writeln();
    }
    return buffer.toString();
  }
}

class LocalRAG {
  List<Protocol> _protocols = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;

  static const List<String> _protocolFiles = [
    'anaphylaxis',
    'burns',
    'cardiac_arrest',
    'crush_syndrome',
    'drug_doses',
    'hypothermia',
    'mci_triage',
    'pediatric_emergency',
    'poisoning',
    'seizure',
    'stemi',
    'stroke',
    'trauma',
  ];

  /// Load all protocol JSONs from Flutter assets.
  Future<void> initialize() async {
    if (_initialized) return;

    final protocols = <Protocol>[];
    for (final file in _protocolFiles) {
      try {
        final jsonStr =
            await rootBundle.loadString('assets/protocols/$file.json');
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;

        final sections = <Map<String, String>>[];
        for (final section in (data['sections'] as List? ?? [])) {
          if (section is Map) {
            sections.add({
              'title': section['title']?.toString() ?? '',
              'content': section['content']?.toString() ?? '',
            });
          }
        }

        final keywords = <String>[];
        for (final kw in (data['keywords'] as List? ?? [])) {
          keywords.add(kw.toString().toLowerCase());
        }
        // Also add the protocol name as a keyword
        keywords.add(
            (data['protocol_name'] as String? ?? '').toLowerCase());

        protocols.add(Protocol(
          name: data['protocol_name'] as String? ?? file,
          keywords: keywords,
          sections: sections,
        ));
      } catch (e) {
        // Skip protocols that fail to load
        continue;
      }
    }

    _protocols = protocols;
    _initialized = true;
  }

  /// Retrieve relevant protocol context for a user query.
  ///
  /// Performs keyword matching against protocol keywords and names.
  /// Returns concatenated content of the top matching protocols (max 2),
  /// or null if no match found.
  String? retrieveContext(String query) {
    if (!_initialized || _protocols.isEmpty) return null;

    final queryLower = query.toLowerCase();
    final queryWords = queryLower
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toList();

    // Score each protocol by keyword matches
    final scores = <int, int>{};
    for (var i = 0; i < _protocols.length; i++) {
      int score = 0;
      final protocol = _protocols[i];

      for (final keyword in protocol.keywords) {
        // Exact keyword match in query
        if (queryLower.contains(keyword)) {
          score += 3;
        } else {
          // Partial word match
          for (final word in queryWords) {
            if (keyword.contains(word) || word.contains(keyword)) {
              score += 1;
            }
          }
        }
      }

      if (score > 0) {
        scores[i] = score;
      }
    }

    if (scores.isEmpty) return null;

    // Sort by score descending, take top 2
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topIndices = sorted.take(2).map((e) => e.key).toList();

    final buffer = StringBuffer();
    for (final idx in topIndices) {
      buffer.write(_protocols[idx].contentText);
      buffer.writeln('---');
    }

    return buffer.toString();
  }
}
