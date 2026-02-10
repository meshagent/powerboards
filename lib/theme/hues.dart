import 'package:flutter/material.dart';

/// Darken a color by [percent] amount (100 = black)
// ........................................................
Color darken(Color c, [int percent = 10]) {
  assert(1 <= percent && percent <= 100);
  var f = 1 - percent / 100;
  return Color.fromARGB((c.a * 255).toInt(), (c.r * 255 * f).round(), (c.g * 255 * f).round(), (c.b * 255 * f).round());
}

/// Lighten a color by [percent] amount (100 = white)
// ........................................................
Color lighten(Color c, [int percent = 10]) {
  assert(1 <= percent && percent <= 100);
  var p = percent / 100;
  return Color.fromARGB(
    (c.a * 255).toInt(),
    (c.r * 255).toInt() + ((255 - c.r * 255) * p).round(),
    (c.g * 255).toInt() + ((255 - c.g * 255) * p).round(),
    (c.b * 255).toInt() + ((255 - c.b * 255) * p).round(),
  );
}
