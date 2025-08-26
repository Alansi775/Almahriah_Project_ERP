// lib/custom_page_route.dart

import 'package:flutter/material.dart';

// دالة الانتقال المخصصة Fade
class CustomPageRoute extends PageRouteBuilder {
  final Widget child;

  CustomPageRoute({required this.child})
      : super(
          transitionDuration: const Duration(milliseconds: 80), // ⚡ تم تسريع الانتقال
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 💡 Haptic feedback has been removed from here
            
            // ⚡ تأثير الـ Fade In
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );
}