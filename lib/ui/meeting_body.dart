import 'package:flutter/material.dart';

class MeetingBodyLayout extends StatelessWidget {
  const MeetingBodyLayout({super.key, required this.rightStripBuilder, required this.mainBuilder});

  final WidgetBuilder rightStripBuilder;
  final WidgetBuilder mainBuilder;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: mainBuilder(context)),
        rightStripBuilder(context),
      ],
    );
  }
}
