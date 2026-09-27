# Privacy and distribution declarations

The app has no user account or central content storage. Notes, folders, attachments
and preferences live locally.

Optional diagnostics require consent. Allowed technical fields and operational
limits are in [observability](observability.md). No user identity, note content,
stable device ID or precise location is permitted. Locale region is not GPS or
IP-based country detection. Receiving a network request exposes an IP to its endpoint;
non-retention requires service configuration and cannot be guaranteed by Dart code.
The only other network use is a link the user opens (the author, support, or a
dictionary entry from the references page), which the system browser handles.

The policy is displayed through `PrivacyPage` / `l10n.dart` and published under
`site/privacy/` in English only. App and public policy must match each release.
Store declarations must reflect the actual binary, SDK behavior and configured
services, not an old checklist. Review the iOS privacy manifest with native payloads.

Local deletion cannot erase exports, other applications' copies or reports already
sent. Known pre-release migration leftovers are discarded at database initialization.
Encrypted orphans are collected at startup from a complete reference snapshot.
Exhaustive reset and native validation remain release work.

Author attribution, bundle identifier, repository URLs and the public contact address
identify the publisher. They are distinct from user data and intentionally public.
