import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:powerboards/ui/adaptive_text_selection_toolbar.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';

EditableTextContextMenuBuilder? _defaultAdaptiveContextMenuBuilder(EditableTextContextMenuBuilder? contextMenuBuilder) {
  if (!powerboardsUsesSystemAdaptiveTextSelectionToolbar()) {
    return contextMenuBuilder;
  }

  return contextMenuBuilder ?? powerboardsAdaptiveInputContextMenuBuilder;
}

TapRegionCallback? _defaultAdaptiveOnPressedOutside(TapRegionCallback? onPressedOutside) {
  if (!powerboardsUsesSystemAdaptiveTextSelectionToolbar()) {
    return onPressedOutside;
  }

  return onPressedOutside ?? powerboardsAdaptiveInputOnPressedOutside();
}

bool powerboardsUsesMobileFieldLabelStyle(BuildContext context) {
  final mediaQuery = MediaQuery.maybeOf(context);
  final view = View.maybeOf(context);
  final screenSize = mediaQuery?.size ?? (view == null ? const Size(1024, 768) : view.physicalSize / view.devicePixelRatio);
  final isMobilePlatform = switch (Theme.of(context).platform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows => false,
  };

  return isMobilePlatform && screenSize.shortestSide < 600;
}

TextStyle powerboardsMobileFieldLabelTextStyle(Color color, {TextStyle? baseStyle}) {
  return GoogleFonts.inter(textStyle: baseStyle, color: color, fontWeight: FontWeight.w600);
}

TextStyle powerboardsFieldLabelTextStyle(BuildContext context) {
  final theme = ShadTheme.of(context);
  if (powerboardsUsesMobileFieldLabelStyle(context)) {
    return powerboardsMobileFieldLabelTextStyle(theme.colorScheme.foreground, baseStyle: DefaultTextStyle.of(context).style);
  }

  return theme.decoration.labelStyle ?? DefaultTextStyle.of(context).style;
}

class PowerboardsAdaptiveInput extends StatelessWidget {
  PowerboardsAdaptiveInput({
    super.key,
    this.initialValue,
    this.placeholder,
    this.controller,
    this.focusNode,
    this.decoration,
    this.undoController,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.strutStyle,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.readOnly = false,
    this.showCursor,
    this.autofocus = false,
    this.obscuringCharacter = '•',
    this.obscureText = false,
    this.autocorrect = true,
    this.smartDashesType,
    this.smartQuotesType,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.maxLengthEnforcement,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onAppPrivateCommand,
    this.inputFormatters,
    this.enabled = true,
    this.cursorWidth,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorOpacityAnimates,
    this.cursorColor,
    this.selectionHeightStyle = ui.BoxHeightStyle.tight,
    this.selectionWidthStyle = ui.BoxWidthStyle.tight,
    this.keyboardAppearance,
    this.scrollPadding = const EdgeInsets.all(20),
    this.dragStartBehavior = DragStartBehavior.start,
    this.enableInteractiveSelection,
    this.selectionControls,
    this.onPressed,
    this.onPressedAlwaysCalled = false,
    TapRegionCallback? onPressedOutside,
    this.mouseCursor,
    this.scrollController,
    this.scrollPhysics,
    this.autofillHints,
    this.contentInsertionConfiguration,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.scribbleEnabled = true,
    this.enableIMEPersonalizedLearning = true,
    EditableTextContextMenuBuilder? contextMenuBuilder,
    this.spellCheckConfiguration,
    this.magnifierConfiguration = TextMagnifierConfiguration.disabled,
    this.selectionColor,
    this.padding,
    this.leading,
    this.trailing,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.placeholderStyle,
    this.alignment,
    this.placeholderAlignment,
    this.inputPadding,
    this.gap,
    this.constraints,
    this.stylusHandwritingEnabled = true,
    this.groupId,
    this.scrollbarPadding,
    this.keyboardToolbarBuilder,
    this.top,
    this.bottom,
    this.onLineCountChange,
    this.editableTextSize,
    this.verticalGap,
    this.mobileFlowDialogInset = false,
    this.mobileFlowDialogInsetPadding = const EdgeInsets.all(4),
  }) : contextMenuBuilder = _defaultAdaptiveContextMenuBuilder(contextMenuBuilder),
       onPressedOutside = _defaultAdaptiveOnPressedOutside(onPressedOutside);

