import 'dart:io' show Platform;

import 'package:pdfrx/pdfrx.dart';
import 'package:pdfrx_coregraphics/pdfrx_coregraphics.dart';

void configurePowerboardsPdfBackend() {
  if (Platform.isIOS || Platform.isMacOS) {
    PdfrxEntryFunctions.instance = PdfrxCoreGraphicsEntryFunctions();
  }

  pdfrxFlutterInitialize();
}
