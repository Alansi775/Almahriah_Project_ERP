import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:almahriah_frontend/models/user.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:almahriah_frontend/pages/login_page.dart';

class ManageUsersPage extends StatefulWidget {
  final User user;
  const ManageUsersPage({super.key, required this.user});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  List<dynamic> users = [];
  bool isLoading = true;
  String _message = '';
  double _scrollOffset = 0.0;
  static const platform = MethodChannel('com.almahriah.app/dialog');

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  void _handleAuthenticationError() {
    print('DEBUG: Handling authentication error. Redirecting to login page.');
    _showPlatformMessage('انتهت صلاحية الجلسة، يرجى تسجيل الدخول مرة أخرى.', isSuccess: false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  void _showPlatformMessage(String message, {required bool isSuccess}) async {
    final String title = isSuccess ? 'تمت العملية بنجاح' : 'خطأ!';
    
    if (Platform.isIOS) {
      try {
        await platform.invokeMethod('showNativeDialog', {
          'title': title,
          'message': message,
          'type': isSuccess ? 'toast' : 'alert',
        });
      } on PlatformException catch (e) {
        print("Failed to show native dialog: '${e.message}'.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message, style: GoogleFonts.almarai())),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message, style: GoogleFonts.almarai())),
      );
    }
  }

  Future<void> _fetchUsers() async {
    print('DEBUG: Fetching users...');
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.67:5050/api/admin/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}',
        },
      );
      print('DEBUG: _fetchUsers response status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        setState(() {
          users = json.decode(response.body);
          isLoading = false;
        });
        print('DEBUG: Users fetched successfully.');
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _handleAuthenticationError();
      } else {
        setState(() {
          final errorMessage = json.decode(response.body)['message'] ?? 'فشل جلب المستخدمين';
          print('DEBUG: Failed to fetch users. Message: "$errorMessage"');
          _message = 'فشل جلب المستخدمين: $errorMessage';
          isLoading = false;
        });
      }
    } catch (e) {
      print('ERROR: Exception during _fetchUsers: $e');
      setState(() {
        _message = 'حدث خطأ في الاتصال بالخادم';
        isLoading = false;
      });
    }
  }

  Future<void> _toggleUserActiveStatus(int userId, bool isActive) async {
    HapticFeedback.lightImpact();
    if (userId == 1) {
      _showPlatformMessage('لا يمكن تعطيل حساب المسؤول الرئيسي.', isSuccess: false);
      return;
    }
    try {
      final response = await http.put(
        Uri.parse('http://192.168.1.67:5050/api/admin/users/$userId/toggle-active'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}',
        },
        body: json.encode({'isActive': !isActive}),
      );
      if (response.statusCode == 200) {
        _showPlatformMessage(json.decode(response.body)['message'], isSuccess: true);
        setState(() {
          _fetchUsers();
        });
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _handleAuthenticationError();
      } else {
        _showPlatformMessage(json.decode(response.body)['message'] ?? 'فشل تحديث حالة المستخدم', isSuccess: false);
      }
    } catch (e) {
      _showPlatformMessage('حدث خطأ في الاتصال بالخادم', isSuccess: false);
    }
  }

  Future<void> _deleteUser(int userId) async {
    if (userId == 1) {
      _showPlatformMessage('لا يمكن حذف حساب المسؤول الرئيسي.', isSuccess: false);
      return;
    }
    try {
      final response = await http.delete(
        Uri.parse('http://192.168.1.67:5050/api/admin/users/$userId'),
        headers: {
          'Authorization': 'Bearer ${widget.user.token}',
        },
      );
      final responseBody = json.decode(response.body);
      if (response.statusCode == 200) {
        HapticFeedback.heavyImpact();
        _showPlatformMessage(responseBody['message'] ?? 'تم حذف المستخدم بنجاح.', isSuccess: true);
        setState(() {
          _fetchUsers();
        });
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _handleAuthenticationError();
      } else {
        _showPlatformMessage(responseBody['message'] ?? 'فشل حذف المستخدم.', isSuccess: false);
      }
    } catch (e) {
      _showPlatformMessage('حدث خطأ في الاتصال بالخادم.', isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      body: NotificationListener<ScrollUpdateNotification>(
        onNotification: (ScrollUpdateNotification notification) {
          setState(() {
            _scrollOffset = notification.metrics.pixels;
          });
          return false;
        },
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              expandedHeight: 0,
              floating: true,
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              title: Text(
                'التحكم في المستخدمين',
                style: GoogleFonts.almarai(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 22),
              ),
              centerTitle: true,
              flexibleSpace: FlexibleSpaceBar(
                background: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: _scrollOffset > 0 ? 10 : 0,
                      sigmaY: _scrollOffset > 0 ? 10 : 0,
                    ),
                    child: Container(
                      color: _scrollOffset > 0 ? Colors.white.withOpacity(0.8) : Colors.transparent,
                    ),
                  ),
                ),
              ),
              leading: Builder(
                builder: (BuildContext innerContext) {
                  return IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
                    onPressed: () => Navigator.of(innerContext).pop(),
                  );
                },
              ),
            ),
            if (isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CupertinoActivityIndicator(radius: 20),
                ),
              )
            else if (users.isEmpty)
              SliverToBoxAdapter(
                child: Center(
                  child: Text(
                    'لا يوجد مستخدمون حالياً.',
                    style: GoogleFonts.almarai(fontSize: 20, color: Colors.black54),
                  ),
                ),
              )
            else
              CupertinoSliverRefreshControl(
                onRefresh: _fetchUsers,
                builder: (
                  BuildContext context,
                  RefreshIndicatorMode refreshState,
                  double pulledExtent,
                  double refreshTriggerPullDistance,
                  double refreshIndicatorExtent,
                ) {
                  return CupertinoSliverRefreshControl.buildRefreshIndicator(
                    context,
                    refreshState,
                    pulledExtent,
                    refreshTriggerPullDistance,
                    refreshIndicatorExtent,
                  );
                },
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final user = users[index];
                      final String initials = user['fullName'] != null && user['fullName'].isNotEmpty
                          ? (user['fullName'] as String).split(' ').map((s) => s.isNotEmpty ? s[0] : '').join().substring(0, user['fullName'].split(' ').map((s) => s.isNotEmpty ? s[0] : '').join().length > 1 ? 2 : 1).toUpperCase()
                          : (user['username'] as String).substring(0, 2).toUpperCase();
                      
                      final bool isMainAdmin = user['id'] == 1;
              
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                leading: CircleAvatar(
                                  backgroundColor: user['isActive'] == 1 ? Colors.green.shade400 : Colors.red.shade400,
                                  radius: 25,
                                  child: Text(
                                    initials,
                                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                ),
                                title: Text(
                                  user['fullName'] ?? user['username'],
                                  style: GoogleFonts.almarai(fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                                subtitle: Text(
                                  '${user['department']} - ${user['role']}',
                                  style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Delete Button
                                    if (!isMainAdmin)
                                      IconButton(
                                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                                        onPressed: () {
                                          _deleteUser(user['id']);
                                        },
                                      ),
                                    // Toggle Active Status Switch
                                    if (!isMainAdmin)
                                      Switch(
                                        value: user['isActive'] == 1,
                                        onChanged: (bool value) {
                                          _toggleUserActiveStatus(user['id'], user['isActive'] == 1);
                                        },
                                        activeColor: Colors.green,
                                        inactiveTrackColor: Colors.red.shade100,
                                        inactiveThumbColor: Colors.red,
                                      )
                                    else
                                      const Icon(Icons.lock_outline, color: Colors.black45),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: users.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}