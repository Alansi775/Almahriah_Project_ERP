// lib/pages/chat_page.dart - Final Version

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/services/auth_service.dart';
import 'dart:ui';
import 'package:almahriah_frontend/widgets/glassmorphism_widgets.dart';

// ✅ استيراد خدمة المقبس الجديدة
import 'package:almahriah_frontend/services/socket_service.dart';

class ChatPage extends StatefulWidget {
  final User user;
  final dynamic targetUser;

  const ChatPage({super.key, required this.user, required this.targetUser});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final List<dynamic> _messages = [];
  final ScrollController _scrollController = ScrollController();
  
  // ✅ استخدام خدمة المقبس
  final SocketService _socketService = SocketService();
  
  bool _isTyping = false;
  bool _isOnline = false;
  bool _isLoading = false;
  
  // ✅ الاشتراك في تدفق الرسائل
  late StreamSubscription _messagesSubscription;
  
  // ✅ متغير لمراقبة حالة الكتابة للمستخدم الآخر
  bool _isTargetUserTyping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _isOnline = _socketService.userStatus.value[widget.targetUser['id'].toString()] ?? false;
    _isTargetUserTyping = _socketService.typingStatus.value[widget.targetUser['id'].toString()] ?? false;

    // ✅ الاستماع للرسائل الجديدة
    _messagesSubscription = _socketService.messagesStream.listen((data) {
      if (mounted) {
        if (data['senderId'].toString() == widget.targetUser['id'].toString()) {
          setState(() {
            _messages.add(data);
          });
          _scrollToBottom();
          _markMessageAsRead(data['id']);
        }
      }
    });

    // ✅ الاستماع لتغير حالة المستخدم
    _socketService.userStatus.addListener(_onUserStatusChange);
    
    // ✅ الاستماع لتغير حالة الكتابة
    _socketService.typingStatus.addListener(_onTypingStatusChange);
    
