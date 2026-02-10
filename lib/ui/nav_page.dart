import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:powerboards/nav/nav.dart';

class NavPage extends StatefulWidget {
  const NavPage({super.key, this.selectedRoom, required this.projectId, required this.builder});

  final String? projectId;
  final String? selectedRoom;
  final Widget Function(BuildContext context, Resource<List<Project>> projects) builder;

  @override
  State<NavPage> createState() => _NavPageState();
}

class _NavPageState extends State<NavPage> {
  late final projects = Resource<List<Project>>(fetchProjects);

  @override
  void dispose() {
    projects.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Nav(
      selectedRoom: widget.selectedRoom,
      projectId: widget.projectId,
      projects: projects,
      child: Semantics(scopesRoute: true, explicitChildNodes: true, child: widget.builder(context, projects)),
    );
  }
}
