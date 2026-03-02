import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SweepStatusText extends StatefulWidget {
  const SweepStatusText({super.key, required this.text, required this.style, this.textAlign = TextAlign.center});

  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  State<SweepStatusText> createState() => _SweepStatusTextState();
}

class _SweepStatusTextState extends State<SweepStatusText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Shader _sweepShader(BuildContext context, Rect rect, double t) {
    final colorScheme = ShadTheme.of(context).colorScheme;
    final centerX = -1.4 + (t * 2.8);
    final highlight = colorScheme.background.withAlpha(210);

    return LinearGradient(
      begin: Alignment(centerX - 0.45, 0),
      end: Alignment(centerX + 0.45, 0),
      colors: [Colors.transparent, highlight, Colors.transparent],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(rect);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final base = Text(widget.text, style: widget.style, textAlign: widget.textAlign);
        return Stack(
          children: [
            base,
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (rect) => _sweepShader(context, rect, _controller.value),
              child: Text(
                widget.text,
                style: widget.style.copyWith(color: Colors.white),
                textAlign: widget.textAlign,
              ),
            ),
          ],
        );
      },
    );
  }
}
