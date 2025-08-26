import 'dart:async'; // Added for StreamSubscription
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/pages/chat_page.dart';
import 'package:almahriah_frontend/services/auth_service.dart';
import 'package:almahriah_frontend/custom_page_route.dart';
import 'dart:ui';

// ✅ استيراد خدمة المقبس الجديدة
import 'package:almahriah_frontend/services/socket_service.dart';

class ChatListPage extends StatefulWidget {
  final User user;

  const ChatListPage({super.key, required this.user});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  List<dynamic> users = [];
  bool isLoading = true;
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  // ✅ استخدام خدمة المقبس
  final SocketService _socketService = SocketService();
  
  // ✅ متغيرات لحالة المقبس والمستخدمين
  bool _socketConnected = false;
  late StreamSubscription _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    
    _socketConnected = _socketService.isConnected.value;
    
    // ✅ الاستماع للتغيرات في حالة الاتصال
    _socketService.isConnected.addListener(_updateConnectionStatus);
    
    // ✅ الاستماع للتغيرات في حالة المستخدمين
    _socketService.userStatus.addListener(_updateUsersStatus);

    _scrollController.addListener(() {
      if (mounted) {
        setState(() {
          _isScrolled = _scrollController.offset > 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _socketService.isConnected.removeListener(_updateConnectionStatus);
    _socketService.userStatus.removeListener(_updateUsersStatus);
    super.dispose();
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
      });
    }
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
          
          // تحديث الحالة فورًا بعد جلب القائمة
          _updateUsersStatus();
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: ${json.decode(response.body)['message']}', style: GoogleFonts.almarai())),
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
        SnackBar(content: Text('حدث خطأ في الاتصال بالخادم: $e', style: GoogleFonts.almarai())),
      );
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ✅ إعادة محاولة الاتصال عبر الخدمة
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
            // مؤشر حالة الاتصال
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
          // زر إعادة المحاولة إذا انقطع الاتصال
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
              // رسالة حالة الاتصال
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
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF2C3E50)))
                    : users.isEmpty
                        ? Center(
                            child: Text(
                              'لا يوجد مستخدمون متاحون للدردشة.',
                              style: GoogleFonts.almarai(fontSize: 18, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              await _fetchUsers();
                              _retryConnection(); // Ensure a connection is re-attempted on pull-to-refresh
                            },
                            color: const Color(0xFF2C3E50),
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
                                  final String initials = user['fullName'] != null && user['fullName'].isNotEmpty
                                      ? user['fullName'][0].toUpperCase()
                                      : '?';
                                  
                                  // ✅ قراءة حالة isLoggedIn من الكائن
                                  final bool isOnline = user['isLoggedIn'] == 1;

                                  return _buildUserTile(context, user, initials, isOnline);
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

  Widget _buildUserTile(BuildContext context, dynamic user, String initials, bool isOnline) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              final result = await Navigator.push(
                context,
                CustomPageRoute(
                  child: ChatPage(
                    user: widget.user,
                    targetUser: user,
                  ),
                ),
              );
              
              // تحديث البيانات عند العودة من صفحة المحادثة
              if (result == true && mounted) {
                _fetchUsers();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Row(
                children: [
                  _buildUserAvatar(initials, isOnline),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['fullName'],
                          style: GoogleFonts.almarai(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String initials, bool isOnline) {
    final Color glowColor = isOnline ? Colors.green.shade400 : Colors.red.shade400;

    return Container(
      width: 50,
      height: 50,
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
            fontSize: 22,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}