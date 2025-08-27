// lib/pages/chat_page.dart - النسخة النهائية والمصححة

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/services/auth_service.dart';
import 'dart:ui';
import 'package:almahriah_frontend/services/socket_service.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:almahriah_frontend/widgets/message_options_sheet.dart';
import 'package:almahriah_frontend/widgets/edit_message_dialog.dart';
import 'package:almahriah_frontend/widgets/message_bubble.dart';

const platform = MethodChannel("com.almahriah.app/dialog");

class ChatPage extends StatefulWidget {
  final User user;
  final dynamic targetUser;

  const ChatPage({super.key, required this.user, required this.targetUser});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver, TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final List<dynamic> _messages = [];
  final ScrollController _scrollController = ScrollController();
  
  final SocketService _socketService = SocketService();
  
  bool _isTyping = false;
  bool _isOnline = false;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isTargetUserTyping = false;
  
  late StreamSubscription _messagesSubscription;
  late StreamSubscription _messageStatusSubscription;
  
  // ✅ متغيرات جديدة للسحب والتظليل
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;

  dynamic _replyingToMessage;
  final FocusNode _focusNode = FocusNode();
  
  final Map<String, AnimationController> _statusAnimationControllers = {};
  final Map<String, Animation<double>> _statusAnimations = {};

  bool get _isIOS => !kIsWeb && Platform.isIOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _isOnline = _socketService.userStatus.value[widget.targetUser['id'].toString()] ?? false;
    _isTargetUserTyping = _socketService.typingStatus.value[widget.targetUser['id'].toString()] ?? false;

    // ✅ إضافة listener للكيبورد
    _focusNode.addListener(_onFocusChange);

    _messagesSubscription = _socketService.messagesStream.listen((data) {
      if (mounted && data['senderId'].toString() == widget.targetUser['id'].toString()) {
        setState(() {
          _messages.add(data);
        });
        _scrollToBottom();
        Future.delayed(const Duration(milliseconds: 200), () {
          _markMessageAsRead(data['id']);
        });
      }
    });

    _messageStatusSubscription = _socketService.messageStatusStream.listen((data) {
      if (mounted) {
        _updateMessageStatus(data);
      }
    });

    _socketService.userStatus.addListener(_onUserStatusChange);
    _socketService.typingStatus.addListener(_onTypingStatusChange);
    
    _scrollController.addListener(_onScroll);
    
