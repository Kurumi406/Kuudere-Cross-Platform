import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedBackground extends StatefulWidget {
  final Widget child;

  const AnimatedBackground({Key? key, required this.child}) : super(key: key);

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> particles = List.generate(
    20,
    (index) => Particle()
      ..position = Offset(
        math.Random().nextDouble() * 400,
        math.Random().nextDouble() * 800,
      )
      ..velocity = Offset(
        math.Random().nextDouble() * 2 - 1,
        math.Random().nextDouble() * 2 - 1,
      ),
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomPaint(
          painter: ParticlePainter(particles, _controller),
          size: Size.infinite,
        ),
        widget.child,
      ],
    );
  }
}

class Particle {
  late Offset position;
  late Offset velocity;
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Animation<double> animation;

  ParticlePainter(this.particles, this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    for (var particle in particles) {
      particle.position += particle.velocity;

      if (particle.position.dx < 0 || particle.position.dx > size.width) {
        particle.velocity = Offset(-particle.velocity.dx, particle.velocity.dy);
      }
      if (particle.position.dy < 0 || particle.position.dy > size.height) {
        particle.velocity = Offset(particle.velocity.dx, -particle.velocity.dy);
      }

      canvas.drawCircle(particle.position, 3, paint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}