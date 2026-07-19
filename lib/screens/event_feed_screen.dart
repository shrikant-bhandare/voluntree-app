import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../services/posts_service.dart';

class EventFeedScreen extends StatefulWidget {
  const EventFeedScreen({super.key});

  @override
  State<EventFeedScreen> createState() => _EventFeedScreenState();
}

class _EventFeedScreenState extends State<EventFeedScreen> {
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final auth = Provider.of<AuthService>(context, listen: false);
      if (auth.token != null) {
        Provider.of<PostsService>(context, listen: false).fetchPosts(auth.token!);
        Provider.of<EventService>(context, listen: false).fetchEvents();
      }
      _isInit = false;
    }
  }

  Future<void> _refreshFeed() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.token != null) {
      await Provider.of<PostsService>(context, listen: false).fetchPosts(auth.token!);
    }
  }

  void _showCreatePostSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const CreatePostWidget(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final postsService = Provider.of<PostsService>(context);
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    final isOrganizer = user?.userType == 'ORGANIZER' || user?.userType == 'ADMIN';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Community Moments',
          style: GoogleFonts.plusJakartaSans(
            textStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isOrganizer)
            IconButton(
              icon: const Icon(Icons.add_box_outlined, color: Colors.white, size: 26),
              onPressed: () => _showCreatePostSheet(context),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshFeed,
        color: theme.colorScheme.primary,
        child: postsService.isLoading
            ? const Center(child: CircularProgressIndicator())
            : postsService.posts.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      const Center(
                        child: Column(
                          children: [
                            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No moments posted yet!',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Organizers can post event photos to share moments.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: postsService.posts.length,
                    itemBuilder: (ctx, index) {
                      final post = postsService.posts[index];
                      return PostCard(post: post);
                    },
                  ),
      ),
    );
  }
}

class PostCard extends StatefulWidget {
  final FeedPost post;
  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _showHeartOverlay = false;

  void _triggerDoubleTapLike() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final postsService = Provider.of<PostsService>(context, listen: false);
    if (auth.token == null) return;

    setState(() {
      _showHeartOverlay = true;
    });

