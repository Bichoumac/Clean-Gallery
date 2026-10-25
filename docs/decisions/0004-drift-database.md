# ADR 0004 — Drift on a background isolate

Why the database is Drift, how it is opened, and how migrations are handled from the first version.

Last updated: 2026-10-25 — Milestone M0

- **Status**: Accepted
- **Date**: 2026-10-25

## Context

The app indexes up to tens of thousands of media items, stores analysis results and must never freeze the UI. The brief asks for Drift running in a background isolate, with migrations from day one.

## Decision

- **Drift** with tables declared in Dart ([tables.dart](../../lib/core/database/tables.dart)) and type-safe queries.
- **`drift_flutter`'s `driftDatabase()`** opens the file on a background isolate; the UI isolate only sends queries and receives results.
- **Enums stored as text** (`textEnum`) so the database stays readable when debugging and enum order can change freely.
- **Foreign keys enabled** on every connection, with cascade deletes from `assets`, so removing an asset never leaves orphan rows.
- **Migrations**: `schemaVersion` starts at 1, with an empty `onUpgrade` ready for `if (from < n)` steps. History lives in [database.md](../database.md#migrations).
- **`analysis_version` column** per asset, separate from the schema version, so an algorithm change triggers re-analysis without a schema migration.

## Alternatives considered

- **`sqflite` with raw SQL**: no compile-time checks, manual mapping.
- **Isar / ObjectBox**: fast, but weaker relational queries (duplicate groups, joins with trash) and uncertain long-term maintenance for Isar.

## Consequences

- Generated code (`app_database.g.dart`) must be rebuilt after any table change.
- Before the first release with a schema change, schema snapshots (`drift_dev schema dump`) and migration tests will be added, so each upgrade path is tested.
