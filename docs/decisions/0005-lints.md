# ADR 0005 — `very_good_analysis` lints and exceptions

Which lint set the project uses, the extra strictness on top of it, and the one rule turned off.

Last updated: 2026-10-25 — Milestone M0

- **Status**: Accepted
- **Date**: 2026-10-25

## Context

The brief asks for strict lints with either `flutter_lints` or `very_good_analysis`.

## Decision

- **`very_good_analysis` 11.0.0**, the stricter of the two, in [analysis_options.yaml](../../analysis_options.yaml).
- Analyzer modes `strict-casts`, `strict-inference` and `strict-raw-types` turned on.
- `public_member_api_docs` on: public APIs need `///` comments, as the brief requires.
- Generated files are excluded from analysis.

## Exception: `unnecessary_type_name_in_constructor` is off

This recent rule, enabled by `very_good_analysis` 11, rewrites every constructor declaration from `const HomeShell({super.key})` to `const new({super.key})`. That syntax is valid in current Dart but is not used by Flutter, its templates, its documentation or most packages, so it would make the code harder to read for anyone familiar with Flutter. Revisit if the Flutter team adopts it.

## Consequences

- `flutter analyze` must report no issues before every commit; CI enforces it.
- Formatting follows `dart format` defaults and is also checked in CI.
