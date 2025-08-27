// lib/widgets/message_bubble.dart - النسخة النهائية المصححة

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
  final Function(dynamic, bool) onLongPress;
  final dynamic repliedMessageContent;
  final bool isHighlighted;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMyMessage,
    required this.onReply,
    required this.onLongPress,
    this.repliedMessageContent,
    required this.isHighlighted,
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
      return '${_formatTime(updatedAt)} (Edited)';
    } else {
      return _formatTime(createdAt);
    }
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isMyMessage ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        repliedMessageContent,
        style: GoogleFonts.almarai(
          color: isMyMessage ? Colors.white70 : Colors.black54,
          fontSize: 12,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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

    // ✅ التعديل هنا لضمان أن اتجاه السحب للرد يكون دائمًا نحو وسط الشاشة
    final DismissDirection swipeDirection = isMyMessage 
        ? DismissDirection.startToEnd 
        : DismissDirection.endToStart; 

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
        onLongPress: () => onLongPress(message, isMyMessage),
        child: AnimatedContainer( // ✅ تغيير Container إلى AnimatedContainer
          duration: const Duration(milliseconds: 300), // ✅ مدة الانتقال
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.50),
          decoration: BoxDecoration(
            color: isHighlighted // ✅ استخدام isHighlighted لتغيير اللون
                ? Colors.blue.withOpacity(0.3)
                : (isMyMessage ? const Color(0xFF2C3E50).withOpacity(0.9) : Colors.grey.shade200),
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isHighlighted ? 0.3 : 0.05),
                spreadRadius: isHighlighted ? 2 : 1,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (repliedMessageContent != null)
                  _buildReplyPreview(),
                
                Text(
                  message['content'],
                  style: GoogleFonts.almarai(
                    color: isMyMessage ? Colors.white : Colors.black87,
                    fontSize: 15,
                  ),
                ),
                Align(
                  alignment: isMyMessage ? Alignment.bottomRight : Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getDisplayTime(message),
                          style: GoogleFonts.almarai(
                            color: isMyMessage ? Colors.white70 : Colors.black54,
                            fontSize: 10,
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