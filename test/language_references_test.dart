import 'package:flutter_test/flutter_test.dart';
import 'package:tano/shared/config/language_references_controller.dart';

MalagasyWordRef _ref({String word = 'Fandraisana', String keyword = ''}) =>
    MalagasyWordRef(
      key: 'home',
      word: word,
      keyword: keyword,
      description: '',
      hasWebsiteRef: true,
      shouldDisplay: true,
    );

void main() {
  test('the link looks the keyword up, falling back to the wording', () {
    expect(_ref(keyword: 'fandraisana').lookupWord, 'fandraisana');
    expect(_ref().lookupWord, 'Fandraisana');
  });

  test('a keyword survives the runtime round trip', () {
    final MalagasyWordRef ref = _ref(
      word: 'Fandraisana an-trano',
      keyword: 'fandraisana',
    );
    expect(ref.toJson()['keyword'], 'fandraisana');

    final MalagasyWordRef reloaded = MalagasyWordRef.fromJson(ref.toJson());
    expect(reloaded.word, 'Fandraisana an-trano');
    expect(reloaded.lookupWord, 'fandraisana');
  });

  test('a runtime file written before the field falls back to the word', () {
    final MalagasyWordRef ref = MalagasyWordRef.fromJson(<String, dynamic>{
      'key': 'home',
      'word': 'Fandraisana',
      'description': '',
      'hasWebsiteRef': true,
      'shouldDisplay': true,
    });
    expect(ref.keyword, 'Fandraisana');
    expect(ref.lookupWord, 'Fandraisana');
  });

  test('an old runtime file is detected for migration', () {
    expect(
      needsKeywordMigration(<dynamic>[
        <String, dynamic>{'key': 'home', 'word': 'Fandraisana'},
      ]),
      isTrue,
    );
    expect(
      needsKeywordMigration(<dynamic>[
        <String, dynamic>{
          'key': 'home',
          'word': 'Fandraisana',
          'keyword': 'fandraisana',
        },
      ]),
      isFalse,
    );
  });
}
