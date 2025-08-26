// ✅ Final and corrected code for glassmorphism_widgets.dart

import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';

// A reusable Glassmorphism container widget
class GlassmorphismContainer extends StatelessWidget {
  final double sigmaX;
  final double sigmaY;
  final Color color;
  final Widget? child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;
  final BoxShadow? boxShadow;

  const GlassmorphismContainer({
    super.key,
    this.sigmaX = 10.0,
    this.sigmaY = 10.0,
    this.color = Colors.white,
    this.child,
    this.borderRadius,
    this.padding,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: borderRadius ?? BorderRadius.circular(16.0),
            border: border ?? Border.all(color: color.withOpacity(0.2), width: 1.0),
            boxShadow: boxShadow != null ? [boxShadow!] : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

// A reusable Glassmorphism Tag widget
Widget buildGlassTag({required String text, Color? color, IconData? icon}) {
  Color textColor = Colors.black87;
  if (color is MaterialColor) {
    textColor = color.shade900.withOpacity(0.9);
  } else if (color != null) {
    // A simple heuristic to pick a darker text color for custom colors
    textColor = color.withOpacity(0.9);
  }

  return GlassmorphismContainer(
    sigmaX: 5,
    sigmaY: 5,
    borderRadius: BorderRadius.circular(20),
    color: color ?? Colors.grey,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: GoogleFonts.almarai(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    ),
  );
}

// A reusable Glassmorphism Card widget
Widget buildGlassCard({required Widget child, EdgeInsets? padding, BoxShadow? boxShadow}) {
  return GlassmorphismContainer(
    borderRadius: BorderRadius.circular(25),
    border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
    sigmaX: 10,
    sigmaY: 10,
    color: Colors.white.withOpacity(0.2),
    boxShadow: boxShadow, // ✅ Pass the boxShadow to the container
    child: Padding(
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    ),
  );
}