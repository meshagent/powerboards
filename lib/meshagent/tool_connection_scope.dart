import 'package:flutter/material.dart';
import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter/meshagent_flutter.dart';

class ToolConnectionScope extends StatefulWidget {
  const ToolConnectionScope({
    super.key,
    required this.room,
    required this.tools,
    required this.builder,
  });

  final RoomClient room;
  final List<Toolkit> tools;

  final Widget Function(BuildContext context, Object? error) builder;

  @override
  State createState() => _ToolConnectionScope();
}

class _ToolConnectionScope extends State<ToolConnectionScope> {
  @override
  Widget build(BuildContext context) {
    return ClientToolkits(
      room: widget.room,
      toolkits: widget.tools,
      public: false,
      child: Builder(builder: (context) => widget.builder(context, null)),
    );
  }
}
