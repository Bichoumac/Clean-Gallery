# ADR 0019 — Similar photo search with multi-index hashing instead of a BK-tree

How pairs of similar photos are found without comparing every photo with every other, and why the brief's BK-tree was replaced.

Last updated: 2026-10-27 — Milestone M4

- **Status**: Proposed to the product owner at the end of M4 (implemented, awaiting approval)
- **Date**: 2026-10-27

## Context

The brief: "Search through a **BK-tree** (no O(n²) comparison). A pair is similar if: pHash distance ≤ strict threshold (default 6) and aspect ratio within ±2 %; or time difference ≤ time window (default 10 s) and pHash distance ≤ loose threshold (default 12)."

A BK-tree was implemented first and measured on 30,000 photos. A BK-tree prunes a branch only when the query is far from the branch's distance. pHashes of unrelated photos sit around 32 bits apart, so at a radius of 6 almost no branch can be skipped:

| Search, 30,000 photos, radius 6 (AOT, development laptop) | Time |
| --- | --- |
| Every pair compared (brute force) | 21 s |
| BK-tree, nodes in flat arrays | 117 s (25 % of the nodes visited per query) |
| BK-tree, nodes with maps (first version) | 189 s |
| Multi-index hashing (this decision) | 0.6–1.1 s |

The laptop's CPU was throttled to 600 MHz during part of these runs, so absolute times vary; the ranking did not change between runs.

## Decision

- **Strict rule: multi-index hashing** ([hash_index.dart](../../lib/analysis/hash_index.dart)). Each pHash is cut into four 16-bit blocks; each block value indexes the photos having it (flat arrays). Two hashes at most *r* bits apart differ by at most ⌊r / 4⌋ bits in at least one block (pigeonhole), so for each photo only the photos whose block is within ⌊r / 4⌋ bits are compared. The search is exact: the same pairs as a BK-tree or brute force, which a test checks at radii 0 to 20.
- **Loose rule: time window**. Photos are sorted by capture date and each is compared only with those of the next *window* seconds. No index is needed.
- **Groups: union-find** over the similar pairs, minus pairs marked "Not duplicates" and pairs already in one exact or burst group ([similarity.dart](../../lib/analysis/similarity.dart)).
- **Hashes as 32-bit halves** in the search loop: Dart boxes integers that do not fit in 63 bits, which made every comparison on full 64-bit hashes allocate.
- **Advanced mode caps the strict threshold at 10.** At 12, unrelated random photos already start to match (90 false groups in the benchmark) and the search takes several seconds; at 20 it took over a minute and grouped everything. The loose threshold goes up to 20, since only photos taken close together are compared.

## Alternatives considered

- **BK-tree as in the brief**: correct, but slower than brute force on this kind of data (table above).
- **Brute force with 32-bit halves**: simple and exact, 21 s for 30,000 photos at any radius, quadratic beyond.
- **Locality-sensitive hashing (random bit sampling)**: fast, but approximate: some similar pairs would be missed.

## Consequences

- Grouping 30,000 photos takes about a second with the default thresholds and a few seconds at High, in an isolate; changing the sensitivity regroups without reading any thumbnail.
- The brief's wording "BK-tree" is not followed literally; its intent (no O(n²) comparison, exact thresholds) is.
- If the product owner prefers the BK-tree for conformity, it can come back behind the same `findSimilarGroups` function; tests compare against brute force either way.
