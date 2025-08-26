// lib/widgets/animated_ai_button.dart
import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedAiButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String tooltip;

  const AnimatedAiButton({
    Key? key,
    required this.onPressed,
    this.tooltip = 'مساعد الذكاء الاصطناعي',
  }) : super(key: key);

  @override
  _AnimatedAiButtonState createState() => _AnimatedAiButtonState();
}

class _AnimatedAiButtonState extends State<AnimatedAiButton>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(_rotationController);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      verticalOffset: 40.0, // رفع الكلمة للأعلى
      textStyle: const TextStyle(fontSize: 10, color: Colors.white, fontFamily: 'Almarai'), // تصغير حجم الخط
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The pulsing/glowing container
          ScaleTransition(
            scale: _pulseAnimation,
            child: AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade800.withOpacity(0.8),
                          blurRadius: 15,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // The main button
          FloatingActionButton(
            onPressed: widget.onPressed,
            backgroundColor: Colors.blue.shade800,
            shape: const CircleBorder(),
            elevation: 5,
            child: Container(),
          ),
        ],
      ),
    );
  }
}