import 'package:flutter/material.dart';
import 'package:meshagent/agent.dart';

class ToolConnectionScope extends StatefulWidget {
  const ToolConnectionScope({super.key, required this.tools, required this.builder});

  final List<RemoteToolkit> tools;

  final Widget Function(BuildContext context, Object? error) builder;

  @override
  State createState() => _ToolConnectionScope();
}

class _ToolConnectionScope extends State<ToolConnectionScope> {
  Object? error;

  @override
  void initState() {
    super.initState();

    for (var tool in widget.tools) {
      tool.start(public: false);
    }
  }

  @override
  void dispose() {
    super.dispose();

    for (var tool in widget.tools) {
      tool.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, error);
  }
}
