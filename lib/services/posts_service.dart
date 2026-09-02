import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'api_helpers.dart';

class FeedPost {
  final String id;
  final String eventId;
  final String organizerId;
  final String imageUrl;
  final String? caption;
  final DateTime createdAt;
  final String eventTitle;
  final String organizerName;
  final String? organizerAvatar;
  int likeCount;
  int commentCount;
  bool hasLiked;
  bool hasSaved;
  final List<PostComment> comments;

  FeedPost({
    required this.id,
    required this.eventId,
    required this.organizerId,
    required this.imageUrl,
    this.caption,
    required this.createdAt,
    required this.eventTitle,
    required this.organizerName,
    this.organizerAvatar,
    required this.likeCount,
    required this.commentCount,
    required this.hasLiked,
    required this.hasSaved,
    required this.comments,
  });

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    final event = json['event'] ?? {};
    final organizer = json['organizer'] ?? {};
    final profile = organizer['profile'] ?? {};
    final commentsList = (json['comments'] as List? ?? [])
        .map((c) => PostComment.fromJson(c))
        .toList();

    return FeedPost(
      id: json['id'] ?? '',
      eventId: json['eventId'] ?? '',
      organizerId: json['organizerId'] ?? '',
      imageUrl: AppConfig.formatMediaUrl(json['imageUrl']) ?? '',
      caption: json['caption'],
      createdAt: parseServerDate(json['createdAt']),
      eventTitle: event['title'] ?? 'Community Event',
      organizerName: organizer['fullName'] ?? 'Organizer',
      organizerAvatar: AppConfig.formatMediaUrl(profile['avatarUrl']),
      likeCount: json['likeCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      hasLiked: json['hasLiked'] ?? false,
      hasSaved: json['hasSaved'] ?? false,
      comments: commentsList,
    );
  }
}

class PostComment {
  final String id;
  final String content;
  final DateTime createdAt;
  final String userName;
  final String? userAvatar;

  PostComment({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.userName,
    this.userAvatar,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    final user = json['user'] ?? {};
    final profile = user['profile'] ?? {};
    return PostComment(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      createdAt: parseServerDate(json['createdAt']),
      userName: user['fullName'] ?? 'Volunteer',
      userAvatar: AppConfig.formatMediaUrl(profile['avatarUrl']),
    );
  }
}

class PostsService extends ChangeNotifier {
  static String get baseUrl => AppConfig.baseUrl;

  List<FeedPost> _posts = [];
  bool _isLoading = false;

  List<FeedPost> get posts => _posts;
  bool get isLoading => _isLoading;

  void clear() {
    _posts = [];
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchPosts(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/posts'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = unwrapList(jsonDecode(response.body));
        _posts = data.map((json) => FeedPost.fromJson(json)).toList();
      } else {
        _posts = [];
      }
    } catch (e) {
      debugPrint('[POSTS SERVICE] Fetch error: $e');
      _posts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createPost({
    required String token,
    required String eventId,
    required String imageUrl,
    String? caption,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'eventId': eventId,
          'imageUrl': imageUrl,
          if (caption != null && caption.isNotEmpty) 'caption': caption,
        }),
      );

      if (response.statusCode == 201) {
        await fetchPosts(token);
        return {'success': true};
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': apiMessage(data, 'Failed to create post'),
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network failure: $e'};
    }
  }

  Future<bool> toggleLike(String token, String postId) async {
    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      final post = _posts[postIndex];
      post.hasLiked = !post.hasLiked;
      post.likeCount += post.hasLiked ? 1 : -1;
      notifyListeners();
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/like'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (postIndex != -1) {
          _posts[postIndex].hasLiked = data['liked'] as bool;
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint('[POSTS SERVICE] Like connection error: $e');
    }

    if (postIndex != -1) {
      final post = _posts[postIndex];
      post.hasLiked = !post.hasLiked;
      post.likeCount += post.hasLiked ? 1 : -1;
      notifyListeners();
    }
    return false;
  }

  Future<bool> toggleSave(String token, String postId) async {
    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      final post = _posts[postIndex];
      post.hasSaved = !post.hasSaved;
      notifyListeners();
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/save'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (postIndex != -1) {
          _posts[postIndex].hasSaved = data['saved'] as bool;
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint('[POSTS SERVICE] Save connection error: $e');
    }

    if (postIndex != -1) {
      final post = _posts[postIndex];
      post.hasSaved = !post.hasSaved;
      notifyListeners();
    }
    return false;
  }

  Future<PostComment?> addComment(
    String token,
    String postId,
    String content,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/comments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'content': content}),
      );

      if (response.statusCode == 201) {
        final newComment = PostComment.fromJson(jsonDecode(response.body));

        final postIndex = _posts.indexWhere((p) => p.id == postId);
        if (postIndex != -1) {
          _posts[postIndex].comments.add(newComment);
          _posts[postIndex].commentCount = _posts[postIndex].comments.length;
          notifyListeners();
        }
        return newComment;
      }
    } catch (e) {
      debugPrint('[POSTS SERVICE] Comment error: $e');
    }
    return null;
  }

  Future<bool> deletePost(String token, String postId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _posts.removeWhere((p) => p.id == postId);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[POSTS SERVICE] Delete post error: $e');
    }
    return false;
  }
}
