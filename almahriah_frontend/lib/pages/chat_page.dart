// lib/pages/chat_page.dart

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
import 'package:shared_preferences/shared_preferences.dart';

import 'package:almahriah_frontend/widgets/edit_message_dialog.dart';
import 'package:almahriah_frontend/widgets/message_bubble.dart';
import 'package:almahriah_frontend/widgets/chat/chat_app_bar.dart';
import 'package:almahriah_frontend/widgets/chat/chat_message_list.dart';
import 'package:almahriah_frontend/widgets/chat/chat_message_input.dart';

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
  List<dynamic> _messages = [];
  final ScrollController _scrollController = ScrollController();
  
  final SocketService _socketService = SocketService();

  Set<String> _selectedMessageIds = {};
  bool _isSelectionMode = false; 
  
  bool _isTyping = false;
  bool _isOnline = false;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isTargetUserTyping = false;
  
  late StreamSubscription _messagesSubscription;
  late StreamSubscription _messageStatusSubscription;
  
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;

  dynamic _replyingToMessage;
  final FocusNode _focusNode = FocusNode();
  
  bool get _isIOS => !kIsWeb && Platform.isIOS;

  late final User _user = widget.user;

  bool _isChatLoading = false;
  bool _hasMoreMessages = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _isOnline = _socketService.userStatus.value[widget.targetUser['id'].toString()] ?? false;
    _isTargetUserTyping = _socketService.typingStatus.value[widget.targetUser['id'].toString()] ?? false;

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
          if (_isIOS) {
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

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
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
        if (newOnlineStatus) {
          _updateDeliveryStatusForUndeliveredMessages();
        }
      }
    }
  }

  void _scrollToAndHighlight(String? messageId) {
    if (messageId == null) return;
    final GlobalKey? key = _messageKeys[messageId];
    if (key != null) {
      final BuildContext? context = key.currentContext;
      if (context != null) {
        setState(() {
          _highlightedMessageId = messageId;
        });
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
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
  
  void _onReply(dynamic message) {
    _replyToMessage(message);
  }

  void _onLongPress(dynamic message) {
    _onMessageLongPress(message);
  }

  void _onMessageTap(dynamic message) {
    _toggleMessageSelection(message);
  }

  Future<void> _fetchMoreMessages() async {
    if (_isChatLoading || !_hasMoreMessages) return;
    setState(() {
      _isChatLoading = true;
    });
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isChatLoading = false;
    });
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
    if (data['action'] == 'bulkDeleted') {
      final List<String> messageIds = List<String>.from(data['messageIds']);
      setState(() {
        _messages.removeWhere((msg) => messageIds.contains(msg['id'].toString()));
      });
      return;
    }
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
        headers: {'Authorization': 'Bearer ${_user.token}'},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          final List<dynamic> fetchedMessages = json.decode(response.body);
          final prefs = await SharedPreferences.getInstance();
          final String chatKey = 'deleted_messages_${_user.id}_${widget.targetUser['id']}';
          final List<String> deletedMessageIds = prefs.getStringList(chatKey) ?? [];
          
          final filteredMessages = fetchedMessages.where((msg) => !deletedMessageIds.contains(msg['id'].toString())).toList();

          setState(() {
            _messages = filteredMessages;
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
      'senderId': _user.id.toString(),
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
      'senderId': _user.id,
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

  Future<void> _deleteMessageForMe(dynamic message) async {
    if (_isIOS) {
      HapticFeedback.mediumImpact();
    }
    
    final prefs = await SharedPreferences.getInstance();
    final String chatKey = 'deleted_messages_${_user.id}_${widget.targetUser['id']}';
    final List<String> currentDeleted = prefs.getStringList(chatKey) ?? [];
    currentDeleted.add(message['id'].toString());
    await prefs.setStringList(chatKey, currentDeleted);

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
      'senderId': _user.id,
      'receiverId': widget.targetUser['id'],
    });
  }

  // ✅ Updated _editMessage function
  void _editMessage(dynamic message) {
    if (_isIOS) {
      _showNativeEditMessageDialog(message);
    } else {
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return EditMessageDialog(
            initialContent: message['content'],
            onSave: (newContent) {
              _socketService.emitEvent('editMessage', {
                'messageId': message['id'].toString(),
                'senderId': _user.id,
                'newContent': newContent,
                'receiverId': widget.targetUser['id'],
              });
            },
          );
        },
      );
    }
  }

  // ✅ New method to show the native edit dialog
  Future<void> _showNativeEditMessageDialog(dynamic message) async {
    try {
      final newContent = await platform.invokeMethod('showEditMessageDialog', {
        'initialContent': message['content'],
      });

      if (newContent != null) {
        _socketService.emitEvent('editMessage', {
          'messageId': message['id'].toString(),
          'senderId': _user.id,
          'newContent': newContent,
          'receiverId': widget.targetUser['id'],
        });
      }
    } on PlatformException catch (e) {
      print("Failed to show native edit dialog: '${e.message}'.");
      // Optionally, you can fall back to the Flutter dialog if the native one fails
      _editMessage(message); 
    }
  }

  void _onTyping(String text) {
    if (!_isTyping && text.trim().isNotEmpty) {
      _isTyping = true;
      _socketService.emitEvent('typing', {
        'senderId': _user.id,
        'receiverId': widget.targetUser['id'],
        'isTyping': true,
      });
    } else if (_isTyping && text.trim().isEmpty) {
      _isTyping = false;
      _socketService.emitEvent('typing', {
        'senderId': _user.id,
        'receiverId': widget.targetUser['id'],
        'isTyping': false,
      });
    }
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      _socketService.emitEvent('typing', {
        'senderId': _user.id,
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
      'receiverId': _user.id
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _onMessageLongPress(dynamic message) {
    if (_isIOS) {
      _showNativeActionSheet(message);
    } else {
      showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) {
          final isMyMessage = message['senderId'].toString() == _user.id.toString();
          return CupertinoActionSheet(
            title: Text('خيارات الرسالة', style: GoogleFonts.almarai(fontWeight: FontWeight.bold)),
            actions: <CupertinoActionSheetAction>[
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _isSelectionMode = true;
                    _toggleMessageSelection(message);
                  });
                },
                child: Text('تحديد', style: GoogleFonts.almarai(color: CupertinoColors.activeBlue)),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  _replyToMessage(message);
                },
                child: Text('رد', style: GoogleFonts.almarai(color: CupertinoColors.activeBlue)),
              ),
              if (isMyMessage)
                CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.pop(context);
                    _editMessage(message);
                  },
                  child: Text('تعديل', style: GoogleFonts.almarai(color: CupertinoColors.activeBlue)),
                ),
              if (isMyMessage)
                CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteMessageForEveryone(message);
                  },
                  child: Text('حذف لدى الجميع', style: GoogleFonts.almarai(color: CupertinoColors.systemRed)),
                ),
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
        },
      );
    }
  }

  // ✅ New method to show the native iOS action sheet
  Future<void> _showNativeActionSheet(dynamic message) async {
    HapticFeedback.lightImpact();
    final isMyMessage = message['senderId'].toString() == _user.id.toString();

    final List<Map<String, String>> actions = [
      {'title': 'تحديد', 'action': 'select'},
      {'title': 'رد', 'action': 'reply'},
      if (isMyMessage) ...[
        {'title': 'تعديل', 'action': 'edit'},
        {'title': 'حذف لدى الجميع', 'action': 'delete_for_everyone'},
      ],
      {'title': 'حذف لدي', 'action': 'delete_for_me'},
    ];

    try {
      final String? selectedAction = await platform.invokeMethod('showActionSheet', {
        'title': 'خيارات الرسالة',
        'actions': actions,
      });

      switch (selectedAction) {
        case 'select':
          setState(() {
            _isSelectionMode = true;
            _toggleMessageSelection(message);
          });
          break;
        case 'reply':
          _replyToMessage(message);
          break;
        case 'edit':
          _editMessage(message);
          break;
        case 'delete_for_everyone':
          _deleteMessageForEveryone(message);
          break;
        case 'delete_for_me':
          _deleteMessageForMe(message);
          break;
        default:
          // User canceled or no action was selected
          break;
      }
    } on PlatformException catch (e) {
      print("Failed to show native action sheet: '${e.message}'.");
    }
  }

  void _toggleMessageSelection(dynamic message) {
    setState(() {
      final messageId = message['id'].toString();
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }
      if (_selectedMessageIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _showBulkDeleteDialog() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text(
            'حذف الرسائل المحددة',
            style: GoogleFonts.almarai(fontWeight: FontWeight.bold),
          ),
          actions: <CupertinoActionSheetAction>[
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _deleteSelectedMessages(isDeleteForEveryone: false);
              },
              child: Text(
                'حذف لدي',
                style: GoogleFonts.almarai(color: CupertinoColors.systemRed),
              ),
            ),
            if (_selectedMessageIds.isNotEmpty && _selectedMessageIds.every((id) => _messages.firstWhere((msg) => msg['id'].toString() == id, orElse: () => null)?['senderId']?.toString() == _user.id.toString()))
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteSelectedMessages(isDeleteForEveryone: true);
                },
                child: Text(
                  'حذف لدى الجميع',
                  style: GoogleFonts.almarai(color: CupertinoColors.systemRed),
                ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: GoogleFonts.almarai(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteSelectedMessages({required bool isDeleteForEveryone}) async {
    final messageIdsToDelete = _selectedMessageIds.toList();
    if (isDeleteForEveryone) {
      _socketService.emitEvent('bulkDeleteMessages', {
        'messageIds': messageIdsToDelete,
        'senderId': _user.id,
        'receiverId': widget.targetUser['id'],
      });
    } else {
      final prefs = await SharedPreferences.getInstance();
      final String chatKey = 'deleted_messages_${_user.id}_${widget.targetUser['id']}';
      List<String> currentDeleted = prefs.getStringList(chatKey) ?? [];
      currentDeleted.addAll(messageIdsToDelete);
      await prefs.setStringList(chatKey, currentDeleted);

      setState(() {
        _messages.removeWhere((msg) => messageIdsToDelete.contains(msg['id'].toString()));
      });
    }
    _exitSelectionMode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messagesSubscription.cancel();
    _messageStatusSubscription.cancel();
    _socketService.userStatus.removeListener(_onUserStatusChange);
    _socketService.typingStatus.removeListener(_onTypingStatusChange);
    _scrollController.removeListener(_onScroll);
    _focusNode.removeListener(_onFocusChange);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
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
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _isLoading
                  ? Center(
                      child: _isIOS
                          ? const CupertinoActivityIndicator(radius: 20)
                          : const CircularProgressIndicator(color: Color(0xFF2C3E50)),
                    )
                  : ChatMessageList(
                      targetUser: widget.targetUser,
                      isOnline: _isOnline,
                      isTargetUserTyping: _isTargetUserTyping,
                      messages: _messages,
                      user: _user,
                      messageKeys: _messageKeys,
                      highlightedMessageId: _highlightedMessageId,
                      isSelectionMode: _isSelectionMode,
                      selectedMessageIds: _selectedMessageIds,
                      scrollController: _scrollController,
                      isIOS: _isIOS,
                      onMarkAllMessagesAsRead: _markAllMessagesAsRead,
                      onReply: _onReply,
                      onLongPress: _onLongPress,
                      onMessageTap: _onMessageTap,
                      showBulkDeleteDialog: _showBulkDeleteDialog,
                      exitSelectionMode: _exitSelectionMode,
                      isChatLoading: _isChatLoading,
                      hasMoreMessages: _hasMoreMessages,
                      onFetchMoreMessages: _fetchMoreMessages,
                      onRefresh: _handleRefresh,
                    ),
            ),
          ),
          bottomNavigationBar: _isSelectionMode
              ? null
              : ChatMessageInput(
                  textController: _textController,
                  focusNode: _focusNode,
                  replyingToMessage: _replyingToMessage,
                  user: _user,
                  targetUser: widget.targetUser,
                  onSendMessage: _sendMessage,
                  onTyping: _onTyping,
                  onReplyPreviewTap: () => _scrollToAndHighlight(_replyingToMessage['id'].toString()),
                  onCancelReply: () {
                    setState(() {
                      _replyingToMessage = null;
                    });
                  },
                ),
        ),
      ),
    );
  }
}