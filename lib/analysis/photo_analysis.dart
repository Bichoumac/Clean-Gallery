import 'package:clean_gallery/analysis/image_quality.dart';
import 'package:clean_gallery/analysis/perceptual_hash.dart';
import 'package:clean_gallery/domain/gray_image.dart';

/// Everything the engine measures on a photo's grayscale thumbnail, in one
/// pass: its perceptual hashes (similar photos) and its quality (blurry and
/// dark photos). See `docs/analysis-engine.md`.
typedef PhotoAnalysis = ({PerceptualHashes hashes, ImageQuality quality});

/// [PhotoAnalysis] of [image].
PhotoAnalysis analyzePhoto(GrayImage image) =>
    (hashes: perceptualHashes(image), quality: imageQuality(image));
