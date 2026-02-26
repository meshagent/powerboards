String joinPaths(String s1, String s2) {
  return [...s1.split("/"), ...s2.split("/")].where((x) => x.isNotEmpty).join("/");
}

String parentPath(String s) {
  final normalized = s.endsWith('/') ? s.substring(0, s.length - 1) : s;
  final index = normalized.lastIndexOf('/');
  return index <= 0 ? '' : normalized.substring(0, index);
}
