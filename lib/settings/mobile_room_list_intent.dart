String? _stayOnMobileRoomListProjectId;

void requestStayOnMobileRoomList(String projectId) {
  _stayOnMobileRoomListProjectId = projectId;
}

bool shouldStayOnMobileRoomList(String projectId) {
  return _stayOnMobileRoomListProjectId == projectId;
}

bool consumeStayOnMobileRoomList(String projectId) {
  if (_stayOnMobileRoomListProjectId != projectId) {
    return false;
  }

  _stayOnMobileRoomListProjectId = null;
  return true;
}
