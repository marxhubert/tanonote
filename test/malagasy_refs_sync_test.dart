import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/update_malagasy_refs.dart';

void main() {
  const String l10n = '''
  static const Map<String, String> _en = <String, String>{
    'home': 'Home',
    'search': 'Search',
    'zeta': 'Zeta',
    'alpha': 'Alpha',
    if (kDebugMode) 'dev_only': 'Dev',
  };
  static const Map<String, String> _fr = <String, String>{
    'home': 'Accueil',
    'search': 'Recherche',
    'zeta': 'Zeta',
    'alpha': 'Alpha',
  };
  static const Map<String, String> _mg = <String, String>{
    'home': 'Fandraisana',
    'search': 'Karohy',
    'zeta': 'Zeta',
    'alpha': 'Alpha',
  };
  ''';

  test('adds a missing key pre-filled, keeps the others, and sorts', () {
    final MalagasyRefsSync result = buildMalagasyRefs(
      l10nSource: l10n,
      refsJson: jsonEncode(<String, dynamic>{
        'home': <String, dynamic>{
          'expression': 'Fandraisana',
          'description': 'kept',
          'hasWebsiteRef': true,
          'shouldDisplay': true,
        },
      }),
    );
    final Map<String, dynamic> json =
        jsonDecode(result.json) as Map<String, dynamic>;

    expect(result.removed, isEmpty);
    expect(result.added, <String>['alpha', 'dev_only', 'search', 'zeta']);
    expect(json['alpha'], <String, dynamic>{
      'keyword': 'Alpha',
      'expression': 'Alpha',
      'description': '',
      'hasWebsiteRef': false,
      'shouldDisplay': false,
    });
    // A key both sides share keeps its content, with a keyword added.
    expect(json['home'], <String, dynamic>{
      'keyword': 'Fandraisana',
      'expression': 'Fandraisana',
      'description': 'kept',
      'hasWebsiteRef': true,
      'shouldDisplay': true,
    });
    // Alphabetical order.
    expect(json.keys.toList(), <String>[
      'alpha',
      'dev_only',
      'home',
      'search',
      'zeta',
    ]);
  });

  test('removes a key the l10n no longer defines', () {
    final MalagasyRefsSync result = buildMalagasyRefs(
      l10nSource: l10n,
      refsJson: jsonEncode(<String, dynamic>{
        'home': <String, dynamic>{
          'expression': 'x',
          'description': '',
          'hasWebsiteRef': false,
          'shouldDisplay': false,
        },
        'gone': <String, dynamic>{
          'expression': 'y',
          'description': '',
          'hasWebsiteRef': false,
          'shouldDisplay': false,
        },
      }),
    );

    expect(result.removed, <String>['gone']);
    expect(result.json.contains('"gone"'), isFalse);
  });

  test('pre-fills from the Malagasy wording, then English, then the key', () {
    const String source = '''
  static const Map<String, String> _en = <String, String>{
    'only_en': 'English only',
  };
  static const Map<String, String> _fr = <String, String>{};
  static const Map<String, String> _mg = <String, String>{
    'only_en': 'Malagasy wins',
  };
  ''';
    final Map<String, dynamic> json =
        jsonDecode(buildMalagasyRefs(l10nSource: source, refsJson: '{}').json)
            as Map<String, dynamic>;

    expect(json['only_en']['expression'], 'Malagasy wins');
  });

  test('keeps the extra-l10n entries the references page relies on', () {
    final MalagasyRefsSync result = buildMalagasyRefs(
      l10nSource: l10n,
      refsJson: jsonEncode(<String, dynamic>{
        'fiteny': <String, dynamic>{
          'expression': 'Fiteny',
          'description': 'kept',
          'hasWebsiteRef': true,
          'shouldDisplay': true,
        },
        'voambolana': <String, dynamic>{
          'expression': 'Voambolana',
          'description': 'kept',
          'hasWebsiteRef': true,
          'shouldDisplay': true,
        },
        'gone': <String, dynamic>{
          'expression': 'x',
          'description': '',
          'hasWebsiteRef': false,
          'shouldDisplay': false,
        },
      }),
    );
    final Map<String, dynamic> json =
        jsonDecode(result.json) as Map<String, dynamic>;

    // fiteny and voambolana back no l10n key, yet they are kept.
    expect(result.preserved, <String>['fiteny', 'voambolana']);
    expect(result.removed, <String>['gone']);
    expect(json.containsKey('fiteny'), isTrue);
    expect(json.containsKey('voambolana'), isTrue);
    expect(result.json.contains('"gone"'), isFalse);
  });

  test('flags an unsorted file as out of date', () {
    final MalagasyRefsSync canonical = buildMalagasyRefs(
      l10nSource: l10n,
      refsJson: '{}',
    );
    final Map<String, dynamic> entries =
        jsonDecode(canonical.json) as Map<String, dynamic>;
    final String shuffled = jsonEncode(<String, dynamic>{
      'zeta': entries['zeta'],
      'home': entries['home'],
      'alpha': entries['alpha'],
      'search': entries['search'],
      'dev_only': entries['dev_only'],
    });

    final MalagasyRefsSync result = buildMalagasyRefs(
      l10nSource: l10n,
      refsJson: shuffled,
    );
    expect(result.added, isEmpty);
    expect(result.removed, isEmpty);
    expect(result.changed, isTrue);
  });

  test('extracts and cleans the Malagasy explanations', () {
    const String html = '''
    <table width='100%' cellspacing='4'>
    <tr valign='top'>
    <td width='18%' align='right'>Explanations in Malagasy&nbsp;</td>
    <td>
    <span class='rminute'>19</span>&nbsp;Feo avoakan' ny vavan' ny olombelona: <i>Tsy nanonona teny izy</i>
    <br/>
    <span class='rminute'>21</span>&nbsp;Enti-milaza koa ny karazan-teny: <i>Mahay teny anglisy ve ianao?</i>
     <span class='source'>[<a href='/bins/teny2/x#mg.nt'>1.1</a>]</span><br/>
    </td>
    </tr></table>
    ''';
    expect(
      firstExplanation(html),
      "Feo avoakan' ny vavan' ny olombelona: Tsy nanonona teny izy ; "
      "Enti-milaza koa ny karazan-teny: Mahay teny anglisy ve ianao?",
    );
  });

  test('returns null when a page holds no explanation section', () {
    expect(firstExplanation('<html>nothing</html>'), isNull);
    const String empty =
        "<td>Explanations in Malagasy&nbsp;</td><td><br/></td>";
    expect(firstExplanation(empty), isNull);
  });

  test('falls through the sections in order', () {
    const String html = '''
    <td>Explanations in Malagasy&nbsp;</td><td><br/></td>
    <td>Examples&nbsp;</td><td><span class='rminute'>1</span>&nbsp;Ohatra iray</td>
    <td>Explanations in English&nbsp;</td><td>a word</td>
    ''';
    expect(firstExplanation(html), 'Ohatra iray');
    expect(explanationSection(html, 'Explanations in English'), 'a word');
  });

  test('prefers the earliest section that has content', () {
    const String html = '''
    <td>Explanations in Malagasy&nbsp;</td><td>Teny</td>
    <td>Examples&nbsp;</td><td>Ohatra</td>
    ''';
    expect(firstExplanation(html), 'Teny');
  });

  test('decodes the entities the word pages use', () {
    expect(
      decodeEntities('a&nbsp;b &amp; c &#39;d&#39; &#x27;e&#x27;'),
      "a b & c 'd' 'e'",
    );
  });

  test('the tool runs only on a local debug or profile machine', () {
    expect(webSyncAllowed(mode: 'debug', local: true), isTrue);
    expect(webSyncAllowed(mode: 'profile', local: true), isTrue);
    expect(webSyncAllowed(mode: 'release', local: true), isFalse);
    expect(webSyncAllowed(mode: 'debug', local: false), isFalse);
  });

  test('a CI variable marks the machine as a build farm', () {
    expect(isLocalEnvironment(<String, String>{}), isTrue);
    expect(isLocalEnvironment(<String, String>{'CI': 'true'}), isFalse);
    expect(
      isLocalEnvironment(<String, String>{'GITHUB_ACTIONS': 'true'}),
      isFalse,
    );
    expect(isLocalEnvironment(<String, String>{'CI': 'false'}), isTrue);
  });

  test('the web sync skips a filled description by default', () async {
    final Map<String, dynamic> entries = <String, dynamic>{
      'keep': <String, dynamic>{
        'expression': 'Tenina',
        'description': 'manual',
        'hasWebsiteRef': false,
        'shouldDisplay': true,
      },
      'fill': <String, dynamic>{
        'expression': 'Fandraisana',
        'description': '',
        'hasWebsiteRef': false,
        'shouldDisplay': false,
      },
    };
    final List<String> asked = <String>[];
    final WebSyncReport report = await syncWebDescriptions(
      entries: entries,
      cache: <String, dynamic>{},
      fetch: (String word) async {
        asked.add(word);
        return 'site';
      },
      limit: 0,
      delay: Duration.zero,
    );

    expect(asked, <String>['Fandraisana']);
    expect(entries['keep']['description'], 'manual');
    expect(entries['fill']['description'], 'site');
    expect(entries['fill']['hasWebsiteRef'], isTrue);
    expect(report.filled, 1);
    expect(report.replaced, 0);
  });

  test('a refresh replaces a filled description, keeps it on a miss', () async {
    final Map<String, dynamic> entries = <String, dynamic>{
      'update': <String, dynamic>{
        'expression': 'Fandraisana',
        'description': 'old',
        'hasWebsiteRef': false,
        'shouldDisplay': true,
      },
      'keep': <String, dynamic>{
        'expression': 'Tsy misy',
        'description': 'manual',
        'hasWebsiteRef': true,
        'shouldDisplay': true,
      },
    };
    final WebSyncReport report = await syncWebDescriptions(
      entries: entries,
      cache: <String, dynamic>{},
      fetch: (String word) async => word == 'Fandraisana' ? 'clean' : null,
      limit: 0,
      delay: Duration.zero,
      refresh: true,
    );

    expect(entries['update']['description'], 'clean');
    expect(entries['update']['hasWebsiteRef'], isTrue);
    expect(entries['keep']['description'], 'manual');
    expect(entries['keep']['hasWebsiteRef'], isTrue);
    expect(report.filled, 1);
    expect(report.replaced, 1);
    expect(report.empty, 1);
  });

  test('a fresh cache answer is reused without fetching', () async {
    final Map<String, dynamic> entries = <String, dynamic>{
      'fill': <String, dynamic>{
        'expression': 'Fandraisana',
        'description': '',
        'hasWebsiteRef': false,
        'shouldDisplay': false,
      },
    };
    final Map<String, dynamic> cache = <String, dynamic>{
      'Fandraisana': <String, dynamic>{
        'description': 'cached',
        'fetchedAt': DateTime.now().toIso8601String(),
      },
    };
    int calls = 0;
    final WebSyncReport report = await syncWebDescriptions(
      entries: entries,
      cache: cache,
      fetch: (String word) async {
        calls++;
        return 'site';
      },
      limit: 0,
      delay: Duration.zero,
    );

    expect(calls, 0);
    expect(entries['fill']['description'], 'cached');
    expect(report.reused, 1);
  });

  test('overwrite resets the l10n entries but keeps the special ones', () {
    final MalagasyRefsSync result = buildMalagasyRefs(
      l10nSource: l10n,
      refsJson: jsonEncode(<String, dynamic>{
        'home': <String, dynamic>{
          'expression': 'old',
          'description': 'hand-written',
          'hasWebsiteRef': true,
          'shouldDisplay': true,
        },
        'fiteny': <String, dynamic>{
          'expression': 'Fiteny',
          'description': 'kept',
          'hasWebsiteRef': true,
          'shouldDisplay': true,
        },
      }),
      overwrite: true,
    );
    final Map<String, dynamic> json =
        jsonDecode(result.json) as Map<String, dynamic>;

    // home is an l10n key: reset to the default entry.
    expect(json['home'], <String, dynamic>{
      'keyword': 'Fandraisana',
      'expression': 'Fandraisana',
      'description': '',
      'hasWebsiteRef': false,
      'shouldDisplay': false,
    });
    expect(result.overwritten, contains('home'));
    // fiteny backs no l10n key: it is the exception, kept untouched.
    expect(json['fiteny'], <String, dynamic>{
      'keyword': 'Fiteny',
      'expression': 'Fiteny',
      'description': 'kept',
      'hasWebsiteRef': true,
      'shouldDisplay': true,
    });
    expect(result.preserved, <String>['fiteny']);
  });

  test('a keyword already set is never overwritten', () {
    final MalagasyRefsSync result = buildMalagasyRefs(
      l10nSource: l10n,
      refsJson: jsonEncode(<String, dynamic>{
        'home': <String, dynamic>{
          'keyword': 'fandraisana',
          'expression': 'Fandraisana an-trano',
          'description': 'kept',
          'hasWebsiteRef': true,
          'shouldDisplay': true,
        },
      }),
    );
    final Map<String, dynamic> json =
        jsonDecode(result.json) as Map<String, dynamic>;

    // The expression is a phrase; the hand-picked keyword stays.
    expect(json['home']['keyword'], 'fandraisana');
    expect(json['home']['expression'], 'Fandraisana an-trano');
    expect(json['home']['description'], 'kept');
  });

  test('the web sync looks the keyword up, not the expression', () async {
    final Map<String, dynamic> entries = <String, dynamic>{
      'home': <String, dynamic>{
        'keyword': 'fandraisana',
        'expression': 'Fandraisana an-trano',
        'description': '',
        'hasWebsiteRef': false,
        'shouldDisplay': false,
      },
    };
    final List<String> asked = <String>[];
    await syncWebDescriptions(
      entries: entries,
      cache: <String, dynamic>{},
      fetch: (String word) async {
        asked.add(word);
        return 'explained';
      },
      limit: 0,
      delay: Duration.zero,
    );

    expect(asked, <String>['fandraisana']);
    expect(entries['home']['description'], 'explained');
  });

  test(
    'ignoring the cache fetches again and stores the fresh answer',
    () async {
      final Map<String, dynamic> entries = <String, dynamic>{
        'fill': <String, dynamic>{
          'keyword': 'Fandraisana',
          'expression': 'Fandraisana',
          'description': '',
          'hasWebsiteRef': false,
          'shouldDisplay': false,
        },
      };
      final Map<String, dynamic> cache = <String, dynamic>{
        'Fandraisana': <String, dynamic>{
          'description': 'stale',
          'fetchedAt': DateTime.now().toIso8601String(),
        },
      };
      int calls = 0;
      final WebSyncReport report = await syncWebDescriptions(
        entries: entries,
        cache: cache,
        fetch: (String word) async {
          calls++;
          return 'fresh';
        },
        limit: 0,
        delay: Duration.zero,
        ignoreCache: true,
      );

      expect(calls, 1);
      expect(entries['fill']['description'], 'fresh');
      expect(cache['Fandraisana']['description'], 'fresh');
      expect(report.reused, 0);
    },
  );

  test('decodes a page the UTF-8 decoder rejects', () {
    // 0xe9 is 'é' in Latin-1 and an invalid stand-alone UTF-8 byte.
    expect(decodeHtml(<int>[0x46, 0xe9]), 'Fé');
    expect(decodeHtml(utf8.encode('Fané taona')), 'Fané taona');
  });

  test('decodes the named entities the pages use', () {
    expect(
      decodeEntities('a&ntilde;entana &agrave; &eacute; &amp; fin'),
      'añentana à é & fin',
    );
  });

  test('drops a bracketed aside from a sense', () {
    const String html = '''
    <td>Examples&nbsp;</td><td><span class='rminute'>1</span>&nbsp;imperative of passive verb aiditra [<a href='/x'>Full list</a>]</td>
    ''';
    expect(firstExplanation(html), 'imperative of passive verb aiditra');
  });

  test('the committed references file is in sync with l10n', () {
    final MalagasyRefsSync result = buildMalagasyRefs(
      l10nSource: File(l10nPath).readAsStringSync(),
      refsJson: File(refsPath).readAsStringSync(),
    );

    expect(
      result.changed,
      isFalse,
      reason: 'Run: dart run tool/update_malagasy_refs.dart',
    );
  });
}
