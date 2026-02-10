import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:powerboards/meshagent/project.dart';
import 'package:powerboards/theme/theme.dart';

import 'avatar_menu_button.dart';

class MainWrapper extends StatelessWidget {
  const MainWrapper({super.key, this.leftSideBar, this.projectId, required this.projects, required this.child});

  final Widget? leftSideBar;
  final String? projectId;
  final Resource<List<Project>> projects;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        children: [
          SizedBox(
            height: headerHeight,
            child: Padding(
              padding: const .symmetric(horizontal: 10),
              child: Row(
                children: [
                  ?leftSideBar,

                  Spacer(),

                  UserAvatarMenuButton(projectId: projectId, projects: projects),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