    if (!widget.post.hasLiked) {
      await postsService.toggleLike(auth.token!, widget.post.id);
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showHeartOverlay = false;
        });
      }
    });
  }

  Future<void> _downloadPhoto(String url, String filename) async {
    try {
      final response = await http.get(Uri.parse(url));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo downloaded to: ${file.path}'),
            backgroundColor: const Color(0xFF0E6C4A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to download image.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _sharePhoto(String url) {
    Clipboard.setData(ClipboardData(text: 'Check out this amazing volunteer moment: $url'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Moment link copied to clipboard!'),
        backgroundColor: Color(0xFF0E6C4A),
      ),
    );
  }

  void _showCommentsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => CommentsSheetWidget(post: widget.post),
    );
  }

  void _deletePost() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final postsService = Provider.of<PostsService>(context, listen: false);
    if (auth.token == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this moment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await postsService.deletePost(auth.token!, widget.post.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully!'), backgroundColor: Color(0xFF0E6C4A)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthService>(context, listen: false);
    final currentUser = auth.currentUser;
    final isCreator = currentUser?.id == widget.post.organizerId || currentUser?.userType == 'ADMIN';
    final initials = widget.post.organizerName.isNotEmpty ? widget.post.organizerName[0].toUpperCase() : 'O';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE8EFF1),
              backgroundImage: widget.post.organizerAvatar != null && widget.post.organizerAvatar!.isNotEmpty
                  ? NetworkImage(widget.post.organizerAvatar!)
                  : null,
              child: widget.post.organizerAvatar == null || widget.post.organizerAvatar!.isEmpty
                  ? Text(initials, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary))
                  : null,
            ),
            title: Text(
              widget.post.organizerName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              widget.post.eventTitle,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
            ),
            trailing: isCreator
                ? IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    onPressed: _deletePost,
                  )
                : null,
          ),

          // Post image (Instagram ratio/style)
          GestureDetector(
            onDoubleTap: _triggerDoubleTapLike,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(
                      widget.post.imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (_showHeartOverlay)
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                    builder: (ctx, double value, child) {
                      return Transform.scale(
                        scale: value,
                        child: const Icon(
                          Icons.favorite,
                          size: 100,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    widget.post.hasLiked ? Icons.favorite : Icons.favorite_border,
                    color: widget.post.hasLiked ? Colors.red : Colors.black87,
                  ),
                  onPressed: () {
                    if (auth.token != null) {
                      Provider.of<PostsService>(context, listen: false).toggleLike(auth.token!, widget.post.id);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.mode_comment_outlined, color: Colors.black87),
                  onPressed: () => _showCommentsSheet(context),
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.black87),
                  onPressed: () => _sharePhoto(widget.post.imageUrl),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.download_for_offline_outlined, color: Colors.black87),
                  onPressed: () => _downloadPhoto(widget.post.imageUrl, 'moments_${widget.post.id}.jpg'),
                ),
                IconButton(
                  icon: Icon(
                    widget.post.hasSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: widget.post.hasSaved ? theme.colorScheme.primary : Colors.black87,
                  ),
                  onPressed: () {
                    if (auth.token != null) {
                      Provider.of<PostsService>(context, listen: false).toggleSave(auth.token!, widget.post.id);
                    }
                  },
                ),
              ],
            ),
          ),

          // Likes & Caption
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.post.likeCount} likes',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                if (widget.post.caption != null && widget.post.caption!.isNotEmpty) ...[
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black87, fontSize: 13),
                      children: [
                        TextSpan(
                          text: '${widget.post.organizerName} ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: widget.post.caption),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // Comments summary
                if (widget.post.comments.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => _showCommentsSheet(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        'View all ${widget.post.commentCount} comments',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ),
                  ...widget.post.comments.take(2).map((comment) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black87, fontSize: 12),
                            children: [
                              TextSpan(
                                text: '${comment.userName} ',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: comment.content),
                            ],
                          ),
                        ),
                      )),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommentsSheetWidget extends StatefulWidget {
  final FeedPost post;
  const CommentsSheetWidget({super.key, required this.post});

  @override
  State<CommentsSheetWidget> createState() => _CommentsSheetWidgetState();
}

class _CommentsSheetWidgetState extends State<CommentsSheetWidget> {
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final auth = Provider.of<AuthService>(context, listen: false);
    final postsService = Provider.of<PostsService>(context, listen: false);
    if (auth.token == null) return;

    setState(() {
      _isSubmitting = true;
    });

    final comment = await postsService.addComment(auth.token!, widget.post.id, text);
    
