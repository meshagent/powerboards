String joinPaths(String s1, String s2) {
  return [...s1.split("/"), ...s2.split("/")].where((x) => x.isNotEmpty).join("/");
}
