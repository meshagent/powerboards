class Address {
  const Address(this.mailAddress, [this.name]);

  final String? name;
  final String mailAddress;

  static final _quotableNameRegExp = RegExp(r'[",]');

  String? get sanitizedName {
    if (name == null) return null;

    // Quote the name if it contains a comma or a quote.
    if (name!.contains(_quotableNameRegExp)) {
      return '"${name!.replaceAll('"', r'\"')}"';
    }

    return name;
  }

  String get sanitizedAddress => mailAddress;

  @override
  String toString() => name == null ? mailAddress : "$name <$mailAddress>";
}

List<Address> parseEmailList(String addresses) {
  final result = <Address>[];
  final nameOrEmail = <int>[];
  final email = <int>[];
  final name = <int>[];

  final commaCodeUnit = ','.codeUnitAt(0);
  final semicolonCodeUnit = ';'.codeUnitAt(0); // <-- add this
  final quoteCodeUnit = '"'.codeUnitAt(0);
  final openAngleBracket = '<'.codeUnitAt(0);
  final closeAngleBracket = '>'.codeUnitAt(0);
  final backslashCodeUnit = r'\'.codeUnitAt(0);

  var inQuote = false;
  var inAngleBrackets = false;

  void addAddress() {
    if (nameOrEmail.isNotEmpty) {
      if (email.isEmpty) {
        email.addAll(nameOrEmail);
      } else if (name.isEmpty) {
        name.addAll(nameOrEmail);
      }
    }

    if (email.isNotEmpty) {
      result.add(
        Address(String.fromCharCodes(email).trim(), String.fromCharCodes(name).trim().isEmpty ? null : String.fromCharCodes(name).trim()),
      );
    }

    email.clear();
    name.clear();
    nameOrEmail.clear();
    inAngleBrackets = false;
    inQuote = false;
  }

  List<int> codeUnits = addresses.codeUnits;
  for (int p = 0; p < codeUnits.length; p++) {
    int c = codeUnits[p];

    if (inQuote) {
      if (c == quoteCodeUnit) {
        inQuote = false;
      } else if (c == backslashCodeUnit) {
        ++p;
        if (p < codeUnits.length) {
          name.add(codeUnits[p]);
        }
      } else {
        name.add(c);
      }
    } else if (inAngleBrackets) {
      if (c == closeAngleBracket) {
        inAngleBrackets = false;
      } else {
        email.add(c);
      }
    } else if (c == commaCodeUnit || c == semicolonCodeUnit) {
      addAddress();
    } else if (c == quoteCodeUnit) {
      inQuote = true;
    } else if (c == openAngleBracket) {
      inAngleBrackets = true;
    } else {
      nameOrEmail.add(c);
    }
  }

  addAddress();

  return result;
}
