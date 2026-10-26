import 'package:clean_gallery/analysis/best_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  final base = testItem(5, sizeBytes: 100);

  test('a favorite wins', () {
    final favorite = testItem(9, isFavorite: true, sizeBytes: 10);
    expect(pickBest([base, favorite]).id, '9');
  });

  test('then the highest resolution', () {
    final small = base.copyWith(id: '1', width: 100, height: 100);
    expect(pickBest([small, base]).id, '5');
  });

  test('then the sharpest, when known for both', () {
    final other = base.copyWith(id: '9');
    expect(pickBest([base, other], sharpness: {'5': 10, '9': 80}).id, '9');
    expect(pickBest([base, other], sharpness: {'9': 80}).id, '5');
  });

  test('then the largest file', () {
    expect(pickBest([base, base.copyWith(id: '9', sizeBytes: 200)]).id, '9');
  });

  test('then the oldest, then the smallest id', () {
    final older = base.copyWith(id: '9', takenAt: DateTime(2020));
    expect(pickBest([base, older]).id, '9');
    expect(pickBest([base.copyWith(id: '12'), base]).id, '5');
  });

  test('bestFirst keeps the others in order', () {
    final items = [testItem(1), testItem(2, isFavorite: true), testItem(3)];
    expect(bestFirst(items).map((i) => i.id), ['2', '1', '3']);
  });
}
