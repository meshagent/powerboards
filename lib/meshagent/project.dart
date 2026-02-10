import 'package:powerboards/meshagent/meshagent.dart';

// import 'package:flutter_solidart/flutter_solidart.dart';
// import 'package:meshagent/meshagent.dart';

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

/*
class ProjectResourceFactory {
  ProjectResourceFactory(this.projectId);

  final String projectId;
  final client = getMeshagentClient();

  static ProjectResourceFactory? _current;

  static ProjectResourceFactory getCurrent(String projectId) {
    if (projectId != _current?.projectId) {
      _current = ProjectResourceFactory(projectId);
    }

    return _current!;
  }

  late final canCreateRooms = Resource<bool>(() => client.canCreateRooms(projectId));
  late final status = Resource<bool>(() => client.getStatus(projectId));
  late final rooms = Resource<List<Room>>(() => listMeshagentRooms(projectId));
}
*/
