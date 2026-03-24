import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../domain/models/feed_mode.dart';
import '../domain/models/media_post.dart';
import '../domain/models/post_image.dart';

class PostMediaCard extends StatelessWidget {
  const PostMediaCard({
    super.key,
    required this.post,
    required this.image,
    required this.onPreview,
    required this.onSave,
    required this.onOpenPost,
    required this.isSaved,
  });

  final MediaPost post;
  final PostImage image;
  final VoidCallback onPreview;
  final VoidCallback onSave;
  final VoidCallback onOpenPost;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: image.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => const ColoredBox(
                    color: Color(0xFFE5E7EB),
                    child: Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onPreview,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '@${post.authorUsername}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MetaChip(label: post.sourceType.shortLabel),
                    if ((post.reposterUsername ?? '').isNotEmpty)
                      _MetaChip(label: 'Reposted by @${post.reposterUsername}'),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSave,
                    icon: Icon(isSaved ? Icons.check : Icons.download_rounded),
                    label: Text(isSaved ? 'Saved' : 'Save'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: onOpenPost,
                  icon: const Icon(Icons.open_in_new_rounded),
                  tooltip: 'Open original post',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}
