import 'dart:math';
import 'package:flutter/material.dart';

RelativeRect getMenuPosition(BuildContext context, Offset offset) {
  final RenderBox renderBox = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
  final renderZero = renderBox.localToGlobal(Offset.zero);
  final globalOffset = Offset(offset.dx - renderZero.dx, offset.dy - renderZero.dy);
  final size = MediaQuery.of(context).size;

  return RelativeRect.fromLTRB(
    globalOffset.dx,
    globalOffset.dy,
    max(size.width - globalOffset.dx, globalOffset.dx),
    max(size.height - globalOffset.dy, globalOffset.dy),
  );
}
