import 'package:flutter/material.dart';

import '../theme/pb_theme.dart';
import 'preview_page.dart';

class PowerboardsUiPreviewApp extends StatelessWidget {
  const PowerboardsUiPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, title: 'Powerboards UI Preview', theme: pbTheme(), home: const PreviewPage());
  }
}
