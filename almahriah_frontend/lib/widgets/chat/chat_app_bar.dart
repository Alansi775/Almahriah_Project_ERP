// lib/widgets/chat/chat_app_bar.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class ChatAppBar extends StatelessWidget {
  final dynamic targetUser;
  final bool isOnline;
  final bool isTargetUserTyping;

  const ChatAppBar({
    super.key,
    required this.targetUser,
    required this.isOnline,
    required this.isTargetUserTyping,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double expandedHeight = constraints.biggest.height;
        final double collapsedHeight = 100.0;
        final double maxExpandedHeight = 140.0;
        
        // This 't' value is the key to the animation. It goes from 0 to 1 as the app bar expands.
        final double t = ((expandedHeight - collapsedHeight) / (maxExpandedHeight - collapsedHeight)).clamp(0.0, 1.0);

        final double avatarSize = 40.0 + (5 * t);
        final double nameFontSize = 12.0 + (3 * t);
        final double statusFontSize = 10.0 + (2 * t);

        final Color appBarColor = Color.lerp(
          Colors.transparent,
          Colors.white.withOpacity(0.8),
          t,
        )!;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: appBarColor,
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: avatarSize,
                  height: avatarSize,
                  child: _buildUserAvatar(targetUser['fullName'], isOnline, avatarSize),
                ),
                SizedBox(height: 2 + (2 * t)),
                Flexible(
                  child: Text(
                    targetUser['fullName'] ?? '',
                    style: GoogleFonts.almarai(
                      fontWeight: FontWeight.bold,
                      fontSize: nameFontSize,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Flexible(
                  child: Text(
                    isTargetUserTyping
                      ? 'يكتب...'
                      : isOnline
                        ? 'متصل الآن'
                        : 'غير متصل',
                    style: GoogleFonts.almarai(
                      fontSize: statusFontSize,
                      color: isTargetUserTyping
                        ? Colors.blue.shade400
                        : (isOnline ? Colors.green.shade400 : Colors.red.shade400),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildUserAvatar(String fullName, bool isOnline, double size) {
    // Keep this helper method as is
    final String initials = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
    final Color glowColor = isOnline ? Colors.green.shade400 : Colors.red.shade400;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade200,
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(isOnline ? 0.7 : 0.5),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}