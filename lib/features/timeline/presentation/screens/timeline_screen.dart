import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../domain/models/media_post.dart';
import '../../../../domain/models/post_image.dart';
import '../../../../services/service_providers.dart';
import '../../../../widgets/async_value_view.dart';
import '../../../../widgets/post_media_card.dart';
import '../../../../widgets/section_empty_view.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../saved/presentation/providers/saved_media_controller.dart';
import '../providers/timeline_controller.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineState = ref.watch(timelineControllerProvider);
    final savedState = ref.watch(savedMediaControllerProvider);
    final savedMediaKeys = savedState.valueOrNull
            ?.map((record) => record.mediaKey)
            .toSet() ??
        <String>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline Images'),
        actions: [
          IconButton(
            onPressed: () => context.go(AppRoutes.saved),
            icon: const Icon(Icons.bookmark_rounded),
            tooltip: 'Saved items',
          ),
          IconButton(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: AsyncValueView(
        value: timelineState,
        loadingLabel: 'Loading image posts...',
        onRetry: () => ref.read(timelineControllerProvider.notifier).reload(),
        data: (posts) {
          if (posts.isEmpty) {
            return const SectionEmptyView(
              title: 'No image posts found',
              message: 'No posts with images were found in the timeline.',
            );
          }

          final items = _flattenPosts(posts);
          return RefreshIndicator(
            onRefresh: () => ref.read(timelineControllerProvider.notifier).reload(),
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final entry = items[index];
                return PostMediaCard(
                  post: entry.post,
                  image: entry.image,
                  isSaved: savedMediaKeys.contains(entry.image.mediaKey),
                  onSave: () async {
                    try {
                      final existing = await ref
                          .read(savedMediaControllerProvider.notifier)
                          .saveImage(post: entry.post, image: entry.image);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              existing == null
                                  ? 'Image saved'
                                  : 'This image is already saved',
                            ),
                          ),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Save failed: $error')),
                        );
                      }
                    }
                  },
                  onOpenPost: () async {
                    try {
                      await ref
                          .read(linkLauncherServiceProvider)
                          .openExternal(entry.post.originalPostUrl);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class TimelineEntry {
  const TimelineEntry({
    required this.post,
    required this.image,
  });

  final MediaPost post;
  final PostImage image;
}

List<TimelineEntry> _flattenPosts(List<MediaPost> posts) {
  return posts
      .expand(
        (post) => post.images.map(
          (image) => TimelineEntry(post: post, image: image),
        ),
      )
      .toList(growable: false);
}
