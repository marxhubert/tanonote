# Malagasy references

`assets/config/malagasy_refs.json` is the seed the app copies on first launch.
Each entry is keyed by an `AppText` key and carries:

| Field | Meaning |
| --- | --- |
| `keyword` | The single word the web sync looks up; starts as the expression. |
| `expression` | The Malagasy word shown in the references page. |
| `description` | A Malagasy definition; empty until one is written or fetched. |
| `hasWebsiteRef` | Whether the row links to malagasyword.org. |
| `shouldDisplay` | Whether the row appears in the page at all. |

`LanguageReferencesController` copies the file into the app documents directory
on first launch, keeping only the `shouldDisplay` rows and sorting them by word.
Later launches read that local copy, so editing the asset only reaches a fresh
install.

## Keeping the file in sync

`tool/update_malagasy_refs.dart` reconciles the file with the keys of
`lib/shared/config/l10n.dart`:

- a key the l10n defines and the file does not is added, with `keyword` and
  `expression` pre-filled from the Malagasy wording (then English, then the key),
  an empty description, `hasWebsiteRef: false` and `shouldDisplay: false`;
- a key the file holds, the l10n no longer defines and `preservedKeys` does not
  name is removed;
- the keys are sorted alphabetically, and any other drift in the file is
  rewritten to that canonical form.

New keys arrive with `shouldDisplay: false`: fill the description and flip the
flag for the rows the page should show.

`--overwrite` rebuilds every l10n entry from scratch: the expression is
re-derived, the description is emptied and both flags return to false. The
`preservedKeys` entries are the only exception — they are kept untouched. It is
the way to discard a batch of hand-edits and start again; no build passes it.

### Special entries

A few rows the page shows are not l10n keys — `fiteny` and `voambolana` today.
They are listed in `preservedKeys` in the tool, which never removes them and
keeps their entry untouched. Add a key there to protect another one.

## Filling the descriptions from the web

`--sync-web` asks malagasyword.org for every entry whose `description` is still
empty, looks the entry's `keyword` up, and takes the first section the word page
fills, in this order: "Explanations in Malagasy", "Examples", "Explanations in
French", then "Explanations in English". A word the Malagasy block leaves out is
still caught by its examples or a translation. It drops the sense numbers, the
`[1.1]`-style dictionary references and the markup, and stores the cleaned senses
in `description` with `hasWebsiteRef: true`.
`shouldDisplay` is never changed: the flag stays the human decision that puts the
row — and its link — on the page.

An entry that already has a description is left alone. `--refresh` (which implies
`--sync-web`) re-fetches those too: it replaces the text when the site has an
explanation and keeps it when the site has none, so a hand-written description is
never lost to a miss.

The command is local and developer only. It refuses to run on a build farm
(any `CI`, `GITHUB_ACTIONS`, … variable) or in a release build, so a GitHub
build never reaches the network; `--force` overrides the guard. Answers are
cached in the git-ignored `.dart_tool/malagasy_refs_web_cache.json` for 30 days
and fetched one at a time, so a word is only asked once and the site is not
hammered. Pass `--no-cache` to ignore it for one pass — useful after a logic
change, so a word the old code missed is fetched again.

The site answers for a single word, which is why the lookup uses `keyword` and
not `expression`: set `keyword` to a word inside a long expression — or inside a
sentence — to target it. A `keyword` set by hand is never overwritten.

## Running it

The tool is a plain Dart CLI and needs no Flutter build; it resolves the
repository from its own path, so it runs from any directory:

```
dart run tool/update_malagasy_refs.dart            # reconcile the file
dart run tool/update_malagasy_refs.dart --check     # exit 1 when out of date
dart run tool/update_malagasy_refs.dart --sync-web  # fill empty descriptions
dart run tool/update_malagasy_refs.dart --sync-web --no-cache  # ignore the cache
dart run tool/update_malagasy_refs.dart --refresh   # also redownload the filled
dart run tool/update_malagasy_refs.dart --overwrite # reset every l10n entry
```

| Argument | Effect |
| --- | --- |
| `--sync-web` | Fetch the empty descriptions from malagasyword.org. |
| `--no-cache` | Ignore the cached answers and fetch again. |
| `--refresh` | Also re-fetch the filled descriptions (implies `--sync-web`). |
| `--overwrite` | Reset every l10n entry to its default; keep the special ones. |
| `--limit=N` | Fetch at most N words this pass (0, the default, means all). |
| `--delay-ms=N` | Wait N ms between two fetches (default 700). |
| `--mode=debug\|profile\|release` | The build mode the guard reads (default debug). |
| `--force` | Run even outside a local debug/profile environment. |

A build also runs the tool before the asset is bundled, with `--sync-web` and a
small `--limit`: the `preBuild` Gradle hook on Android, and the "Sync Malagasy
refs" Xcode build phase on iOS, both passing their own build mode. The test
`test/malagasy_refs_sync_test.dart` fails in CI when the committed file drifts.

## For collaborators

To fix a Malagasy wording, edit only three fields of the entry:

| Field | What it is |
| --- | --- |
| `keyword` | The single word the web sync and the link look up. |
| `expression` | The wording the references page shows. |
| `description` | The Malagasy definition the page prints. |

Leave `hasWebsiteRef` and `shouldDisplay` alone: the first is set by
`--sync-web`, and the second is the decision that puts the row — and its link —
on the page. After editing, run `dart run tool/update_malagasy_refs.dart`: it
sorts the file and keeps its keys in step with the app.
