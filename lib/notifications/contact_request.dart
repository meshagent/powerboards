import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class ContactRequest {
  ContactRequest(this._data);

  final Map<String, dynamic> _data;

  String get initials {
    return "${firstName.characters.firstOrNull ?? ""}${lastName.characters.firstOrNull ?? ""}";
  }

  String get userID {
    return _data["userID"] ?? "";
  }

  String get fullName {
    return "$firstName $lastName";
  }

  String get firstName {
    return _data["firstName"] ?? "";
  }

  String get lastName {
    return _data["lastName"] ?? "";
  }

  String get email {
    return _data["email"] ?? "";
  }
}

ContactRequest constructContactRequest(Map<String, dynamic> data) {
  if (data["__obj__"] is ContactRequest) {
    final ContactRequest o = data["__obj__"];
    if (o._data != data) {
      debugPrint("Unexpected object corruption ${data["id"]}");
    }
    return o;
  } else {
    final ContactRequest o = ContactRequest(data);
    data["__obj__"] = o;
    return o;
  }
}
