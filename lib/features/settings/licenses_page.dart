import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tano/shared/config/app_config.dart';
import 'package:tano/shared/config/l10n.dart';
import 'package:tano/shared/widgets/page_layout.dart';
import 'package:tano/shared/widgets/theme.dart';
import 'package:tano/shared/widgets/theme_toggle.dart';

/// The legal notices the app ships under.
///
/// Both texts are the canonical English originals, bundled verbatim: the
/// project licence, read from the repository's own `LICENSE`, and the font
/// licence, kept next to the font it covers. Neither is translated — a
/// translation would not be the licence itself.
class LicensesPage extends StatefulWidget {
  const LicensesPage({super.key});

  /// The notices shown, as (title, asset path) pairs, in reading order. The
  /// titles are the licences' own names, which are proper nouns and so are
  /// never translated.
  static const List<(String, String)> notices = <(String, String)>[
    ('GNU Affero General Public License v3.0', 'LICENSE'),
    (
      'Noto Serif — SIL Open Font License 1.1',
      'assets/fonts/NotoSerif-LICENSE.txt',
    ),
  ];

  @override
  State<LicensesPage> createState() => _LicensesPageState();
}

class _LicensesPageState extends State<LicensesPage> {
  /// The notice texts, by asset path. Empty until the bundle has been read.
  final Map<String, String> _texts = <String, String>{};
  bool _isLoading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    try {
      final Map<String, String> loaded = <String, String>{};
      for (final (String _, String asset) in LicensesPage.notices) {
        loaded[asset] = await rootBundle.loadString(asset);
      }
      if (!mounted) return;
      setState(() {
        _texts
          ..clear()
          ..addAll(loaded);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _failed = true;
      });
    }
  }

  /// The copyright line above the notices. A build that names no author shows
  /// the year alone, the way the About page shows no author.
  String get _copyright => AppConfig.authorName.isEmpty
      ? '© ${AppConfig.year}'
      : '© ${AppConfig.year}, ${AppConfig.authorName}';

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: sectionGap),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      );
    }
    if (_failed) {
      // The same words as every other loading failure in the app.
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: sectionGap),
          child: Text(
            AppText.tr('load_error_message'),
            style: TextStyle(
              color: primaryTextColor(context),
              fontSize: 16.0,
              height: 1.6,
            ),
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildListDelegate(<Widget>[
        for (final (String title, String asset) in LicensesPage.notices)
          _Notice(title: title, text: _texts[asset] ?? ''),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: AppText.tr('licenses'),
      actions: const <Widget>[ThemeToggleButton()],
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20.0, appPaddingTight, 20.0, 0.0),
          sliver: SliverToBoxAdapter(
            child: Text(
              _copyright,
              style: TextStyle(
                color: mutedTextColor(context),
                fontSize: TanoText.label,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 40.0),
          sliver: _buildBody(context),
        ),
      ],
    );
  }
}

/// One notice: the licence's own name, then its verbatim text.
class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              color: primaryTextColor(context),
              fontSize: TanoText.listTitle,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            text,
            style: TextStyle(
              color: primaryTextColor(context),
              fontSize: 16.0,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
