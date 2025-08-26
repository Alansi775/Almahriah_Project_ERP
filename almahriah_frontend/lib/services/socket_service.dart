// lib/services/socket_service.dart
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/user.dart';
import 'dart:async';
import 'auth_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  late IO.Socket _socket;
  bool _isInitialized = false;

  // ✅ ValueNotifier لمشاركة حالة الاتصال
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);

  // ✅ ValueNotifier لمشاركة حالة "يكتب الآن..."
  final ValueNotifier<Map<String, bool>> typingStatus = ValueNotifier<Map<String, bool>>({});
  
  // ✅ StreamController لمشاركة الرسائل
  final StreamController<dynamic> _messagesController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get messagesStream => _messagesController.stream;

  // ✅ ValueNotifier لحالة المستخدمين (متصل/غير متصل)
  final ValueNotifier<Map<String, bool>> userStatus = ValueNotifier<Map<String, bool>>({});

  void initialize(User user) {
    if (_isInitialized) return;
    _isInitialized = true;
    _connect(user);
  }

  void _connect(User user) {
    try {
      _socket = IO.io(
        AuthService.baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setQuery({'userId': user.id.toString()})
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .build(),
      );

      _socket.connect();

      _socket.onConnect((_) {
        print('✅ SocketService: Connected to server!');
        isConnected.value = true;
      });

      _socket.onDisconnect((_) {
        print('❌ SocketService: Disconnected from server!');
        isConnected.value = false;
      });

      _socket.on('user-status-changed', (data) {
        if (data is Map) {
          userStatus.value = {
            ...userStatus.value,
            data['userId'].toString(): data['status'] as bool,
          };
          print('✅ SocketService: User ${data['userId']} status changed to ${data['status']}');
        }
      });

      _socket.on('receiveMessage', (data) {
        _messagesController.sink.add(data);
      });
      
      _socket.on('typing', (data) {
        if (data is Map) {
          final senderId = data['senderId'].toString();
          final isTyping = data['isTyping'] as bool;
          typingStatus.value[senderId] = isTyping;
          typingStatus.notifyListeners();
        }
      });
    } catch (e) {
      print('🚨 SocketService: Error connecting socket: $e');
    }
  }

  void sendMessage(dynamic data) {
    if (isConnected.value) {
      _socket.emit('sendMessage', data);
    }
  }

  void emitEvent(String eventName, dynamic data) {
    if (isConnected.value) {
      _socket.emit(eventName, data);
    }
  }

  void dispose() {
    _socket.disconnect();
    _socket.dispose();
    _messagesController.close();
    isConnected.value = false;
    _isInitialized = false;
  }
}