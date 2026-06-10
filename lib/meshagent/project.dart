import 'package:powerboards/meshagent/meshagent.dart';

class Project {
  Project({required this.id, required this.name});

  final String id;
  final String name;

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(id: json['id'] as String, name: json['name'] as String);
  }
}

Future<List<Project>> fetchProjects() async {
  final client = getMeshagentClient();
  final projectsJson = await client.listProjects();

  return projectsJson.map((json) => Project.fromJson(json)).toList();
}
