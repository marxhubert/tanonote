import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tano/shared/config/app_config.dart';
import 'package:tano/shared/config/l10n.dart';
import 'package:tano/shared/config/language_references_controller.dart';
import 'package:tano/shared/widgets/page_layout.dart';
import 'package:tano/shared/widgets/theme_toggle.dart';
import 'package:tano/shared/widgets/theme.dart';

class LanguageReferencesPage extends StatefulWidget {
  const LanguageReferencesPage({super.key});

  @override
  State<LanguageReferencesPage> createState() => _LanguageReferencesPageState();
}

class _LanguageReferencesPageState extends State<LanguageReferencesPage> {
  /// The one inline link of the credit line; held so it can be disposed.
  final TapGestureRecognizer _websiteLink = TapGestureRecognizer();

  @override
  void dispose() {
    _websiteLink.dispose();
    super.dispose();
  }

  /// The first letter of [value] in upper case, the rest untouched.
  String _capitalized(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  /// [value] as a sentence: a capital first letter and a closing period.
  String _asSentence(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    final String capitalized = _capitalized(trimmed);
    final String last = capitalized[capitalized.length - 1];
    return last == '.' || last == '?' || last == '!'
        ? capitalized
        : '$capitalized.';
  }

  String _buildUrl(String word) {
    final String normalized = word.toLowerCase().replaceAll('-', '');
    return '${AppConfig.malagasyWordUrl}$normalized';
  }

  Future<void> _launchUrl(String word) async {
    final String url = _buildUrl(word);
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _openWebsite() async {
    final Uri uri = Uri.parse(AppConfig.malagasyWordHomeUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<MalagasyWordRef> refs =
        LanguageReferencesController.instance.references;

    return PageScaffold(
      title: AppText.tr('language_references'),
      headerMetadata: 'Teny ${refs.length} isa',
      actions: const [ThemeToggleButton()],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            appPaddingLarge,
            appPaddingMedium,
            appPaddingLarge,
            0.0,
          ),
          sliver: SliverToBoxAdapter(
            child: Text(
              "Natao ity hanazavana ireo teny sy fiteny nampiasaina ato amin'ity rindrankajy ity. Niezahana ho voambolana malagasy ofisialy, saingy misy fiteny mifanendrika bebe kokoa amin'ny angaly tiana havoitra. \n\nIreto izy ireo raha mahaliana anao ny heviny. Araho ny rohy ho fanampim-panazavana misimisy kokoa.",
              style: TextStyle(
                fontSize: TanoText.label,
                color: mutedTextColor(context),
                height: 1.5,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: appPaddingLarge,
            vertical: sectionGap,
          ),
          sliver: SliverList.separated(
            itemCount: refs.length,
            separatorBuilder: (context, index) => Divider(
              height: 1.0,
              thickness: 0.5,
              color: primaryTextColor(context).withValues(alpha: 0.08),
            ),
            itemBuilder: (context, index) {
              final ref = refs[index];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: appPaddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: TextStyle(
                                color: mutedTextColor(context),
                                fontSize: TanoText.label,
                                fontWeight: FontWeight.normal,
                              ),
                              children: [
                                TextSpan(text: "${index + 1}. "),
                                TextSpan(
                                  text: _capitalized(ref.keyword),
                                  style: TextStyle(
                                    color: primaryTextColor(context),
                                    fontSize: TanoText.listTitle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (ref.hasWebsiteRef)
                          GestureDetector(
                            onTap: () => _launchUrl(ref.lookupWord),
                            child: const Icon(
                              Symbols.open_in_new,
                              size: 14.0,
                              color: tanoAmber,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      _asSentence(ref.description),
                      style: TextStyle(
                        color: mutedTextColor(context),
                        fontSize: TanoText.label,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            appPaddingLarge,
            appPaddingMedium,
            appPaddingLarge,
            appPaddingLarge,
          ),
          sliver: SliverToBoxAdapter(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: TanoText.label,
                  color: mutedTextColor(context),
                  height: 1.5,
                ),
                children: <InlineSpan>[
                  const TextSpan(
                    text:
                        "Nataon'ny AI ireo fandikan-teny sy fanazavana ireo ary "
                        'mety misy tsy fahamarinana. Nalaina tao amin\'ny '
                        'tranokala ',
                  ),
                  TextSpan(
                    text: 'malagasyword.org',
                    style: const TextStyle(
                      color: tanoAmber,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: _websiteLink..onTap = _openWebsite,
                  ),
                  const TextSpan(
                    text:
                        ' ny ankamaroan\'ny fanazavana. Raha mila fanazavana '
                        'feno sy voamarina, tsidiho io tranokala io.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
