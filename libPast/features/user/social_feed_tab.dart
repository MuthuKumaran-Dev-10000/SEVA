import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/models/post_model.dart';
import '../../core/models/comment_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/app_provider.dart';
import '../../core/services/auth_provider.dart';

class SocialFeedTab extends StatefulWidget {
  const SocialFeedTab({super.key});

  @override
  State<SocialFeedTab> createState() => _SocialFeedTabState();
}

class _SocialFeedTabState extends State<SocialFeedTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppProvider>(context, listen: false).listenAllGlobalData();
    });
  }

  void _showCreatePostDialog(BuildContext context, AppProvider app, AuthProvider auth) {
    final captionController = TextEditingController();
    final imageController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Create Social Post', style: TextStyle(color: DivineTheme.maroon, fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: captionController,
                    decoration: const InputDecoration(
                      labelText: 'Write a caption...',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: imageController,
                    decoration: const InputDecoration(
                      labelText: 'Spiritual Image URL',
                      hintText: 'https://images.unsplash.com/...',
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: DivineTheme.textLight)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newPost = PostModel(
                  id: '',
                  authorId: auth.currentUser!.uid,
                  authorName: auth.currentUser!.name,
                  authorImage: auth.currentUser!.profilePic,
                  imageUrl: imageController.text.trim(),
                  videoUrl: '',
                  caption: captionController.text.trim(),
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                );
                await app.addSocialPost(newPost);
                if (context.mounted) Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DivineTheme.maroon,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Post', style: TextStyle(fontSize: 13)),
            ),
          ],
        );
      },
    );
  }

  String _feedFilter = 'All'; // 'All' or 'Saved'

  void _toggleBookmark(AppProvider app, AuthProvider auth, PostModel post) async {
    await app.toggleBookmark(auth.currentUser!.uid, post.id);
  }

  void _reportPost(BuildContext context, AppProvider app, AuthProvider auth, PostModel post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Post', style: TextStyle(color: DivineTheme.maroon, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to report this post? It will be hidden from your feed immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: DivineTheme.textLight)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await app.reportPost(auth.currentUser!.uid, post.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post reported and hidden.'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: DivineTheme.maroon),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final app = Provider.of<AppProvider>(context);
    final userId = auth.currentUser?.uid ?? '';

    final showCreateButton = auth.currentUser?.role == UserRole.temple || auth.currentUser?.role == UserRole.priest;

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        app.getSavedPostIds(userId),
        app.getReportedPostIds(userId),
        app.getFollowingIds(userId),
      ]),
      builder: (context, snapshot) {
        final savedIds = snapshot.data?[0] as List<String>? ?? [];
        final reportedIds = snapshot.data?[1] as List<String>? ?? [];
        final followedIds = snapshot.data?[2] as List<String>? ?? [];

        final filteredPosts = app.posts.where((post) {
          if (reportedIds.contains(post.id)) return false;
          if (_feedFilter == 'Saved') {
            return savedIds.contains(post.id);
          }
          return true;
        }).toList();

        // Sort: Prioritize posts from followed authors, then by timestamp descending
        filteredPosts.sort((a, b) {
          final aFollowed = followedIds.contains(a.authorId);
          final bFollowed = followedIds.contains(b.authorId);
          if (aFollowed && !bFollowed) return -1;
          if (!aFollowed && bFollowed) return 1;
          return b.timestamp.compareTo(a.timestamp);
        });

        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          body: Column(
            children: [
              // Filters row (ChoiceChips)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All Updates'),
                      selected: _feedFilter == 'All',
                      selectedColor: DivineTheme.maroon.withOpacity(0.15),
                      onSelected: (selected) {
                        if (selected) setState(() => _feedFilter = 'All');
                      },
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Saved Sevas'),
                      selected: _feedFilter == 'Saved',
                      selectedColor: DivineTheme.saffron.withOpacity(0.2),
                      onSelected: (selected) {
                        if (selected) setState(() => _feedFilter = 'Saved');
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredPosts.isEmpty
                    ? Center(
                        child: Text(
                          _feedFilter == 'Saved'
                              ? 'No bookmarked posts yet.'
                              : 'No updates on the social wall currently.',
                          style: const TextStyle(color: DivineTheme.textLight),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: filteredPosts.length,
                        itemBuilder: (context, index) {
                          final post = filteredPosts[index];
                          final isBookmarked = savedIds.contains(post.id);
                          return SocialPostCard(
                            post: post,
                            isBookmarked: isBookmarked,
                            onBookmarkToggle: () => _toggleBookmark(app, auth, post),
                            onReport: () => _reportPost(context, app, auth, post),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: showCreateButton
              ? FloatingActionButton(
                  backgroundColor: DivineTheme.saffron,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.add_a_photo),
                  onPressed: () => _showCreatePostDialog(context, app, auth),
                )
              : null,
        );
      },
    );
  }
}

class SocialPostCard extends StatefulWidget {
  final PostModel post;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;
  final VoidCallback onReport;

  const SocialPostCard({
    super.key,
    required this.post,
    required this.isBookmarked,
    required this.onBookmarkToggle,
    required this.onReport,
  });

  @override
  State<SocialPostCard> createState() => _SocialPostCardState();
}

class _SocialPostCardState extends State<SocialPostCard> {
  bool _isHeartAnimating = false;

  void _triggerDoubleTapLike(AppProvider app, AuthProvider auth) async {
    setState(() {
      _isHeartAnimating = true;
    });

    final hasLiked = await app.checkUserLiked(widget.post.id, auth.currentUser!.uid);
    if (!hasLiked) {
      await app.toggleLike(widget.post.id, auth.currentUser!.uid);
    }

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _isHeartAnimating = false;
        });
      }
    });
  }

  void _showCommentsSheet(BuildContext context, AppProvider app, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CommentsBottomSheet(post: widget.post, app: app, auth: auth);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final app = Provider.of<AppProvider>(context);

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar with gradient border + name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.0),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        DivineTheme.saffron,
                        DivineTheme.gold,
                        DivineTheme.maroon,
                        DivineTheme.saffron,
                      ],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundImage: widget.post.authorImage.isNotEmpty ? NetworkImage(widget.post.authorImage) : null,
                      backgroundColor: DivineTheme.creamDark,
                      child: widget.post.authorImage.isEmpty ? const Icon(Icons.account_balance, color: DivineTheme.maroon, size: 16) : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.authorName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: DivineTheme.textDark),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        DateTime.fromMillisecondsSinceEpoch(widget.post.timestamp).toString().split(' ')[0],
                        style: const TextStyle(fontSize: 10, color: DivineTheme.textLight),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: DivineTheme.textDark),
                  onSelected: (value) {
                    if (value == 'report') {
                      widget.onReport();
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'report',
                      child: Text('Report Post', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Post Image with Double-Tap Like animation
          GestureDetector(
            onDoubleTap: () => _triggerDoubleTapLike(app, auth),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.network(
                  widget.post.imageUrl,
                  height: 320,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 250,
                    color: DivineTheme.creamDark,
                    child: const Icon(Icons.image, size: 64, color: DivineTheme.textLight),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _isHeartAnimating ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: AnimatedScale(
                    scale: _isHeartAnimating ? 1.1 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 90,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action Row (Instagram style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                FutureBuilder<bool>(
                  future: app.checkUserLiked(widget.post.id, auth.currentUser!.uid),
                  builder: (context, snapshot) {
                    final liked = snapshot.data ?? false;
                    return IconButton(
                      icon: Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        color: liked ? Colors.red : DivineTheme.textDark,
                        size: 26,
                      ),
                      onPressed: () async {
                        await app.toggleLike(widget.post.id, auth.currentUser!.uid);
                      },
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, size: 24, color: DivineTheme.textDark),
                  onPressed: () => _showCommentsSheet(context, app, auth),
                ),
                IconButton(
                  icon: const Icon(Icons.near_me_outlined, size: 24, color: DivineTheme.textDark),
                  onPressed: () {},
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 24,
                    color: widget.isBookmarked ? DivineTheme.saffron : DivineTheme.textDark,
                  ),
                  onPressed: widget.onBookmarkToggle,
                ),
              ],
            ),
          ),

          // Likes Summary Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: FutureBuilder<int>(
              future: app.getPostLikes(widget.post.id),
              builder: (context, snapshot) {
                final likesCount = snapshot.data ?? 0;
                return Text(
                  '$likesCount like${likesCount != 1 ? "s" : ""}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark),
                );
              },
            ),
          ),

          // Caption Row (Rich text for name and caption)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: DivineTheme.textDark, fontSize: 13, height: 1.4, fontFamily: 'Poppins'),
                children: [
                  TextSpan(
                    text: widget.post.authorName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(text: widget.post.caption),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}


class CommentsBottomSheet extends StatefulWidget {
  final PostModel post;
  final AppProvider app;
  final AuthProvider auth;

  const CommentsBottomSheet({
    super.key,
    required this.post,
    required this.app,
    required this.auth,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final _commentController = TextEditingController();
  List<CommentModel> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  void _loadComments() async {
    final list = await widget.app.getComments(widget.post.id);
    if (mounted) {
      setState(() {
        _comments = list;
        _isLoading = false;
      });
    }
  }

  void _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final newComment = CommentModel(
      id: '',
      postId: widget.post.id,
      userId: widget.auth.currentUser!.uid,
      userName: widget.auth.currentUser!.name,
      content: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    // Optimistic Update
    setState(() {
      _comments.add(newComment);
      _commentController.clear();
    });

    await widget.app.addComment(newComment);
    // Reload full comments to sync with backend database IDs
    _loadComments();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Slide pill indicator
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Comments',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: DivineTheme.textDark),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),

            // Comments List
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(color: DivineTheme.maroon),
                    )
                  : _comments.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60.0),
                          child: Center(
                            child: Text(
                              'No comments yet. Be the first to comment!',
                              style: TextStyle(color: DivineTheme.textLight, fontSize: 13),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final c = _comments[index];
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: DivineTheme.creamDark,
                                  child: Text(
                                    c.userName.isNotEmpty ? c.userName[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DivineTheme.maroon),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          style: const TextStyle(color: DivineTheme.textDark, fontSize: 12.5, fontFamily: 'Poppins'),
                                          children: [
                                            TextSpan(
                                              text: c.userName,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            const TextSpan(text: ' '),
                                            TextSpan(text: c.content),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
            ),

            const Divider(height: 1),
            // Input Bar at bottom
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: DivineTheme.creamDark,
                    child: Text(
                      widget.auth.currentUser!.name.isNotEmpty ? widget.auth.currentUser!.name[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DivineTheme.maroon),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _commentController,
                    builder: (context, value, child) {
                      final hasText = value.text.trim().isNotEmpty;
                      return TextButton(
                        onPressed: hasText ? _postComment : null,
                        child: Text(
                          'Post',
                          style: TextStyle(
                            color: hasText ? DivineTheme.saffron : DivineTheme.textLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
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