  final String? initialValue;
  final Widget? placeholder;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ShadDecoration? decoration;
  final UndoHistoryController? undoController;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final bool readOnly;
  final bool? showCursor;
  final bool autofocus;
  final String obscuringCharacter;
  final bool obscureText;
  final bool autocorrect;
  final SmartDashesType? smartDashesType;
  final SmartQuotesType? smartQuotesType;
  final bool enableSuggestions;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final AppPrivateCommandCallback? onAppPrivateCommand;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final double? cursorWidth;
  final double? cursorHeight;
  final Radius? cursorRadius;
  final bool? cursorOpacityAnimates;
  final Color? cursorColor;
  final ui.BoxHeightStyle selectionHeightStyle;
  final ui.BoxWidthStyle selectionWidthStyle;
  final Brightness? keyboardAppearance;
  final EdgeInsets scrollPadding;
  final DragStartBehavior dragStartBehavior;
  final bool? enableInteractiveSelection;
  final TextSelectionControls? selectionControls;
  final GestureTapCallback? onPressed;
  final bool onPressedAlwaysCalled;
  final TapRegionCallback? onPressedOutside;
  final MouseCursor? mouseCursor;
  final ScrollController? scrollController;
  final ScrollPhysics? scrollPhysics;
  final Iterable<String>? autofillHints;
  final ContentInsertionConfiguration? contentInsertionConfiguration;
  final Clip clipBehavior;
  final String? restorationId;
  final bool scribbleEnabled;
  final bool enableIMEPersonalizedLearning;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final SpellCheckConfiguration? spellCheckConfiguration;
  final TextMagnifierConfiguration magnifierConfiguration;
  final Color? selectionColor;
  final EdgeInsetsGeometry? padding;
  final Widget? leading;
  final Widget? trailing;
  final MainAxisAlignment? mainAxisAlignment;
  final CrossAxisAlignment? crossAxisAlignment;
  final TextStyle? placeholderStyle;
  final AlignmentGeometry? alignment;
  final AlignmentGeometry? placeholderAlignment;
  final EdgeInsetsGeometry? inputPadding;
  final double? gap;
  final BoxConstraints? constraints;
  final bool stylusHandwritingEnabled;
  final Object? groupId;
  final EdgeInsets? scrollbarPadding;
  final WidgetBuilder? keyboardToolbarBuilder;
  final Widget? top;
  final Widget? bottom;
  final ValueChanged<int>? onLineCountChange;
  final Size? editableTextSize;
  final double? verticalGap;
  final bool mobileFlowDialogInset;
  final EdgeInsetsGeometry mobileFlowDialogInsetPadding;

  @override
  Widget build(BuildContext context) {
    Widget child = ShadInput(
      initialValue: initialValue,
      placeholder: placeholder,
      controller: controller,
      focusNode: focusNode,
      decoration: decoration,
      undoController: undoController,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      readOnly: readOnly,
      showCursor: showCursor,
      autofocus: autofocus,
      obscuringCharacter: obscuringCharacter,
      obscureText: obscureText,
      autocorrect: autocorrect,
      smartDashesType: smartDashesType,
      smartQuotesType: smartQuotesType,
      enableSuggestions: enableSuggestions,
      maxLines: maxLines,
      minLines: minLines,
      expands: expands,
      maxLength: maxLength,
      maxLengthEnforcement: maxLengthEnforcement,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      onAppPrivateCommand: onAppPrivateCommand,
      inputFormatters: inputFormatters,
      enabled: enabled,
      cursorWidth: cursorWidth,
      cursorHeight: cursorHeight,
      cursorRadius: cursorRadius,
      cursorOpacityAnimates: cursorOpacityAnimates,
      cursorColor: cursorColor,
      selectionHeightStyle: selectionHeightStyle,
      selectionWidthStyle: selectionWidthStyle,
      keyboardAppearance: keyboardAppearance,
      scrollPadding: scrollPadding,
      dragStartBehavior: dragStartBehavior,
      enableInteractiveSelection: enableInteractiveSelection,
      selectionControls: selectionControls,
      onPressed: onPressed,
      onPressedAlwaysCalled: onPressedAlwaysCalled,
      onPressedOutside: onPressedOutside,
      mouseCursor: mouseCursor,
      scrollController: scrollController,
      scrollPhysics: scrollPhysics,
      autofillHints: autofillHints ?? const <String>[],
      contentInsertionConfiguration: contentInsertionConfiguration,
      clipBehavior: clipBehavior,
      restorationId: restorationId,
      scribbleEnabled: scribbleEnabled,
      enableIMEPersonalizedLearning: enableIMEPersonalizedLearning,
      contextMenuBuilder: contextMenuBuilder,
      spellCheckConfiguration: spellCheckConfiguration,
      magnifierConfiguration: magnifierConfiguration,
      selectionColor: selectionColor,
      padding: padding,
      leading: leading,
      trailing: trailing,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      placeholderStyle: placeholderStyle,
      alignment: alignment,
      placeholderAlignment: placeholderAlignment,
      inputPadding: inputPadding,
      gap: gap,
      constraints: constraints,
      stylusHandwritingEnabled: stylusHandwritingEnabled,
      groupId: groupId,
      scrollbarPadding: scrollbarPadding,
      keyboardToolbarBuilder: keyboardToolbarBuilder,
      top: top,
      bottom: bottom,
      onLineCountChange: onLineCountChange,
      editableTextSize: editableTextSize,
      verticalGap: verticalGap,
    );

    if (mobileFlowDialogInset && powerboardsUsesNativeMobileDialogLayout(context)) {
      child = Padding(padding: mobileFlowDialogInsetPadding, child: child);
    }

    return child;
  }
}

