import 'package:localstorage/localstorage.dart';

void setLastSelectedRoom(String projectId, String roomName) {
  final key = 'lastSelectedRoom::$projectId';

  localStorage.setItem(key, roomName);
}

void clearLastSelectedRoom(String projectId) {
  final key = 'lastSelectedRoom::$projectId';

  localStorage.removeItem(key);
}

String? getLastSelectedRoom(String projectId) {
  final key = 'lastSelectedRoom::$projectId';

  return localStorage.getItem(key);
}
