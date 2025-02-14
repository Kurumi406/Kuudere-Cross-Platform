import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kuudere/services/auth_service.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'data.dart';

class CommentBottomSheet extends StatefulWidget {
  final int commentCount;
  final Map<String, dynamic> episodeData;
  final dynamic epNumber;
  final dynamic animeId;
  final List<Comment> comments;
  final Function(List<Comment>) updateComments;

  const CommentBottomSheet({
    Key? key,
    required this.commentCount,
    required this.episodeData,
    required this.epNumber,
    required this.animeId,
    required this.comments,
    required this.updateComments,
  }) : super(key: key);

  @override
  State<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  late List<Comment> comments;
  final TextEditingController _commentController = TextEditingController();
  final Map<String, TextEditingController> _replyControllers = {};
  Map<String, bool> showReplyForms = {};
  Map<String, bool> expandedReplies = {};
  bool isSpoiler = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    print('Episode Number: ${widget.epNumber}');
    print('Anime ID: ${widget.animeId}');
    comments = widget.comments;
  
    for (var comment in comments) {
      showReplyForms[comment.id] = false;
      expandedReplies[comment.id] = false;
      _replyControllers[comment.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    for (var controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleInteraction(String commentId, String type) async {
    final url = 'https://kuudere.to/api/anime/comment/respond/$commentId';
    final authService = AuthService();
    final sessionInfo = await authService.getStoredSession();

    if (sessionInfo == null) {
      print('No session information found.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'secret': SECRET,
          'key': sessionInfo.session,
          'commentId': commentId,
          'type': type,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          final comment = comments.firstWhere((c) => c.id == commentId);
          if (type == 'like') {
            if (comment.isLiked) {
              comment.likes--;
              comment.isLiked = false;
            } else {
              comment.likes++;
              comment.isLiked = true;
              if (comment.isDisliked) {
                comment.dislikes--;
                comment.isDisliked = false;
              }
            }
          } else if (type == 'dislike') {
            if (comment.isDisliked) {
              comment.dislikes--;
              comment.isDisliked = false;
            } else {
              comment.dislikes++;
              comment.isDisliked = true;
              if (comment.isLiked) {
                comment.likes--;
                comment.isLiked = false;
              }
            }
          }
        });
      } else {
        print('Failed to $type comment: ${response.statusCode}');
      }
    } catch (e) {
      print('Error ${type}ing comment: $e');
    }
  }

  Widget _buildCommentForm({bool isReply = false, String? commentId}) {
    final controller = isReply ? _replyControllers[commentId]! : _commentController;
    
    return Column(
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: isReply ? 'Write a reply...' : 'Add a comment...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Checkbox(
                  value: isSpoiler,
                  onChanged: (value) => setState(() => isSpoiler = value!),
                  fillColor: MaterialStateProperty.all(Colors.grey[800]),
                ),
                Text(
                  'Spoiler?',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
            TextButton(
              onPressed: _isSubmitting ? null : () async {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _isSubmitting = true;
                  });
                  if (isReply) {
                    await _handleReplySubmit(commentId!);
                  } else {
                    await _handleCommentSubmit();
                  }
                  setState(() {
                    _isSubmitting = false;
                  });
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: _isSubmitting
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: LoadingAnimationWidget.threeArchedCircle(
                      color: Colors.white,
                      size: 24,
                    ),
                  )
                : Text(
                    isReply ? 'Reply' : 'Comment',
                    style: const TextStyle(color: Colors.white),
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleCommentSubmit() async {
    final authService = AuthService();
    final sessionInfo = await authService.getStoredSession();

    if (sessionInfo == null) {
      print('No session information found.');
      return;
    }

    final url = 'https://kuudere.to/anime/comment/';
    
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'secret': SECRET,
          'key': sessionInfo.session,
          'anime': widget.animeId,
          'ep': widget.epNumber,
          'content': _commentController.text
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          setState(() {
            comments.insert(0, Comment(
              id: responseData['data']['commentId'],
              author: responseData['data']['username'],
              content: _commentController.text,
              time: 'Just now',
              likes: 0,
              dislikes: 0,
              isLiked: false,
              isDisliked: false,
              isSpoiler: isSpoiler,
              replies: [],
            ));
            _commentController.clear();
            isSpoiler = false;
          });
          widget.updateComments(comments);
        } else {
          print('Failed to add comment: ${responseData['message']}');
        }
      } else {
        print('Failed to add comment: ${response.statusCode}');
      }
    } catch (e) {
      print('Error adding comment: $e');
    }
  }

