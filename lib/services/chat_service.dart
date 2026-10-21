// ignore_for_file: constant_identifier_names
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config.dart';
import '../utils/encryption_helper.dart';
import 'api_helpers.dart';

enum MessageType {
  TEXT,
  EMOJI,
  IMAGE,
  VIDEO,
  AUDIO,
  VOICE_NOTE,
  PDF,
  DOCUMENT,
  CONTACT,
  LOCATION,
  GIF,
  STICKER,
}

enum MessageStatus { SENDING, SENT, DELIVERED, READ, FAILED }

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final String? fileUrl;
  final MessageType type;
  final MessageStatus status;
  final String? replyToId;
  final ChatMessage? replyTo;
  final List<String> isStarredBy;
  final bool isPinned;
  final bool isEdited;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? editedAt;
  final String senderName;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.fileUrl,
    required this.type,
    required this.status,
    this.replyToId,
    this.replyTo,
    required this.isStarredBy,
    required this.isPinned,
    required this.isEdited,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
    this.deliveredAt,
    this.readAt,
    this.editedAt,
    required this.senderName,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] ?? {};

    // Parse MessageType
    final typeStr = json['type'] ?? 'TEXT';
    final type = MessageType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => MessageType.TEXT,
    );

    // Parse MessageStatus
    var statusStr = json['status'];
    if (statusStr == null) {
      final read = json['read'] ?? false;
      statusStr = read ? 'READ' : 'SENT';
    }
    final status = MessageStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => MessageStatus.SENT,
    );

    // Parse list of starred users
    final starredJson = json['isStarredBy'];
    final List<String> isStarredBy = starredJson != null
        ? List<String>.from(starredJson)
        : [];

    // E2EE Decryption logic
    var rawContent = json['content'] ?? '';
    String? fileUrl = json['fileUrl'];

    if (AppConfig.enableE2EE &&
        rawContent.startsWith('{') &&
        rawContent.endsWith('}')) {
      try {
        final parsed = jsonDecode(rawContent);
        if (parsed.containsKey('ct') && parsed.containsKey('ek')) {
          final ct = parsed['ct'];
          final ek = parsed['ek'];
          final fileCt = parsed['fileCt'];

          final privKey = EncryptionHelper.localPrivateKey;
          if (privKey != null) {
            rawContent = EncryptionHelper.decryptMessage(
              ciphertext: ct,
              encryptedKey: ek,
              privateKeyJson: privKey,
            );
            if (fileCt != null) {
              fileUrl = EncryptionHelper.decryptMessage(
                ciphertext: fileCt,
                encryptedKey: ek,
                privateKeyJson: privKey,
              );
            }
          } else {
            rawContent = '[Encrypted Message]';
          }
        }
      } catch (e) {
        debugPrint('[CHAT MESSAGE] E2EE Decrypter parse failure: $e');
      }
    }

    return ChatMessage(
      id: json['id'] ?? '',
      senderId: json['senderId'] ?? '',
      receiverId: json['receiverId'] ?? '',
      content: rawContent,
      fileUrl: AppConfig.formatMediaUrl(fileUrl),
      type: type,
      status: status,
      replyToId: json['replyToId'],
      replyTo: json['replyTo'] != null
          ? ChatMessage.fromJson(json['replyTo'])
          : null,
      isStarredBy: isStarredBy,
      isPinned: json['isPinned'] ?? false,
      isEdited: json['isEdited'] ?? false,
      isDeleted: json['isDeleted'] ?? false,
      createdAt: parseServerDate(json['createdAt']),
      updatedAt: parseServerDate(json['updatedAt']),
      deliveredAt: parseServerDateOrNull(json['deliveredAt']),
      readAt: parseServerDateOrNull(json['readAt']),
      editedAt: parseServerDateOrNull(json['editedAt']),
      senderName: sender['fullName'] ?? 'User',
    );
  }
}

class ChatService extends ChangeNotifier {
  static String get baseUrl => AppConfig.baseUrl;

  io.Socket? _socket;
  String? _token;
  List<ChatMessage> _messages = [];
  List<dynamic> _conversations = [];
  bool _isLoadingHistory = false;
  bool _isConnected = false;
  bool _isConnecting = false;

