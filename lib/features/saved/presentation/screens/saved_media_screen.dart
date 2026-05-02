import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../services/service_providers.dart';
import '../models/saved_media_viewer_context.dart';
import '../../../settings/presentation/providers/app_preferences_controller.dart';
import '../../../settings/presentation/widgets/app_preferences_dialog.dart';
import '../../../../widgets/async_value_view.dart';
import '../../../../widgets/section_empty_view.dart';
import '../providers/saved_media_controller.dart';
import '../widgets/creator_search_sheet.dart';
import '../widgets/saved_media_card.dart';
import '../widgets/saved_media_filter_bar.dart';

class SavedMediaScreen extends ConsumerStatefulWidget {
  const SavedMediaScreen({super.key});

  @override
  ConsumerState<SavedMediaScreen> createState() => _SavedMediaScreenState();
}

class _SavedMediaScreenState extends ConsumerState<SavedMediaScreen> {
  static const int _defaultPreferredColumnCount = 2;
  static const int _maxPreferredColumnCount = 5;
  static const double _minTileWidth = 120;
  static const double _gridSpacing = 8;
  static const double _gridHorizontalPadding = 32;

  late final TextEditingController _tagQueryController;
  int _preferredColumnCount = _defaultPreferredColumnCount;

  @override
  void initState() {
    super.initState();
    _tagQueryController = TextEditingController();
    _loadPreferredColumnCount();
  }

  @override
  void dispose() {
    _tagQueryController.dispose();
    super.dispose();
  }

  Future<void> _showAppPreferencesDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => const AppPreferencesDialog(),
    );
  }

  Future<void> _loadPreferredColumnCount() async {
    final prefs = await SharedPreferences.getInstance();
    final storedValue =
        prefs.getInt(StorageKeys.savedMediaPreferredColumnCount) ??
            _defaultPreferredColumnCount;
    if (!mounted) {
      return;
    }
    setState(() {
      _preferredColumnCount =
          storedValue.clamp(1, _maxPreferredColumnCount).toInt();
    });
  }

  Future<void> _savePreferredColumnCount(int value) async {
    final normalized = value.clamp(1, _maxPreferredColumnCount).toInt();
    if (mounted) {
      setState(() {
        _preferredColumnCount = normalized;
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      StorageKeys.savedMediaPreferredColumnCount,
      normalized,
    );
  }

  int _computeEffectiveColumnCount(double width) {
    final availableWidth = (width - _gridHorizontalPadding).clamp(
      _minTileWidth,
      double.infinity,
    );
    final maxColumnsByWidth =
        ((availableWidth + _gridSpacing) / (_minTileWidth + _gridSpacing))
            .floor()
            .clamp(1, _maxPreferredColumnCount);
    return _preferredColumnCount < maxColumnsByWidth
        ? _preferredColumnCount
        : maxColumnsByWidth;
  }

  double _computeChildAspectRatio({
    required int columns,
  }) {
    if (columns <= 1) {
      return 1.18;
    }
    if (columns == 2) {
      return 0.84;
    }
    if (columns == 3) {
      return 0.78;
    }
    if (columns == 4) {
      return 0.72;
    }
    return 0.68;
  }

  @override
  Widget build(BuildContext context) {
    final savedState = ref.watch(savedMediaControllerProvider);
    final savedItemsLabel = ref.watch(
      appPreferencesProvider.select((value) => value.savedItemsLabel),
    );
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
        title: Text(savedItemsLabel),
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.timeline),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to timeline',
        ),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Columns',
            initialValue: _preferredColumnCount,
            onSelected: _savePreferredColumnCount,
            itemBuilder: (context) {
              return List<PopupMenuEntry<int>>.generate(
                _maxPreferredColumnCount,
                (index) {
                  final value = index + 1;
                  return PopupMenuItem<int>(
                    value: value,
                    child: Row(
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text('$value column${value == 1 ? '' : 's'}'),
                      ],
                    ),
                  );
                },
              );
            },
            icon: const Icon(Icons.grid_view_rounded),
          ),
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
          IconButton(
            onPressed: _showAppPreferencesDialog,
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Display settings',
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
                  return SectionEmptyView(
                    title: 'No $savedItemsLabel yet',
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
                    final effectiveColumnCount =
                        _computeEffectiveColumnCount(width);
                    final compactMode = effectiveColumnCount >= 4;
                    final childAspectRatio = _computeChildAspectRatio(
                      columns: effectiveColumnCount,
                    );

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: effectiveColumnCount,
                        crossAxisSpacing: _gridSpacing,
                        mainAxisSpacing: _gridSpacing,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: filteredRecords.length,
                      itemBuilder: (context, index) {
                        final record = filteredRecords[index];
                        final viewerContext = SavedMediaViewerContext(
                          recordIds: filteredRecords
                              .map((entry) => entry.recordId)
                              .toList(growable: false),
                          initialIndex: index,
                          sourceType: _resolveViewerSourceType(),
                          sourceTitle: _resolveViewerSourceTitle(
                            savedItemsLabel: savedItemsLabel,
                            filterAuthor: filter.authorUsername,
                            tagQuery: filter.tagQuery,
                          ),
                        );
                        return SavedMediaCard(
                          record: record,
                          isGrid: effectiveColumnCount > 1,
                          compactMode: compactMode,
                          onOpen: () => context.push(
                            AppRoutes.savedDetailPath(record.recordId),
                            extra: viewerContext,
                          ),
                          onToggleFavorite: () => _toggleFavorite(record.recordId),
                          onOpenCreatorSearch: () => showCreatorSearchSheet(
                            context: context,
                            ref: ref,
                            authorName: record.authorName,
                            authorUsername: record.authorUsername,
                          ),
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

  SavedMediaViewerSourceType _resolveViewerSourceType() {
    final filter = ref.read(savedMediaFilterProvider);
    if ((filter.authorUsername ?? '').isNotEmpty) {
      return SavedMediaViewerSourceType.author;
    }
    if (filter.tagQuery.trim().isNotEmpty) {
      return SavedMediaViewerSourceType.search;
    }
    return SavedMediaViewerSourceType.gallery;
  }

  String _resolveViewerSourceTitle({
    required String savedItemsLabel,
    required String? filterAuthor,
    required String tagQuery,
  }) {
    if ((filterAuthor ?? '').isNotEmpty) {
      return '@$filterAuthor';
    }
    if (tagQuery.trim().isNotEmpty) {
      return 'Search: ${tagQuery.trim()}';
    }
    return savedItemsLabel;
  }
}
