import 'dart:math';

final _rand = Random.secure();

String _randBase36(int len) {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

  return List.generate(len, (_) => alphabet[_rand.nextInt(alphabet.length)]).join();
}

String _slugify(String input, {int maxLength = 24}) {
  String s = input.trim().toLowerCase();

  const map = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'ā': 'a',
    'ă': 'a',
    'ą': 'a',
    'ç': 'c',
    'ć': 'c',
    'č': 'c',
    'ď': 'd',
    'đ': 'd',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ē': 'e',
    'ĕ': 'e',
    'ė': 'e',
    'ę': 'e',
    'ě': 'e',
    'ğ': 'g',
    'ǵ': 'g',
    'ḥ': 'h',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ī': 'i',
    'ĭ': 'i',
    'į': 'i',
    'ķ': 'k',
    'ĺ': 'l',
    'ľ': 'l',
    'ł': 'l',
    'ñ': 'n',
    'ń': 'n',
    'ň': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ō': 'o',
    'ŏ': 'o',
    'ő': 'o',
    'ř': 'r',
    'ŕ': 'r',
    'ś': 's',
    'š': 's',
    'ș': 's',
    'ť': 't',
    'ț': 't',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ū': 'u',
    'ŭ': 'u',
    'ű': 'u',
    'ų': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'ź': 'z',
    'ž': 'z',
    'ż': 'z',
  };
  final buf = StringBuffer();
  for (final ch in s.runes) {
    final c = String.fromCharCode(ch);
    buf.write(map[c] ?? c);
  }
  s = buf.toString();

  // Replace non-alphanumeric with dashes, remove emoji and symbols
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  // Collapse multiple dashes
  s = s.replaceAll(RegExp(r'-{2,}'), '-');

  // Trim dashes
  s = s.replaceAll(RegExp(r'^-+|-+$'), '');

  // Enforce max length
  if (s.length > maxLength) {
    s = s.substring(0, maxLength);
    s = s.replaceAll(RegExp(r'-+$'), ''); // avoid trailing dash after cut
  }

  return s;
}

String generateRoomSlug(String name, {required Set<String> existingSlugs, int maxLength = 24}) {
  final baseSlug = _slugify(name, maxLength: maxLength);
  String candidate = baseSlug;

  for (int i = 0; i < 100; i++) {
    if (!existingSlugs.contains(candidate)) {
      return candidate;
    }

    candidate = '$baseSlug-$i';
  }

  return _randBase36(6);
}
