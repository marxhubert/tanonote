// Keeps assets/config/malagasy_refs.json in sync with the keys that
// lib/shared/config/l10n.dart defines, and can enrich its empty descriptions
// with the Malagasy explanations published by malagasyword.org.
//
//   dart run tool/update_malagasy_refs.dart            # rewrite the file
//   dart run tool/update_malagasy_refs.dart --check     # fail when out of date
//   dart run tool/update_malagasy_refs.dart --sync-web  # fill empty descriptions
//   dart run tool/update_malagasy_refs.dart --overwrite # reset every l10n entry
//
// The l10n maps cannot be imported here: l10n.dart needs dart:ui, which a plain
// Dart process cannot load. The tool parses the source instead. The Android
// Gradle preBuild hook and the iOS "Sync Malagasy refs" build phase run it
// before the asset is bundled.
//
// Every entry carries a `keyword`: the single word --sync-web looks up. It
// starts as the `expression` and can be edited to target a word inside a phrase,
// which the site's word pages require.
//
// The tool is blocked outside a local debug or profile environment, so a build
// farm or a release build never runs it; pass --force to override. The web sync
// is part of the same guard, so a GitHub build never reaches the network.

import 'dart:convert';
import 'dart:io';

/// Source of truth for the keys, relative to the project root.
const String l10nPath = 'lib/shared/config/l10n.dart';

/// The references file the tool reconciles, relative to the project root.
const String refsPath = 'assets/config/malagasy_refs.json';

/// Where the fetched words are remembered, relative to the project root.
const String cachePath = '.dart_tool/malagasy_refs_web_cache.json';

/// The word pages, the same the app links to.
const String wordBase = 'https://malagasyword.org/bins/teny2/';

/// How long a cached answer is trusted before the word is fetched again.
const Duration cacheTtl = Duration(days: 30);

/// Environment variables that mean "a build farm, not a developer machine".
const List<String> ciVariables = <String>[
  'CI',
  'GITHUB_ACTIONS',
  'GITLAB_CI',
  'BUILD_NUMBER',
  'TEAMCITY_VERSION',
  'JENKINS_URL',
  'TRAVIS',
  'CIRCLECI',
  'BITBUCKET_BUILD_NUMBER',
];

/// Entries the references page shows that no l10n key backs: the tool never
/// removes them and keeps them exactly where they are. Add a key here to
/// protect it.
const Set<String> preservedKeys = <String>{'fiteny', 'voambolana'};

/// What [buildMalagasyRefs] produced.
class MalagasyRefsSync {
  MalagasyRefsSync({
    required this.json,
    required this.added,
    required this.removed,
    required this.preserved,
    required this.overwritten,
    required this.unchanged,
    required this.changed,
  });

  /// The reconciled document, sorted by key, with a trailing newline.
  final String json;

  /// Keys the l10n holds and the references did not: they were added.
  final List<String> added;

  /// Keys the references held and the l10n no longer has: they were removed.
  final List<String> removed;

  /// Extra-l10n entries the tool kept because [preservedKeys] names them.
  final List<String> preserved;

  /// Entries reset to their default under --overwrite; [preservedKeys] are not.
  final List<String> overwritten;

  /// Keys both sides share: their entry is kept untouched.
  final int unchanged;

  int get total => added.length + unchanged;

  /// Whether the file differed from the canonical form the tool writes.
  final bool changed;
}

/// The l10n keys, plus the wording used to pre-fill a fresh expression.
class L10n {
  L10n({required this.keys, required this.english, required this.malagasy});

  final Set<String> keys;
  final Map<String, String> english;
  final Map<String, String> malagasy;

  /// The word a new reference starts from: the Malagasy wording, then English,
  /// then the key itself when neither map carries it.
  String prefill(String key) {
    final String? mg = malagasy[key];
    if (mg != null && mg.isNotEmpty) return mg;
    final String? en = english[key];
    if (en != null && en.isNotEmpty) return en;
    return key;
  }
}

/// Reads the keys and the en/mg values out of the l10n source.
L10n parseL10n(String source) {
  final Map<String, String> en = _parseMap(source, '_en');
  final Map<String, String> fr = _parseMap(source, '_fr');
  final Map<String, String> mg = _parseMap(source, '_mg');
  return L10n(
    keys: <String>{...en.keys, ...fr.keys, ...mg.keys},
    english: en,
    malagasy: mg,
  );
}

