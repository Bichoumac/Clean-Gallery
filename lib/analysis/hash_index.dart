import 'dart:typed_data';

/// Finds every pair of 64-bit hashes within a Hamming radius without
/// comparing each hash with all the others: multi-index hashing.
///
/// Each hash is cut into four 16-bit blocks. Two hashes at most `r` bits
/// apart have at least one block at most `r ~/ 4` bits apart (pigeonhole),
/// so only hashes sharing a block within that small radius are compared.
/// The search is exact: no pair is missed.
///
/// Hashes are kept as 32-bit halves, so the hot loop works on small
/// integers; a full 64-bit Dart integer is boxed. See ADR 0019 for why this
/// replaces the brief's BK-tree.
final class HashIndex {
  /// Indexes [hashes]; pairs are reported by position in this list.
  HashIndex(List<int> hashes)
    : _high = Uint32List(hashes.length),
      _low = Uint32List(hashes.length) {
    for (var i = 0; i < hashes.length; i++) {
      _high[i] = (hashes[i] >>> 32) & 0xFFFFFFFF;
      _low[i] = hashes[i] & 0xFFFFFFFF;
    }
    for (var block = 0; block < _blocks; block++) {
      _tables.add(_Table(this, block));
    }
  }

  static const _blocks = 4;
  static const _blockBits = 16;

  final Uint32List _high;
  final Uint32List _low;
  final _tables = <_Table>[];

  /// Number of indexed hashes.
  int get length => _low.length;

  /// Number of bits that differ between the hashes at [i] and [j].
  int distance(int i, int j) =>
      _bitCount(_high[i] ^ _high[j]) + _bitCount(_low[i] ^ _low[j]);

  /// Calls [found] once for every pair of positions `i < j` whose hashes
  /// are at most [radius] bits apart, with their distance.
  void pairsWithin(
    int radius,
    void Function(int i, int j, int distance) found,
  ) {
    final masks = _masksWithin(radius ~/ _blocks);
    // Last query each position was compared with, so a pair sharing
    // several blocks is compared once.
    final seen = Int32List(length)..fillRange(0, length, -1);
    for (var i = 0; i < length; i++) {
      for (final table in _tables) {
        final key = table.keyOf(i);
        for (final mask in masks) {
          final bucket = key ^ mask;
          final end = table.starts[bucket + 1];
          for (var k = table.starts[bucket]; k < end; k++) {
            final j = table.members[k];
            if (j <= i || seen[j] == i) continue;
            seen[j] = i;
            final d = distance(i, j);
            if (d <= radius) found(i, j, d);
          }
        }
      }
    }
  }

  /// Every 16-bit value with at most [bits] bits set: the block keys within
  /// [bits] of a block are its key XOR one of them.
  static Uint16List _masksWithin(int bits) => Uint16List.fromList([
    for (var mask = 0; mask < 1 << _blockBits; mask++)
      if (_bitCount(mask) <= bits) mask,
  ]);

  /// Number of set bits of a value below 2³².
  static int _bitCount(int value) =>
      _bitsIn16[value & 0xFFFF] + _bitsIn16[value >>> 16];

  static final Uint8List _bitsIn16 = () {
    final table = Uint8List(1 << _blockBits);
    for (var i = 1; i < table.length; i++) {
      table[i] = (i & 1) + table[i >> 1];
    }
    return table;
  }();
}

/// Positions grouped by the value of one 16-bit block, as flat arrays:
/// the positions whose block is `key` are
/// `members[starts[key] .. starts[key + 1]]`.
final class _Table {
  _Table(this._index, int block)
    : _word = block < 2 ? _index._low : _index._high,
      _shift = block.isEven ? 0 : 16,
      starts = Int32List((1 << HashIndex._blockBits) + 1),
      members = Int32List(_index.length) {
    final n = _index.length;
    for (var i = 0; i < n; i++) {
      starts[keyOf(i) + 1]++;
    }
    for (var key = 0; key < 1 << HashIndex._blockBits; key++) {
      starts[key + 1] += starts[key];
    }
    final next = Int32List.fromList(starts);
    for (var i = 0; i < n; i++) {
      members[next[keyOf(i)]++] = i;
    }
  }

  final HashIndex _index;
  final Uint32List _word;
  final int _shift;

  /// Start of each key's positions in [members]; one more entry than keys.
  final Int32List starts;

  /// Positions, ordered by key.
  final Int32List members;

  /// This block of the hash at position [i].
  int keyOf(int i) => (_word[i] >>> _shift) & 0xFFFF;
}
