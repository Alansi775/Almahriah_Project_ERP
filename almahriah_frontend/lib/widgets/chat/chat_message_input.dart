// lib/widgets/chat/chat_message_input.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:almahriah_frontend/models/user.dart';

class ChatMessageInput extends StatelessWidget {
  final TextEditingController textController;
  final FocusNode focusNode;
  final dynamic replyingToMessage;
  final User user;
  final dynamic targetUser;
  final VoidCallback onSendMessage;
  final Function(String) onTyping;
  final VoidCallback onReplyPreviewTap;
  final VoidCallback onCancelReply;

  const ChatMessageInput({
    super.key,
    required this.textController,
    required this.focusNode,
    this.replyingToMessage,
    required this.user,
    required this.targetUser,
    required this.onSendMessage,
    required this.onTyping,
    required this.onReplyPreviewTap,
    required this.onCancelReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 10,
        left: 12,
        right: 12,
        top: 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyingToMessage != null)
            GestureDetector(
              onTap: onReplyPreviewTap,
              child: _buildReplyPreview(),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  cursorColor: Colors.blue.shade600,
                  controller: textController,
                  focusNode: focusNode,
                  onChanged: onTyping,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  style: GoogleFonts.almarai(),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    hintText: 'اكتب رسالتك...',
                    hintStyle: GoogleFonts.almarai(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onSendMessage,
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade100.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  replyingToMessage['senderId'].toString() == user.id.toString() ? 'أنت' : targetUser['fullName'],
                  style: GoogleFonts.almarai(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  replyingToMessage['content'],
                  style: GoogleFonts.almarai(color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: onCancelReply,
          ),
        ],
      ),
    );
  }
}