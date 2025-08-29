// lib/widgets/chat/chat_message_input.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:almahriah_frontend/models/user.dart';

class ChatMessageInput extends StatefulWidget {
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
  _ChatMessageInputState createState() => _ChatMessageInputState();
}

class _ChatMessageInputState extends State<ChatMessageInput> {
  static const platform = MethodChannel("com.almahriah.app/dialog");
  bool _isSendButtonVisible = false;

  @override
  void initState() {
    super.initState();
    widget.textController.addListener(_updateSendButtonVisibility);
  }

  @override
  void dispose() {
    widget.textController.removeListener(_updateSendButtonVisibility);
    super.dispose();
  }

  void _updateSendButtonVisibility() {
    setState(() {
      _isSendButtonVisible = widget.textController.text.trim().isNotEmpty;
    });
  }

  void _handleSend() {
    if (widget.textController.text.trim().isNotEmpty) {
      widget.onSendMessage();
    }
  }

  void _onEnterPressed(RawKeyEvent event) {
    if (kIsWeb) {
      if (event.logicalKey == LogicalKeyboardKey.enter && !event.isShiftPressed) {
        _handleSend();
      }
    }
  }

  void _showComingSoonAlert() {
    if (Platform.isIOS) {
      platform.invokeMethod('showAlert', {
        'title': 'قريباً',
        'message': 'ستتوفر قريباً ميزات إرسال الملفات والوسائط.',
      });
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('قريباً', style: GoogleFonts.almarai(fontWeight: FontWeight.bold)),
            content: Text('ستتوفر قريباً ميزات إرسال الملفات والوسائط.', style: GoogleFonts.almarai()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('موافق', style: GoogleFonts.almarai(color: Colors.blue)),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = kIsWeb;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        // ✅ زيادة المسافة السفلية على الأيفون
        bottom: isWeb ? 10 : MediaQuery.of(context).viewInsets.bottom + 25,
        left: 12,
        right: 12,
        top: 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyingToMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GestureDetector(
                onTap: widget.onReplyPreviewTap,
                child: _buildReplyPreview(),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ✅ إزالة الشرط لإظهار الأيقونة على الويب
              Container(
                margin: const EdgeInsets.only(left: 8, bottom: 2),
                child: IconButton(
                  icon: const Icon(CupertinoIcons.plus_circle_fill, color: Colors.blue),
                  onPressed: _showComingSoonAlert,
                  iconSize: 24,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isWeb ? 0 : 8),
                  child: RawKeyboardListener(
                    focusNode: FocusNode(),
                    onKey: _onEnterPressed,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: TextField(
                        cursorColor: Colors.blue.shade600,
                        controller: widget.textController,
                        focusNode: widget.focusNode,
                        onChanged: widget.onTyping,
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        minLines: 1,
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
                  ),
                ),
              ),
              if (_isSendButtonVisible)
                GestureDetector(
                  onTap: _handleSend,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8, bottom: 2),
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                  ),
                ),
              if (!_isSendButtonVisible && !isWeb)
                Container(
                  margin: const EdgeInsets.only(right: 8, bottom: 2),
                  child: IconButton(
                    icon: const Icon(Icons.mic_none_outlined, color: Colors.blue),
                    onPressed: _showComingSoonAlert,
                    iconSize: 24,
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
      margin: const EdgeInsets.only(bottom: 8),
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
                  widget.replyingToMessage['senderId'].toString() == widget.user.id.toString()
                      ? 'أنت'
                      : widget.targetUser['fullName'],
                  style: GoogleFonts.almarai(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.replyingToMessage['content'],
                  style: GoogleFonts.almarai(color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: widget.onCancelReply,
          ),
        ],
      ),
    );
  }
}