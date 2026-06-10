bool powerboardsIsExpectedRoomLifecycleClosure(Object error, [StackTrace? stackTrace]) {
  final errorText = '$error'.toLowerCase();
  final stackText = stackTrace?.toString().toLowerCase() ?? '';

  return errorText.contains('room client disposed') ||
      errorText.contains('room client was closed before request completed') ||
      errorText.contains('room client was closed before tool call completed') ||
      errorText.contains('room client was closed before message send completed') ||
      errorText.contains('room client was closed before streamed tool call request completed') ||
      errorText.contains('room client was closed before the room became ready') ||
      errorText.contains('room connection closed before request completed') ||
      errorText.contains('room connection closed before tool call completed') ||
      errorText.contains('room connection closed before message send completed') ||
      errorText.contains('room connection closed before streamed tool call request completed') ||
      errorText.contains('room connection closed before reconnect completed') ||
      errorText.contains('room connection closed before the room became ready') ||
      errorText.contains('room connection unexpectedly closed before request completed') ||
      errorText.contains('room connection unexpectedly closed before tool call completed') ||
      errorText.contains('room connection unexpectedly closed before message send completed') ||
      errorText.contains('room connection lost before streamed tool call request completed') ||
      stackText.contains('room client disposed');
}
