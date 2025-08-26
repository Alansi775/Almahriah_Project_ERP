// lib/pages/tasks_list_page.dart

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/widgets/glassmorphism_widgets.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class TasksListPage extends StatefulWidget {
  final User user;
  final String title;
  final String? statusFilter;

  const TasksListPage({
    super.key,
    required this.user,
    required this.title,
    this.statusFilter,
  });

  @override
  State<TasksListPage> createState() => _TasksListPageState();
}

class _TasksListPageState extends State<TasksListPage> {
  List _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String url = 'http://192.168.1.52:5050/api/tasks/department';
      if (widget.statusFilter != null) {
        url += '?status=${widget.statusFilter}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _tasks = json.decode(response.body)['tasks'];
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load tasks');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch tasks: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getTaskStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'لم تبدأ بعد';
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'completed':
        return 'مكتملة';
      case 'canceled':
        return 'ملغاة';
      default:
        return 'غير معروف';
    }
  }

  Color _getTaskStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.grey.shade600;
      case 'in_progress':
        return Colors.blue.shade600;
      case 'completed':
        return Colors.green.shade600;
      case 'canceled':
        return Colors.red.shade600;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'عاجل':
        return Colors.red.shade600;
      case 'مهم':
        return Colors.orange.shade600;
      case 'عادي':
      default:
        return Colors.blue.shade600;
    }
  }

  String _formatDate(String? date) {
    if (date == null) return 'غير محدد';
    try {
      return intl.DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(date).toLocal());
    } catch (e) {
      return 'تاريخ غير صالح';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.almarai(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ),
        leading: kIsWeb
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
              )
            : null,
        // ✅ Add a refresh button for web only
        actions: kIsWeb
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  onPressed: _fetchTasks,
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : kIsWeb
              ? RefreshIndicator(
                  onRefresh: () async {
                    HapticFeedback.heavyImpact();
                    await _fetchTasks();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return _buildTaskCard(task);
                    },
                  ),
                )
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: <Widget>[
                    CupertinoSliverRefreshControl(
                      onRefresh: () async {
                        HapticFeedback.heavyImpact();
                        await _fetchTasks();
                      },
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          final task = _tasks[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: _buildTaskCard(task),
                          );
                        },
                        childCount: _tasks.length,
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTaskCard(dynamic task) {
    final statusColor = _getTaskStatusColor(task['status']);
    final statusText = _getTaskStatusText(task['status']);
    final priorityColor = _getPriorityColor(task['priority']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: buildGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                buildGlassTag(text: statusText, color: statusColor),
                buildGlassTag(text: task['priority'], color: priorityColor),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              task['title'],
              style: GoogleFonts.almarai(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              task['description'],
              style: GoogleFonts.almarai(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                const Icon(Icons.person_pin, size: 20, color: Colors.black54),
                const SizedBox(width: 5),
                Text('مسندة إلى: ${task['assignedToName']}', style: GoogleFonts.almarai(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(Icons.verified_user, size: 20, color: Colors.black54),
                const SizedBox(width: 5),
                Text('مسندة من: ${task['assignedByName']}', style: GoogleFonts.almarai(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 15),
            _buildDateTag(label: 'تاريخ الإنشاء', date: task['createdAt'], color: Colors.blue.shade800),
            if (task['inProgressAt'] != null)
              _buildDateTag(label: 'بدأت في', date: task['inProgressAt'], color: Colors.blue.shade600),
            if (task['completedAt'] != null)
              _buildDateTag(label: 'اكتملت في', date: task['completedAt'], color: Colors.green.shade600),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTag({required String label, required String date, required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: buildGlassTag(
        text: '$label: ${_formatDate(date)}',
        color: color,
      ),
    );
  }
}