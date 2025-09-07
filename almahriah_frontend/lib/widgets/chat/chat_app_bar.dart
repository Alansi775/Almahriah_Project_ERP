// lib/widgets/chat/chat_app_bar.dart - النسخة النهائية المُحسنة والمُصححة

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:almahriah_frontend/services/auth_service.dart';
import 'package:almahriah_frontend/widgets/glassmorphism_widgets.dart'; // ✅ إضافة لاستخدام buildGlassTag

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

  String _getInitials(String? fullName) {
    if (fullName == null || fullName.isEmpty) return '?';
    final parts = fullName.split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return fullName[0].toUpperCase();
  }

  Widget _buildUserAvatar(String? fullName, String? profilePictureUrl, bool isOnline, double size) {
    final String initials = _getInitials(fullName);
    final Color glowColor = isOnline ? Colors.green.shade400 : Colors.red.shade400;
    
    final bool hasProfilePicture = profilePictureUrl != null && profilePictureUrl.isNotEmpty;
    final String fullImageUrl = hasProfilePicture ? '${AuthService.baseUrl}$profilePictureUrl' : '';

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
      child: hasProfilePicture
          ? ClipOval(
              child: Image.network(
                fullImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Text(
                      initials,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: size * 0.4,
                        color: Colors.black87,
                      ),
                    ),
                  );
                },
              ),
            )
          : Center(
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double expandedHeight = constraints.biggest.height;
        const double collapsedHeight = 100.0;
        const double maxExpandedHeight = 140.0;
        
        final double t = ((expandedHeight - collapsedHeight) / (maxExpandedHeight - collapsedHeight)).clamp(0.0, 1.0);

        final double avatarSize = 40.0 + (5 * t);
        final double nameFontSize = 12.0 + (3 * t);
        final double statusFontSize = 10.0 + (2 * t);
        final double tagOpacity = t;

        final Color appBarColor = Color.lerp(
          Colors.transparent,
          Colors.white.withOpacity(0.8),
          t,
        )!;
        
        // جلب البيانات من كائن المستخدم الهدف
        final String? fullName = targetUser['fullName'];
        final String? profilePictureUrl = targetUser['profilePictureUrl'];
        final String? role = targetUser['role'];
        final String? department = targetUser['department'];

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
                  child: _buildUserAvatar(fullName, profilePictureUrl, isOnline, avatarSize),
                ),
                SizedBox(height: 2 + (2 * t)),
                Flexible(
                  child: Text(
                    fullName ?? '',
                    style: GoogleFonts.almarai(
                      fontWeight: FontWeight.bold,
                      fontSize: nameFontSize,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // ✅ إضافة الدور والقسم مع التحكم بالشفافية
                if (role != null && department != null) ...[
                  Opacity(
                    opacity: tagOpacity,
                    child: buildGlassTag(
                      text: '$role - $department',
                      fontSize: 7 + (2 * t),
                    ),
                  ),
                  SizedBox(height: 4 + (4 * t)), // ✅ مسافة بين الدور وحالة الاتصال
                ],
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
}