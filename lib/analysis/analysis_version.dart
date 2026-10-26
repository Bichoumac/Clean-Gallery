/// Version of the image analysis algorithms (perceptual hashes; blur from
/// M5).
///
/// Stored on every photo once analysed (`assets.analysis_version`); `0`
/// means not analysed yet, or analysed before its file changed. Bump it
/// whenever an algorithm changes so the engine analyses every photo again.
/// See `docs/analysis-engine.md`.
const int analysisVersion = 1;
