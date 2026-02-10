class BadAlphabetException implements Exception {}

class NonAlphabeticException implements Exception {}

class Converter {
  Converter(this.srcAlphabet, this.dstAlphabet) {
    if (srcAlphabet == "" || dstAlphabet == "" || srcAlphabet.isEmpty || dstAlphabet.isEmpty) {
      throw BadAlphabetException();
    }
  }
  String srcAlphabet;
  String dstAlphabet;

  String convert(String number) {
    int i = 0;
    int divide = 0;
    int newlen = 0;

    var numberMap = <int, int>{}, fromBase = srcAlphabet.length, toBase = dstAlphabet.length, length = number.length, result = '';

    if (!isValid(number)) {
      throw NonAlphabeticException(); // 'Number "' + number + '" contains of non-alphabetic digits (' + this.srcAlphabet + ')');
    }

    if (srcAlphabet == dstAlphabet) {
      return number;
    }

    for (i = 0; i < length; i++) {
      numberMap[i] = srcAlphabet.indexOf(number[i]);
    }
    do {
      divide = 0;
      newlen = 0;
      for (i = 0; i < length; i++) {
        divide = divide * fromBase + (numberMap[i] as int);
        if (divide >= toBase) {
          numberMap[newlen++] = (divide ~/ toBase); //int.parse(divide / toBase, radix: 10);
          divide = divide % toBase;
        } else if (newlen > 0) {
          numberMap[newlen++] = 0;
        }
      }
      length = newlen;
      result = dstAlphabet.substring(divide, divide + 1) + result;
    } while (newlen != 0);

    return result;
  }

  bool isValid(String number) {
    int i = 0;
    for (; i < number.length; ++i) {
      if (!srcAlphabet.contains(number[i])) {
        return false;
      }
    }
    return true;
  }
}

String Function(String) anyBase(String srcAlphabet, String dstAlphabet) {
  Converter converter = Converter(srcAlphabet, dstAlphabet);
  /**
     * Convert function
     *
     * @param {string|Array} number
     *
     * @return {string|Array} number
     */
  return (String number) {
    return converter.convert(number);
  };
}

const String anybaseBIN = '01';
const String anybaseOCT = '01234567';
const String anybaseDEC = '0123456789';
const String anybaseHEX = '0123456789abcdef';
