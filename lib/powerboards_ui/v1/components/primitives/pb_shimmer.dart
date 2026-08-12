import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';

class PbShimmer extends StatefulWidget {
  const PbShimmer({super.key, required this.child, required this.idleColor, required this.sweepColor, required this.peakColor});

  final Widget child;
  final Color idleColor;
  final Color sweepColor;
  final Color peakColor;

  @override
  State<PbShimmer> createState() => _PbShimmerState();
}

class _PbShimmerState extends State<PbShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) {
          final progress = Curves.easeInOut.transform(_controller.value);
          final center = Alignment.lerp(const Alignment(-1.4, -1.4), const Alignment(1.4, 1.4), progress)!;
          return RadialGradient(
            center: center,
            radius: 1.18,
            colors: [
              widget.peakColor,
              Color.lerp(widget.peakColor, widget.sweepColor, 0.4)!,
              widget.sweepColor,
              Color.lerp(widget.sweepColor, widget.idleColor, 0.5)!,
              widget.idleColor,
            ],
            stops: const [0, 0.22, 0.5, 0.68, 1],
          ).createShader(bounds);
        },
        child: child,
      ),
    );
  }
}

class PbThreadAttachmentLoadingPlaceholder extends StatelessWidget {
  const PbThreadAttachmentLoadingPlaceholder({super.key, required this.borderRadius});

  final BorderRadius borderRadius;

  static Color get surfaceColor => Color.lerp(PbColors.surfacePanelSoft, PbColors.borderSoft, 0.62)!;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PbShimmer(
            key: const ValueKey('pb-thread-attachment-loading-shimmer'),
            idleColor: surfaceColor,
            sweepColor: Color.lerp(surfaceColor, PbColors.surfaceAccentSoft, 0.6)!,
            peakColor: Color.lerp(surfaceColor, Colors.white, 0.5)!,
            child: const ColoredBox(color: Colors.white),
          ),
          Center(
            child: Semantics(
              label: 'Loading attachment',
              child: const SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class PbThreadImageGenerationLoadingPlaceholder extends StatelessWidget {
  const PbThreadImageGenerationLoadingPlaceholder({super.key, required this.borderRadius});

  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: PbShimmer(
        key: const ValueKey('pb-thread-image-generation-loading-shimmer'),
        idleColor: PbColors.customStateSelectedSurface,
        sweepColor: Color.lerp(PbColors.customStateSelectedSurfaceStart, PbColors.customStateSelectedBorder, 0.12)!,
        peakColor: Color.lerp(PbColors.customStateSelectedSurface, Colors.white, 0.64)!,
        child: const ColoredBox(color: Colors.white, child: SizedBox.expand()),
      ),
    );
  }
}