/// Encodes the entries the canonical way: sorted by key, two-space indent.
String encodeRefs(Map<String, dynamic> entries) {
  final List<String> sorted = entries.keys.toList()..sort();
  final Map<String, dynamic> ordered = <String, dynamic>{
    for (final String key in sorted) key: entries[key],
  };
  final String encoded = const JsonEncoder.withIndent('  ').convert(ordered);
  return '$encoded\n';
}

/// Reconciles [refsJson] with the keys [l10nSource] defines.
MalagasyRefsSync buildMalagasyRefs({
  required String l10nSource,
  required String refsJson,
  bool overwrite = false,
}) {
  final L10n l10n = parseL10n(l10nSource);
  final Map<String, dynamic> current = refsJson.trim().isEmpty
      ? <String, dynamic>{}
      : jsonDecode(refsJson) as Map<String, dynamic>;

  final List<String> added = <String>[];
  final List<String> removed = <String>[
    for (final String key in current.keys)
      if (!l10n.keys.contains(key) && !preservedKeys.contains(key)) key,
  ];
  final List<String> preserved = <String>[
    for (final String key in current.keys)
      if (!l10n.keys.contains(key) && preservedKeys.contains(key)) key,
  ];
  final Set<String> target = <String>{...l10n.keys, ...preserved};

  final List<String> overwritten = <String>[];
  Map<String, dynamic> defaultEntry(String key) => <String, dynamic>{
    'keyword': l10n.prefill(key),
    'expression': l10n.prefill(key),
    'description': '',
    'hasWebsiteRef': false,
    'shouldDisplay': false,
  };

  // keyword is the single word the web sync looks up. It starts as the
  // expression and can be edited to target a word inside a phrase; a keyword the
  // file already carries is never overwritten.
  Map<String, dynamic> normalizeEntry(Map<String, dynamic> entry) {
    final String expression = entry['expression'] as String? ?? '';
    final String keyword = entry['keyword'] as String? ?? '';
    return <String, dynamic>{
      'keyword': keyword.isEmpty ? expression : keyword,
      'expression': expression,
      'description': entry['description'] as String? ?? '',
      'hasWebsiteRef': entry['hasWebsiteRef'] as bool? ?? false,
      'shouldDisplay': entry['shouldDisplay'] as bool? ?? false,
    };
  }

  final Map<String, dynamic> next = <String, dynamic>{};
  for (final String key in target) {
    final Object? existing = current[key];
    // The preserved entries are the one exception --overwrite never touches.
    final bool isPreserved =
        !l10n.keys.contains(key) && preservedKeys.contains(key);
    if (existing is Map<String, dynamic>) {
      if (overwrite && !isPreserved) {
        overwritten.add(key);
        next[key] = defaultEntry(key);
      } else {
        // The migration adds a missing keyword; the content is kept.
        next[key] = normalizeEntry(existing);
      }
    } else {
      added.add(key);
      next[key] = defaultEntry(key);
    }
  }

  final String json = encodeRefs(next);
  final bool changed =
      added.isNotEmpty ||
      removed.isNotEmpty ||
      json != (refsJson.endsWith('\n') ? refsJson : '$refsJson\n');
  return MalagasyRefsSync(
    json: json,
    added: added..sort(),
    removed: removed..sort(),
    preserved: preserved..sort(),
    overwritten: overwritten..sort(),
    unchanged: next.length - added.length,
    changed: changed,
  );
}

/// Reads the values of one top-level map literal out of the l10n source.
Map<String, String> _parseMap(String source, String name) {
  final RegExp declaration = RegExp('Map<String, String>\\s+$name\\s*=');
  final Match? match = declaration.firstMatch(source);
  if (match == null) return <String, String>{};
  final int open = source.indexOf('{', match.end);
  if (open < 0) return <String, String>{};
  final int close = source.indexOf('\n  };', open);
  return _parseEntries(
    source.substring(open + 1, close < 0 ? source.length : close),
  );
}

/// Reads every 'key': value pair of a map body, string literals concatenated.
Map<String, String> _parseEntries(String body) {
  final Map<String, String> entries = <String, String>{};
  final RegExp keyPattern = RegExp("'([a-z][a-z0-9_]*)'\\s*:");
  int cursor = 0;
  while (cursor < body.length) {
    final Match? key = keyPattern.firstMatch(body.substring(cursor));
    if (key == null) break;
    final int colon = cursor + key.end;
    final int end = _valueEnd(body, colon);
    entries[key.group(1)!] = _readStrings(body.substring(colon, end));
    cursor = end + 1;
  }
  return entries;
}

