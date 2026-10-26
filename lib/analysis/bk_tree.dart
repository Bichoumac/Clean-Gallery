import 'package:clean_gallery/analysis/perceptual_hash.dart';

/// Burkhard–Keller tree of 64-bit hashes under the Hamming distance.
///
/// Finds every hash within a radius of a query without comparing it with
/// all of them: the triangle inequality skips whole branches. Each node
/// holds the indexes of every value with its hash.
final class BkTree {
  _Node? _root;

  /// Adds [hash] for the value at [index].
  void add(int hash, int index) {
    final root = _root;
    if (root == null) {
      _root = _Node(hash, index);
      return;
    }
    var node = root;
    while (true) {
      final distance = hammingDistance(hash, node.hash);
      if (distance == 0) {
        node.indexes.add(index);
        return;
      }
      final child = node.children[distance];
      if (child == null) {
        node.children[distance] = _Node(hash, index);
        return;
      }
      node = child;
    }
  }

  /// Calls [found] with the index and distance of every value whose hash is
  /// at most [radius] bits from [hash].
  void search(
    int hash,
    int radius,
    void Function(int index, int distance) found,
  ) {
    final root = _root;
    if (root == null) return;
    final pending = [root];
    while (pending.isNotEmpty) {
      final node = pending.removeLast();
      final distance = hammingDistance(hash, node.hash);
      if (distance <= radius) {
        for (final index in node.indexes) {
          found(index, distance);
        }
      }
      for (final MapEntry(key: edge, value: child) in node.children.entries) {
        if ((edge - distance).abs() <= radius) pending.add(child);
      }
    }
  }
}

final class _Node {
  _Node(this.hash, int index) : indexes = [index];

  final int hash;
  final List<int> indexes;

  /// Children by their distance to [hash].
  final children = <int, _Node>{};
}
