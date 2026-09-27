import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tano/shared/config/l10n.dart';

class MalagasyWordRef {
  final String key;

  /// The wording shown in the list (the asset's "expression").
  final String word;

  /// The single word the site lookup and the link use.
  final String keyword;

  final String description;
  final bool hasWebsiteRef;
  final bool shouldDisplay;

  MalagasyWordRef({
    required this.key,
    required this.word,
    required this.keyword,
    required this.description,
    required this.hasWebsiteRef,
    required this.shouldDisplay,
  });

  /// The word the site link looks up: the keyword, or the wording itself when
  /// no keyword was set.
  String get lookupWord => keyword.isEmpty ? word : keyword;

  Map<String, dynamic> toJson() => {
    'key': key,
    'word': word,
    'keyword': keyword,
    'description': description,
    'hasWebsiteRef': hasWebsiteRef,
    'shouldDisplay': shouldDisplay,
  };

  factory MalagasyWordRef.fromJson(Map<String, dynamic> json) {
    final String word = json['word'] as String? ?? '';
    final String keyword = json['keyword'] as String? ?? '';
    return MalagasyWordRef(
      key: json['key'] as String? ?? '',
      word: word,
      // A runtime file written before the field existed falls back to the word.
      keyword: keyword.isEmpty ? word : keyword,
      description: json['description'] as String? ?? '',
      hasWebsiteRef: json['hasWebsiteRef'] as bool? ?? false,
      shouldDisplay: json['shouldDisplay'] as bool? ?? false,
    );
  }
}

/// Whether a runtime file was written before the keyword field existed, so the
/// controller rebuilds it from the asset.
bool needsKeywordMigration(List<dynamic> entries) => entries.any(
  (dynamic entry) => !(entry as Map<String, dynamic>).containsKey('keyword'),
);

class LanguageReferencesController {
  LanguageReferencesController._();
  static final LanguageReferencesController instance =
      LanguageReferencesController._();

  static const String _localFileName = 'malagasy_refs_runtime.json';
  List<MalagasyWordRef> _references = [];

  List<MalagasyWordRef> get references => _references;

  Future<void> init() async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final File localFile = File('${directory.path}/$_localFileName');

    // If local file exists, we load it. Otherwise, we generate it from asset.
    if (await localFile.exists()) {
      final String content = await localFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(content) as List<dynamic>;
      // A file written before the keyword field existed is rebuilt from the
      // asset, so an install that already ran still gets the keyword.
      if (!needsKeywordMigration(jsonList)) {
        _references = jsonList
            .map(
              (dynamic j) =>
                  MalagasyWordRef.fromJson(j as Map<String, dynamic>),
            )
            .toList();
        return;
      }
    }
    await _generateInitialConfig(localFile);
  }

  Future<void> _generateInitialConfig(File localFile) async {
    // 1. Load the dev config from assets
    final String assetContent = await rootBundle.loadString(
      'assets/config/malagasy_refs.json',
    );
    final Map<String, dynamic> devConfig = jsonDecode(assetContent);

    // 2. Cross-reference with AppText Malagasy translations
    final List<MalagasyWordRef> generated = [];

    devConfig.forEach((key, data) {
      // Only include if key exists in dev config AND has shouldDisplay true
      if (data['shouldDisplay'] == true) {
        // Priority: Use 'expression' from JSON. Fallback: Use AppText Malagasy translation.
        final String? jsonExpression = data['expression'];
        final String malagasyWord =
            (jsonExpression != null && jsonExpression.isNotEmpty)
            ? jsonExpression
            : AppText.trFor('mg', key);

        generated.add(
          MalagasyWordRef(
            key: key,
            word: malagasyWord,
            keyword: ((data['keyword'] as String?) ?? '').isNotEmpty
                ? data['keyword'] as String
                : malagasyWord,
            description: data['description'],
            hasWebsiteRef: data['hasWebsiteRef'],
            shouldDisplay: data['shouldDisplay'],
          ),
        );
      }
    });

    // Sort alphabetically by word
    generated.sort((a, b) => a.word.compareTo(b.word));
    _references = generated;

    // 3. Save to local storage for future launches
    await localFile.writeAsString(
      jsonEncode(_references.map((r) => r.toJson()).toList()),
    );
  }
}