/// The index of the comma that closes the value that starts at [start].
int _valueEnd(String body, int start) {
  String? quote;
  bool escaped = false;
  for (int i = start; i < body.length; i++) {
    final String char = body[i];
    if (quote != null) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
    } else if (char == ',') {
      return i;
    }
  }
  return body.length;
}

/// Concatenates the string literals of a value segment, unescaping the usual
/// sequences. Adjacent literals are joined in Dart, so they are joined here.
String _readStrings(String segment) {
  final StringBuffer value = StringBuffer();
  final StringBuffer current = StringBuffer();
  String? quote;
  bool escaped = false;
  for (int i = 0; i < segment.length; i++) {
    final String char = segment[i];
    if (quote == null) {
      if (char == "'" || char == '"') {
        quote = char;
        current.clear();
      }
      continue;
    }
    if (escaped) {
      current.write(
        char == 'n'
            ? '\n'
            : char == 't'
            ? '\t'
            : char,
      );
      escaped = false;
    } else if (char == '\\') {
      escaped = true;
    } else if (char == quote) {
      value.write(current);
      quote = null;
    } else {
      current.write(char);
    }
  }
  return value.toString();
}

/// Whether this is a developer machine rather than a build farm.
bool isLocalEnvironment([Map<String, String>? environment]) {
  final Map<String, String> env = environment ?? Platform.environment;
  for (final String name in ciVariables) {
    final String value = (env[name] ?? '').toLowerCase();
    if (value.isNotEmpty && value != 'false') return false;
  }
  return true;
}

/// Whether the tool may run: a local machine, in a debug or profile build.
bool webSyncAllowed({required String mode, required bool local}) =>
    local && mode != 'release';

/// The sections a word page may hold, in the order the sync tries them: the
/// first one with content wins, so a word the Malagasy block leaves out is still
/// caught by its examples or a translation.
const List<String> explanationLabels = <String>[
  'Explanations in Malagasy',
  'Examples',
  'Explanations in French',
  'Explanations in English',
  'Part of speech',
];

/// The cleaned text of one [label] section of a word page, or null when the
/// page holds none.
///
/// Each sense is printed as a number, its text, then a bracketed dictionary
/// reference. The number, the reference and the markup are dropped, and the
/// senses are joined with ' ; '.
String? explanationSection(String html, String label) {
  final int start = html.indexOf(label);
  if (start < 0) return null;
  final int labelEnd = html.indexOf('</td>', start);
  if (labelEnd < 0) return null;
  final int cellStart = html.indexOf('<td', labelEnd);
  if (cellStart < 0) return null;
  final int cellOpen = html.indexOf('>', cellStart);
  if (cellOpen < 0) return null;
  final int cellEnd = html.indexOf('</td>', cellOpen);
  if (cellEnd < 0) return null;
  final String raw = html.substring(cellOpen + 1, cellEnd);
  final List<String> senses = <String>[];
  for (final String part in raw.split(RegExp('<br\\s*/?>'))) {
    final String cleaned = _cleanSense(part);
    if (cleaned.isNotEmpty) senses.add(cleaned);
  }
  return senses.isEmpty ? null : senses.join(' ; ');
}

/// The first of [explanationLabels] the page fills, or null when none does.
String? firstExplanation(String html) {
  for (final String label in explanationLabels) {
    final String? section = explanationSection(html, label);
    if (section != null) return section;
  }
  return null;
}

