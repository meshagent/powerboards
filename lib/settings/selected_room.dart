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

String _lastSelectedRoomAgentKey(String projectId, String roomName) {
  return 'lastSelectedRoomAgent::$projectId::$roomName';
}

void setLastSelectedRoomAgent(String projectId, String roomName, String agentRouteId) {
  localStorage.setItem(_lastSelectedRoomAgentKey(projectId, roomName), agentRouteId);
}

void clearLastSelectedRoomAgent(String projectId, String roomName) {
  localStorage.removeItem(_lastSelectedRoomAgentKey(projectId, roomName));
}

String? getLastSelectedRoomAgent(String projectId, String roomName) {
  return localStorage.getItem(_lastSelectedRoomAgentKey(projectId, roomName));
}

String _lastSelectedRoomThreadKey(String projectId, String roomName, String agentRouteId) {
  return 'lastSelectedRoomThread::$projectId::$roomName::$agentRouteId';
}

String _lastSelectedRoomThreadTitleKey(String projectId, String roomName, String agentRouteId) {
  return 'lastSelectedRoomThreadTitle::$projectId::$roomName::$agentRouteId';
}

void setLastSelectedRoomThread(String projectId, String roomName, String agentRouteId, String threadPath, {String? threadTitle}) {
  localStorage.setItem(_lastSelectedRoomThreadKey(projectId, roomName, agentRouteId), threadPath);

  final normalizedTitle = threadTitle?.trim();
  if (normalizedTitle == null || normalizedTitle.isEmpty) {
    localStorage.removeItem(_lastSelectedRoomThreadTitleKey(projectId, roomName, agentRouteId));
    return;
  }

  localStorage.setItem(_lastSelectedRoomThreadTitleKey(projectId, roomName, agentRouteId), normalizedTitle);
}

void clearLastSelectedRoomThread(String projectId, String roomName, String agentRouteId) {
  localStorage.removeItem(_lastSelectedRoomThreadKey(projectId, roomName, agentRouteId));
  localStorage.removeItem(_lastSelectedRoomThreadTitleKey(projectId, roomName, agentRouteId));
}

String? getLastSelectedRoomThread(String projectId, String roomName, String agentRouteId) {
  return localStorage.getItem(_lastSelectedRoomThreadKey(projectId, roomName, agentRouteId));
}

String? getLastSelectedRoomThreadTitle(String projectId, String roomName, String agentRouteId) {
  return localStorage.getItem(_lastSelectedRoomThreadTitleKey(projectId, roomName, agentRouteId));
}
