// ✅ Full, correct, and ready-to-use code for ai.dart

import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:almahriah_frontend/models/user.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class AiChatPage extends StatefulWidget {
  final User user;

  const AiChatPage({super.key, required this.user});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _showInitialWelcome = true;
  static const platform = MethodChannel("com.almahriah.app/dialog");

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_updateSendButtonState);
  }

  void _updateSendButtonState() {
    setState(() {});
  }

  @override
  void dispose() {
    _messageController.removeListener(_updateSendButtonState);
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showAlert(String title, String message) {
    if (kIsWeb || (!kIsWeb && Platform.isAndroid)) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: Text(title, style: GoogleFonts.almarai(fontWeight: FontWeight.bold)),
            content: Text(message, style: GoogleFonts.almarai()),
            actions: [
              CupertinoDialogAction(
                child: const Text('موافق', style: TextStyle(color: CupertinoColors.activeBlue)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } else if (!kIsWeb && Platform.isIOS) {
      try {
        platform.invokeMethod('showAlert', {
          'title': title,
          'message': message,
        });
      } on PlatformException catch (e) {
        print("Failed to show native alert: '${e.message}'.");
      }
    }
  }

  void _showComingSoonAlert() {
    _showAlert('قريباً', 'هذه الميزة ستكون متاحة قريباً.');
  }

  void _triggerHapticFeedback() {
    if (!kIsWeb && Platform.isIOS) {
      HapticFeedback.lightImpact();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isLoading) return;

    if (_showInitialWelcome) {
      setState(() {
        _showInitialWelcome = false;
      });
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _messages.add({
        'text': messageText,
        'isUser': true,
        'isCompleted': true, // User messages are always completed
      });
      _messages.add({
        'text': '',
        'isUser': false,
        'isThinking': true,
        'isCompleted': false,
      });
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();
    
    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.65:5050/api/ai/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.user.token}',
        },
        body: jsonEncode({
          'prompt': messageText,
          'history': _messages.where((m) => m['isThinking'] != true).map((m) => {
            'role': m['isUser'] ? 'user' : 'assistant',
            'content': m['text'],
          }).toList(),
        }),
      );

      if (!mounted) return;

      _messages.removeLast();
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _messages.add({
            'text': data['message'],
            'isUser': false,
            'isThinking': false,
            'isCompleted': false, // Will be set to true after animation
          });
          _isLoading = false;
        });
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _showAlert('انتهت صلاحية الجلسة', 'الرجاء تسجيل الدخول مرة أخرى.');
        setState(() {
          _isLoading = false;
        });
      } else {
        _showAlert(
          'خطأ',
          json.decode(response.body)['message'] ?? 'عذراً، حدث خطأ أثناء الاتصال بالمساعد الذكي.',
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _messages.removeLast();
      _showAlert('خطأ في الاتصال', 'عذراً، لا يمكن الاتصال بالخادم. الرجاء المحاولة لاحقاً.');
      setState(() {
        _isLoading = false;
      });
    } finally {
      if (mounted) {
        _scrollToBottom();
      }
    }
  }

  void _onStreamingComplete(int index) {
    if (mounted && index < _messages.length) {
      setState(() {
        _messages[index]['isCompleted'] = true;
      });
    }
  }

  Widget _buildAiMessage(Map<String, dynamic> message, int index) {
    if (message['isThinking'] == true) {
      return _MessageBubble(
        isUser: false,
        child: _buildElegantTypingIndicator(),
      );
    }
    
    // ✅ Check if the message is completed
    if (message['isCompleted'] == true) {
      return _MessageBubble(
        isUser: false,
        child: _FormattedText(text: message['text']),
      );
    } else {
      // ✅ Pass the completion callback to the streaming widget
      return _MessageBubble(
        isUser: false,
        child: _StreamingText(
          text: message['text'],
          scrollController: _scrollController,
          onComplete: () => _onStreamingComplete(index),
        ),
      );
    }
  }

  Widget _MessageBubble({required bool isUser, required Widget child}) {
    final color = isUser ? Colors.blue.shade100 : Colors.grey.shade100;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(0),
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 120,
              width: 120,
            ),
            const SizedBox(height: 20),
            Text(
              'مرحباً بك، ${widget.user.fullName}!',
              textAlign: TextAlign.center,
              style: GoogleFonts.marhey( 
                fontSize: 60,
                fontWeight: FontWeight.w400,
                color: Colors.black87,
                shadows: [
                  Shadow(
                    offset: const Offset(2.0, 2.0),
                    blurRadius: 3.0,
                    color: Colors.black.withOpacity(0.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'أنا كهلان، مساعدك الذكي المخصص لموظفي قناة المهرية الفضائية.\nكيف يمكنني مساعدتك اليوم؟',
              textAlign: TextAlign.center,
              style: GoogleFonts.almarai(
                fontSize: 18,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElegantTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _TypingDot(delay: 0),
        _TypingDot(delay: 200),
        _TypingDot(delay: 400),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = !kIsWeb && Platform.isIOS;
    final isDesktop = kIsWeb || (!isIOS && (Platform.isMacOS || Platform.isWindows || Platform.isLinux));
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          'مساعدك الذكي كهلان',
          style: GoogleFonts.almarai(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Center(
          child: SizedBox(
            width: isDesktop ? 800 : double.infinity,
            child: Column(
              children: [
                Expanded(
                  child: _showInitialWelcome
                      ? _buildWelcomeScreen()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(top: 16, bottom: 16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            if (message['isUser']) {
                              return _MessageBubble(
                                isUser: true,
                                child: SelectableText(
                                  message['text'],
                                  style: GoogleFonts.almarai(
                                    color: Colors.blue.shade900,
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),
                              );
                            } else {
                              return _buildAiMessage(message, index);
                            }
                          },
                        ),
                ),
                
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade200,
                          ),
                          child: IconButton(
                            icon: const Icon(CupertinoIcons.mic_fill, color: Colors.black54),
                            onPressed: _showComingSoonAlert,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.grey.shade300, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    cursorColor: Colors.blue.shade800,
                                    decoration: InputDecoration(
                                      hintText: 'اكتب رسالتك هنا...',
                                      hintStyle: GoogleFonts.almarai(color: Colors.grey.shade600),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    ),
                                    style: GoogleFonts.almarai(color: Colors.black87),
                                    onSubmitted: (_) => _sendMessage(),
                                    maxLines: null,
                                    minLines: 1,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(CupertinoIcons.plus_circle_fill, color: Colors.black54),
                                  onPressed: _showComingSoonAlert,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _messageController.text.isNotEmpty ? Colors.blue.shade800 : Colors.grey.shade400,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.white),
                            onPressed: _sendMessage,
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
    );
  }
}

// ✅ New widget to handle streaming text with formatting and haptic feedback
class _StreamingText extends StatefulWidget {
  final String text;
  final ScrollController scrollController;
  final VoidCallback onComplete;

  const _StreamingText({
    required this.text,
    required this.scrollController,
    required this.onComplete,
  });

  @override
  State<_StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<_StreamingText> {
  final List<String> _displayedLines = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _streamText();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _streamText() async {
    final lines = widget.text.split('\n');
    for (var line in lines) {
      if (_isDisposed) return;
      
      _displayedLines.add(line);
      _listKey.currentState?.insertItem(_displayedLines.length - 1);
      
      if (!kIsWeb && Platform.isIOS) {
        HapticFeedback.lightImpact();
      }
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.scrollController.hasClients) {
          widget.scrollController.animateTo(
            widget.scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
      await Future.delayed(const Duration(milliseconds: 200));
    }
    // ✅ Call the onComplete callback after all lines are displayed
    if (!_isDisposed) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      initialItemCount: _displayedLines.length,
      itemBuilder: (context, index, animation) {
        final line = _displayedLines[index].trim();
        final formattedLine = _buildFormattedText(line);
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: formattedLine,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormattedText(String text) {
    String cleanedText = text.replaceAll('"', '');
    final spans = <TextSpan>[];
    final boldRegex = RegExp(r'\*\*(.*?)\*\*');
    
    String currentText = cleanedText;
    int lastMatchEnd = 0;

    for (var match in boldRegex.allMatches(cleanedText)) {
      if (match.start > lastMatchEnd) {
        spans.addAll(_processSingleStars(currentText.substring(lastMatchEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < currentText.length) {
      spans.addAll(_processSingleStars(currentText.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(
        style: GoogleFonts.almarai(
          fontSize: (!kIsWeb && Platform.isIOS) ? 15 : 16,
          color: Colors.black87,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }
  
  List<TextSpan> _processSingleStars(String text) {
    return text.split('*').map((part) {
      if (part.isNotEmpty) {
        return TextSpan(text: part);
      }
      return const TextSpan(text: '• ');
    }).toList();
  }
}

// ✅ New Stateless widget to display formatted text after streaming is complete
class _FormattedText extends StatelessWidget {
  final String text;

  const _FormattedText({required this.text});
  
  @override
  Widget build(BuildContext context) {
    String cleanedText = text.replaceAll('"', '');
    final spans = <TextSpan>[];
    final boldRegex = RegExp(r'\*\*(.*?)\*\*');
    
    String currentText = cleanedText;
    int lastMatchEnd = 0;

    for (var match in boldRegex.allMatches(cleanedText)) {
      if (match.start > lastMatchEnd) {
        spans.addAll(_processSingleStars(currentText.substring(lastMatchEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < currentText.length) {
      spans.addAll(_processSingleStars(currentText.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(
        style: GoogleFonts.almarai(
          fontSize: (!kIsWeb && Platform.isIOS) ? 15 : 16,
          color: Colors.black87,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }

  List<TextSpan> _processSingleStars(String text) {
    return text.split('*').map((part) {
      if (part.isNotEmpty) {
        return TextSpan(text: part);
      }
      return const TextSpan(text: '• ');
    }).toList();
  }
}

// ✅ StatefulWidget for the elegant typing dots animation
class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(() {
      setState(() {});
    });
    _animation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );
    _startAnimationWithDelay();
  }

  void _startAnimationWithDelay() async {
    await Future.delayed(Duration(milliseconds: widget.delay));
    if (mounted) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade800.withOpacity(_animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}