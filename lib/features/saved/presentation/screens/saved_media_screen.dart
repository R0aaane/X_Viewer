import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../services/service_providers.dart';
import '../../../../widgets/async_value_view.dart';
import '../../../../widgets/section_empty_view.dart';
import '../models/saved_media_layout.dart';
import '../providers/saved_media_controller.dart';
import '../widgets/saved_media_card.dart';
import '../widgets/saved_media_filter_bar.dart';

class SavedMediaScreen extends ConsumerStatefulWidget {
  const SavedMediaScreen({super.key});

  @override
  ConsumerState<SavedMediaScreen> createState() => _SavedMediaScreenState();
}

class _SavedMediaScreenState extends ConsumerState<SavedMediaScreen> {
  late final TextEditingController _tagQueryController;

  @override
  void initState() {
    super.initState();
    _tagQueryController = TextEditingController();
  }

  @override
  void dispose() {
    _tagQueryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savedState = ref.watch(savedMediaControllerProvider);
    final filter = ref.watch(savedMediaFilterProvider);
    final authors = ref.watch(savedMediaAuthorsProvider);
    final tags = ref.watch(savedMediaTagsProvider);
    final filteredRecords = ref.watch(savedMediaFilteredRecordsProvider);

    if (_tagQueryController.text != filter.tagQuery) {
      _tagQueryController.value = TextEditingValue(
        text: filter.tagQuery,
        selection: TextSelection.collapsed(offset: filter.tagQuery.length),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Images'),
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.timeline),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to timeline',
        ),
        actions: [
          IconButton(
            onPressed: () async {
              try {
                await ref
                    .read(savedMediaControllerProvider.notifier)
                    .openGalleryApp();
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              }
            },
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Open gallery app',
          ),
        ],
      ),
      body: Column(
        children: [
          FutureBuilder<String>(
            future: ref
                .read(savedMediaControllerProvider.notifier)
                .getStorageDirectory(),
            builder: (context, snapshot) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text(
                  'Storage: ${snapshot.data ?? 'Checking...'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          ),
          SavedMediaFilterBar(
            filter: filter,
            authors: authors,
            suggestedTags: tags,
            tagQueryController: _tagQueryController,
            onSelectAuthor: (value) {
              ref.read(savedMediaFilterProvider.notifier).setAuthor(value);
            },
            onToggleFavoritesOnly: () {
              ref.read(savedMediaFilterProvider.notifier).toggleFavoritesOnly();
            },
            onTagQueryChanged: (value) {
              ref.read(savedMediaFilterProvider.notifier).setTagQuery(value);
            },
            onClearFilters: () {
              ref.read(savedMediaFilterProvider.notifier).clear();
            },
          ),
          Expanded(
            child: AsyncValueView(
              value: savedState,
              onRetry: () => ref.invalidate(savedMediaControllerProvider),
              data: (records) {
                if (records.isEmpty) {
                  return const SectionEmptyView(
                    title: 'No saved images yet',
                    message: 'Save an image from the timeline screen first.',
                  );
                }

                if (filteredRecords.isEmpty) {
                  return const SectionEmptyView(
                    title: 'No matching items',
                    message: 'Try clearing the author, favorites, or tag filters.',
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : MediaQuery.sizeOf(context).width;
                    final layout = SavedMediaLayout.fromWidth(width);

                    if (layout.mode == SavedMediaLayoutMode.list) {
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredRecords.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final record = filteredRecords[index];
                          return SavedMediaCard(
                            record: record,
                            isGrid: false,
                            onOpen: () => context.push(
                              AppRoutes.savedDetailPath(record.recordId),
                            ),
                            onToggleFavorite: () => _toggleFavorite(record.recordId),
                            onOpenPost: () => _openPost(record.originalPostUrl),
                            onDelete: () => _deleteRecord(record.recordId),
                          );
                        },
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: layout.columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: layout.childAspectRatio,
                      ),
                      itemCount: filteredRecords.length,
                      itemBuilder: (context, index) {
                        final record = filteredRecords[index];
                        return SavedMediaCard(
                          record: record,
                          isGrid: true,
                          onOpen: () => context.push(
                            AppRoutes.savedDetailPath(record.recordId),
                          ),
                          onToggleFavorite: () => _toggleFavorite(record.recordId),
                          onOpenPost: () => _openPost(record.originalPostUrl),
                          onDelete: () => _deleteRecord(record.recordId),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(String recordId) async {
    await ref.read(savedMediaControllerProvider.notifier).toggleFavorite(recordId);
  }

  Future<void> _deleteRecord(String recordId) async {
    final record = ref.read(savedMediaRecordProvider(recordId));
    if (record == null) {
      return;
    }

    await ref.read(savedMediaControllerProvider.notifier).deleteRecord(record);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved record removed')));
    }
  }

  Future<void> _openPost(String url) async {
    try {
      await ref.read(linkLauncherServiceProvider).openExternal(url);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}
