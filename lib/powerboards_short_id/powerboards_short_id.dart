import "dart:math";
import "anybase.dart";

const flickrBase58 = '123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ';
const cookieBase90 = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!#\$%&'()*+-./:<=>?@[]^_`{|}~";

class UuidOptions {
  bool consistentLength = true;
  int shortIdLength = 0;
  String paddingChar = "";
}

typedef Translator = String Function(String);

/// Takes a UUID, strips the dashes, and translates.
///  @param {string} longId
/// @param {function(string)} translator
/// @param {Object} [paddingParams]
/// @returns {string}
String shortenUUID(String longId, Translator translator, UuidOptions? paddingParams) {
  final translated = translator(longId.toLowerCase().replaceAll('-', ''));

  if (paddingParams == null || !paddingParams.consistentLength) {
    return translated;
  }

  return translated.padLeft(paddingParams.shortIdLength, paddingParams.paddingChar);
}

final uuidRegExp = RegExp(r'(\w{8})(\w{4})(\w{4})(\w{4})(\w{12})');

///
/// Translate back to hex and turn back into UUID format, with dashes
/// @param {string} shortId
/// @param {function(string)} translator
/// @returns {string}
String enlargeUUID(String shortId, Translator translator) {
  final uu1 = translator(shortId).padLeft(32, '0');

  // Join the zero padding and the UUID and then slice it up with match
  final m = uuidRegExp.firstMatch(uu1);

  if (m is RegExpMatch) {
    // Accumulate the matches and join them.
    return [m[1], m[2], m[3], m[4], m[5]].join('-');
  } else {
    throw InvalidFormatException();
  }
}

class InvalidFormatException implements Exception {}

// Calculate length for the shortened ID
int getShortIdLength(num alphabetLength) {
  return (log(pow(2.0, 128)) / log(alphabetLength)).ceil().toInt();
}

// Default to Flickr 58
const useAlphabet = flickrBase58;

// Default to baseOptions
final selectedOptions = UuidOptions();

// Check alphabet for duplicate entries
/*if ([...new Set(Array.from(useAlphabet))].length !== useAlphabet.length) {
  throw new Error('The provided Alphabet has duplicate characters resulting in unreliable results');
}*/

final shortIdLength = getShortIdLength(useAlphabet.length);

// Padding Params
final paddingParams = UuidOptions()
  ..shortIdLength = shortIdLength
  ..consistentLength = selectedOptions.consistentLength
  ..paddingChar = useAlphabet[0];

// UUIDs are in hex, so we translate to and from.
final fromHex = anyBase(anybaseHEX, useAlphabet);
final toHex = anyBase(useAlphabet, anybaseHEX);
//final generate = () => shortenUUID(uuidv4(), fromHex, paddingParams);

String fromUUID(String uuid) {
  return shortenUUID(uuid, fromHex, paddingParams);
}

String? maybeFromUUID(String uuid) {
  try {
    return shortenUUID(uuid, fromHex, paddingParams);
  } catch (_) {
    return null;
  }
}

String toUUID(String shortUuid) {
  return enlargeUUID(shortUuid, toHex);
}