    if (mounted) {
      setState(() {
        _isSubmitting = false;
        if (comment != null) {
          _commentController.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final postsService = Provider.of<PostsService>(context);
    final postIndex = postsService.posts.indexWhere((p) => p.id == widget.post.id);
    final post = postIndex != -1 ? postsService.posts[postIndex] : widget.post;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Comments',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const Divider(height: 24),

            // Comments List
            Expanded(
              child: post.comments.isEmpty
                  ? const Center(
                      child: Text(
                        'No comments yet. Start the conversation!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: post.comments.length,
                      itemBuilder: (ctx, idx) {
                        final comment = post.comments[idx];
                        final cInitials = comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : 'U';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE8EFF1),
                            backgroundImage: comment.userAvatar != null && comment.userAvatar!.isNotEmpty
                                ? NetworkImage(comment.userAvatar!)
                                : null,
                            child: comment.userAvatar == null || comment.userAvatar!.isEmpty
                                ? Text(cInitials, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary))
                                : null,
                          ),
                          title: Text(
                            comment.userName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            comment.content,
                            style: const TextStyle(color: Colors.black87, fontSize: 13),
                          ),
                        );
                      },
                    ),
            ),

            // Text input field at bottom
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: 14),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: _submitComment,
                          child: Text(
                            'Post',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreatePostWidget extends StatefulWidget {
  const CreatePostWidget({super.key});

  @override
  State<CreatePostWidget> createState() => _CreatePostWidgetState();
}

class _CreatePostWidgetState extends State<CreatePostWidget> {
  final _captionController = TextEditingController();
  String? _selectedEventId;
  String? _uploadedImageUrl;
  bool _isUploading = false;
  bool _isPublishing = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    bool hasPermission = false;
    
    try {
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        if (status.isGranted) {
          hasPermission = true;
        } else if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
      } else {
        if (Platform.isIOS) {
          final status = await Permission.photos.request();
          if (status.isGranted || status.isLimited) {
            hasPermission = true;
          } else if (status.isPermanentlyDenied) {
            await openAppSettings();
          }
        } else if (Platform.isAndroid) {
          final status = await Permission.photos.request();
          if (status.isGranted) {
            hasPermission = true;
          } else {
            final storageStatus = await Permission.storage.request();
            if (storageStatus.isGranted) {
              hasPermission = true;
            } else if (storageStatus.isPermanentlyDenied) {
              await openAppSettings();
            }
          }
        } else {
          hasPermission = true;
        }
      }
    } catch (e) {
      hasPermission = true; // fallback
    }

    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, imageQuality: 85);
      if (image == null) return;

      setState(() {
        _isUploading = true;
      });

      final bytes = await image.readAsBytes();
      final auth = Provider.of<AuthService>(context, listen: false);
      final eventService = Provider.of<EventService>(context, listen: false);

      if (auth.token != null) {
        final url = await eventService.uploadEventImage(auth.token!, bytes, image.name);
        if (url != null) {
          setState(() {
            _uploadedImageUrl = url;
          });
        }
      }
    } catch (e) {
      debugPrint('[CREATE POST] Pick error: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _submitPost() async {
    if (_selectedEventId == null || _uploadedImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an event and upload a photo!'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthService>(context, listen: false);
    final postsService = Provider.of<PostsService>(context, listen: false);
    if (auth.token == null) return;

    setState(() {
      _isPublishing = true;
    });

    final result = await postsService.createPost(
      token: auth.token!,
      eventId: _selectedEventId!,
      imageUrl: _uploadedImageUrl!,
      caption: _captionController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isPublishing = false;
      });

      if (result['success']) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Moment shared successfully!'),
            backgroundColor: Color(0xFF0E6C4A),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to share moment'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthService>(context, listen: false);
    final eventService = Provider.of<EventService>(context, listen: false);
    
    final organizerId = auth.currentUser?.id;
    final organizerEvents = eventService.events
        .where((e) => e.organizerId == organizerId)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Share a Moment',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF012D1D)),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedEventId,
              hint: const Text('Select Associated Event'),
              items: organizerEvents.map((e) {
                return DropdownMenuItem(
                  value: e.id,
                  child: Text(e.title, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedEventId = val;
                });
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF4FAFD),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text('Choose from Gallery'),
                          onTap: () {
                            Navigator.pop(ctx);
                            _pickAndUploadPhoto(ImageSource.gallery);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.camera_alt),
                          title: const Text('Take a Photo'),
                          onTap: () {
                            Navigator.pop(ctx);
                            _pickAndUploadPhoto(ImageSource.camera);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  image: _uploadedImageUrl != null
                      ? DecorationImage(image: NetworkImage(_uploadedImageUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: _uploadedImageUrl != null
                    ? null
                    : _isUploading
                        ? const Center(child: CircularProgressIndicator())
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Tap to add photo', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _captionController,
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                filled: true,
                fillColor: const Color(0xFFF4FAFD),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isPublishing || _isUploading ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isPublishing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white), strokeWidth: 2),
                    )
                  : const Text('Share Moment', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
