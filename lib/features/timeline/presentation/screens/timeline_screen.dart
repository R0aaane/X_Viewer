import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../domain/models/media_post.dart';
import '../../../../domain/models/post_image.dart';
import '../../../../domain/models/save_failure_reason.dart';
import '../../../../services/service_providers.dart';
import '../../../../widgets/async_value_view.dart';
import '../../../../widgets/post_media_card.dart';
import '../../../../widgets/section_empty_view.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../saved/presentation/providers/saved_media_controller.dart';
import '../providers/timeline_controller.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 320) {
      return;
    }

    ref.read(timelineControllerProvider.notifier).loadNextPage();
  }

  @override
  Widget build(BuildContext context) {
    final timelineState = ref.watch(timelineControllerProvider);
    final savedState = ref.watch(savedMediaControllerProvider);
    final savedMediaKeys =
        savedState.valueOrNull?.map((record) => record.mediaKey).toSet() ??
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
        data: (timeline) {
          final posts = timeline.items;
          if (posts.isEmpty) {
            return const SectionEmptyView(
              title: 'No image posts found',
              message: 'No posts with images were found in the timeline.',
            );
          }

          final items = _flattenPosts(posts);
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(timelineControllerProvider.notifier).reload(),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.62,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final entry = items[index];
                      return PostMediaCard(
                        post: entry.post,
                        image: entry.image,
                        isSaved: savedMediaKeys.contains(entry.image.mediaKey),
                        onSave: () async {
                          try {
                            final result = await ref
                                .read(savedMediaControllerProvider.notifier)
                                .saveImage(
                                  post: entry.post,
                                  image: entry.image,
                                );
                            if (context.mounted) {
                              final message = switch (result.failureReason) {
                                SaveFailureReason.duplicate =>
                                  'This image is already saved',
                                SaveFailureReason.permissionDenied =>
                                  'Gallery permission was denied, so the image was kept in app storage',
                                SaveFailureReason.galleryUnavailable =>
                                  'Saved in app storage because gallery save was unavailable',
                                SaveFailureReason.unsupportedPlatform =>
                                  'Saved in app storage on this platform',
                                SaveFailureReason.writeFailed =>
                                  'Gallery save failed, so the image was kept in app storage',
                                _ =>
                                  result.message ??
                                      'Saved to ${result.locationType.name}',
                              };
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(message)));
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
                    }, childCount: items.length),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _TimelineFooter(
                    isLoadingMore: timeline.isLoadingMore,
                    hasMore: timeline.hasMore,
                    errorMessage: timeline.errorMessage,
                    onRetry: () {
                      ref
                          .read(timelineControllerProvider.notifier)
                          .loadNextPage();
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class TimelineEntry {
  const TimelineEntry({required this.post, required this.image});

  final MediaPost post;
  final PostImage image;
}

List<TimelineEntry> _flattenPosts(List<MediaPost> posts) {
  return posts
      .expand(
        (post) =>
            post.images.map((image) => TimelineEntry(post: post, image: image)),
      )
      .toList(growable: false);
}

class _TimelineFooter extends StatelessWidget {
  const _TimelineFooter({
    required this.isLoadingMore,
    required this.hasMore,
    required this.errorMessage,
    required this.onRetry,
  });

  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Loading more...'),
            ],
          ),
        ),
      );
    }

    if ((errorMessage ?? '').isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: Column(
            children: [
              Text(errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Retry load more'),
              ),
            ],
          ),
        ),
      );
    }

    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(child: Text('No more posts')),
      );
    }

    return const SizedBox(height: 24);
  }
}
