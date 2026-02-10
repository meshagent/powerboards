import 'package:powerboards/powerboards_short_id/powerboards_short_id.dart';

class TextValidators {
  static final RegExp _emailRegExp = RegExp(r'^[\w-]+(\.[\w-]+)*(\+[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,}$');
  static String? emailAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an email';
    }

    if (!_emailRegExp.hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? folder(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a folder name';
    }

    return null;
  }

  static String? joinLink(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a link';
    }

    final uri = Uri.parse(value.startsWith('www') ? 'https://${value.trim()}' : value.trim());
    final path = uri.path;

    if (path.startsWith('/r/') == false) {
      return 'Please enter a valid link';
    }

    try {
      // Strip the '/r/' from the path and convert the short UUID to a full UUID
      toUUID(path.replaceFirst('/r/', ''));
    } catch (e) {
      return 'Please enter a valid link';
    }

    return null;
  }
}
