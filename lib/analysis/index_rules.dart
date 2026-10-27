/// Version of the rules applied to each item while it is indexed: the
/// capture date (`resolveCaptureDate`), the burst id (`burstIdOf`) and
/// whether it is a screenshot (`isScreenshot`).
///
/// Bump it when one of them changes: the next index sync then describes
/// every item again and applies the new rules, keeping other analysis
/// results. History: 1 capture dates; 2 burst ids; 3 screenshots.
const indexRulesVersion = 3;
