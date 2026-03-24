import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
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
  static const double _defaultGridItemExtent = 148;
  static const double _minGridItemExtent = 112;
  static const double _maxGridItemExtent = 220;

  double _gridItemExtent = _defaultGridItemExtent;

  @override
  void initState() {
    super.initState();
    _loadGridPreferences();
  }

  Future<void> _loadGridPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final storedExtent = prefs.getDouble(StorageKeys.galleryGridItemExtent);
    if (!mounted || storedExtent == null) {
      return;
    }

    setState(() {
      _gridItemExtent = _clampGridItemExtent(storedExtent);
    });
  }

  Future<void> _setGridItemExtent(double value) async {
    final nextValue = _clampGridItemExtent(value);
    if (!mounted) {
      return;
    }

    setState(() {
      _gridItemExtent = nextValue;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(StorageKeys.galleryGridItemExtent, nextValue);
  }

  double _clampGridItemExtent(double value) {
    return value.clamp(_minGridItemExtent, _maxGridItemExtent).toDouble();
  }

  String _gridSizeLabel(double value) {
    if (value <= 132) {
      return 'Small';
    }
    if (value >= 188) {
      return 'Large';
    }
    return 'Medium';
  }

  Future<void> _showGridSizeDialog() async {
    var draftValue = _gridItemExtent;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Display size'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_gridSizeLabel(draftValue)} (${draftValue.round()} px)'),
                  const SizedBox(height: 12),
                  Slider(
                    value: draftValue,
                    min: _minGridItemExtent,
                    max: _maxGridItemExtent,
                    divisions:
                        (_maxGridItemExtent - _minGridItemExtent).round(),
                    label: _gridSizeLabel(draftValue),
                    onChanged: (value) {
                      setDialogState(() {
                        draftValue = value;
                      });
                      _setGridItemExtent(value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      draftValue = _defaultGridItemExtent;
                    });
                    _setGridItemExtent(_defaultGridItemExtent);
                  },
                  child: const Text('Reset'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
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
            onPressed: _showGridSizeDialog,
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'Display size',
          ),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth =
                    constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : MediaQuery.sizeOf(context).width;
                final widthLimitedExtent =
                    (availableWidth - 32)
                        .clamp(_minGridItemExtent, _maxGridItemExtent)
                        .toDouble();
                final maxExtent = _gridItemExtent
                    .clamp(_minGridItemExtent, widthLimitedExtent)
                    .toDouble();

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (timeline.isRefreshing)
                      const SliverToBoxAdapter(
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: maxExtent,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.62,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final entry = items[index];
                          return PostMediaCard(
                            post: entry.post,
                            image: entry.image,
                            isSaved: savedMediaKeys.contains(
                              entry.image.mediaKey,
                            ),
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
                                  ).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                }
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Save failed: $error'),
                                    ),
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
                        onLoadMore: () {
                          ref
                              .read(timelineControllerProvider.notifier)
                              .loadNextPage();
                        },
                      ),
                    ),
                  ],
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
    required this.onLoadMore,
  });

  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;
  final VoidCallback onLoadMore;

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
                onPressed: onLoadMore,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Center(
        child: FilledButton.tonal(
          onPressed: onLoadMore,
          child: const Text('Load more'),
        ),
      ),
    );
  }
}
