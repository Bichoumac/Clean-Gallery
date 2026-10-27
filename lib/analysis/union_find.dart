/// Disjoint sets of the indexes `0 … size - 1`, merged pair by pair.
///
/// Path halving and union by size keep each operation nearly constant.
final class UnionFind {
  /// Creates [size] sets of one index each.
  UnionFind(int size)
    : _parent = List.generate(size, (i) => i),
      _size = List.filled(size, 1);

  final List<int> _parent;
  final List<int> _size;

  /// Representative of the set holding [index].
  int find(int index) {
    var i = index;
    while (_parent[i] != i) {
      _parent[i] = _parent[_parent[i]];
      i = _parent[i];
    }
    return i;
  }

  /// Merges the sets holding [a] and [b].
  void union(int a, int b) {
    var rootA = find(a);
    var rootB = find(b);
    if (rootA == rootB) return;
    if (_size[rootA] < _size[rootB]) (rootA, rootB) = (rootB, rootA);
    _parent[rootB] = rootA;
    _size[rootA] += _size[rootB];
  }

  /// Sets of two indexes or more, each in increasing order.
  List<List<int>> groups() {
    final byRoot = <int, List<int>>{};
    for (var i = 0; i < _parent.length; i++) {
      (byRoot[find(i)] ??= []).add(i);
    }
    return [
      for (final members in byRoot.values)
        if (members.length > 1) members,
    ];
  }
}
