// lib/widgets/message_bubble.dart - إصلاح عرض الردود

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

class MessageBubble extends StatelessWidget {
  final dynamic message;
  final bool isMyMessage;
  final Function(dynamic) onReply;
  final Function(dynamic) onLongPress;
  final String? repliedMessageContent;
  final String? repliedMessageId;
  final bool isHighlighted;
  final bool isSelected;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMyMessage,
    required this.onReply,
    required this.onLongPress,
    this.repliedMessageContent,
    this.repliedMessageId,
    required this.isHighlighted,
    this.isSelected = false,
  });

  Widget _buildMessageStatusIcon(dynamic msg) {
    final bool readStatus = (msg['readStatus'] == true || msg['readStatus'] == 1);
    final bool deliveredStatus = (msg['deliveredStatus'] == true || msg['deliveredStatus'] == 1);
    
    Widget statusIcon;
    if (readStatus) {
      statusIcon = const Icon(Icons.done_all, size: 14, color: Colors.blueAccent);
    } else if (deliveredStatus) {
      statusIcon = const Icon(Icons.done_all, size: 14, color: Colors.white54);
    } else {
      statusIcon = const Icon(Icons.done, size: 14, color: Colors.white54);
    }
    return statusIcon;
  }

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a', 'en_US').format(time.toLocal());
  }

  String _getDisplayTime(Map<String, dynamic> msg) {
    final createdAt = DateTime.parse(msg['createdAt']);
    final updatedAt = msg['updatedAt'] != null ? DateTime.parse(msg['updatedAt']) : null;
    
    if (updatedAt != null) {
      return '${_formatTime(updatedAt)} (تم التعديل)';
    } else {
      return _formatTime(createdAt);
    }
  }

  Widget _buildReplyPreview() {
    // التحقق من وجود الرد في الرسالة نفسها أولاً
    final replyContent = message['replyToMessageContent'] ?? repliedMessageContent;
    
    if (replyContent == null || replyContent.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isMyMessage 
            ? Colors.white.withOpacity(0.2) 
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          right: BorderSide(
            color: isMyMessage ? Colors.white : const Color(0xFF2C3E50),
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.reply,
                size: 16,
                color: isMyMessage ? Colors.white70 : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                'رد على:',
                style: GoogleFonts.almarai(
                  color: isMyMessage ? Colors.white70 : Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isMyMessage 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              replyContent.toString(),
              style: GoogleFonts.almarai(
                color: isMyMessage 
                    ? Colors.white.withOpacity(0.9) 
                    : Colors.grey.shade800,
                fontSize: 13,
                height: 1.3,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: isMyMessage ? const Radius.circular(20) : const Radius.circular(5),
      bottomRight: isMyMessage ? const Radius.circular(5) : const Radius.circular(20),
    );

    final DismissDirection swipeDirection = isMyMessage 
        ? DismissDirection.startToEnd 
        : DismissDirection.endToStart; 

    final Color backgroundColor = isSelected
        ? (isMyMessage ? const Color(0xFF2C3E50).withOpacity(0.5) : Colors.grey.shade400)
        : (isMyMessage ? const Color(0xFF2C3E50).withOpacity(0.9) : Colors.grey.shade200);

    return Dismissible(
      key: ValueKey(message['id'].toString()),
      direction: swipeDirection,
      movementDuration: const Duration(milliseconds: 100),
      crossAxisEndOffset: 0.1,
      confirmDismiss: (direction) async {
        onReply(message);
        if (Theme.of(context).platform == TargetPlatform.iOS) {
          HapticFeedback.lightImpact();
        }
        return false;
      },
      background: Align(
        alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Icon(Icons.reply, color: Colors.blueGrey.withOpacity(0.5)),
        ),
      ),
      child: Align(
        alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => onLongPress(message),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isHighlighted 
                  ? Colors.blue.withOpacity(0.3)
                  : backgroundColor,
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isHighlighted || isSelected ? 0.3 : 0.05),
                  spreadRadius: isHighlighted || isSelected ? 2 : 1,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // عرض الرسالة المردود عليها
                _buildReplyPreview(),
                
                // محتوى الرسالة الأساسي
                Text(
                  message['content'],
                  style: GoogleFonts.almarai(
                    color: isMyMessage ? Colors.white : Colors.black87,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                
                // الوقت وحالة التسليم
                Align(
                  alignment: isMyMessage ? Alignment.bottomRight : Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getDisplayTime(message),
                          style: GoogleFonts.almarai(
                            color: isMyMessage ? Colors.white70 : Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                        if (isMyMessage) ...[
                          const SizedBox(width: 5),
                          _buildMessageStatusIcon(message),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}