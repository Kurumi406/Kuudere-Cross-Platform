import 'package:flutter/material.dart';

class Comment {
  final String id;
  final String author;
  final String content;
  final String time;
  bool isSpoiler;
  int likes;
  int dislikes;
  bool isLiked;
  bool isDisliked;
  List<Comment> replies;
  bool showReplies;
  bool isUnliked;

  Comment({
    required this.id,
    required this.author,
    required this.content,
    required this.time,
    this.isSpoiler = false,
    this.likes = 0,
    this.dislikes = 0,
    this.isLiked = false,
    this.isDisliked = false,
    this.replies = const [],
    this.showReplies = false,
    required this.isUnliked,
  });
}

class CommentItem extends StatelessWidget {
  final Comment comment;
  final Function(String) onReply;
  final Function(String) onToggleReplies;
  final Function(String, bool) onVote;

  const CommentItem({
    Key? key,
    required this.comment,
    required this.onReply,
    required this.onToggleReplies,
    required this.onVote,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              IconButton(
                icon: Icon(
                  Icons.thumb_up,
                  color: comment.isLiked ? Colors.red : Colors.grey,
                ),
                onPressed: () => onVote(comment.id, true),
              ),
              Text(
                '${comment.likes}',
                style: const TextStyle(color: Colors.grey),
              ),
              IconButton(
                icon: Icon(
                  Icons.thumb_down,
                  color: comment.isDisliked ? Colors.blue : Colors.grey,
                ),
                onPressed: () => onVote(comment.id, false),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.author,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.time,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: TextStyle(
                    color: Colors.white,
                    backgroundColor: comment.isSpoiler ? Colors.black54 : null,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => onReply(comment.id),
                      child: const Text('Reply', style: TextStyle(color: Colors.red)),
                    ),
                    if (comment.replies.isNotEmpty)
                      TextButton(
                        onPressed: () => onToggleReplies(comment.id),
                        child: Text(
                          comment.showReplies ? 'Hide replies' : 'View ${comment.replies.length} replies',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
                if (comment.showReplies)
                  ...comment.replies.map((reply) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: CommentItem(
                      comment: reply,
                      onReply: onReply,
                      onToggleReplies: onToggleReplies,
                      onVote: onVote,
                    ),
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

