import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WaterBackground extends StatefulWidget {
  final Widget child;
  final bool animate;

  const WaterBackground({super.key, required this.child, this.animate = true});

  @override
  State<WaterBackground> createState() => _WaterBackgroundState();
}

class _WaterBackgroundState extends State<WaterBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_WaterDrop> _drops = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    for (int i = 0; i < 15; i++) {
      _drops.add(_WaterDrop(
        x: (i * 0.07 + 0.02) % 1.0,
        delay: i * 0.2,
        size: 3.0 + (i % 3) * 2.0,
        speed: 0.8 + (i % 5) * 0.15,
        opacity: 0.08 + (i % 4) * 0.03,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.isDark
        ? const [
            Color(0xFF0B1421),
            Color(0xFF122336),
            Color(0xFF0B1421),
          ]
        : const [
            Color(0xFFE7F6FA),
            Color(0xFFF7FCFE),
            Colors.white,
          ];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          if (widget.animate)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: _WaterPainter(_drops, _controller.value),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

class _WaterDrop {
  final double x;
  final double delay;
  final double size;
  final double speed;
  final double opacity;

  const _WaterDrop({
    required this.x,
    required this.delay,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class _WaterPainter extends CustomPainter {
  final List<_WaterDrop> drops;
  final double progress;

  _WaterPainter(this.drops, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final drop in drops) {
      final p = (progress * drop.speed + drop.delay) % 1.0;
      final y = p * size.height;
      final x = drop.x * size.width;
      final opacity = p > 0.9 ? drop.opacity * (1 - (p - 0.9) / 0.1) : drop.opacity;

      final paint = Paint()
        ..color = AppColors.primaryLight.withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(Offset(x, y), drop.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaterPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class AnimatedLogo extends StatefulWidget {
  final double size;
  final IconData icon;

  const AnimatedLogo({
    super.key,
    this.size = 100,
    this.icon = Icons.local_car_wash,
  });

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _float;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _float = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _pulse = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
      builder: (context, _) => Transform.translate(
        offset: Offset(0, -_float.value),
        child: Transform.scale(
          scale: _pulse.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryLight, AppColors.primaryDark],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(widget.icon, size: widget.size * 0.5, color: Colors.white),
                Positioned(
                  bottom: widget.size * 0.15,
                  child: Icon(Icons.water_drop, size: widget.size * 0.18, color: Colors.white38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StaggeredFadeIn extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration delay;

  const StaggeredFadeIn({
    super.key,
    required this.index,
    required this.child,
    this.delay = const Duration(milliseconds: 80),
  });

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    final staggerDelay = Duration(milliseconds: widget.index * widget.delay.inMilliseconds);
    Future.delayed(staggerDelay, () {
      if (mounted) _controller.forward();
    });

    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
