import 'package:flutter/material.dart';
import 'package:lapce_editor_flutter/lapce_editor_flutter.dart' as lapce;
import 'package:meshagent_flutter_shadcn/code_editor.dart';
import 'package:meshagent_flutter_shadcn/file_preview/code.dart';

Widget buildPowerboardsLapceCodePreviewEditor(BuildContext context, CodePreviewEditorConfiguration configuration) =>
    _PowerboardsLapceCodePreviewEditor(configuration: configuration);

class _PowerboardsLapceCodePreviewEditor extends StatefulWidget {
  const _PowerboardsLapceCodePreviewEditor({required this.configuration});

  final CodePreviewEditorConfiguration configuration;

  @override
  State<_PowerboardsLapceCodePreviewEditor> createState() => _PowerboardsLapceCodePreviewEditorState();
}

class _PowerboardsLapceCodePreviewEditorState extends State<_PowerboardsLapceCodePreviewEditor> {
  lapce.LapceEditorController? _lapceController;
  lapce.TreeSitterSyntaxHighlighter? _syntaxHighlighter;
  bool _synchronizing = false;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(covariant _PowerboardsLapceCodePreviewEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldConfiguration = oldWidget.configuration;
    final configuration = widget.configuration;
    if (oldConfiguration.controller != configuration.controller) {
      _detach(oldConfiguration);
      _attach();
    } else if (oldConfiguration.filename != configuration.filename ||
        !identical(oldConfiguration.style.codeTheme?.theme, configuration.style.codeTheme?.theme)) {
      _replaceSyntaxHighlighter();
    }
    _lapceController?.readOnly = configuration.readOnly;
  }

  void _attach() {
    final configuration = widget.configuration;
    final source = configuration.controller;
    _lastText = source.text;
    _lapceController = lapce.LapceEditorController(text: source.text, readOnly: configuration.readOnly)..addListener(_handleLapceChanged);
    source.addListener(_handleSourceChanged);
    _replaceSyntaxHighlighter();
  }

  void _detach(CodePreviewEditorConfiguration configuration) {
    configuration.controller.removeListener(_handleSourceChanged);
    _syntaxHighlighter?.dispose();
    _syntaxHighlighter = null;
    _lapceController
      ?..removeListener(_handleLapceChanged)
      ..dispose();
    _lapceController = null;
  }

  void _replaceSyntaxHighlighter() {
    _syntaxHighlighter?.dispose();
    final controller = _lapceController;
    if (controller == null) {
      _syntaxHighlighter = null;
      return;
    }
    final language = lapce.LapceLanguage.fromPath(widget.configuration.filename);
    _syntaxHighlighter = lapce.TreeSitterSyntaxHighlighter(
      controller: controller,
      language: language,
      theme: _syntaxThemeFor(widget.configuration.style),
    );
  }

  void _handleSourceChanged() {
    if (_synchronizing) {
      return;
    }
    final source = widget.configuration.controller;
    final controller = _lapceController;
    if (controller == null) {
      return;
    }

    _synchronizing = true;
    try {
      if (controller.text != source.text) {
        final wasReadOnly = controller.readOnly;
        controller.readOnly = false;
        controller.setText(source.text);
        controller.readOnly = wasReadOnly;
      }
      final selection = source.selection;
      if (selection.isValid) {
        controller.setSelection(
          lapce.Selection.region(
            lapce.TextOffset(selection.baseOffset.clamp(0, source.text.length)),
            lapce.TextOffset(selection.extentOffset.clamp(0, source.text.length)),
          ),
        );
      }
      _lastText = source.text;
    } finally {
      _synchronizing = false;
    }
  }

  void _handleLapceChanged() {
    if (_synchronizing) {
      return;
    }
    final source = widget.configuration.controller;
    final controller = _lapceController;
    if (controller == null) {
      return;
    }

    _synchronizing = true;
    final textChanged = source.text != controller.text;
    try {
      if (textChanged) {
        source.text = controller.text;
      }
      final region = controller.selection.lastInserted;
      if (region != null) {
        source.selection = TextSelection(baseOffset: region.start.value, extentOffset: region.end.value);
      }
    } finally {
      _synchronizing = false;
    }

    if (textChanged && controller.text != _lastText) {
      _lastText = controller.text;
      widget.configuration.onChanged(controller.text);
    }
  }

  @override
  void dispose() {
    _detach(widget.configuration);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _lapceController;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    final configuration = widget.configuration;
    controller.readOnly = configuration.readOnly;

    final style = configuration.style;
    final rootStyle = style.codeTheme?.theme['root'];
    final foreground = style.textColor ?? rootStyle?.color ?? DefaultTextStyle.of(context).style.color ?? const Color(0xffd4d4d4);
    final background = style.backgroundColor ?? rootStyle?.backgroundColor ?? Colors.transparent;
    final caret = configuration.readOnly ? Colors.transparent : style.cursorColor ?? foreground;
    final padding = configuration.padding.resolve(Directionality.of(context));

    return lapce.LapceEditor(
      controller: controller,
      focusNode: configuration.focusNode,
      showGutter: false,
      syntaxHighlightProvider: _syntaxHighlighter,
      theme: lapce.LapceEditorTheme(
        background: background,
        foreground: foreground,
        caret: caret,
        selection: (style.cursorColor ?? foreground).withValues(alpha: 0.25),
        currentLine: background,
        placeholder: foreground.withValues(alpha: 0.55),
        padding: padding,
        wrapMethod: const lapce.WrapMethod.none(),
        textStyle: TextStyle(fontFamily: style.fontFamily, fontSize: style.fontSize, color: foreground, height: 1.4),
      ),
    );
  }
}

lapce.SyntaxHighlightTheme _syntaxThemeFor(CodeEditorStyle style) {
  final source = style.codeTheme?.theme;
  if (source == null) {
    return lapce.SyntaxHighlightTheme.dark;
  }

  final scopes = <String, TextStyle>{};
  for (final entry in source.entries) {
    final scope = entry.key.replaceFirst(RegExp(r'^\.?hljs-'), '');
    scopes[scope] = entry.value;
  }
  if (scopes['attr'] case final attribute?) {
    scopes['attribute'] = attribute;
    scopes['property'] = attribute;
    scopes['variable.other.member'] = attribute;
  }
  if (scopes['literal'] case final literal?) {
    scopes['boolean'] = literal;
    scopes['constant'] = literal;
    scopes['constant.builtin'] = literal;
    scopes['constant.builtin.boolean'] = literal;
  }
  if (scopes['number'] case final number?) {
    scopes['constant.numeric'] = number;
    scopes['constant.numeric.integer'] = number;
    scopes['constant.numeric.float'] = number;
  }
  if (scopes['built_in'] case final builtIn?) {
    scopes['variable.builtin'] = builtIn;
    scopes['constant.character.escape'] = builtIn;
  }
  if (scopes['punctuation'] case final punctuation?) {
    scopes['punctuation.delimiter'] = punctuation;
    scopes['punctuation.bracket'] = punctuation;
    scopes['punctuation.special'] = punctuation;
  }
  return lapce.SyntaxHighlightTheme(scopes);
}
