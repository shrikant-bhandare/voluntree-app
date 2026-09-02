import 'dart:async';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/responsive.dart';

class DirectChatScreen extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;

  const DirectChatScreen({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  // Replying state
  ChatMessage? _replyingToMessage;

  // Typing detection state
  bool _isTyping = false;
  Timer? _typingTimer;
  ChatService? _chatService;
  String? _token;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initChat();
      // Track active chat recipient ID to prevent dual-notification banner triggering
      Provider.of<ChatService>(context, listen: false).activeChatUserId =
          widget.targetUserId;
      // The server refuses sends that break the contact rules (not applied
      // to their event, blocked, malformed). Show it instead of dropping it.
      Provider.of<ChatService>(context, listen: false).onSendError = (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      };
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cached here because dispose() must not look up inherited widgets.
    _chatService ??= Provider.of<ChatService>(context, listen: false);
  }

  void _initChat() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final chatService = Provider.of<ChatService>(context, listen: false);

    if (authService.token != null) {
      chatService.initSocket(authService.token!);
      chatService.fetchChatHistory(authService.token!, widget.targetUserId);
    }
  }

  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText && !_isTyping) {
      _isTyping = true;
      Provider.of<ChatService>(
        context,
        listen: false,
      ).sendTypingStatus(widget.targetUserId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        Provider.of<ChatService>(
          context,
          listen: false,
        ).sendTypingStatus(widget.targetUserId, false);
      }
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    // Synchronous, on the cached service: the old post-frame callback ran
    // after the State was unmounted, so the tracker was never cleared and
    // this partner's banners stayed suppressed (and their messages auto-read).
    if (_chatService?.activeChatUserId == widget.targetUserId) {
      _chatService?.activeChatUserId = null;
    }
    _chatService?.onSendError = null;
    super.dispose();
  }

  void _send({
    MessageType type = MessageType.TEXT,
    String? customContent,
    String? fileUrl,
  }) {
    final text = customContent ?? _messageController.text.trim();
    if (text.isEmpty && fileUrl == null) return;

    final chatService = Provider.of<ChatService>(context, listen: false);
    if (!chatService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Not connected to chat yet — please try again in a moment.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    chatService.sendMessage(
      widget.targetUserId,
      text,
      fileUrl: fileUrl,
      type: type,
      replyToId: _replyingToMessage?.id,
    );

    if (customContent == null) {
      _messageController.clear();
    }

    setState(() {
      _replyingToMessage = null;
    });

    if (_isTyping) {
      _isTyping = false;
      chatService.sendTypingStatus(widget.targetUserId, false);
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final chatService = Provider.of<ChatService>(context);
    final messages = chatService.messages;
    final isLoading = chatService.isLoadingHistory;
    final currentUserId = authService.currentUser?.id;

    _token = authService.token;
    // Only jump to the bottom when a message was added; rebuilding for a
    // typing indicator or presence change must not yank the user's scroll.
    if (messages.length != _lastMessageCount) {
      _lastMessageCount = messages.length;
      if (messages.isNotEmpty) _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.targetUserName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Container(
                  height: 6,
                  width: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        (chatService.userPresenceMap[widget.targetUserId] ??
                            false)
                        ? const Color(0xFF10B981)
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  (chatService.userPresenceMap[widget.targetUserId] ?? false)
                      ? 'Online'
                      : 'Offline',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
        elevation: 1,
      ),
      body: ResponsiveCenter(
        maxWidth: 900,
        child: Column(
          children: [
            // Message feed
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF0E6C4A),
                        ),
                      ),
                    )
                  : messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Start of chat transcript with ${widget.targetUserName}',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.senderId == currentUserId;

                        // Determine if we should show date header
                        bool showDateHeader = false;
                        if (index == 0) {
                          showDateHeader = true;
                        } else {
                          final prevMsg = messages[index - 1];
                          final prevDate = prevMsg.createdAt;
                          final currentDate = msg.createdAt;
                          if (prevDate.year != currentDate.year ||
                              prevDate.month != currentDate.month ||
                              prevDate.day != currentDate.day) {
                            showDateHeader = true;
                          }
                        }

                        final bubble = _buildChatBubble(msg, isMe);

                        if (showDateHeader) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [_buildDateHeader(msg.createdAt), bubble],
                          );
                        }

                        return bubble;
                      },
                    ),
            ),

            // Typing status indicator
            if (chatService.typingStatusMap.containsKey(
              widget.targetUserId,
            )) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      height: 10,
                      width: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFA0F4C8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getTypingText(
                        chatService.typingStatusMap[widget.targetUserId]!,
                      ),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Message input bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(
                  top: BorderSide(color: Color(0xFF334155), width: 1),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Replying Preview Indicator
                  if (_replyingToMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(
                          left: BorderSide(color: Color(0xFF0E6C4A), width: 3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Replying to ${_replyingToMessage!.senderName}',
                                  style: const TextStyle(
                                    color: Color(0xFFA0F4C8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _replyingToMessage!.content,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                              size: 16,
                            ),
                            onPressed: () {
                              setState(() {
                                _replyingToMessage = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Color(0xFFA0F4C8),
                          size: 24,
                        ),
                        onPressed: _showAttachmentSheet,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Type your message...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF64748B),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        backgroundColor: const Color(0xFF0E6C4A),
                        child: IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () => _send(),
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
    );
  }

  String _getTypingText(String action) {
    if (action == 'recording') {
      return '${widget.targetUserName} is recording audio...';
    } else if (action == 'uploading') {
      return '${widget.targetUserName} is uploading a file...';
    }
    return '${widget.targetUserName} is typing...';
  }

  Widget _buildChatBubble(ChatMessage msg, bool isMe) {
    final isStarred = msg.isStarredBy.contains(
      Provider.of<AuthService>(context, listen: false).currentUser?.id,
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showOptionsBottomSheet(msg),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: msg.isDeleted
                ? const Color(0xFF1E293B).withOpacity(0.5)
                : (isMe ? const Color(0xFF0E6C4A) : const Color(0xFF1E293B)),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 0),
              bottomRight: Radius.circular(isMe ? 0 : 16),
            ),
            border: Border.all(
              color: msg.isDeleted
                  ? Colors.grey.withOpacity(0.2)
                  : (isMe ? const Color(0xFF0E6C4A) : const Color(0xFF334155)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Replying preview headers
              if (msg.replyTo != null && !msg.isDeleted) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(6),
                    border: const Border(
                      left: BorderSide(color: Color(0xFFA0F4C8), width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.replyTo!.senderName,
                        style: const TextStyle(
                          color: Color(0xFFA0F4C8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        msg.replyTo!.isDeleted
                            ? 'This message was deleted'
                            : msg.replyTo!.content,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],

              if (!isMe && !msg.isDeleted) ...[
                Text(
                  msg.senderName,
                  style: const TextStyle(
                    color: Color(0xFFA0F4C8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
              ],

              if (msg.isDeleted) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.delete_outline, color: Colors.grey, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'This message was deleted',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                _buildMessageContent(msg),
              ],

              const SizedBox(height: 6),

              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isStarred) ...[
                    const Icon(Icons.star, color: Colors.amber, size: 10),
                    const SizedBox(width: 4),
                  ],
                  if (msg.isEdited && !msg.isDeleted) ...[
                    const Text(
                      'Edited  ',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 8,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  Text(
                    _formatTime(msg.createdAt),
                    style: const TextStyle(color: Colors.white54, fontSize: 8),
                  ),
                  if (isMe && !msg.isDeleted) ...[
                    const SizedBox(width: 6),
                    _buildMessageStatusTick(msg.status),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Attachments live in the private bucket behind a Bearer-guarded route.
  /// Browsers cannot attach headers to an <img>, so on web they still need a
  /// signed URL — a known gap.
  Map<String, String>? _authHeaders() =>
      kIsWeb || _token == null ? null : {'Authorization': 'Bearer $_token'};

  Widget _buildMessageContent(ChatMessage msg) {
    switch (msg.type) {
      case MessageType.IMAGE:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                msg.fileUrl ?? '',
                headers: _authHeaders(),
                height: 150,
                width: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.black26,
                  height: 150,
                  width: 200,
                  child: const Icon(Icons.broken_image, color: Colors.white54),
                ),
              ),
            ),
            if (msg.content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                msg.content,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ],
        );
      case MessageType.VIDEO:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 150,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: const [
                  Icon(
                    Icons.video_library_outlined,
                    color: Colors.white38,
                    size: 48,
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.white24,
                    radius: 24,
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
            if (msg.content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                msg.content,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ],
        );
      case MessageType.AUDIO:
      case MessageType.VOICE_NOTE:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              backgroundColor: Colors.black26,
              radius: 18,
              child: Icon(Icons.play_arrow, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    12,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      height: (i % 3 + 1) * 4.0,
                      width: 2,
                      color: Colors.white54,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  msg.type == MessageType.VOICE_NOTE
                      ? 'Voice note (0:12)'
                      : 'Audio track',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ],
        );
      case MessageType.PDF:
      case MessageType.DOCUMENT:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, color: Colors.white, size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '2.4 MB • PDF Document',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        );
      case MessageType.LOCATION:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://images.unsplash.com/photo-1524661135-423995f22d0b?q=80&w=250',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
              child: const Center(
                child: Icon(Icons.location_on, color: Colors.red, size: 32),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              msg.content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      case MessageType.CONTACT:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '+91 98765 43210',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        );
      case MessageType.GIF:
      case MessageType.STICKER:
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            msg.fileUrl ?? '',
            headers: _authHeaders(),
            height: 100,
            width: 100,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox(
              height: 100,
              width: 100,
              child: Icon(Icons.broken_image, color: Colors.white54),
            ),
          ),
        );
      default:
        return Text(
          msg.content,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        );
    }
  }

  Widget _buildMessageStatusTick(MessageStatus status) {
    switch (status) {
      case MessageStatus.SENDING:
        return const SizedBox(
          height: 8,
          width: 8,
          child: CircularProgressIndicator(
            strokeWidth: 1,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
          ),
        );
      case MessageStatus.SENT:
        return const Icon(Icons.check, color: Colors.white54, size: 10);
      case MessageStatus.DELIVERED:
        return const Icon(Icons.done_all, color: Colors.white54, size: 10);
      case MessageStatus.READ:
        return const Icon(Icons.done_all, color: Color(0xFF3B82F6), size: 10);
      case MessageStatus.FAILED:
        return const Icon(Icons.error_outline, color: Colors.red, size: 10);
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    String label;
    if (msgDate == today) {
      label = 'Today';
    } else if (msgDate == yesterday) {
      label = 'Yesterday';
    } else {
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      label = '${date.day} ${months[date.month - 1]} ${date.year}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    // Browsers gate gallery/file access through their own picker UI;
    // permission_handler only applies to the mobile platforms.
    if (!kIsWeb) {
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        _showPermissionDeniedDialog('Gallery');
        return;
      }
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _uploadAndSendAttachment(
        bytes: await pickedFile.readAsBytes(),
        type: MessageType.IMAGE,
        fileName: pickedFile.name,
      );
    }
  }

  Future<void> _pickVideo() async {
    if (!kIsWeb) {
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        _showPermissionDeniedDialog('Gallery');
        return;
      }
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      _uploadAndSendAttachment(
        bytes: await pickedFile.readAsBytes(),
        type: MessageType.VIDEO,
        fileName: pickedFile.name,
      );
    }
  }

  Future<void> _pickDocument() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
    );
    if (file == null) return;
    // readAsBytes resolves from bytes or path, including on web.
    final bytes = await file.readAsBytes();
    _uploadAndSendAttachment(
      bytes: bytes,
      type: MessageType.PDF,
      fileName: file.name,
    );
  }

  Future<void> _shareLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showPermissionDeniedDialog('Location');
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    _send(
      type: MessageType.LOCATION,
      customContent:
          'Live Location: Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}',
    );
  }

  Future<void> _recordVoiceNote() async {
    if (!kIsWeb) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _showPermissionDeniedDialog('Microphone');
        return;
      }
    }

    final record = AudioRecorder();
    final fileName = 'voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
    // The record plugin ignores the output path on web (stop() returns a
    // blob URL), so the temp directory is only resolved on mobile/desktop.
    final path = kIsWeb
        ? fileName
        : '${(await getTemporaryDirectory()).path}/$fileName';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _VoiceRecordingDialog(
          recorder: record,
          outputPath: path,
          onFinish: (recordedPath) async {
            _uploadAndSendAttachment(
              bytes: await XFile(recordedPath).readAsBytes(),
              type: MessageType.VOICE_NOTE,
              fileName: fileName,
              displayName: 'Voice note',
            );
          },
        );
      },
    );
  }

  Future<void> _shareContact() async {
    if (!kIsWeb) {
      final status = await Permission.contacts.request();
      if (!status.isGranted) {
        _showPermissionDeniedDialog('Contacts');
        return;
      }
    }

    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Share Contact',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Contact Name',
                  hintStyle: TextStyle(color: Color(0xFF64748B)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Phone Number',
                  hintStyle: TextStyle(color: Color(0xFF64748B)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E6C4A),
              ),
              onPressed: () {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                if (name.isNotEmpty && phone.isNotEmpty) {
                  Navigator.pop(context);
                  _send(
                    type: MessageType.CONTACT,
                    customContent: '$name: $phone',
                  );
                }
              },
              child: const Text('Share', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _uploadAndSendAttachment({
    required Uint8List bytes,
    required MessageType type,
    required String fileName,
    String? displayName,
  }) async {
    final chatService = Provider.of<ChatService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    chatService.sendTypingStatus(
      widget.targetUserId,
      true,
      action: 'uploading',
    );
    final uploadUrl = await chatService.uploadAttachment(
      authService.token!,
      bytes: bytes,
      filename: fileName,
    );
    chatService.sendTypingStatus(widget.targetUserId, false);

    if (uploadUrl != null) {
      _send(
        type: type,
        customContent: displayName ?? fileName,
        fileUrl: uploadUrl,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload file attachment.')),
      );
    }
  }

  void _showPermissionDeniedDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            '$feature Permission Required',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Text(
            'This application needs $feature access to share attachments.',
            style: const TextStyle(color: Color(0xFF94A3B8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Dismiss',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E6C4A),
              ),
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text(
                'Open Settings',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  Icons.image,
                  'Photo Gallery',
                  Colors.purple,
                  () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                _buildAttachmentOption(Icons.videocam, 'Video', Colors.red, () {
                  Navigator.pop(context);
                  _pickVideo();
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            radius: 24,
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  void _showOptionsBottomSheet(ChatMessage msg) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isMe = msg.senderId == authService.currentUser?.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply, color: Colors.white70),
                title: const Text(
                  'Reply',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _replyingToMessage = msg;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.white70),
                title: const Text(
                  'Copy Text',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: msg.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copied to clipboard'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.star_border, color: Colors.white70),
                title: const Text(
                  'Toggle Star',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final chatService = Provider.of<ChatService>(
                    context,
                    listen: false,
                  );
                  await chatService.toggleStarMessage(
                    authService.token!,
                    msg.id,
                  );
                },
              ),
              if (isMe && !msg.isDeleted) ...[
                ListTile(
                  leading: const Icon(Icons.edit_note, color: Colors.white70),
                  title: const Text(
                    'Edit Message',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(msg);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Delete Message',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final chatService = Provider.of<ChatService>(
                      context,
                      listen: false,
                    );
                    await chatService.deleteMessage(authService.token!, msg.id);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(ChatMessage msg) {
    final editController = TextEditingController(text: msg.content);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Edit Message',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: TextField(
            controller: editController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter updated message...',
              hintStyle: TextStyle(color: Color(0xFF64748B)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white30),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E6C4A),
              ),
              onPressed: () async {
                final text = editController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(context);
                  final authService = Provider.of<AuthService>(
                    context,
                    listen: false,
                  );
                  final chatService = Provider.of<ChatService>(
                    context,
                    listen: false,
                  );
                  await chatService.editMessage(
                    authService.token!,
                    msg.id,
                    text,
                  );
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

class _VoiceRecordingDialog extends StatefulWidget {
  final AudioRecorder recorder;
  final String outputPath;
  final Function(String) onFinish;

  const _VoiceRecordingDialog({
    required this.recorder,
    required this.outputPath,
    required this.onFinish,
  });

  @override
  State<_VoiceRecordingDialog> createState() => _VoiceRecordingDialogState();
}

class _VoiceRecordingDialogState extends State<_VoiceRecordingDialog> {
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  void _startRecording() async {
    try {
      if (await widget.recorder.hasPermission()) {
        await widget.recorder.start(
          const RecordConfig(),
          path: widget.outputPath,
        );
        if (!mounted) return;
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) return;
          setState(() {
            _seconds++;
          });
        });
      } else {
        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('[RECORDER] Start failure: $e');
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  void _stopRecording({bool cancel = false}) async {
    _timer?.cancel();
    final path = await widget.recorder.stop();
    await widget.recorder.dispose();
    if (!mounted) return;
    Navigator.pop(context);

    if (!cancel && path != null && _seconds > 0) {
      widget.onFinish(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final minuteStr = (_seconds ~/ 60).toString().padLeft(2, '0');
    final secondStr = (_seconds % 60).toString().padLeft(2, '0');

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Recording Audio Note',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$minuteStr:$secondStr',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => _stopRecording(cancel: true),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBA1A1A),
                  ),
                  onPressed: () => _stopRecording(cancel: false),
                  child: const Text(
                    'Stop & Send',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
