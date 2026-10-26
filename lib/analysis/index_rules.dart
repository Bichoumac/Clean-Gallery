/// Version of the rules applied to each item while it is indexed: the
/// capture date (`resolveCaptureDate`) and the burst id (`burstIdOf`).
///
/// Bump it when one of them changes: the next index sync then describes
/// every item again and applies the new rules, keeping other analysis
/// results. History: 1 capture dates; 2 burst ids.
const indexRulesVersion = 2;
