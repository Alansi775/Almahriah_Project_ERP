// lib/pages/chat_page.dart - النسخة المُحسنة والمُصححة

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
import 'package:almahriah_frontend/widgets/chat/chat_message_input.dart';
import 'package:almahriah_frontend/widgets/message_options_sheet.dart';

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
  bool get _isWeb => kIsWeb;

  late final User _user = widget.user;

  // بيانات إضافية
  bool _isChatLoading = false;
  bool _hasMoreMessages = true;
  
  bool get _areAllMessagesSelected => _selectedMessageIds.length == _messages.length && _messages.isNotEmpty;

  void _toggleSelectAll() {
    setState(() {
      if (_areAllMessagesSelected) {
        _selectedMessageIds.clear();
      } else {
        _selectedMessageIds = _messages.map((msg) => msg['id'].toString()).toSet();
      }
    });
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _isOnline = _socketService.userStatus.value[widget.targetUser['id'].toString()] ?? false;
    _isTargetUserTyping = _socketService.typingStatus.value[widget.targetUser['id'].toString()] ?? false;

    _focusNode.addListener(_onFocusChange);

    // الاستماع للرسائل الجديدة
    _messagesSubscription = _socketService.messagesStream.listen((data) {
      if (mounted) {
        _handleIncomingMessage(data);
      }
    });

    // الاستماع لتحديثات حالة الرسائل
    _messageStatusSubscription = _socketService.messageStatusStream.listen((data) {
      if (mounted) {
        _handleMessageStatusUpdate(data);
      }
    });

    _socketService.userStatus.addListener(_onUserStatusChange);
    _socketService.typingStatus.addListener(_onTypingStatusChange);
    
    _scrollController.addListener(_onScroll);
    
    // تحميل المحادثة وتصفير العدادات
    _initializeChatPage();
  }

  Future<void> _initializeChatPage() async {
    await _fetchChatHistory();
    
    // تصفير عداد الرسائل غير المقروءة عند فتح المحادثة
    _socketService.clearUnreadCountForSender(widget.targetUser['id'].toString());
    
    if (mounted && _messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(force: true);
        Future.delayed(const Duration(milliseconds: 800), () {
          _markVisibleMessagesAsRead();
        });
      });
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    final senderId = data['senderId'].toString();
    final receiverId = data['receiverId'].toString();
    final myId = _user.id.toString();
    final targetId = widget.targetUser['id'].toString();

    // التأكد أن الرسالة تخص هذه المحادثة
    if ((senderId == targetId && receiverId == myId) || 
        (senderId == myId && receiverId == targetId)) {

      final messageId = data['id'].toString();
      final tempId = data['tempId']?.toString();

      setState(() {
        int existingIndex = -1;

        // البحث عن الرسالة المؤقتة أولاً
        if (tempId != null) {
          existingIndex = _messages.indexWhere((msg) => msg['id'].toString() == tempId);
        }

        // ثم البحث بالمعرف الفعلي
        if (existingIndex == -1) {
          existingIndex = _messages.indexWhere((msg) => msg['id'].toString() == messageId);
        }

        if (existingIndex != -1) {
          // تحديث الرسالة الموجودة
          _messages[existingIndex] = {
            ...data,
            'isMyMessage': senderId == myId,
          };
          debugPrint('Updated existing message to prevent duplication');
        } else {
          // إضافة رسالة جديدة
          _messages.add({
            ...data,
            'isMyMessage': senderId == myId,
          });
          debugPrint('Added new message to chat');
        }
      });

      _scrollToBottom(force: true);

      // قراءة الرسائل الواردة تلقائياً
      if (senderId == targetId) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _markMessageAsRead(messageId, senderId);
        });
      }
    }

    if (data['replyToMessageContent'] != null) {
     debugPrint('✅ Received message with reply: ${data['replyToMessageContent']}');
    }
  }

  void _handleMessageStatusUpdate(Map<String, dynamic> data) {
    final action = data['action'];
    
    switch (action) {
      case 'deleted':
        _handleMessageDeletion(data);
        break;
      case 'edited':
        _handleMessageEdit(data);
        break;
      case 'status_update':
        _handleStatusUpdate(data);
        break;
      case 'error':
        _handleMessageError(data);
        break;
    }
  }

  void _handleMessageDeletion(Map<String, dynamic> data) {
    final messageId = data['messageId'].toString();
    setState(() {
      _messages.removeWhere((msg) => msg['id'].toString() == messageId);
    });
    debugPrint('Message deleted: $messageId');
  }

  void _handleMessageEdit(Map<String, dynamic> data) {
    final messageId = data['messageId'].toString();
    final newContent = data['newContent'];
    final updatedAt = data['updatedAt'];
    
    final index = _messages.indexWhere((msg) => msg['id'].toString() == messageId);
    if (index != -1) {
      setState(() {
        _messages[index]['content'] = newContent;
        _messages[index]['updatedAt'] = updatedAt;
      });
      debugPrint('Message edited: $messageId');
    }
  }

  void _handleStatusUpdate(Map<String, dynamic> data) {
    final String messageId = data['messageId'].toString();
    final String? tempId = data['tempId']?.toString();
    final String status = data['status'];
    
    for (int i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      final msgId = msg['id'].toString();
      
      if (msgId == messageId || (tempId != null && msgId == tempId)) {
        setState(() {
          // تحديث ID إذا كان مؤقتاً
          if (tempId != null && msgId == tempId) {
            _messages[i]['id'] = messageId;
          }
          
          // تحديث حالة التسليم/القراءة
          if (status == 'delivered') {
            _messages[i]['deliveredStatus'] = true;
          } else if (status == 'read') {
            _messages[i]['deliveredStatus'] = true;
            _messages[i]['readStatus'] = true;
          }
        });
        break;
      }
    }
  }

  void _handleMessageError(Map<String, dynamic> data) {
    final tempId = data['tempId']?.toString();
    if (tempId != null) {
      setState(() {
        _messages.removeWhere((msg) => msg['id'].toString() == tempId);
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('خطأ في إرسال الرسالة', style: GoogleFonts.almarai())),
    );
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
    _markVisibleMessagesAsRead();
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
    MessageOptionsSheet.showForMessage(
      context: context,
      message: message,
      myUserId: _user.id.toString(),
      onAction: _handleMessageAction,
    );
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // تصفير العدادات عند العودة للتطبيق
      _socketService.clearUnreadCountForSender(widget.targetUser['id'].toString());
      Future.delayed(const Duration(milliseconds: 500), () {
        _markVisibleMessagesAsRead();
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
        final List<dynamic> fetchedMessages = json.decode(response.body);

        setState(() {
          _messages.clear();
          _messages.addAll(fetchedMessages);
          _isLoading = false;
          _hasMoreMessages = fetchedMessages.length >= 50;
        });
        
        _scrollToBottom();
        _markVisibleMessagesAsRead();
        
      } else {
        debugPrint('Failed to load chat history. Status code: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل في تحميل المحادثة', style: GoogleFonts.almarai())),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching chat history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الاتصال بالخادم', style: GoogleFonts.almarai())),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

    void _sendMessage() async {
    if (_textController.text.trim().isEmpty) return;

    final String content = _textController.text.trim();
    final String tempId = DateTime.now().microsecondsSinceEpoch.toString();
    
    // حفظ بيانات الرد قبل مسحها
    final String? replyToMessageId = _replyingToMessage?['id']?.toString();
    final String? replyToMessageContent = _replyingToMessage?['content'];
    
    _textController.clear();

    // إضافة الرسالة المؤقتة للواجهة مع بيانات الرد
    setState(() {
      _messages.add({
        'id': tempId,
        'senderId': _user.id.toString(),
        'receiverId': widget.targetUser['id'].toString(),
        'content': content,
        'deliveredStatus': false,
        'readStatus': false,
        'createdAt': DateTime.now().toIso8601String(),
        'replyToMessageId': replyToMessageId,
        'replyToMessageContent': replyToMessageContent,
        'isMyMessage': true,
      });
      // مسح الرد بعد حفظ البيانات
      _replyingToMessage = null;
    });

    // إرسال الرسالة للخادم مع بيانات الرد
    _socketService.sendMessage(
      senderId: _user.id.toString(),
      receiverId: widget.targetUser['id'].toString(),
      content: content,
      tempId: tempId,
      replyToMessageId: replyToMessageId,
      replyToMessageContent: replyToMessageContent,
    );
    
    _scrollToBottom();
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
    final messageId = message['id'].toString();
    
    setState(() {
      _messages.removeWhere((msg) => msg['id'].toString() == messageId);
    });

    // حفظ محلياً
    await _saveDeletedMessagesLocally([messageId]);
  }

  Future<void> _deleteMessageForEveryone(dynamic message) async {
    if (_isIOS) {
      HapticFeedback.mediumImpact();
    }
    final messageId = message['id'].toString();
    
    _socketService.deleteMessage(
      messageId,
      _user.id.toString(),
      widget.targetUser['id'].toString(),
      'forEveryone',
    );
  }

  Future<void> _saveDeletedMessagesLocally(List<String> messageIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String chatKey = 'deleted_messages_${_user.id}_${widget.targetUser['id']}';
      final List<String> deletedMessageIds = prefs.getStringList(chatKey) ?? [];
      deletedMessageIds.addAll(messageIds);
      await prefs.setStringList(chatKey, deletedMessageIds);
    } catch (e) {
      debugPrint('Error saving deleted messages locally: $e');
    }
  }

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
              _socketService.editMessage(
                message['id'].toString(),
                _user.id.toString(),
                widget.targetUser['id'].toString(),
                newContent,
              );
            },
          );
        },
      );
    }
  }

  Future<void> _showNativeEditMessageDialog(dynamic message) async {
    try {
      final newContent = await platform.invokeMethod('showEditMessageDialog', {
        'initialContent': message['content'],
      });

      if (newContent != null) {
        _socketService.editMessage(
          message['id'].toString(),
          _user.id.toString(),
          widget.targetUser['id'].toString(),
          newContent,
        );
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to show native edit dialog: '${e.message}'");
      _editMessage(message); 
    }
  }

  void _onTyping(String text) {
    if (!_isTyping && text.trim().isNotEmpty) {
      _isTyping = true;
      _socketService.emitTyping(
        _user.id.toString(),
        widget.targetUser['id'].toString(),
        true,
      );
    } else if (_isTyping && text.trim().isEmpty) {
      _isTyping = false;
      _socketService.emitTyping(
        _user.id.toString(),
        widget.targetUser['id'].toString(),
        false,
      );
    }
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      _socketService.emitTyping(
        _user.id.toString(),
        widget.targetUser['id'].toString(),
        false,
      );
    }
  }

  void _markMessageAsRead(String messageId, String senderId) {
    _socketService.markMessageAsRead(
      messageId,
      senderId,
      _user.id.toString(),
    );
  }

  void _markVisibleMessagesAsRead() {
    if (_messages.isEmpty) return;
    
    for (var message in _messages) {
      if (message['senderId'].toString() == widget.targetUser['id'].toString() &&
          (message['readStatus'] == false || message['readStatus'] == 0)) {
        _markMessageAsRead(message['id'].toString(), message['senderId'].toString());
      }
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (!_scrollController.hasClients) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        if (_isIOS || _isWeb) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: force ? 100 : 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  void _handleMessageAction(String? action, dynamic message) {
    if (action == null) return;
    switch (action) {
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
    }
  }
  
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }
  
  bool get _canDeleteForEveryone => _selectedMessageIds.isNotEmpty && _selectedMessageIds.every((id) {
    final message = _messages.firstWhere((msg) => msg['id'].toString() == id, orElse: () => null);
    return message != null && message['senderId']?.toString() == _user.id.toString();
  });

  void _showBulkDeleteDialog() {
    if (_isIOS) {
      _showNativeBulkDeleteDialog();
    } else {
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
              if (_canDeleteForEveryone)
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
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'إلغاء',
                style: GoogleFonts.almarai(fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      );
    }
  }

  Future<void> _showNativeBulkDeleteDialog() async {
    HapticFeedback.lightImpact();
    final List<Map<String, String>> actions = [
      {'title': 'حذف لدي', 'action': 'delete_for_me_bulk'},
    ];
    
    if (_canDeleteForEveryone) {
      actions.add({'title': 'حذف لدى الجميع', 'action': 'delete_for_everyone_bulk'});
    }

    try {
      final String? selectedAction = await platform.invokeMethod('showActionSheet', {
        'title': 'حذف الرسائل المحددة',
        'actions': actions,
      });

      switch (selectedAction) {
        case 'delete_for_me_bulk':
          _deleteSelectedMessages(isDeleteForEveryone: false);
          break;
        case 'delete_for_everyone_bulk':
          _deleteSelectedMessages(isDeleteForEveryone: true);
          break;
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to show native bulk delete dialog: '${e.message}'");
    }
  }

  Future<void> _deleteSelectedMessages({required bool isDeleteForEveryone}) async {
    final messageIdsToDelete = _selectedMessageIds.toList();
    if (messageIdsToDelete.isEmpty) return;

    if (_isIOS) {
      HapticFeedback.mediumImpact();
    }

    if (isDeleteForEveryone) {
      try {
        final response = await http.post(
          Uri.parse('${AuthService.baseUrl}/api/chat/delete-message'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${_user.token}',
          },
          body: json.encode({
            'messageIds': messageIdsToDelete,
            'deleteType': 'forEveryone'
          }),
        );
        
        if (response.statusCode == 200) {
          for (final messageId in messageIdsToDelete) {
            _socketService.deleteMessage(
              messageId,
              _user.id.toString(),
              widget.targetUser['id'].toString(),
              'forEveryone',
            );
          }
        }
      } catch (e) {
        debugPrint('Error deleting bulk messages for everyone: $e');
      }
    } else {
      await _saveDeletedMessagesLocally(messageIdsToDelete);
    }
    
    setState(() {
      _messages.removeWhere((msg) => messageIdsToDelete.contains(msg['id'].toString()));
    });
    
    _exitSelectionMode();
  }
  
  Future<bool> _handleBackPress() async {
    // إذا كان هناك رد نشط أو وضع التحديد مفعل، اخرج من هذه الأوضاع أولاً
    if (_replyingToMessage != null || _isSelectionMode) {
      setState(() {
        _replyingToMessage = null;
        _isSelectionMode = false;
        _selectedMessageIds.clear();
      });
      return false; // البقاء في الصفحة
    }

    // إذا كان لوحة المفاتيح مفتوحة، أغلقها قبل الرجوع
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // تأكد من تصفير العدادات قبل المغادرة
    _socketService.clearUnreadCountForSender(widget.targetUser['id'].toString());

    return true; // السماح بالرجوع
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
        child: WillPopScope(
          onWillPop: _handleBackPress,
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
                    : GestureDetector(
                        onTap: () {
                          FocusScope.of(context).unfocus();
                        },
                        child: CustomScrollView(
                          controller: _scrollController,
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          physics: _isIOS
                              ? const BouncingScrollPhysics()
                              : const ClampingScrollPhysics(),
                          slivers: [
                            _isSelectionMode
                                ? SliverAppBar(
                                    expandedHeight: 140,
                                    collapsedHeight: 100,
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    elevation: 1,
                                    centerTitle: true,
                                    title: Text(
                                      '${_selectedMessageIds.length} رسالة محددة',
                                      style: GoogleFonts.almarai(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    actions: [
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: _showBulkDeleteDialog,
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          _areAllMessagesSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                          color: Colors.black,
                                        ),
                                        onPressed: _toggleSelectAll,
                                      ),
                                    ],
                                    leading: IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: _exitSelectionMode,
                                    ),
                                    floating: true,
                                    snap: true,
                                    pinned: true,
                                  )
                                : SliverAppBar(
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
                                        onTap: () async {
                                          bool canPop = await _handleBackPress();
                                          if (canPop) {
                                            Navigator.of(context).pop(true);
                                          }
                                        },
                                        child: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
                                      ),
                                    ),
                                    title: Container(),
                                    flexibleSpace: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                                      child: ChatAppBar(
                                        targetUser: widget.targetUser,
                                        isOnline: _isOnline,
                                        isTargetUserTyping: _isTargetUserTyping,
                                      ),
                                    ),
                                  ),
                            CupertinoSliverRefreshControl(
                              onRefresh: _handleRefresh,
                            ),
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (BuildContext context, int index) {
                                  final message = _messages[index];
                                  final messageId = message['id'].toString();
                                  
                                  // إنشاء مفتاح للرسالة
                                  _messageKeys[messageId] ??= GlobalKey();
                                  
                                  return GestureDetector(
                                    onLongPress: () {
                                      if (!_isSelectionMode) {
                                        _onLongPress(message);
                                      } else {
                                        _toggleMessageSelection(message);
                                      }
                                    },
                                    onTap: () {
                                      if (_isSelectionMode) {
                                        _toggleMessageSelection(message);
                                      }
                                    },
                                    child: MessageBubble(
                                      key: _messageKeys[messageId],
                                      message: message,
                                      isMyMessage: message['senderId'].toString() == _user.id.toString(),
                                      onReply: _onReply,
                                      onLongPress: _onLongPress,
                                      repliedMessageContent: message['replyToMessageContent'],
                                      repliedMessageId: message['replyToMessageId'],
                                      isHighlighted: _highlightedMessageId == messageId,
                                      isSelected: _selectedMessageIds.contains(messageId),
                                    ),
                                  );
                                },
                                childCount: _messages.length,
                              ),
                            ),
                          ],
                        ),
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
                    onReplyPreviewTap: () => _scrollToAndHighlight(_replyingToMessage?['id']?.toString()),
                    onCancelReply: () {
                      setState(() {
                        _replyingToMessage = null;
                      });
                    },
                  ),
          ),
        ),
      ),
    );
  }
}