class PowerboardsAdaptiveInputFormField extends ShadInputFormField {
  PowerboardsAdaptiveInputFormField({
    super.id,
    super.key,
    super.onSaved,
    super.forceErrorText,
    super.validator,
    super.initialValue,
    super.enabled,
    super.autovalidateMode,
    super.restorationId,
    super.controller,
    super.label,
    super.error,
    super.description,
    super.onChanged,
    super.valueTransformer,
    super.toValueTransformer,
    super.fromValueTransformer,
    super.onReset,
    super.focusNode,
    super.decoration,
    super.placeholder,
    super.magnifierConfiguration,
    super.keyboardType,
    super.textInputAction,
    super.textCapitalization,
    super.style,
    super.strutStyle,
    super.textAlign,
    super.textDirection,
    super.autofocus,
    super.obscuringCharacter,
    super.obscureText,
    super.autocorrect,
    super.smartDashesType,
    super.smartQuotesType,
    super.enableSuggestions,
    super.maxLines,
    super.minLines,
    super.expands,
    super.readOnly,
    super.showCursor,
    super.maxLength,
    super.maxLengthEnforcement,
    super.onEditingComplete,
    super.onSubmitted,
    super.onAppPrivateCommand,
    super.inputFormatters,
    super.cursorWidth,
    super.cursorHeight,
    super.cursorRadius,
    super.cursorOpacityAnimates,
    super.cursorColor,
    super.selectionHeightStyle,
    super.selectionWidthStyle,
    super.keyboardAppearance,
    super.scrollPadding,
    super.enableInteractiveSelection,
    super.selectionControls,
    super.dragStartBehavior,
    super.onPressed,
    super.onPressedAlwaysCalled,
    TapRegionCallback? onPressedOutside,
    super.mouseCursor,
    super.scrollPhysics,
    super.scrollController,
    super.autofillHints,
    super.clipBehavior,
    super.scribbleEnabled,
    super.enableIMEPersonalizedLearning,
    super.contentInsertionConfiguration,
    EditableTextContextMenuBuilder? contextMenuBuilder,
    super.undoController,
    super.spellCheckConfiguration,
    super.selectionColor,
    super.padding,
    super.leading,
    super.trailing,
    super.mainAxisAlignment,
    super.crossAxisAlignment,
    super.placeholderStyle,
    super.alignment,
    super.placeholderAlignment,
    super.inputPadding,
    super.gap,
    super.constraints,
    super.groupId,
    super.keyboardToolbarBuilder,
    super.top,
    super.bottom,
    super.onLineCountChange,
    super.editableTextSize,
  }) : super(
         contextMenuBuilder: _defaultAdaptiveContextMenuBuilder(contextMenuBuilder),
         onPressedOutside: _defaultAdaptiveOnPressedOutside(onPressedOutside),
       );
}
