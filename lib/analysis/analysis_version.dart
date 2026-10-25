/// Version of the analysis algorithms (dates, hashes, grouping, scoring).
///
/// Stored on every indexed asset. Bump it whenever an algorithm changes so
/// the incremental indexer re-analyses the items computed by the old version.
/// See `docs/analysis-engine.md`.
const int analysisVersion = 1;
