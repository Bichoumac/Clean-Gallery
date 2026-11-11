import 'package:clean_gallery/features/editor/color_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hex codes are read and written as opaque colors', () {
    expect(parseHex('#12ab9f'), 0xFF12AB9F);
    expect(parseHex('FFFFFF'), 0xFFFFFFFF);
    expect(parseHex('#12AB9'), isNull);
    expect(parseHex('#GG0000'), isNull);
    expect(hexOf(0xFF0A84FF), '#0A84FF');
    expect(hexOf(0x800A84FF), '#0A84FF');
  });
}
