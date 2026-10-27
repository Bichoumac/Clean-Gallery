/// Version of the image analysis algorithms: perceptual hashes, sharpness
/// and brightness.
///
/// Stored on every photo once analysed (`assets.analysis_version`); `0`
/// means not analysed yet, or analysed before its file changed. Bump it
/// whenever an algorithm changes so the engine analyses every photo again.
/// See `docs/analysis-engine.md`.
///
/// History: 1 perceptual hashes on 128-pixel thumbnails (M4); 2 sharpness
/// and brightness added, thumbnails of 256 pixels (M5); 3 contrast added
/// (M6; the schema 4 migration keeps version 2 photos that are sharp
/// enough, which do not need it).
const int analysisVersion = 3;
