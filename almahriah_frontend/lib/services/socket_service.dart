// lib/services/socket_service.dart - النسخة المُحسنة والمُصححة

import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/user.dart';
import 'dart:async';
import 'auth_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isInitialized = false;
  User? _currentUser;

  IO.Socket get socket => _socket!;

  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<Map<String, bool>> typingStatus = ValueNotifier<Map<String, bool>>({});
  final ValueNotifier<Map<String, bool>> userStatus = ValueNotifier<Map<String, bool>>({});
  final ValueNotifier<Map<String, int>> unreadCount = ValueNotifier<Map<String, int>>({});

  final StreamController<dynamic> _messagesController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get messagesStream => _messagesController.stream;

  final StreamController<dynamic> _messageStatusController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get messageStatusStream => _messageStatusController.stream;

  void initialize(User user) {
    if (_isInitialized && _socket?.connected == true && _currentUser?.id == user.id) {
      debugPrint('✅ Socket already initialized and connected for user ${user.id}');
      return;
    }
    
    _currentUser = user;
    _isInitialized = true;
    _connect(user);
  }

  void _connect(User user) {
    try {
      _socket?.dispose();
      _socket = IO.io(
        AuthService.baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setQuery({'userId': user.id.toString(), 'token': user.token})
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .build(),
      );

      _socket!.connect();

      // ⭐ أحداث الاتصال
      _socket!.onConnect((_) {
        debugPrint('🔗 SocketService: Connected to server for user ${user.id}');
        isConnected.value = true;
      });

      _socket!.onDisconnect((_) {
        debugPrint('❌ SocketService: Disconnected from server');
        isConnected.value = false;
      });

      // ⭐ حالة المستخدمين
      _socket!.on('user-status-changed', (data) {
        if (data is Map) {
          final Map<String, dynamic> statusMap = Map<String, dynamic>.from(data);
          final String userId = statusMap['userId'].toString();
          final bool status = statusMap['status'] as bool;
          final currentStatus = Map<String, bool>.from(userStatus.value);
          currentStatus[userId] = status;
          userStatus.value = currentStatus;
          debugPrint('👤 User status changed: $userId -> $status');
        }
      });
      
      // ⭐ استقبال الرسائل
      _socket!.on('receiveMessage', (data) {
        debugPrint('📥 Received message: ${data is Map ? data['content'] : 'Unknown'}');
        if (data is Map) {
          final Map<String, dynamic> messageMap = Map<String, dynamic>.from(data);
          final messageData = _processIncomingMessage(messageMap);
          _messagesController.sink.add(messageData);
          
          // تحديث عداد الرسائل غير المقروءة فقط للرسائل المستقبلة
          final senderId = messageMap['senderId'].toString();
          final receiverId = messageMap['receiverId'].toString();
          final currentUserId = _currentUser?.id.toString();
          
          if (receiverId == currentUserId && senderId != currentUserId) {
            _incrementUnreadCount(senderId);
          }
        }
      });
      
      // ⭐ الكتابة
      _socket!.on('typing', (data) {
        if (data is Map) {
          final Map<String, dynamic> typingMap = Map<String, dynamic>.from(data);
          final senderId = typingMap['senderId'].toString();
          final isTyping = typingMap['isTyping'] as bool;
          final currentTyping = Map<String, bool>.from(typingStatus.value);
          currentTyping[senderId] = isTyping;
          typingStatus.value = currentTyping;
          debugPrint('⌨️ User $senderId typing: $isTyping');
        }
      });

      // ⭐ تحديثات حالة الرسائل
      _socket!.on('messageStatusUpdate', (data) {
        if (data is Map) {
          final Map<String, dynamic> statusMap = Map<String, dynamic>.from(data);
          debugPrint('📊 Message status update: ${statusMap['status']}');
          _messageStatusController.sink.add({
            'messageId': statusMap['messageId'].toString(),
            'tempId': statusMap['tempId']?.toString(),
            'status': statusMap['status'],
            'action': 'status_update'
          });
        }
      });

      // ⭐ تحديثات عداد الرسائل غير المقروءة
      _socket!.on('unreadCountUpdate', (data) {
        if (data is Map) {
          final Map<String, dynamic> countMap = Map<String, dynamic>.from(data);
          final String senderId = countMap['senderId'].toString();
          final int count = int.tryParse(countMap['count'].toString()) ?? 0;
          _updateUnreadCount(senderId, count);
        }
      });

      // ⭐ تصفير عداد الرسائل
      _socket!.on('messagesMarkedAsRead', (data) {
        if (data is Map) {
          final Map<String, dynamic> readMap = Map<String, dynamic>.from(data);
          final String senderId = readMap['senderId'].toString();
          _clearUnreadCount(senderId);
          debugPrint('✅ Messages marked as read for sender: $senderId');
        }
      });

      _socket!.on('unreadCountCleared', (data) {
        if (data is Map) {
          final Map<String, dynamic> clearMap = Map<String, dynamic>.from(data);
          final String senderId = clearMap['senderId'].toString();
          _clearUnreadCount(senderId);
          debugPrint('🧹 Unread count cleared for sender: $senderId');
        }
      });

      // ⭐ حذف الرسائل
      _socket!.on('messageDeleted', (data) {
        if (data is Map) {
          final Map<String, dynamic> deleteMap = Map<String, dynamic>.from(data);
          debugPrint('🗑️ Message deleted: ${deleteMap['messageId']}');
          _messageStatusController.sink.add({
            'messageId': deleteMap['messageId'].toString(),
            'deleteType': deleteMap['deleteType'],
            'action': 'deleted',
          });
        }
      });

      // ⭐ تعديل الرسائل
      _socket!.on('messageEdited', (data) {
        if (data is Map) {
          final Map<String, dynamic> editMap = Map<String, dynamic>.from(data);
          debugPrint('✏️ Message edited: ${editMap['messageId']}');
          _messageStatusController.sink.add({
            'messageId': editMap['messageId'].toString(),
            'newContent': editMap['newContent'],
            'updatedAt': editMap['updatedAt'],
            'action': 'edited',
          });
        }
      });

      // ⭐ أخطاء الرسائل
      _socket!.on('messageError', (data) {
        debugPrint('❌ Message error: $data');
        if (data is Map) {
          final Map<String, dynamic> errorMap = Map<String, dynamic>.from(data);
          if (errorMap['tempId'] != null) {
            _messageStatusController.sink.add({
              'tempId': errorMap['tempId'].toString(),
              'action': 'error',
              'error': errorMap['error']
            });
          }
        }
      });

      _socket!.onError((error) {
        debugPrint('❌ Socket error: $error');
        isConnected.value = false;
      });

      _socket!.onConnectError((error) {
        debugPrint('❌ Socket connection error: $error');
        isConnected.value = false;
      });

    } catch (e) {
      debugPrint('❌ SocketService: Error connecting socket: $e');
      isConnected.value = false;
    }
  }

  // ⭐ معالجة الرسائل الواردة
  Map<String, dynamic> _processIncomingMessage(Map<String, dynamic> data) {
    return {
      'id': data['id'].toString(),
      'senderId': data['senderId'].toString(),
      'receiverId': data['receiverId'].toString(),
      'content': data['content'],
      'readStatus': data['readStatus'] == true || data['readStatus'] == 1,
      'deliveredStatus': data['deliveredStatus'] == true || data['deliveredStatus'] == 1,
      'createdAt': data['createdAt'],
      'replyToMessageId': data['replyToMessageId']?.toString(),
      'replyToMessageContent': data['replyToMessageContent'],
      'tempId': data['tempId']?.toString(),
      'updatedAt': data['updatedAt'],
    };
  }

  // ⭐ زيادة عداد الرسائل غير المقروءة
  void _incrementUnreadCount(String senderId) {
    final currentCounts = Map<String, int>.from(unreadCount.value);
    final currentCount = currentCounts[senderId] ?? 0;
    currentCounts[senderId] = currentCount + 1;
    unreadCount.value = currentCounts;
    debugPrint('📈 Unread count incremented for $senderId: ${currentCounts[senderId]}');
  }

  // ⭐ تحديث عداد الرسائل غير المقروءة
  void _updateUnreadCount(String senderId, int count) {
    final currentCounts = Map<String, int>.from(unreadCount.value);
    currentCounts[senderId] = count;
    unreadCount.value = currentCounts;
    debugPrint('📊 Unread count updated for $senderId: $count');
  }

  // ⭐ تصفير عداد الرسائل غير المقروءة
  void _clearUnreadCount(String senderId) {
    final currentCounts = Map<String, int>.from(unreadCount.value);
    currentCounts[senderId] = 0;
    unreadCount.value = currentCounts;
    debugPrint('🧹 Unread count cleared for $senderId');
  }

  // ⭐ الدوال العامة
  void emitEvent(String eventName, dynamic data) {
    if (_socket?.connected == true) {
      debugPrint('📤 Emitting event: $eventName');
      _socket!.emit(eventName, data);
    } else {
      debugPrint('❌ Socket not connected. Cannot emit event: $eventName');
    }
  }

  void sendMessage({
    required String senderId,
    required String receiverId,
    required String content,
    required String tempId,
    String? replyToMessageId,
    String? replyToMessageContent,
  }) {
    final messageData = {
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'tempId': tempId,
      'replyToMessageId': replyToMessageId,
      'replyToMessageContent': replyToMessageContent,
      'createdAt': DateTime.now().toIso8601String(),
    };
    
    emitEvent('sendMessage', messageData);
  }

  void markMessageAsRead(String messageId, String senderId, String receiverId) {
    emitEvent('readMessage', {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
    });
  }

  void clearUnreadCountForSender(String senderId) {
    emitEvent('clearUnreadCount', {
      'senderId': senderId,
      'receiverId': _currentUser?.id.toString(),
    });
    _clearUnreadCount(senderId);
  }

  void emitTyping(String senderId, String receiverId, bool isTyping) {
    emitEvent('typing', {
      'senderId': senderId,
      'receiverId': receiverId,
      'isTyping': isTyping,
    });
  }

  void deleteMessage(String messageId, String senderId, String receiverId, String deleteType) {
    emitEvent('deleteMessage', {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
      'deleteType': deleteType,
    });
  }

  void editMessage(String messageId, String senderId, String receiverId, String newContent) {
    emitEvent('editMessage', {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
      'newContent': newContent,
    });
  }

  // دوال إدارة العدادات
  void clearUnreadCount(String senderId) {
    _clearUnreadCount(senderId);
  }

  void updateUnreadCount(String senderId, int count) {
    _updateUnreadCount(senderId, count);
  }

  void setUnreadCounts(Map<String, int> counts) {
    unreadCount.value = Map<String, int>.from(counts);
    debugPrint('📊 Set all unread counts: $counts');
  }

  void clearUnreadCountForChat(String chatId) {
    _clearUnreadCount(chatId);
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isInitialized = false;
      _currentUser = null;
      isConnected.value = false;
      debugPrint('🔌 SocketService: Disconnected');
    }
  }

  void dispose() {
    _messagesController.close();
    _messageStatusController.close();
    isConnected.dispose();
    userStatus.dispose();
    typingStatus.dispose();
    unreadCount.dispose();
    disconnect();
    debugPrint('🗑️ SocketService: Disposed');
  }
}