  Future<void> _handleReplySubmit(String commentId) async {
    final authService = AuthService();
    final sessionInfo = await authService.getStoredSession();

    if (sessionInfo == null) {
      print('No session information found.');
      return;
    }

    final url = 'https://kuudere.to/anime/comments/reply';
    final replyContent = _replyControllers[commentId]!.text;

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'secret': SECRET,
          'key': sessionInfo.session,
          'commentId': commentId,
          'content': replyContent,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        setState(() {
          final commentIndex = comments.indexWhere((comment) => comment.id == commentId);
          if (commentIndex != -1) {
            comments[commentIndex].replies.add(Reply(
              id: responseData['id'],
              author: responseData['author'],
              content: responseData['content'],
              time: responseData['time'],
            ));
            _replyControllers[commentId]!.clear();
            showReplyForms[commentId] = false;
            expandedReplies[commentId] = true;
            isSpoiler = false;
          }
        });
        widget.updateComments(comments);
      } else {
        print('Failed to submit reply: ${response.statusCode}');
        // You might want to show an error message to the user here
      }
    } catch (e) {
      print('Error submitting reply: $e');
      // You might want to show an error message to the user here
    }
  }

  void toggleReplyForm(String commentId) {
    setState(() {
      showReplyForms[commentId] = !(showReplyForms[commentId] ?? false);
    });
  }

  void toggleReplies(String commentId) {
    setState(() {
      expandedReplies[commentId] = !(expandedReplies[commentId] ?? false);
    });
  }

  Widget _buildCommentContent(Comment comment) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.orange,
          child: Text(
            comment.author[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '@${comment.author}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '• ${comment.time}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  if (comment.isSpoiler)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'SPOILER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (comment.isSpoiler)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      comment.isSpoiler = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'This comment contains spoilers. Tap to reveal.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              else
                Text(
                  comment.content,
                  style: const TextStyle(color: Colors.white),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildInteractionButton(
                    icon: Icons.thumb_up_outlined,
                    count: comment.likes,
                    isActive: comment.isLiked,
                    onTap: () => _handleInteraction(comment.id, 'like'),
                  ),
                  const SizedBox(width: 16),
                  _buildInteractionButton(
                    icon: Icons.thumb_down_outlined,
                    count: comment.dislikes,
                    isActive: comment.isDisliked,
                    onTap: () => _handleInteraction(comment.id, 'dislike'),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () => toggleReplyForm(comment.id),
                    child: const Text(
                      'Reply',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  if (comment.replies.isNotEmpty)
                    TextButton(
                      onPressed: () => toggleReplies(comment.id),
                      child: Text(
                        (expandedReplies[comment.id] ?? false) ? 'Hide Replies' : 'Show Replies (${comment.replies.length})',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentItem(Comment comment) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentContent(comment),
          if (showReplyForms[comment.id] ?? false)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 12),
              child: _buildCommentForm(isReply: true, commentId: comment.id),
            ),
          if (comment.replies.isNotEmpty && (expandedReplies[comment.id] ?? false))
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 12),
              child: Column(
                children: comment.replies.map((reply) => _buildReplyContent(reply)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyContent(Reply reply) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.orange,
            child: Text(
              reply.author[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '@${reply.author}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${reply.time}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reply.content,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: isActive ? Colors.blue : Colors.white70,
            size: 20,
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: TextStyle(
                color: isActive ? Colors.blue : Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0A0A0A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Comments ${widget.commentCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF2A2A2A)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildCommentForm(),
              ),
              const Divider(color: Color(0xFF2A2A2A)),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: comments.length,
                  separatorBuilder: (context, index) => const Divider(
                    color: Color(0xFF2A2A2A),
                    height: 1,
                  ),
                  itemBuilder: (context, index) => _buildCommentItem(comments[index]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class Comment {
  final String id;
  final String author;
  final String content;
  final String time;
  int likes;
  int dislikes;
  bool isLiked;
  bool isDisliked;
  final List<Reply> replies;
  bool isSpoiler;

  Comment({
    required this.id,
    required this.author,
    required this.content,
    required this.time,
    required this.likes,
    required this.dislikes,
    required this.isLiked,
    required this.isDisliked,
    required this.replies,
    required this.isSpoiler,
  });
}

class Reply {
  final String id;
  final String author;
  final String content;
  final String time;

  Reply({
    required this.id,
    required this.author,
    required this.content,
    required this.time,
  });
}

