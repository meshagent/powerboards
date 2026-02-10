import 'package:intl/intl.dart';

extension DateTimeExtension on DateTime {
  String timeAgo() {
    final difference = DateTime.now().difference(this);

    if (difference.inDays >= 7) {
      return DateFormat.yMMMMd().format(this);
    } else if (difference.inDays >= 2) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays >= 1) {
      return 'Yesterday';
    } else if (difference.inHours >= 2) {
      return '${difference.inHours} hours ago';
    } else if (difference.inHours >= 1) {
      return 'An hour ago';
    } else if (difference.inMinutes >= 2) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inMinutes >= 1) {
      return 'A minute ago';
    } else if (difference.inSeconds >= 10) {
      return '${difference.inSeconds} seconds ago';
    } else {
      return 'Just now';
    }
  }

  String modified() {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff < const Duration(days: 1)) {
      // e.g. 2 hours ago
      return timeAgo();
    }

    if (year == now.year) {
      // e.g. Apr 30  2:15 PM
      final fmt = DateFormat.MMMd().add_jm();
      return fmt.format(this);
    }

    // e.g. Dec 12, 2023  9:45 AM
    final fullFmt = DateFormat.yMMMd().add_jm();
    return fullFmt.format(this);
  }
}