    _fetchChatHistory();
  }

  void _onUserStatusChange() {
    if (mounted) {
      setState(() {
        _isOnline = _socketService.userStatus.value[widget.targetUser['id'].toString()] ?? false;
      });
      if (_isOnline) {
        _updatePendingMessagesDelivery();
      }
    }
  }

  void _onTypingStatusChange() {
    if (mounted) {
      setState(() {
        _isTargetUserTyping = _socketService.typingStatus.value[widget.targetUser['id'].toString()] ?? false;
      });
      if (_isTargetUserTyping) {
        // يمكننا إضافة مؤقت هنا لإخفاء حالة "يكتب..." تلقائيًا
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _isTargetUserTyping) {
            setState(() {
              _isTargetUserTyping = false;
            });
          }
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      _markAllMessagesAsRead();
    } else if (state == AppLifecycleState.paused) {
      _stopTyping();
    }
  }

  Future<void> _fetchChatHistory() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/api/chat/history/${widget.targetUser['id']}'),
        headers: {'Authorization': 'Bearer ${widget.user.token}'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(json.decode(response.body));
            _isLoading = false;
          });
          _scrollToBottom();
          _markAllMessagesAsRead();
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load chat history.', style: GoogleFonts.almarai())),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل تاريخ المحادثة: $e', style: GoogleFonts.almarai())),
        );
      }
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    
    final messageData = {
      'tempId': tempId,
      'senderId': widget.user.id,
      'receiverId': widget.targetUser['id'],
      'content': text,
      'readStatus': false,
      'deliveredStatus': _isOnline,
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (mounted) {
      setState(() {
        _messages.add(messageData);
      });
    }
    
    _textController.clear();
    _scrollToBottom();
    
    // ✅ إرسال الرسالة عبر خدمة المقبس
    _socketService.emitEvent('sendMessage', messageData);
    
    _stopTyping();
  }

  void _onTyping(String text) {
    _socketService.emitEvent('typing', {
      'senderId': widget.user.id,
      'receiverId': widget.targetUser['id'],
      'isTyping': text.trim().isNotEmpty,
    });
  }

  void _stopTyping() {
    _socketService.emitEvent('typing', {
      'senderId': widget.user.id,
      'receiverId': widget.targetUser['id'],
      'isTyping': false,
    });
  }

  void _markMessageAsRead(dynamic messageId) {
    if (messageId == null) return;
    _socketService.emitEvent('readMessage', {
      'messageId': messageId,
      'senderId': widget.user.id,
      'receiverId': widget.targetUser['id']
    });
  }

  void _markAllMessagesAsRead() {
    for (var message in _messages) {
      if (message['senderId'].toString() == widget.targetUser['id'].toString() &&
          (message['readStatus'] == false || message['readStatus'] == null)) {
        _markMessageAsRead(message['id']);
      }
    }
  }

  void _updatePendingMessagesDelivery() {
    if (!mounted) return;
    
    setState(() {
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i]['senderId'].toString() == widget.user.id.toString() &&
            ( _messages[i]['deliveredStatus'] == false ||  _messages[i]['deliveredStatus'] == null)) {
          _messages[i]['deliveredStatus'] = true;
        }
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messagesSubscription.cancel();
    _socketService.userStatus.removeListener(_onUserStatusChange);
    _socketService.typingStatus.removeListener(_onTypingStatusChange);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextSelectionTheme(
      data: TextSelectionThemeData(
        selectionColor: Colors.blue.shade100,
        selectionHandleColor: Colors.blue.shade800,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          toolbarHeight: 140.0,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildUserAvatar(widget.targetUser['fullName'], _isOnline),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.targetUser['fullName'],
                  style: GoogleFonts.almarai(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isTargetUserTyping
                    ? 'يكتب...'
                    : _isOnline
                        ? 'متصل الآن'
                        : 'غير متصل',
                style: GoogleFonts.almarai(
                  fontSize: 12,
                  color: _isTargetUserTyping
                      ? Colors.blue.shade400
                      : (_isOnline ? Colors.green.shade400 : Colors.red.shade400),
                ),
              ),
            ],
          ),
          centerTitle: true,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
        ),
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF2C3E50)))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final isMyMessage = message['senderId'].toString() == widget.user.id.toString();
                              return _buildMessageBubble(message, isMyMessage);
                            },
                          ),
                  ),
                  _buildMessageInput(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String fullName, bool isOnline) {
    final String initials = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
    final Color glowColor = isOnline ? Colors.green.shade400 : Colors.red.shade400;

    return Container(
      width: 60,
      height: 60,
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
            fontSize: 24,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(dynamic message, bool isMyMessage) {
    final BorderRadius borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: isMyMessage ? const Radius.circular(20) : const Radius.circular(5),
      bottomRight: isMyMessage ? const Radius.circular(5) : const Radius.circular(20),
    );

    return Align(
      alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: isMyMessage ? const Color(0xFF2C3E50).withOpacity(0.9) : Colors.grey.shade200,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message['content'],
              style: GoogleFonts.almarai(
                color: isMyMessage ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            if (isMyMessage)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: _buildMessageStatusIcon(message),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageStatusIcon(dynamic message) {
    if (message['readStatus'] == true) {
      return const Icon(Icons.done_all, size: 14, color: Colors.blueAccent);
    } else if (message['deliveredStatus'] == true) {
      return const Icon(Icons.done_all, size: 14, color: Colors.white54);
    } else {
      return const Icon(Icons.done, size: 14, color: Colors.white54);
    }
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              onChanged: _onTyping,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              style: GoogleFonts.almarai(),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade100,
                hintText: 'اكتب رسالة...',
                hintStyle: GoogleFonts.almarai(color: Colors.grey.shade600),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.blue.shade800, width: 2),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add, color: Colors.black54),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('سيتم إضافة وظيفة إرسال الملفات قريبًا!', style: GoogleFonts.almarai()))
                    );
                  },
                ),
              ),
              cursorColor: Colors.blue.shade800,
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: const Color(0xFF2C3E50),
            borderRadius: BorderRadius.circular(30),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}