  // Recipient public keys cache
  final Map<String, String> _publicKeysCache = {};

  // User presence cache
  final Map<String, bool> _userPresenceMap = {};
  Map<String, bool> get userPresenceMap => _userPresenceMap;

  ChatService() {
    if (AppConfig.enableE2EE) {
      EncryptionHelper.loadKeys();
    }
  }

  Future<String?> getRecipientPublicKey(String token, String userId) async {
    if (_publicKeysCache.containsKey(userId)) {
      return _publicKeysCache[userId];
    }
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/public-key/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pubKey = data['publicKey'];
        if (pubKey != null) {
          _publicKeysCache[userId] = pubKey;
          return pubKey;
        }
      }
    } catch (e) {
      debugPrint('[CHAT SERVICE] Get Public Key Error: $e');
    }
    return null;
  }

  // Track active chat recipient to avoid showing double-notifications inside the active chat screen
  String? activeChatUserId;

  /// Server-side rejection of a send (relationship rule, block, validation).
  /// Without a listener the composer cleared and nothing happened.
  void Function(String message)? onSendError;

  /// Real-time notifications ride on this socket; there is no second one.
  void Function(Map<String, dynamic> data)? onNotificationReceived;
  // Callback hook for when a new chat message is received in the background/foreground
  void Function(ChatMessage)? onMessageReceived;

  // Track typing status of conversation partners
  // Map of userId -> typing actions details ('typing', 'recording', 'uploading')
  final Map<String, String> _typingStatusMap = {};
  Map<String, String> get typingStatusMap => _typingStatusMap;

  List<ChatMessage> get messages => _messages;
  List<dynamic> get conversations => _conversations;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isConnected => _isConnected;

  // Initialize socket connection
  void initSocket(String token) async {
    if (_token == token && (_isConnected || _isConnecting) && _socket != null) {
      debugPrint(
        '[CHAT SERVICE] Socket already connecting/connected. Skipping initialization.',
      );
      return;
    }
    _token = token;
    _isConnecting = true;
    notifyListeners();

    try {
      // E2EE Key Generation and Registration (Only if E2EE is enabled)
      if (AppConfig.enableE2EE) {
        try {
          final keys = await EncryptionHelper.generateAndSaveKeys();
          final pubKey = keys['publicKey']!;

          // Register public key on the backend
          await http.post(
            Uri.parse('$baseUrl/auth/public-key'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'publicKey': pubKey}),
          );
          debugPrint(
            '[CHAT SERVICE] E2EE Public key successfully registered on backend.',
          );
        } catch (e) {
          debugPrint('[CHAT SERVICE] E2EE Key registration failed: $e');
        }
      }

      if (_socket != null) {
        // dispose(), not just disconnect(): the old socket keeps its listeners
        // otherwise, and every reconnect would double-handle each message.
        _socket!.dispose();
        _socket = null;
      }

      _socket = io.io(
        baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket']) // Use WebSocket transport exclusively
            .setQuery({'token': token}) // Pass JWT in query params
            .enableForceNew()
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        _isConnecting = false;
        debugPrint('[CHAT SERVICE] WebSockets connected successfully.');
        if (activeChatUserId != null) {
          sendReadConfirmation(activeChatUserId!);
        }
        notifyListeners();
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        _isConnecting = false;
        debugPrint('[CHAT SERVICE] WebSockets disconnected.');
        notifyListeners();
      });

      _socket!.onConnectError((err) {
        _isConnecting = false;
        debugPrint('[CHAT SERVICE] WebSockets connection error: $err');
        notifyListeners();
      });
    } catch (e) {
      _isConnecting = false;
      debugPrint('[CHAT SERVICE] Socket creation error: $e');
      notifyListeners();
    }

    // Socket construction failed above — registering listeners on it would
    // null-assert and crash.
    if (_socket == null) return;

    // Listen for incoming real-time messages
    _socket!.on('receiveMessage', (data) {
      debugPrint('[CHAT SERVICE] Received message in real-time: $data');
      if (data is! Map<String, dynamic>) return;
      final message = ChatMessage.fromJson(data);
      // _messages holds the currently open thread only; a message from a
      // different partner must not be spliced into this conversation.
      final belongsToOpenThread =
          activeChatUserId != null &&
          (message.senderId == activeChatUserId ||
              message.receiverId == activeChatUserId);
      if (belongsToOpenThread) {
        _messages.add(message);
      }
      if (_token != null) {
        fetchConversations(_token!);
      }
      notifyListeners();

      // Send delivery receipt immediately back
      sendDeliveryConfirmation(message.senderId, message.id);

      // If we are actively chatting with the sender, send read receipt immediately
      if (activeChatUserId == message.senderId) {
        sendReadConfirmation(message.senderId, messageId: message.id);
      }

      // Trigger callback if registered
      if (onMessageReceived != null) {
        onMessageReceived!(message);
      }
    });

    _socket!.on('exception', (data) {
      String message = 'Message could not be sent.';
      if (data is Map && data['message'] is String) {
        message = data['message'] as String;
      }
      debugPrint('[CHAT SERVICE] Server rejected an event: $message');
      onSendError?.call(message);
    });

    _socket!.on('receiveNotification', (data) {
      if (data is! Map) return;
      onNotificationReceived?.call(Map<String, dynamic>.from(data));
    });

    // Listen for presence updates
    _socket!.on('presence', (data) {
      debugPrint('[CHAT SERVICE] Received presence update: $data');
      final userId = data['userId'];
      final isOnline = data['isOnline'] as bool?;
      if (userId != null && isOnline != null) {
        _userPresenceMap[userId] = isOnline;
        notifyListeners();
      }
    });

    // Listen for sender confirmation check
    _socket!.on('messageSent', (data) {
      debugPrint('[CHAT SERVICE] Message dispatch confirmed by server.');
      final message = ChatMessage.fromJson(data);
      if (!_messages.any((m) => m.id == message.id)) {
        _messages.add(message);
        if (_token != null) {
          fetchConversations(_token!);
        }
        notifyListeners();
      }
    });

    // Listen for typing notifications
    _socket!.on('typing', (data) {
      debugPrint('[CHAT SERVICE] Typing update received: $data');
      final senderId = data['senderId'];
      final isTyping = data['isTyping'] ?? false;
      final action = data['action'] ?? 'typing';

      if (isTyping) {
        _typingStatusMap[senderId] = action;
      } else {
        _typingStatusMap.remove(senderId);
      }
      notifyListeners();
    });

    // Listen for read confirmation ticks
    _socket!.on('messageRead', (data) {
      debugPrint('[CHAT SERVICE] Message read receipt received: $data');
      final receiverId = data['receiverId'];
      final messageId = data['messageId'];

      if (messageId != null) {
        for (var i = 0; i < _messages.length; i++) {
          if (_messages[i].id == messageId) {
            _messages[i] = _updateMessageStatus(
              _messages[i],
              MessageStatus.READ,
            );
            break;
          }
        }
      } else {
        for (var i = 0; i < _messages.length; i++) {
          if (_messages[i].senderId != receiverId &&
              _messages[i].status != MessageStatus.READ) {
            _messages[i] = _updateMessageStatus(
              _messages[i],
              MessageStatus.READ,
            );
          }
        }
      }
      notifyListeners();
    });

    // Listen for delivery confirmation ticks
    _socket!.on('messageDelivered', (data) {
      debugPrint('[CHAT SERVICE] Message delivered receipt received: $data');
      final messageId = data['messageId'];
      for (var i = 0; i < _messages.length; i++) {
        if (_messages[i].id == messageId &&
            _messages[i].status == MessageStatus.SENT) {
          _messages[i] = _updateMessageStatus(
            _messages[i],
            MessageStatus.DELIVERED,
          );
          break;
        }
      }
      notifyListeners();
    });

    _socket!.connect();
  }

  ChatMessage _updateMessageStatus(ChatMessage msg, MessageStatus status) {
    return ChatMessage(
      id: msg.id,
      senderId: msg.senderId,
      receiverId: msg.receiverId,
      content: msg.content,
      fileUrl: msg.fileUrl,
      type: msg.type,
      status: status,
      replyToId: msg.replyToId,
      replyTo: msg.replyTo,
      isStarredBy: msg.isStarredBy,
      isPinned: msg.isPinned,
      isEdited: msg.isEdited,
      isDeleted: msg.isDeleted,
      createdAt: msg.createdAt,
      updatedAt: msg.updatedAt,
      deliveredAt: status == MessageStatus.DELIVERED
          ? DateTime.now()
          : msg.deliveredAt,
      readAt: status == MessageStatus.READ ? DateTime.now() : msg.readAt,
      editedAt: msg.editedAt,
      senderName: msg.senderName,
    );
  }

  // Disconnect socket connection
  void disconnectSocket() {
    if (_socket != null) {
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      _isConnecting = false;
      // Without this the UI keeps showing "connected" after logout.
      notifyListeners();
    }
  }

  // Send typing indicator status
  void sendTypingStatus(
    String receiverId,
    bool isTyping, {
    String action = 'typing',
  }) {
    if (_socket == null || !_isConnected) return;
    _socket!.emit('typing', {
      'receiverId': receiverId,
      'isTyping': isTyping,
      'action': action,
    });
  }

  // Send read ticks
  void sendReadConfirmation(String senderId, {String? messageId}) {
    if (_socket == null || !_isConnected) return;
    _socket!.emit('messageRead', {
      'senderId': senderId,
      'messageId': messageId,
    });
  }

  // Send delivery ticks
  void sendDeliveryConfirmation(String senderId, String messageId) {
    if (_socket == null || !_isConnected) return;
    _socket!.emit('messageDelivered', {
      'senderId': senderId,
      'messageId': messageId,
    });
  }

  /// Forget the previous account's threads and presence.
  void clear() {
    _messages = [];
    _conversations = [];
    _typingStatusMap.clear();
    _userPresenceMap.clear();
    _publicKeysCache.clear();
    activeChatUserId = null;
    notifyListeners();
  }

  Future<void> fetchConversations(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/messages/conversations'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _conversations = jsonDecode(response.body);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[CHAT SERVICE] Fetch Conversations Error: $e');
    }
  }

  // Load chat history between current user and target user
  Future<void> fetchChatHistory(String token, String receiverId) async {
    _isLoadingHistory = true;
    _messages = [];
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/messages/history/$receiverId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = unwrapList(jsonDecode(response.body));
        _messages = data.map((json) => ChatMessage.fromJson(json)).toList()
          // The API pages backwards in time (newest first); the thread
          // renders top-down, oldest first.
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        // Mark all loaded history messages as read
        sendReadConfirmation(receiverId);
      } else {
        _messages = [];
      }
    } catch (e) {
      debugPrint('FetchChatHistory Connection Error: $e');
      _messages = [];
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  // Send message through WebSocket
  /// Returns false when nothing was emitted (no socket / not connected).
  /// A message the server refuses arrives via [onSendError].
  Future<bool> sendMessage(
    String receiverId,
    String content, {
    String? fileUrl,
    MessageType type = MessageType.TEXT,
    String? replyToId,
  }) async {
    if (_socket == null || !_isConnected) {
      debugPrint(
        '[CHAT SERVICE] Error: Cannot send message, Socket not connected.',
      );
      return false;
    }

    if (_token == null) return false;

    if (!AppConfig.enableE2EE) {
      _socket!.emit('sendMessage', {
        'receiverId': receiverId,
        'content': content,
        'fileUrl': fileUrl,
        'type': type.name,
        'replyToId': replyToId,
      });
      return true;
    }

    // 1. Get recipient public key
    final recipientPubKey = await getRecipientPublicKey(_token!, receiverId);
    if (recipientPubKey == null) {
      debugPrint(
        '[CHAT SERVICE] Warning: Recipient public key not registered. Sending plaintext fallback.',
      );
      _socket!.emit('sendMessage', {
        'receiverId': receiverId,
        'content': content,
        'fileUrl': fileUrl,
        'type': type.name,
        'replyToId': replyToId,
      });
      return true;
    }

    // 2. Encrypt message content and optional fileUrl using recipient's public key
    final encrypted = EncryptionHelper.encryptMessage(
      plaintext: content,
      recipientPublicKeyJson: recipientPubKey,
      fileUrl: fileUrl,
    );

    if (encrypted == null) {
      debugPrint('[CHAT SERVICE] Error: Encryption failed.');
      return false;
    }

    // 3. Package E2EE block as JSON inside the content payload string
    final packedContent = jsonEncode({
      'ct': encrypted['ciphertext'],
      'ek': encrypted['encryptedKey'],
      if (encrypted.containsKey('fileCt')) 'fileCt': encrypted['fileCt'],
    });

    _socket!.emit('sendMessage', {
      'receiverId': receiverId,
      'content': packedContent,
      'fileUrl':
          null, // set raw fileUrl to null so backend stores the packed version inside content
      'type': type.name,
      'replyToId': replyToId,
    });
    return true;
  }

  Future<bool> editMessage(
    String token,
    String messageId,
    String content,
  ) async {
    try {
      final idx = _messages.indexWhere((m) => m.id == messageId);
      if (idx == -1) return false;

      final msg = _messages[idx];
      final recipientId = msg.receiverId;

      var encryptedContent = content;

      if (AppConfig.enableE2EE) {
        final recipientPubKey = await getRecipientPublicKey(token, recipientId);
        if (recipientPubKey != null) {
          final encrypted = EncryptionHelper.encryptMessage(
            plaintext: content,
            recipientPublicKeyJson: recipientPubKey,
          );
          if (encrypted != null) {
            encryptedContent = jsonEncode({
              'ct': encrypted['ciphertext'],
              'ek': encrypted['encryptedKey'],
            });
          }
        }
      }

      final response = await http.put(
        Uri.parse('$baseUrl/messages/$messageId/edit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'content': encryptedContent}),
      );
      if (response.statusCode == 200) {
        final updatedMsg = ChatMessage.fromJson(jsonDecode(response.body));
        _messages[idx] = updatedMsg;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[CHAT SERVICE] Edit Message Error: $e');
    }
    return false;
  }

  Future<bool> deleteMessage(String token, String messageId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/messages/$messageId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final updatedMsg = ChatMessage.fromJson(jsonDecode(response.body));
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          _messages[idx] = updatedMsg;
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint('[CHAT SERVICE] Delete Message Error: $e');
    }
    return false;
  }

  /// IDs of people the signed-in user has blocked (`GET /messages/blocked`).
  Future<Set<String>> fetchBlockedUserIds(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/messages/blocked'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return unwrapList(jsonDecode(response.body))
            .whereType<Map>()
            .map(
              (row) => (row['blockedId'] ?? row['blocked']?['id'])?.toString(),
            )
            .whereType<String>()
            .toSet();
      }
    } catch (e) {
      debugPrint('[CHAT SERVICE] fetchBlockedUserIds error: $e');
    }
    return {};
  }

  /// Blocks [userId] in both directions. Returns null on success, otherwise
  /// the message to show.
  Future<String?> blockUser(String token, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/messages/block/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return null;
      }
      return apiMessage(
        tryDecodeJson(response.body),
        'Could not block this person. Please try again.',
      );
    } catch (e) {
      return friendlyNetworkError(e);
    }
  }

  /// Removes a block. Returns null on success, otherwise the message to show.
  Future<String?> unblockUser(String token, String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/messages/block/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return null;
      }
      return apiMessage(
        tryDecodeJson(response.body),
        'Could not unblock this person. Please try again.',
      );
    } catch (e) {
      return friendlyNetworkError(e);
    }
  }

  Future<bool> toggleStarMessage(String token, String messageId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/messages/$messageId/star'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final updatedMsg = ChatMessage.fromJson(jsonDecode(response.body));
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          _messages[idx] = updatedMsg;
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint('[CHAT SERVICE] Star Message Error: $e');
    }
    return false;
  }

  /// Takes bytes rather than a file path so the same code works on web,
  /// where picked files only exist as in-memory blobs.
  Future<String?> uploadAttachment(
    String token, {
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/messages/upload'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['url'];
      } else {
        debugPrint(
          '[CHAT SERVICE] Upload Attachment Failed with Status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[CHAT SERVICE] Upload Attachment Error: $e');
    }
    return null;
  }
}
