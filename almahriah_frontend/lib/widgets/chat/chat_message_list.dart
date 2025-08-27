// lib/widgets/chat/chat_message_list.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:almahriah_frontend/models/user.dart';
import 'package:almahriah_frontend/widgets/message_bubble.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:almahriah_frontend/widgets/chat/chat_app_bar.dart';

class ChatMessageList extends StatelessWidget {
  final ScrollController scrollController;
  final bool isIOS;
  final Function() onMarkAllMessagesAsRead;
  final List<dynamic> messages;
  final Map<String, GlobalKey> messageKeys;
  final dynamic user;
  final Function(dynamic message) onReply;
  final Function(dynamic message) onLongPress;
  final String? highlightedMessageId;
  final Set<String> selectedMessageIds;
  final bool isSelectionMode;
  final dynamic targetUser;
  final bool isOnline;
  final bool isTargetUserTyping;
  final Function() showBulkDeleteDialog;
  final Function() exitSelectionMode;
  final Function(dynamic message) onMessageTap;
  final bool isChatLoading;
  final bool hasMoreMessages;
  final Function() onFetchMoreMessages;
  final Future<void> Function() onRefresh; 

  const ChatMessageList({
    super.key,
    required this.scrollController,
    required this.isIOS,
    required this.onMarkAllMessagesAsRead,
    required this.messages,
    required this.messageKeys,
    required this.user,
    required this.onReply,
    required this.onLongPress,
    this.highlightedMessageId,
    required this.selectedMessageIds,
    required this.isSelectionMode,
    required this.targetUser,
    required this.isOnline,
    required this.isTargetUserTyping,
    required this.showBulkDeleteDialog,
    required this.exitSelectionMode,
    required this.onMessageTap,
    required this.isChatLoading,
    required this.hasMoreMessages,
    required this.onFetchMoreMessages,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo is ScrollEndNotification) {
          Future.delayed(const Duration(milliseconds: 200), onMarkAllMessagesAsRead);
        }
        return false;
      },
      child: CustomScrollView(
        controller: scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: isIOS
            ? const BouncingScrollPhysics()
            : const ClampingScrollPhysics(),
        slivers: [
          _buildChatAppBar(context),
          CupertinoSliverRefreshControl(
            onRefresh: onRefresh,
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                return GestureDetector(
                  onLongPress: () {
                    if (!isSelectionMode) {
                      onLongPress(messages[index]);
                    } else {
                      onMessageTap(messages[index]);
                    }
                  },
                  onTap: () {
                    if (isSelectionMode) {
                      onMessageTap(messages[index]);
                    }
                  },
                  child: MessageBubble(
                    key: messageKeys[messages[index]['id'].toString()],
                    message: messages[index],
                    isMyMessage: messages[index]['senderId'].toString() == user.id.toString(),
                    onReply: onReply,
                    onLongPress: onLongPress,
                    repliedMessageContent: messages[index]['replyToMessageContent'],
                    isHighlighted: highlightedMessageId == messages[index]['id'].toString(),
                    isSelected: selectedMessageIds.contains(messages[index]['id'].toString()),
                  ),
                );
              },
              childCount: messages.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatAppBar(BuildContext context) {
    if (isSelectionMode) {
      return SliverAppBar(
        expandedHeight: 140,
        collapsedHeight: 100,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: Text(
          '${selectedMessageIds.length} رسالة محددة',
          style: GoogleFonts.almarai(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: showBulkDeleteDialog,
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: exitSelectionMode,
        ),
        floating: true,
        snap: true,
        pinned: true,
      );
    } else {
      return SliverAppBar(
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
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          ),
        ),
        title: Container(),
        flexibleSpace: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
          child: ChatAppBar(
            targetUser: targetUser,
            isOnline: isOnline,
            isTargetUserTyping: isTargetUserTyping,
          ),
        ),
      );
    }
  }
}