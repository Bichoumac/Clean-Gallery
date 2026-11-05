# ADR 0029 — Face detection and recognition models

Which models People would bundle, what is known about their licenses and what must be measured before any feature code is written.

Last updated: 2026-11-05 — Milestone M10

- **Status**: Proposed, waiting for the product owner's decision on the licensing risk and for a speed measure on the Galaxy A54
- **Date**: 2026-11-05

## Context

M10 needs a face detector and an embedding model that are bundled in the app and run on the phone only, with no download, no cloud API and no ML Kit ([specification](../../prompt.md#people-face-recognition-added-2026-11-01)). Their licenses must allow an app with ads, and the choice, license, size and speed must be recorded here before any code.

A release APK is 26.6 MB today (build of 2026-11-05).

## Proposal

| Part | Model | License as published | File size |
| --- | --- | --- | --- |
| Detection | YuNet, `face_detection_yunet_2023mar` from OpenCV Zoo | MIT | 232 KB (`_int8`: 100 KB) |
| Embedding | SFace (a MobileFaceNet), `face_recognition_sface_2021dec_int8` from OpenCV Zoo | Apache 2.0 | 9.9 MB (float: 38.7 MB) |

YuNet returns the five landmarks SFace expects for alignment. Both come from one source with a published accuracy evaluation (SFace int8: 0.9932).

The int8 embedding model is about three times the spec's "a few MB"; it is the smallest SFace published.

**Runtime**, to confirm with the measure: `flutter_onnxruntime` (MIT, 1.9.0) runs the published files unchanged. `flutter_litert` (Apache 2.0, 3.9.4) would need a conversion to TFLite, so the shipped file would no longer be the one published. Whichever is kept sits behind an interface in `lib/platform/`, and must be read for network calls before it is added.

## The licensing risk

The license on the files does not settle the rights on the training data.

- OpenCV Zoo publishes the SFace folder under Apache 2.0, but the [original repository](https://github.com/zhongyy/SFace) declares no license at all.
- That repository reports models trained on CASIA-WebFace, VGGFace2 and MS-Celeb-1M. Which one produced the OpenCV Zoo file was not established. These are collections of photos of real people, with their own terms, which were not reviewed here.
- The same question applies to every comparable model found. GhostFaceNets has an MIT repository and trains on MS1M variants; the MobileFaceNet code is Apache 2.0, and one fork declines to distribute weights because of their unknown provenance.

No model found is free of this question. This is not a legal opinion: only a lawyer can say whether the risk is acceptable for a published app with ads.

## Not measured yet

- Time per photo on the Galaxy A54, and so the time of a first scan.
- Added APK size, native runtime included.
- Quality on the product owner's own photos, which also sets the grouping threshold.

## Alternatives considered

- **ML Kit, or any cloud API**: excluded by the specification. ML Kit also has no recognition.
- **InsightFace models**: not reviewed further; recalled as non-commercial, to verify if they are ever reconsidered.
- **EdgeFace, GhostFaceNets**: published papers under CC BY-NC-ND, trained on WebFace or MS1M variants; no clearer than SFace.
- **Training our own model**: would need a face dataset with commercial rights and training hardware; not explored.
- **Postponing People**, to build M11 and M12 first: removes the risk from the first release and leaves the feature for later.

## Consequences

If accepted:

- The app ships the model files and their license texts, credited in About.
- The Play Console *Data safety* answers and `docs/release.md` (M12) cover face data.
- The model version is stored per face (`analysis_version`), so a later model can scan again.
