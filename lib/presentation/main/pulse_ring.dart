import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class PulseRing extends StatefulWidget {
  const PulseRing({required this.size, required this.color, super.key});

  final double size;
  final Color color;

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: WraitAnimationTokens.pulse,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        final scale = 1 + ((WraitButtonTokens.pulseScaleMax - 1) * value);
        final opacity = WraitButtonTokens.pulseAlphaStart * (1 - value);

        return Transform.scale(
          scale: scale,
          child: Opacity(opacity: opacity.clamp(0, 1), child: child),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: widget.color, width: 2),
        ),
      ),
    );
  }
}