    _fetchChatHistory().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && _messages.isNotEmpty) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);

          if(_isIOS){
            HapticFeedback.mediumImpact();
          }

          Future.delayed(const Duration(milliseconds: 800), () {
            _markAllMessagesAsRead();
          });
        }
      });
    });

    _socketService.socket.on('messageDeleted', (data) {
      if (mounted) {
        final messageId = data['messageId'];
        setState(() {
          _messages.removeWhere((msg) => msg['id'].toString() == messageId.toString());
        });
      }
    });

    _socketService.socket.on('messageEdited', (data) {
      if (mounted) {
        final messageId = data['id'];
        final newContent = data['newContent'];
        final index = _messages.indexWhere((msg) => msg['id'].toString() == messageId.toString());
        if (index != -1) {
          setState(() {
            _messages[index]['content'] = newContent;
          });
        }
      }
    });
  }

  // ✅ إضافة دالة للتعامل مع تغيير حالة الفوكس
  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // عندما يفتح الكيبورد، انتظر قليلاً ثم اسحب لأسفل
      Future.delayed(const Duration(milliseconds: 450), () {
        _scrollToBottom();
      });
    }
  }

  void _onUserStatusChange() {
    if (mounted) {
      final newOnlineStatus = _socketService.userStatus.value[widget.targetUser['id'].toString()] ?? false;
      if (newOnlineStatus != _isOnline) {
        setState(() {
          _isOnline = newOnlineStatus;
        });
        if (_isOnline) {
          _updateDeliveryStatusForUndeliveredMessages();
        }
      }
    }
  }

  // ✅ دالة جديدة ومحسنة للسحب والتظليل
  void _scrollToAndHighlight(String? messageId) {
    if (messageId == null) return;

    final GlobalKey? key = _messageKeys[messageId];
    if (key != null) {
      final BuildContext? context = key.currentContext;
      if (context != null) {
        // قم بتفعيل التظليل
        setState(() {
          _highlightedMessageId = messageId;
        });

        // السحب إلى موضع الرسالة باستخدام Scrollable.ensureVisible
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.5, // يضع العنصر في منتصف الشاشة
        );
        
        // إيقاف التظليل بعد فترة وجيزة
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _highlightedMessageId = null;
            });
          }
        });
      }
    }
  }

  void _onTypingStatusChange() {
    if (mounted) {
      setState(() {
        _isTargetUserTyping = _socketService.typingStatus.value[widget.targetUser['id'].toString()] ?? false;
      });
    }
  }

  void _onScroll() {
    _markAllMessagesAsRead();
    
    if (_scrollController.position.pixels <= 0 && !_isRefreshing) {
      _handleRefresh();
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });

    if (_isIOS) {
      HapticFeedback.mediumImpact();
    } 

    await Future.delayed(const Duration(seconds: 2));
    
    await _fetchChatHistory();
    
    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  void _updateDeliveryStatusForUndeliveredMessages() {
    setState(() {
      for (final message in _messages) {
        if (message['senderId'].toString() == widget.user.id.toString() &&
            (message['deliveredStatus'] == false || message['deliveredStatus'] == 0)) {
          message['deliveredStatus'] = true;
        }
      }
    });
  }

  void _updateMessageStatus(dynamic data) {
    if (data['action'] == 'deleted') {
      final messageId = data['messageId'].toString();
      setState(() {
        _messages.removeWhere((msg) => msg['id'].toString() == messageId);
      });
      return;
    }

    if (data['action'] == 'edited') {
      final messageId = data['messageId'].toString();
      final newContent = data['newContent'];
      final newUpdatedAt = data['updatedAt'];
      final index = _messages.indexWhere((msg) => msg['id'].toString() == messageId);
      if (index != -1) {
        setState(() {
          _messages[index]['content'] = newContent;
          _messages[index]['updatedAt'] = newUpdatedAt;
        });
      }
      return;
    }

    final String messageId = data['messageId'].toString();
    final String? tempId = data['tempId']?.toString();
    final String status = data['status'];
    
    int messageIndex = -1;
    
    if (tempId != null) {
      messageIndex = _messages.indexWhere((msg) => msg['id'].toString() == tempId);
    }
    
    if (messageIndex == -1) {
      messageIndex = _messages.indexWhere((msg) => msg['id'].toString() == messageId);
    }
    
    if (messageIndex != -1) {
      setState(() {
        if (tempId != null && _messages[messageIndex]['id'].toString() == tempId) {
          _messages[messageIndex]['id'] = messageId;
        }
        
        if (status == 'delivered') {
          _messages[messageIndex]['deliveredStatus'] = true;
        } else if (status == 'read') {
          _messages[messageIndex]['deliveredStatus'] = true;
          _messages[messageIndex]['readStatus'] = true;
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _markAllMessagesAsRead();
      });
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
          final List<dynamic> fetchedMessages = json.decode(response.body);
          setState(() {
            _messages.clear();
            _messages.addAll(fetchedMessages);
            _isLoading = false;
          });
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
    
    final tempId = DateTime.now().microsecondsSinceEpoch.toString();
    
    final messageData = {
      'id': tempId,
      'senderId': widget.user.id.toString(),
      'receiverId': widget.targetUser['id'].toString(),
      'content': text,
      'readStatus': false, 
      'deliveredStatus': false,
      'createdAt': DateTime.now().toIso8601String(),
      'replyToMessageId': _replyingToMessage != null ? _replyingToMessage['id'] : null,
      'replyToMessageContent': _replyingToMessage != null ? _replyingToMessage['content'] : null,
    };

    setState(() {
      _messages.add(messageData);
      _replyingToMessage = null;
    });
    
    _textController.clear();
    
    Future.delayed(const Duration(milliseconds: 50), () {
      _scrollToBottom();
    });
    
    _socketService.emitEvent('sendMessage', {
      'senderId': widget.user.id,
      'receiverId': widget.targetUser['id'],
      'content': text,
      'tempId': tempId,
      'replyToMessageId': messageData['replyToMessageId'],
      'replyToMessageContent': messageData['replyToMessageContent'],
    });
    
    _stopTyping();
  }

  void _replyToMessage(dynamic message) {
    setState(() {
      _replyingToMessage = message;
      FocusScope.of(context).requestFocus(_focusNode);
    });
    if (_isIOS) {
      HapticFeedback.lightImpact();
    }
  }

  void _deleteMessageForMe(dynamic message) {
    if (_isIOS) {
      HapticFeedback.mediumImpact();
    }
    setState(() {
      _messages.removeWhere((msg) => msg['id'].toString() == message['id'].toString());
    });
  }

  void _deleteMessageForEveryone(dynamic message) {
    if (_isIOS) {
      HapticFeedback.mediumImpact();
    }
    _socketService.emitEvent('deleteMessage', {
      'messageId': message['id'].toString(),
      'senderId': widget.user.id,
      'receiverId': widget.targetUser['id'],
    });
  }

  void _editMessage(dynamic message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return EditMessageDialog(
          initialContent: message['content'],
          onSave: (newContent) {
            _socketService.emitEvent('editMessage', {
              'messageId': message['id'].toString(),
              'senderId': widget.user.id,
              'newContent': newContent,
              'receiverId': widget.targetUser['id'],
            });
          },
        );
      },
    );
  }

  void _onTyping(String text) {
    if (!_isTyping && text.trim().isNotEmpty) {
      _isTyping = true;
      _socketService.emitEvent('typing', {
        'senderId': widget.user.id,
        'receiverId': widget.targetUser['id'],
        'isTyping': true,
      });
    } else if (_isTyping && text.trim().isEmpty) {
      _isTyping = false;
      _socketService.emitEvent('typing', {
        'senderId': widget.user.id,
        'receiverId': widget.targetUser['id'],
        'isTyping': false,
      });
    }
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      _socketService.emitEvent('typing', {
        'senderId': widget.user.id,
        'receiverId': widget.targetUser['id'],
        'isTyping': false,
      });
    }
  }

  void _markMessageAsRead(dynamic messageId) {
    if (messageId == null) return;
    _socketService.emitEvent('readMessage', {
      'messageId': messageId,
      'senderId': widget.targetUser['id'],
      'receiverId': widget.user.id
    });
  }

  void _markAllMessagesAsRead() {
    if (_messages.isEmpty) return;
    
    for (var message in _messages) {
      if (message['senderId'].toString() == widget.targetUser['id'].toString() &&
          (message['readStatus'] == false || message['readStatus'] == null || message['readStatus'] == 0)) {
        _markMessageAsRead(message['id']);
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    
    // ✅ استخدام WidgetsBinding.instance.addPostFrameCallback لضمان أن الواجهة قد تم تحديثها
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        // ✅ الانتقال الفوري إلى نهاية القائمة
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Widget _buildRefreshIndicator() {
    if (!_isRefreshing) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _isIOS 
          ? const CupertinoActivityIndicator(radius: 15)
          : Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                ),
              ),
            ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messagesSubscription.cancel();
    _messageStatusSubscription.cancel();
    _socketService.userStatus.removeListener(_onUserStatusChange);
    _socketService.typingStatus.removeListener(_onTypingStatusChange);
    _scrollController.removeListener(_onScroll);
    _focusNode.removeListener(_onFocusChange); // ✅ إزالة listener
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    
    for (var controller in _statusAnimationControllers.values) {
      controller.dispose();
    }
    _statusAnimationControllers.clear();
    _statusAnimations.clear();
    
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  return Directionality(
    textDirection: TextDirection.rtl,
    child: TextSelectionTheme(
      data: TextSelectionThemeData(
        selectionColor: Colors.blue.shade100,
        selectionHandleColor: Colors.blue.shade800,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        
        // ✅ هذا هو الحل. body يحتوي على المحتوى فقط، و bottomNavigationBar يحتوي على صندوق الكتابة
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            _markAllMessagesAsRead();
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: _isIOS 
                              ? const CupertinoActivityIndicator(radius: 20)
                              : const CircularProgressIndicator(color: Color(0xFF2C3E50))
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: (ScrollNotification scrollInfo) {
                              if (scrollInfo is ScrollEndNotification) {
                                Future.delayed(const Duration(milliseconds: 200), () {
                                  _markAllMessagesAsRead();
                                });
                              }
                              return false;
                            },
                            child: CustomScrollView(
                              controller: _scrollController,
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              physics: _isIOS 
                                ? const BouncingScrollPhysics()
                                : const ClampingScrollPhysics(),
                              slivers: [
                                SliverAppBar(
                                  expandedHeight: 140, 
                                  collapsedHeight: 100, 
                                  floating: true,
                                  pinned: true,
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  toolbarHeight: 100, 
                                  leading: Padding(
                                    padding: const EdgeInsets.only(top: 20), 
                                    child: GestureDetector(
                                      onTap: () => Navigator.of(context).pop(),
                                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.black87), 
                                    ),
                                  ),
                                  title: Container(), 
                                  flexibleSpace: InkWell(
                                    onTap: () {},
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    child: ClipRRect( 
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                                      child: LayoutBuilder(
                                        builder: (BuildContext context, BoxConstraints constraints) {
                                          final double expandedHeight = constraints.biggest.height;
                                          final double collapsedHeight = 100.0;
                                          final double maxExpandedHeight = 140.0;
                                          
                                          final double t = ((expandedHeight - collapsedHeight) / (maxExpandedHeight - collapsedHeight)).clamp(0.0, 1.0);
                                          
                                          final double avatarSize = 40.0 + (5 * t); 
                                          final double nameFontSize = 12.0 + (3 * t); 
                                          final double statusFontSize = 10.0 + (2 * t);
                                          
                                          final Color appBarColor = Color.lerp(
                                            Colors.transparent, 
                                            Colors.white.withOpacity(0.8), 
                                            t
                                          )!;

                                          return BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), 
                                            child: Container(
                                              color: appBarColor, 
                                              child: Align(
                                                alignment: Alignment.bottomCenter,
                                                child: Padding(
                                                  padding: const EdgeInsets.only(bottom: 10),
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      SizedBox(
                                                        width: avatarSize,
                                                        height: avatarSize,
                                                        child: _buildUserAvatar(widget.targetUser['fullName'], _isOnline, avatarSize),
                                                      ),
                                                      SizedBox(height: 2 + (2 * t)),
                                                      
                                                      Flexible(
                                                        child: Text(
                                                          widget.targetUser['fullName'],
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
                                                          _isTargetUserTyping
                                                              ? 'يكتب...'
                                                              : _isOnline
                                                                  ? 'متصل الآن'
                                                                  : 'غير متصل',
                                                          style: GoogleFonts.almarai(
                                                            fontSize: statusFontSize,
                                                            color: _isTargetUserTyping
                                                                ? Colors.blue.shade400
                                                                : (_isOnline ? Colors.green.shade400 : Colors.red.shade400),
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                
                                SliverToBoxAdapter(
                                  child: _buildRefreshIndicator(),
                                ),
                                
                                SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (BuildContext context, int index) {
                                      final message = _messages[index];
                                      final isMyMessage = message['senderId'].toString() == widget.user.id.toString();
                                      
                                      // ✅ إضافة مفتاح فريد لكل رسالة
                                      final GlobalKey messageKey = GlobalKey();
                                      _messageKeys[message['id'].toString()] = messageKey;
                                      
                                      if (!isMyMessage && mounted) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (message['readStatus'] == false || message['readStatus'] == null || message['readStatus'] == 0) {
                                            _markMessageAsRead(message['id']);
                                          }
                                        });
                                      }
                                      
                                      return MessageBubble(
                                        key: messageKey,
                                        message: message,
                                        isMyMessage: isMyMessage,
                                        onReply: (msg) {
                                          _replyToMessage(msg);
                                        },
                                        onLongPress: (msg, myMsg) {
                                          _showOptions(msg, myMsg);
                                        },
                                        repliedMessageContent: message['replyToMessageContent'],
                                        isHighlighted: _highlightedMessageId ==  message['id'].toString(),
                                      );
                                    },
                                    childCount: _messages.length,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ✅ نقل صندوق الكتابة إلى bottomNavigationBar
        bottomNavigationBar: _buildMessageInput(),
      ),
    ),
  );
}

  Widget _buildUserAvatar(String fullName, bool isOnline, double size) {
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
          // ❌ الخطأ هنا
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

  void _showOptions(dynamic message, bool isMyMessage) {
    if (kIsWeb) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('خيارات الرسالة', style: GoogleFonts.almarai(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  if (isMyMessage)
                    ListTile(
                      title: Text('تعديل', style: GoogleFonts.almarai(color: Colors.blue)),
                      onTap: () {
                        Navigator.pop(context);
                        _editMessage(message);
                      },
                    ),
                  ListTile(
                    title: Text('حذف لدي', style: GoogleFonts.almarai(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteMessageForMe(message);
                    },
                  ),
                  if (isMyMessage)
                    ListTile(
                      title: Text('حذف لدى الجميع', style: GoogleFonts.almarai(color: Colors.red)),
                      onTap: () {
                        Navigator.pop(context);
                        _deleteMessageForEveryone(message);
                      },
                    ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.almarai(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    } else {
      if (!_isIOS) {
        HapticFeedback.lightImpact();
      }
      showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) {
          if (isMyMessage) {
            return MessageOptionsSheet(
              onEdit: () => _editMessage(message),
              onDeleteForMe: () => _deleteMessageForMe(message),
              onDeleteForEveryone: () => _deleteMessageForEveryone(message),
            );
          } else {
            return CupertinoActionSheet(
              title: Text('خيارات الرسالة', style: GoogleFonts.almarai(fontWeight: FontWeight.bold)),
              actions: <CupertinoActionSheetAction>[
                CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteMessageForMe(message);
                  },
                  child: Text('حذف لدي', style: GoogleFonts.almarai(color: CupertinoColors.systemRed)),
                ),
              ],
              cancelButton: CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.almarai(fontWeight: FontWeight.bold)),
              ),
            );
          }
        },
      );
    }
  }

  Widget _buildMessageInput() {
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
          if (_replyingToMessage != null)
            GestureDetector(
              onTap: () => _scrollToAndHighlight(_replyingToMessage['replyToMessageId'].toString()),
              child: _buildReplyPreview(),
            ),
          
          Row(
            children: [
              Expanded(
                child: TextField(
                  cursorColor: Colors.blue.shade600,
                  controller: _textController,
                  focusNode: _focusNode,
                  onChanged: _onTyping,
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
                onTap: _sendMessage,
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
                  _replyingToMessage['senderId'].toString() == widget.user.id.toString() ? 'أنت' : widget.targetUser['fullName'],
                  style: GoogleFonts.almarai(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _replyingToMessage['content'],
                  style: GoogleFonts.almarai(color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () {
              setState(() {
                _replyingToMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }
}