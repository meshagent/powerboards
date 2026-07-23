import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapce_editor_flutter/lapce_editor_flutter.dart' as lapce;
import 'package:meshagent_flutter_shadcn/code_editor.dart';
import 'package:meshagent_flutter_shadcn/file_preview/code.dart';
import 'package:powerboards/meshagent/lapce_code_preview_editor.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/styles/base16/material-darker.dart';

void main() {
  testWidgets('Powerboards code preview builder renders YAML with Lapce', (tester) async {
    final sourceController = CodeLineEditingController.fromText('version: v1\nkind: Service');
    final focusNode = FocusNode();
    addTearDown(sourceController.dispose);
    addTearDown(focusNode.dispose);
    String? changedText;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => SizedBox(
            width: 480,
            height: 320,
            child: buildPowerboardsLapceCodePreviewEditor(
              context,
              CodePreviewEditorConfiguration(
                filename: 'service.yaml',
                controller: sourceController,
                focusNode: focusNode,
                readOnly: false,
                padding: const EdgeInsets.all(8),
                style: CodeEditorStyle(
                  codeTheme: CodeHighlightTheme(
                    languages: {'default': CodeHighlightThemeMode(mode: langYaml)},
                    theme: materialDarkerTheme,
                  ),
                ),
                onChanged: (value) => changedText = value,
              ),
            ),
          ),
        ),
      ),
    );

    final editor = tester.widget<lapce.LapceEditor>(find.byType(lapce.LapceEditor));
    final highlighter = editor.syntaxHighlightProvider! as lapce.TreeSitterSyntaxHighlighter;
    expect(highlighter.language, lapce.LapceLanguage.yaml);
    editor.controller.setText('edited in Lapce');
    await tester.pump();

    expect(sourceController.text, 'edited in Lapce');
    expect(changedText, 'edited in Lapce');

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });
}