/// Decodes a word page. The site predates UTF-8: most pages are UTF-8, but some
/// carry a stray Latin-1 byte, so a clean UTF-8 decode falls back to Latin-1.
String decodeHtml(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

/// Drops the sense number, the source references and the markup of one sense.
String _cleanSense(String html) {
  String value = html.replaceAll(
    RegExp("<span class=['\"]source['\"]>.*?</span>", dotAll: true),
    ' ',
  );
  value = value.replaceAll(
    RegExp("<span class=['\"]rminute['\"]>.*?</span>", dotAll: true),
    ' ',
  );
  value = value.replaceAll(RegExp('<[^>]*>'), ' ');
  value = decodeEntities(value);
  // A bracketed aside ("[ Full list ]", a dialect tag) is site chrome, not part
  // of the definition.
  value = value.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// The named entities the word pages use: HTML4's Latin-1 set and its common
/// symbols. An unknown name is left as it stands.
const Map<String, String> namedEntities = <String, String>{
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'iexcl': '¡',
  'cent': '¢',
  'pound': '£',
  'curren': '¤',
  'yen': '¥',
  'brvbar': '¦',
  'sect': '§',
  'uml': '¨',
  'copy': '©',
  'ordf': 'ª',
  'laquo': '«',
  'not': '¬',
  'shy': '',
  'reg': '®',
  'macr': '¯',
  'deg': '°',
  'plusmn': '±',
  'sup2': '²',
  'sup3': '³',
  'acute': '´',
  'micro': 'µ',
  'para': '¶',
  'middot': '·',
  'cedil': '¸',
  'sup1': '¹',
  'ordm': 'º',
  'raquo': '»',
  'frac14': '¼',
  'frac12': '½',
  'frac34': '¾',
  'iquest': '¿',
  'Agrave': 'À',
  'Aacute': 'Á',
  'Acirc': 'Â',
  'Atilde': 'Ã',
  'Auml': 'Ä',
  'Aring': 'Å',
  'AElig': 'Æ',
  'Ccedil': 'Ç',
  'Egrave': 'È',
  'Eacute': 'É',
  'Ecirc': 'Ê',
  'Euml': 'Ë',
  'Igrave': 'Ì',
  'Iacute': 'Í',
  'Icirc': 'Î',
  'Iuml': 'Ï',
  'ETH': 'Ð',
  'Ntilde': 'Ñ',
  'Ograve': 'Ò',
  'Oacute': 'Ó',
  'Ocirc': 'Ô',
  'Otilde': 'Õ',
  'Ouml': 'Ö',
  'times': '×',
  'Oslash': 'Ø',
  'Ugrave': 'Ù',
  'Uacute': 'Ú',
  'Ucirc': 'Û',
  'Uuml': 'Ü',
  'Yacute': 'Ý',
  'THORN': 'Þ',
  'szlig': 'ß',
  'agrave': 'à',
  'aacute': 'á',
  'acirc': 'â',
  'atilde': 'ã',
  'auml': 'ä',
  'aring': 'å',
  'aelig': 'æ',
  'ccedil': 'ç',
  'egrave': 'è',
  'eacute': 'é',
  'ecirc': 'ê',
  'euml': 'ë',
  'igrave': 'ì',
  'iacute': 'í',
  'icirc': 'î',
  'iuml': 'ï',
  'eth': 'ð',
  'ntilde': 'ñ',
  'ograve': 'ò',
  'oacute': 'ó',
  'ocirc': 'ô',
  'otilde': 'õ',
  'ouml': 'ö',
  'divide': '÷',
  'oslash': 'ø',
  'ugrave': 'ù',
  'uacute': 'ú',
  'ucirc': 'û',
  'uuml': 'ü',
  'yacute': 'ý',
  'thorn': 'þ',
  'yuml': 'ÿ',
  'ndash': '–',
  'mdash': '—',
  'lsquo': '‘',
  'rsquo': '’',
  'ldquo': '“',
  'rdquo': '”',
  'bull': '•',
  'hellip': '…',
  'permil': '‰',
  'lsaquo': '‹',
  'rsaquo': '›',
  'oline': '‾',
  'frasl': '⁄',
  'euro': '€',
  'trade': '™',
  'larr': '←',
  'uarr': '↑',
  'rarr': '→',
  'darr': '↓',
  'harr': '↔',
  'loz': '◊',
  'spades': '♠',
  'clubs': '♣',
  'hearts': '♥',
  'diams': '♦',
};

/// Decodes the named and numeric entities the word pages use.
String decodeEntities(String value) {
  String decoded = value.replaceAllMapped(
    RegExp(r'&([a-zA-Z][a-zA-Z0-9]*);'),
    (Match match) => namedEntities[match.group(1)!] ?? match.group(0)!,
  );
  decoded = decoded.replaceAllMapped(
    RegExp(r'&#(\d+);'),
    (Match match) => String.fromCharCode(int.parse(match.group(1)!)),
  );
  decoded = decoded.replaceAllMapped(
    RegExp(r'&#x([0-9a-fA-F]+);'),
    (Match match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
  );
  return decoded;
}

/// Fetches the explanation of one word; injected so the loop stays testable.
typedef ExplanationFetcher = Future<String?> Function(String word);

/// What one web pass did.
class WebSyncReport {
  int fetched = 0;
  int filled = 0;
  int replaced = 0;
  int empty = 0;
  int reused = 0;
}

/// Fetches the Malagasy explanation of [word], or null when the site has none.
Future<String?> fetchExplanation(
  String word, {
  required HttpClient client,
}) async {
  try {
    final HttpClientRequest request = await client.getUrl(
      Uri.parse(wordBase + Uri.encodeComponent(word)),
    );
    request.followRedirects = false;
    final HttpClientResponse response = await request.close();
    if (response.statusCode != 200) {
      await response.drain<void>();
      return null;
    }
    final List<int> bytes = <int>[];
    await for (final List<int> chunk in response) {
      bytes.addAll(chunk);
    }
    return firstExplanation(decodeHtml(bytes));
  } catch (_) {
    return null;
  }
}

/// Reads the answers remembered from an earlier pass.
Future<Map<String, dynamic>> readWebCache(File file) async {
  if (!await file.exists()) return <String, dynamic>{};
  try {
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  } catch (_) {
    return <String, dynamic>{};
  }
}

/// Writes the answers back, so a build only fetches each word once.
Future<void> writeWebCache(File file, Map<String, dynamic> cache) async {
  await file.parent.create(recursive: true);
  await file.writeAsString(encodeRefs(cache));
}

/// Fills every empty description the site can explain.
///
/// An entry that already has a description is left alone unless [refresh] is
/// set: a refresh re-fetches it too and replaces it when the site has an
/// explanation, keeping the existing text when the site has none.
Future<WebSyncReport> syncWebDescriptions({
  required Map<String, dynamic> entries,
  required Map<String, dynamic> cache,
  required ExplanationFetcher fetch,
  required int limit,
  required Duration delay,
  bool refresh = false,
  bool ignoreCache = false,
}) async {
  final WebSyncReport report = WebSyncReport();
  final DateTime now = DateTime.now();
  for (final MapEntry<String, dynamic> entry in entries.entries.toList()) {
    if (limit > 0 && report.fetched >= limit) break;
    final Object? value = entry.value;
    if (value is! Map<String, dynamic>) continue;
    final String existing = value['description'] as String? ?? '';
    if (!refresh && existing.isNotEmpty) continue;
    final String keyword = (value['keyword'] as String? ?? '').trim();
    final String expression = (value['expression'] as String? ?? '').trim();
    final String word = keyword.isNotEmpty
        ? keyword
        : (expression.isNotEmpty ? expression : entry.key);
    if (word.isEmpty) continue;

    if (!refresh && !ignoreCache) {
      final Object? cached = cache[word];
      if (cached is Map<String, dynamic>) {
        final DateTime? when = DateTime.tryParse(
          cached['fetchedAt'] as String? ?? '',
        );
        if (when != null && now.difference(when) < cacheTtl) {
          final String description = cached['description'] as String? ?? '';
          if (description.isNotEmpty) {
            value['description'] = description;
            value['hasWebsiteRef'] = true;
            report.filled++;
          } else {
            report.empty++;
          }
          report.reused++;
          continue;
        }
      }
    }

    if (report.fetched > 0 && delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    report.fetched++;
    stdout.writeln('  ... $word');
    final String? explanation = await fetch(word);
    cache[word] = <String, dynamic>{
      'description': explanation ?? '',
      'fetchedAt': DateTime.now().toIso8601String(),
    };
    if (explanation != null && explanation.isNotEmpty) {
      value['description'] = explanation;
      value['hasWebsiteRef'] = true;
      report.filled++;
      if (existing.isNotEmpty) report.replaced++;
    } else {
      report.empty++;
    }
  }
  return report;
}

/// Prints the added and removed keys, then a one-line summary.
void report(MalagasyRefsSync result) {
  for (final String key in result.removed) {
    stdout.writeln('  - $key');
  }
  for (final String key in result.added) {
    stdout.writeln('  + $key');
  }
  stdout.writeln(
    'Malagasy refs: ${result.added.length} added, '
    '${result.removed.length} removed, ${result.unchanged} unchanged '
    '(${result.total} keys).',
  );
  if (result.overwritten.isNotEmpty) {
    stdout.writeln('Reset to default: ${result.overwritten.length} entries.');
  }
  if (result.added.isEmpty && result.removed.isEmpty && result.changed) {
    stdout.writeln('Rewritten to the canonical, sorted form.');
  }
  if (result.preserved.isNotEmpty) {
    stdout.writeln('Kept outside l10n: ${result.preserved.join(', ')}.');
  }
  if (result.added.isNotEmpty) {
    stdout.writeln(
      'Review the added keys: fill their description and set shouldDisplay '
      'for the ones the references page should show.',
    );
  }
}

/// The project root, resolved from this script so the tool runs from any
/// working directory, not only from the build or the repository root.
Directory get projectRoot {
  final Directory beside = File.fromUri(Platform.script).parent.parent;
  return File('${beside.path}/$l10nPath').existsSync()
      ? beside
      : Directory.current;
}

/// The value of a '--name=value' argument, or null when it is absent.
String? _argument(List<String> args, String name) {
  for (final String arg in args) {
    if (arg.startsWith('$name=')) return arg.substring(name.length + 1);
  }
  return null;
}

Future<void> main(List<String> args) async {
  final bool check = args.contains('--check');
  final bool refresh = args.contains('--refresh');
  final bool noCache = args.contains('--no-cache');
  final bool overwrite = args.contains('--overwrite');
  final bool syncWeb = args.contains('--sync-web') || refresh;
  final bool force = args.contains('--force');
  final String mode = (_argument(args, '--mode') ?? 'debug').toLowerCase();
  final bool local = isLocalEnvironment();
  if (!force && !webSyncAllowed(mode: mode, local: local)) {
    stdout.writeln(
      'Malagasy refs tool is for a local debug or profile build only: '
      'skipped (mode: $mode, local: $local). Pass --force to override.',
    );
    return;
  }

  final Directory root = projectRoot;
  final File l10n = File('${root.path}/$l10nPath');
  final File refs = File('${root.path}/$refsPath');
  if (!l10n.existsSync()) {
    stderr.writeln('Missing $l10nPath: run the tool from the project root.');
    exit(2);
  }
  final String current = refs.existsSync() ? refs.readAsStringSync() : '{}\n';
  final MalagasyRefsSync result = buildMalagasyRefs(
    l10nSource: l10n.readAsStringSync(),
    refsJson: current,
    overwrite: overwrite,
  );

  String json = result.json;
  bool changed = result.changed;
  if (syncWeb && !check) {
    final int limit = int.tryParse(_argument(args, '--limit') ?? '') ?? 0;
    final Duration delay = Duration(
      milliseconds: int.tryParse(_argument(args, '--delay-ms') ?? '') ?? 700,
    );
    final Map<String, dynamic> entries =
        jsonDecode(json) as Map<String, dynamic>;
    final File cacheFile = File('${root.path}/$cachePath');
    final Map<String, dynamic> cache = await readWebCache(cacheFile);
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'TanoNote-tool/1.0 (Malagasy references sync)';
    Future<String?> fetch(String word) =>
        fetchExplanation(word, client: client);
    stdout.writeln(
      refresh
          ? 'Refreshing every description from malagasyword.org...'
          : 'Fetching empty descriptions from malagasyword.org...',
    );
    final WebSyncReport web = await syncWebDescriptions(
      entries: entries,
      cache: cache,
      fetch: fetch,
      limit: limit,
      delay: delay,
      refresh: refresh,
      ignoreCache: noCache,
    );
    client.close();
    await writeWebCache(cacheFile, cache);
    json = encodeRefs(entries);
    changed = json != (current.endsWith('\n') ? current : '$current\n');
    stdout.writeln(
      'Web sync: ${web.fetched} fetched, ${web.filled} filled '
      '(${web.replaced} replaced), ${web.empty} without an explanation, '
      '${web.reused} reused from cache.',
    );
  }

  report(result);
  if (check) {
    if (changed) {
      stderr.writeln(
        '$refsPath is out of date: '
        'run dart run tool/update_malagasy_refs.dart.',
      );
      exit(1);
    }
    return;
  }
  if (changed) {
    refs.writeAsStringSync(json);
    stdout.writeln('Updated $refsPath.');
  } else {
    stdout.writeln('$refsPath is already up to date.');
  }
}
