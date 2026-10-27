import 'package:clean_gallery/domain/duplicate_group.dart';
import 'package:clean_gallery/domain/enums.dart';
import 'package:clean_gallery/domain/trashed_item.dart';
import 'package:clean_gallery/features/stats/storage_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  const totals = (photos: 10, photoBytes: 5000, videos: 2, videoBytes: 9000);
  final a = testItem(1, sizeBytes: 300);
  final b = testItem(2, sizeBytes: 200);
  final c = testItem(3, sizeBytes: 100);
  final d = testItem(4, sizeBytes: 50);

  test('counts the extras of each kind of group, each item once', () {
    final summary = summarize(
      totals: totals,
      groups: [
        // b is an identical copy of a, and also looks like c.
        DuplicateGroup(id: 1, kind: DuplicateKind.exact, items: [a, b]),
        DuplicateGroup(id: 2, kind: DuplicateKind.similar, items: [a, b, c]),
        DuplicateGroup(id: 3, kind: DuplicateKind.burst, items: [a, d]),
      ],
      trashed: [
        TrashedItem(
          item: testItem(9, sizeBytes: 1000),
          trashedAt: DateTime(2026),
          expiresAt: DateTime(2026, 2),
          originalFolder: 'Camera',
        ),
      ],
    );
    expect(summary.exact, (count: 1, bytes: 200));
    expect(summary.burst, (count: 1, bytes: 50));
    expect(summary.similar, (count: 1, bytes: 100));
    expect(summary.trash, (count: 1, bytes: 1000));
    expect(summary.usedBytes, 14000);
    expect(summary.reclaimableBytes, 1350);
  });

  test('an empty library frees nothing', () {
    final summary = summarize(
      totals: (photos: 0, photoBytes: 0, videos: 0, videoBytes: 0),
      groups: const [],
      trashed: const [],
    );
    expect(summary.reclaimableBytes, 0);
    expect(summary.usedBytes, 0);
  });
}
