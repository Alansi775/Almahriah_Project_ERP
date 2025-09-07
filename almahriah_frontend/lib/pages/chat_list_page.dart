// lib/pages/chat_list_page.dart - Final and Enhanced Version

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/pages/chat_page.dart';
import 'package:almahriah_frontend/services/auth_service.dart';
import 'package:almahriah_frontend/custom_page_route.dart';
import 'dart:ui';
import 'package:almahriah_frontend/services/socket_service.dart';
import 'package:almahriah_frontend/widgets/glassmorphism_widgets.dart'; // ✅ Add this import
import 'package:flutter/cupertino.dart';
import 'package:almahriah_frontend/widgets/user_profile_popup.dart'; 
import 'package:flutter/services.dart';

class ChatListPage extends StatefulWidget {
  final User user;

  const ChatListPage({super.key, required this.user});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> with WidgetsBindingObserver {
  List<dynamic> users = [];
  bool isLoading = true;
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  final SocketService _socketService = SocketService();
  
  bool _socketConnected = false;
  
  StreamSubscription? _messageSubscription;
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _initializeSocketAndFetchUsers();
    
    _scrollController.addListener(() {
      if (mounted) {
        setState(() {
          _isScrolled = _scrollController.offset > 0;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  Future<void> _initializeSocketAndFetchUsers() async {
    _socketService.initialize(widget.user);
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    _socketConnected = _socketService.isConnected.value;
    
    _socketService.isConnected.addListener(_updateConnectionStatus);
    _socketService.userStatus.addListener(_updateUsersStatus);
    _socketService.unreadCount.addListener(_updateUnreadCounts);
    
    _messageSubscription = _socketService.messagesStream.listen((messageData) {
      if (mounted) {
        _handleNewMessage(messageData);
      }
    });
    
    _statusSubscription = _socketService.messageStatusStream.listen((statusData) {
      if (mounted && statusData is Map) {
        if (statusData['action'] == 'read' || statusData['action'] == 'delivered') {
          setState(() {});
        }
      }
    });
    
    await _fetchUsers();
    await _fetchUnreadCounts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _statusSubscription?.cancel();
    _socketService.isConnected.removeListener(_updateConnectionStatus);
    _socketService.userStatus.removeListener(_updateUsersStatus);
    _socketService.unreadCount.removeListener(_updateUnreadCounts);
    super.dispose();
  }
  
  void _handleNewMessage(Map<String, dynamic> messageData) {
    final senderId = messageData['senderId'].toString();
    final currentUserId = widget.user.id.toString();
    
    if (senderId != currentUserId) {
      debugPrint('📥 New message received from $senderId in chat list');
      _sortUsers();
    }
  }
  
  Future<void> _fetchUnreadCounts() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/api/chat/unread-counts'),
        headers: {'Authorization': 'Bearer ${widget.user.token}'},
      );

      if (response.statusCode == 200 && mounted) {
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<String, int> unreadCounts = {};
        
        data.forEach((key, value) {
          unreadCounts[key] = int.tryParse(value.toString()) ?? 0;
        });
        
        _socketService.setUnreadCounts(unreadCounts);
        debugPrint(' Fetched unread counts: $unreadCounts');
      }
    } catch (e) {
      debugPrint('❌ Error fetching unread counts: $e');
    }
  }
  
  void _updateUnreadCounts() {
    if (mounted) {
      final updatedCounts = _socketService.unreadCount.value;
      setState(() {
        users = users.map((user) {
          final userId = user['id'].toString();
          user['unreadCount'] = updatedCounts[userId] ?? 0;
          return user;
        }).toList();
        _sortUsers();
      });
    }
  }

  void _updateConnectionStatus() {
    if (mounted) {
      setState(() {
        _socketConnected = _socketService.isConnected.value;
      });
    }
  }
  
  void _updateUsersStatus() {
    if (mounted) {
      final updatedStatus = _socketService.userStatus.value;
      setState(() {
        users = users.map((user) {
          final userId = user['id'].toString();
          if (updatedStatus.containsKey(userId)) {
            user['isLoggedIn'] = updatedStatus[userId]! ? 1 : 0;
          }
          return user;
        }).toList();
        _sortUsers();
      });
    }
  }
  
  void _sortUsers() {
    users.sort((a, b) {
      final aUnreadCount = int.tryParse(a['unreadCount']?.toString() ?? '0') ?? 0;
      final bUnreadCount = int.tryParse(b['unreadCount']?.toString() ?? '0') ?? 0;
      
      final aIsOnline = a['isLoggedIn'] == 1;
      final bIsOnline = b['isLoggedIn'] == 1;
      
      if (aUnreadCount > 0 && bUnreadCount == 0) {
        return -1;
      }
      if (aUnreadCount == 0 && bUnreadCount > 0) {
        return 1;
      }
      
      if (aIsOnline && !bIsOnline) {
        return -1;
      }
      if (!aIsOnline && bIsOnline) {
        return 1;
      }

      return a['fullName'].compareTo(b['fullName']);
    });
  }

  Future<void> _fetchUsers() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
    });
    
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/api/chat/users'),
        headers: {'Authorization': 'Bearer ${widget.user.token}'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> fetchedUsers = json.decode(response.body);
        final filteredUsers = fetchedUsers.where((u) => u['id'] != widget.user.id).toList();
        
        if (mounted) {
          setState(() {
            users = filteredUsers;
            isLoading = false;
          });
          
          _updateUsersStatus();
          _updateUnreadCounts();
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجددًا.', style: GoogleFonts.almarai()),
          ),
        );
        AuthService.logout(context, widget.user.id);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في تحميل المستخدمين', style: GoogleFonts.almarai())),
        );
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الاتصال بالخادم: $e', style: GoogleFonts.almarai())),
      );
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    await _fetchUsers();
    await _fetchUnreadCounts();
    _retryConnection();
  }

  void _retryConnection() {
    if (!_socketService.isConnected.value) {
      _socketService.initialize(widget.user);
    }
  }
  
  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          Text(
            'المحادثات',
            style: GoogleFonts.almarai(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _socketConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
      actions: [
        if (!_socketConnected)
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.red),
            onPressed: _retryConnection,
          ),
      ],
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _isScrolled ? 10 : 0, sigmaY: _isScrolled ? 10 : 0),
          child: Container(
            color: _isScrolled ? Colors.white.withOpacity(0.8) : Colors.transparent,
          ),
        ),
      ),
    ),
    body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              if (!_socketConnected)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: Colors.red.shade50,
                  child: Text(
                    'انقطع الاتصال - قد لا تكون التحديثات الفورية متاحة',
                    style: GoogleFonts.almarai(color: Colors.red.shade700, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(
                child: isLoading
                    ? Center(
                        child: Theme.of(context).platform == TargetPlatform.iOS
                            ? const CupertinoActivityIndicator(radius: 15.0)
                            : const CircularProgressIndicator(color: Color(0xFF3498DB)),
                      )
                    : users.isEmpty
                        ? Center(
                            child: Text(
                              'لا يوجد مستخدمون متاحون للدردشة.',
                              style: GoogleFonts.almarai(fontSize: 18, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : Theme.of(context).platform == TargetPlatform.iOS
                            ? CustomScrollView(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                slivers: [
                                  CupertinoSliverRefreshControl(
                                    onRefresh: _refreshData,
                                  ),
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (BuildContext context, int index) {
                                        final user = users[index];
                                        final String initials = _getInitials(user['fullName']);
                                        final bool isOnline = user['isLoggedIn'] == 1;
                                        final int unreadCount = int.tryParse(user['unreadCount']?.toString() ?? '0') ?? 0;
                                        final String? profilePictureUrl = user['profilePictureUrl'];
                                        final String? role = user['role'];
                                        final String? department = user['department'];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                          child: _buildUserTile(context, user, initials, isOnline, unreadCount, profilePictureUrl, role, department),
                                        );
                                      },
                                      childCount: users.length,
                                    ),
                                  ),
                                ],
                              )
                            : RefreshIndicator(
                                onRefresh: _refreshData,
                                color: const Color(0xFF3498DB),
                                child: Scrollbar(
                                  controller: _scrollController,
                                  child: ListView.separated(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                    itemCount: users.length,
                                    separatorBuilder: (context, index) => const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8.0),
                                      child: Divider(
                                        color: Colors.black12,
                                        height: 1,
                                        thickness: 1,
                                        indent: 72,
                                      ),
                                    ),
                                    itemBuilder: (context, index) {
                                      final user = users[index];
                                      final String initials = _getInitials(user['fullName']);
                                      final bool isOnline = user['isLoggedIn'] == 1;
                                      final int unreadCount = int.tryParse(user['unreadCount']?.toString() ?? '0') ?? 0;
                                      final String? profilePictureUrl = user['profilePictureUrl'];
                                      final String? role = user['role'];
                                      final String? department = user['department'];
                                      return _buildUserTile(context, user, initials, isOnline, unreadCount, profilePictureUrl, role, department);
                                    },
                                  ),
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
  );
}

  String _getInitials(String? fullName) {
    if (fullName == null || fullName.isEmpty) return '?';
    final parts = fullName.split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  // The buildUserTile method with long-press functionality
Widget _buildUserTile(BuildContext context, dynamic user, String initials, bool isOnline, int unreadCount, String? profilePictureUrl, String? role, String? department) {
  final isBold = unreadCount > 0;

  return GestureDetector( // ✅ Wrap with GestureDetector
    onLongPress: () {
      HapticFeedback.lightImpact(); // ✅ Add haptic feedback for long press
      _showUserProfilePopup(context, user); // ✅ Call the new function
    },
    child: Container(
      decoration: BoxDecoration(
        color: unreadCount > 0 ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: unreadCount > 0 ? Border.all(color: Colors.blue.shade200, width: 1) : null,
        boxShadow: [
          BoxShadow(
            color: unreadCount > 0 ? Colors.blue.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              _socketService.clearUnreadCountForSender(user['id'].toString());
              
              final result = await Navigator.push(
                context,
                CustomPageRoute(
                  child: ChatPage(
                    user: widget.user,
                    targetUser: user,
                  ),
                ),
              );
              
              if (result == true && mounted) {
                await _refreshData();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Row(
                children: [
                  _buildUserAvatar(initials, isOnline, unreadCount > 0, profilePictureUrl),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['fullName'],
                          style: GoogleFonts.almarai(
                            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                            fontSize: isBold ? 17 : 16,
                            color: isBold ? Colors.black : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (role != null && department != null) ...[
                          Row(
                            children: [
                              buildGlassTag(text: '$role - $department'),
                              const SizedBox(width: 8),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isOnline ? Colors.green.shade400 : Colors.red.shade400,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isOnline ? 'متصل الآن' : 'غير متصل',
                              style: GoogleFonts.almarai(
                                color: isOnline ? Colors.green.shade400 : Colors.red.shade400,
                                fontSize: 14,
                                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(width: 12),
                              Text(
                                'رسالة جديدة',
                                style: GoogleFonts.almarai(
                                  color: Colors.blue.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (unreadCount > 0)
                    _buildUnreadCountBadge(unreadCount),
                ],
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildUnreadCountBadge(int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade500,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: count > 99 ? 10 : 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _showUserProfilePopup(BuildContext context, Map<String, dynamic> user) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation) {
        return UserProfilePopup(user: user);
      },
      transitionBuilder: (BuildContext context, Animation<double> a1, Animation<double> a2, Widget child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(a1),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.5, end: 1.0).animate(a1),
            child: child,
          ),
        );
      },
    );
  }

  // ✅ New widget to build user avatar with image
  Widget _buildUserAvatar(String initials, bool isOnline, bool hasUnreadMessages, String? profilePictureUrl) {
    final Color glowColor = isOnline ? Colors.green.shade400 : Colors.red.shade400;
    final Color borderColor = hasUnreadMessages ? Colors.blue.shade400 : Colors.grey.shade300;
    
    final bool hasProfilePicture = profilePictureUrl != null && profilePictureUrl.isNotEmpty;
    final String fullImageUrl = hasProfilePicture ? '${AuthService.baseUrl}$profilePictureUrl' : '';

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade200,
        border: Border.all(
          color: borderColor,
          width: hasUnreadMessages ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(isOnline ? 0.7 : 0.5),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          if (hasUnreadMessages)
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: hasProfilePicture
          ? ClipOval(
              child: Image.network(
                fullImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Text(
                      initials,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: hasUnreadMessages ? Colors.blue.shade700 : Colors.black87,
                      ),
                    ),
                  );
                },
              ),
            )
          : Center(
              child: Text(
                initials,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: hasUnreadMessages ? Colors.blue.shade700 : Colors.black87,
                ),
              ),
            ),
    );
  }
}