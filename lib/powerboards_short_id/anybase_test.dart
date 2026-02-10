import "package:test/test.dart";

import "powerboards_short_id.dart";

void main() {
  group('Anybase', () {
    test('can convert short to uuid id', () {
      expect(toUUID("fHEqquEA2YieHpFkYZcatb"), "77311d17-64f5-42b4-9aba-4db42803ecf4");
    });

    test('can convert uuid id to short', () {
      expect(fromUUID("77311d17-64f5-42b4-9aba-4db42803ecf4"), "fHEqquEA2YieHpFkYZcatb");
    });
  });
}
