# Contributing

Thanks for your interest in TanoNote. This repository is the open-source base,
released under the **GNU Affero General Public License v3.0** (AGPL-3.0).

## Contributor License Agreement

Before a contribution can be merged, you must agree to the
[Contributor License Agreement](CLA.md). It keeps the copyright of your work with
you while giving the maintainer the right to distribute the same code under the
project's open-source licence and under other licence terms. Without it, a
contribution can only ever live in the AGPL project.

Set it up with the [CLA Assistant](https://github.com/apps/cla-assistant) GitHub
App, or sign the agreement when a pull request asks you to.

## Workflow

- Open an issue to discuss a change before writing a large patch.
- Branch from `main` and keep each change focused.
- Run `flutter analyze` and `flutter test` (the golden tests are compared
  locally: `flutter test --tags golden`).
- Keep this repository complete and buildable on its own: no code here may
  depend on anything that is not part of it.
- Update the documentation and the changelog when the behaviour changes.
