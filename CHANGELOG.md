# Changelog

All notable changes to TanoNote are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the versions
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Older releases are described on the
[releases page](https://github.com/marxhubert/tano/releases).

## [Unreleased]

### Changed

- The Licenses page now shows the licences themselves — the AGPL-3.0 text and
  the Noto Serif SIL Open Font License, read from `LICENSE` and
  `assets/fonts/NotoSerif-LICENSE.txt` — instead of a second privacy and terms
  text that duplicated the policy and contradicted it on data collection.
- The native splash screen keeps the mark in the middle of the screen and puts
  the app name at the bottom edge, as two images the platform places itself,
  instead of centring the two of them together.
- The app icon is a layered Icon Composer document on iOS, carrying its own
  light, dark and tinted appearances, and an adaptive icon on Android: the mark
  on a black background, with a themed-icon layer for Android 13+. The Xcode
  project compiles the document in place of the PNG set, which is no longer
  generated; the square PNG remains for iOS builds and Android versions before
  adaptive icons, now on the same black background.

## [1.0-beta] - 2026-09-26

### Added

- An archive sets documents aside without deleting them: an `Archive` entry in
  Settings, a page with the shared grid or list layout, document filter and
  search, per-card restore and delete, and read-only opening with Find-in.
  Restoring returns the document to Home and resets its creation date; a folder
  can never be archived.
- The four empty screens share one component and one illustration each — empty
  box, empty folder, recycle bin, no result — tinted with the app's colour.
- A `CheckDisc` mark for every “this one is chosen”: the settings' selected row,
  the theme previews, and the cards in selection mode.
- The About page reads its identity from the build (see the README, “Identity”).
  A build that names no author shows no author and no support page.
- The Malagasy word look-up opens from the language references.
- An introduction of three screens on the first launch, reachable again from
  About: what the app is, the lock that protects a note, and where things are
  kept.
- One undo for every deletion: the home list and the folder page now build the
  same notice and put the notes back the same way.
- Moving notes and locking a note or a folder now say so. Android keeps its
  SnackBar; iOS gets a toast that fades away on its own instead of an alert.
- The settings offer four text sizes, and switches for the haptic feedback and
  the sound. The chosen size multiplies the system's own text scale.
- Leaving the search remembers the query: the recent ones are offered while the
  field is empty, and can be cleared in one tap.
- Search is backed by an SQLite FTS5 index, so a large library is searched by
  prefix instead of a full scan; a build without FTS5 falls back to the old query.
- A `.tano` backup (manifest v3) now carries folders as well as notes, tasks and
  attachments, and restoring it puts each note back in its folder.
- The sort order and the document filter are shared controllers, so Home, a
  folder and Settings can no longer disagree.
- A developer-only **Labs** section closes the settings, shown in debug builds
  only. It gathers the fixtures reset — moved off the reset page — and a lab that
  sends one labelled test error to Sentry.
- The Malagasy references state that their translations and explanations are
  AI-assisted and may contain inaccuracies, and credit malagasyword.org as their
  source.
- A `tool/update_malagasy_refs.dart` CLI reconciles `malagasy_refs.json` with the
  l10n keys, sorts it and keeps a short list of extra-l10n entries (`fiteny`,
  `voambolana`). It runs from the command line or before the asset is bundled by
  the Android and iOS builds, and reports the keys it added or removed.
- The same tool fills the empty descriptions from malagasyword.org with
  `--sync-web` (the first section the page fills: Explanations in Malagasy, then
  Examples, French and English), re-fetches the filled ones with `--refresh`,
  ignores its cache with `--no-cache` and resets every entry with `--overwrite`.
  Each reference carries a `keyword`, the single word the sync and the app's link
  look up, which starts equal to the expression and can target a word inside a
  phrase. The tool is gated to a local debug or profile machine, so a build farm
  or a release build never reaches the network.

### Changed

- The Malagasy references no longer carry the placeholder Lorem ipsum: each
  description is either written by hand or fetched from the site with
  `--sync-web`.
- The references page prints the keyword as the word, a capital first letter, and
  the description as a sentence, with the AI note and the source credit below the
  list.
- **The app ships empty.** The demo folders and notes that used to fill a fresh
  install are gone; the first launch opens the introduction on a blank slate.
- **The core was rebuilt** around `lib/core`, `lib/features` and `lib/shared`:
  unified cards (`EntityCard`), list rendering (`EntitySliver`), selection
  (`SelectionController`), dialogs, covers and a rewritten FAB.
- The type scale holds eight sizes; colours, spacings and radii are named
  tokens, and the theme preview reads them instead of copying them.
- The editor's title, metadata line and content share the same inset, and the
  empty screens hold their place when the keyboard opens.
- The app's animations read three named durations instead of six loose ones.
- The privacy policy, the licences and the About notice read the current year.
- Leaving a folder search remembers the query in the shared history, exactly as
  Home does.
- The `.tano` import summary now reports how many folders it created.
- A tablet halves and centres the document tags and the introduction's primary
  button; a phone holds the introduction in portrait.
- The four text-size choices keep a fixed slot, so a bold “A” no longer nudges
  the row, and a landscape window scrolls from the empty margin beside its
  centred column.

### Fixed

- The web sync reads a word page whatever its encoding — UTF-8, or the Latin-1
  some pages still carry — and decodes the named entities, so a word like
  “Mibanaka” is no longer missed; the descriptions also drop the bracketed
  asides such as “[ Full list ]”.
- **A hard reset left the folders and the attachments behind.** It wipes
  everything now.
- The destructive action of the reset dialog was not red: the check compared
  the English word “reset” against a translated label.
- The FAB's rule had its corners cut off; it is painted above the clipped menu
  surface now.
- “Link a note” is refused when the note is the only one, and “Move to” when the
  app holds no folder at all.
- **A failed write no longer leaves a partly-applied change.** Home, a folder and
  the editor report the storage error and reload; moving or deleting a selection
  is one database transaction.
- A backup of a large library is no longer refused: the manifest bound fits the
  import's own note limit, and an over-limit export says so instead of producing
  an unrestorable file.
- A cleartext export no longer drops folder associations on import.
- Switching the FAB from a long menu to a short one no longer lagged: a shorter
  menu snaps into place instead of animating an empty panel away.

### Security

- The repository carries no personal information: the author's name, the
  contact address and the support links are read from the build, and
  `identity.json` is ignored by git.
- A cleartext export is refused as soon as the selection holds a locked note or
  folder; locked content only leaves through a password-encrypted container.
- Destroying locked content for good — a permanent delete, or emptying the trash
  while it holds locked items — requires the device credential.
- An installation key that secure storage did not persist fails loudly instead of
  silently changing on the next launch, and a database passphrase that cannot be
  produced fails closed instead of opening the database in the clear.
- Decrypted attachments handed to the system viewer are swept from the cache
  after ten minutes.
- App Store update links are only followed when they point at Apple over HTTPS.

[Unreleased]: https://github.com/marxhubert/tano/compare/v1.0-beta...HEAD
[1.0-beta]: https://github.com/marxhubert/tano/releases/tag/v1.0-beta
