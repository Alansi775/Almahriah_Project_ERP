// lib/services/socket_service.dart - النسخة النهائية والكاملة

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

  // Getter للسوكت
  IO.Socket get socket => _socket!;

  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<Map<String, bool>> typingStatus = ValueNotifier<Map<String, bool>>({});
  final ValueNotifier<Map<String, bool>> userStatus = ValueNotifier<Map<String, bool>>({});

  final StreamController<dynamic> _messagesController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get messagesStream => _messagesController.stream;

  final StreamController<dynamic> _messageStatusController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get messageStatusStream => _messageStatusController.stream;

  void initialize(User user) {
    if (_isInitialized && _socket?.connected == true) {
      print('Socket already initialized and connected.');
      return;
    }
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

      _socket!.onConnect((_) {
        print('SocketService: Connected to server!');
        isConnected.value = true;
      });

      _socket!.onDisconnect((_) {
        print('SocketService: Disconnected from server!');
        isConnected.value = false;
      });

      // تحديث حالة المستخدمين
      _socket!.on('user-status-changed', (data) {
        if (data is Map) {
          final String userId = data['userId'].toString();
          final bool status = data['status'] as bool;
          userStatus.value = {...userStatus.value, userId: status};
          print('User status changed: $userId -> $status');
        }
      });
      
      // استقبال الرسائل الجديدة مع دعم الرد
      _socket!.on('receiveMessage', (data) {
        print('Received message: $data');
        if (data is Map) {
          // تحويل البيانات لضمان التنسيق الصحيح
          final messageData = {
            'id': data['id'].toString(),
            'senderId': data['senderId'].toString(),
            'receiverId': data['receiverId'].toString(),
            'content': data['content'],
            'readStatus': data['readStatus'] == true || data['readStatus'] == 1,
            'deliveredStatus': data['deliveredStatus'] == true || data['deliveredStatus'] == 1,
            'createdAt': data['createdAt'],
            'replyToMessageId': data['replyToMessageId'],
            'replyToMessageContent': data['replyToMessageContent'], // محتوى الرسالة المردود عليها
          };
          _messagesController.sink.add(messageData);
        }
      });
      
      // حالة الكتابة
      _socket!.on('typing', (data) {
        if (data is Map) {
          final senderId = data['senderId'].toString();
          final isTyping = data['isTyping'] as bool;
          typingStatus.value = {...typingStatus.value, senderId: isTyping};
          print('Typing status: $senderId -> $isTyping');
        }
      });

      // تحديثات حالة الرسائل
      _socket!.on('messageStatusUpdate', (data) {
        if (data is Map) {
          print('Message status update: $data');
          _messageStatusController.sink.add({
            'messageId': data['messageId'].toString(),
            'tempId': data['tempId']?.toString(),
            'status': data['status'],
          });
        }
      });

      // حذف الرسائل
      _socket!.on('messageDeleted', (data) {
        if (data is Map) {
          print('Message deleted: ${data['messageId']}');
          _messageStatusController.sink.add({
            'messageId': data['messageId'].toString(),
            'action': 'deleted',
          });
        }
      });

      // تعديل الرسائل
      _socket!.on('messageEdited', (data) {
        if (data is Map) {
          print('Message edited: ${data['id']}');
          _messageStatusController.sink.add({
            'messageId': data['id'].toString(),
            'newContent': data['newContent'],
            'action': 'edited',
          });
        }
      });

      // معالجة الأخطاء
      _socket!.on('messageError', (data) {
        print('Message error: $data');
      });

      _socket!.onError((error) {
        print('Socket error: $error');
      });

      _socket!.onConnectError((error) {
        print('Socket connection error: $error');
      });

    } catch (e) {
      print('SocketService: Error connecting socket: $e');
    }
  }

  void emitEvent(String eventName, dynamic data) {
    if (_socket?.connected == true) {
      print('Emitting event: $eventName with data: $data');
      _socket!.emit(eventName, data);
    } else {
      print('Socket not connected. Cannot emit event: $eventName');
    }
  }

  // إرسال رسالة مع دعم الرد
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
      'replyToMessageContent': replyToMessageContent, // محتوى الرسالة المردود عليها
      'createdAt': DateTime.now().toIso8601String(),
    };
    
    emitEvent('sendMessage', messageData);
  }

  // قراءة الرسالة
  void markMessageAsRead(String messageId, String senderId, String receiverId) {
    emitEvent('readMessage', {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
    });
  }

  // الكتابة
  void emitTyping(String senderId, String receiverId, bool isTyping) {
    emitEvent('typing', {
      'senderId': senderId,
      'receiverId': receiverId,
      'isTyping': isTyping,
    });
  }

  // حذف رسالة
  void deleteMessage(String messageId, String senderId, String receiverId) {
    emitEvent('deleteMessage', {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
    });
  }

  // تعديل رسالة
  void editMessage(String messageId, String senderId, String receiverId, String newContent) {
    emitEvent('editMessage', {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
      'newContent': newContent,
    });
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isInitialized = false;
      isConnected.value = false;
      print('SocketService: Disconnected');
    }
  }

  void dispose() {
    _messagesController.close();
    _messageStatusController.close();
    isConnected.dispose();
    userStatus.dispose();
    typingStatus.dispose();
    disconnect();
    print('SocketService: Disposed');
  }
}