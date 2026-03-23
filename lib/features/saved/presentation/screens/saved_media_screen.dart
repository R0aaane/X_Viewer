import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../domain/models/save_location_type.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../services/service_providers.dart';
import '../../../../widgets/async_value_view.dart';
import '../../../../widgets/section_empty_view.dart';
import '../providers/saved_media_controller.dart';

class SavedMediaScreen extends ConsumerWidget {
  const SavedMediaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedState = ref.watch(savedMediaControllerProvider);

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

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final previewFile = File(record.previewFilePath);

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 96,
                                height: 96,
                                child: previewFile.existsSync()
                                    ? Image.file(previewFile, fit: BoxFit.cover)
                                    : const ColoredBox(
                                        color: Color(0xFFE5E7EB),
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record.authorName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text('@${record.authorUsername}'),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Saved at: ${DateFormatter.shortDateTime(record.savedAt)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    record.saveLocationType ==
                                            SaveLocationType.gallery
                                        ? 'Location: Gallery'
                                        : 'Location: App storage',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    record.localSavedPath,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton.tonalIcon(
                                        onPressed: () async {
                                          try {
                                            await ref
                                                .read(
                                                  linkLauncherServiceProvider,
                                                )
                                                .openExternal(
                                                  record.originalPostUrl,
                                                );
                                          } catch (error) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    error.toString(),
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.open_in_new_rounded,
                                        ),
                                        label: const Text('Open post'),
                                      ),
                                      if (record.saveLocationType ==
                                              SaveLocationType.gallery &&
                                          (record
                                                  .galleryContentUri
                                                  ?.isNotEmpty ??
                                              false))
                                        FilledButton.tonalIcon(
                                          onPressed: () async {
                                            try {
                                              await ref
                                                  .read(
                                                    savedMediaControllerProvider
                                                        .notifier,
                                                  )
                                                  .openGalleryApp();
                                            } catch (error) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      error.toString(),
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.photo_library_outlined,
                                          ),
                                          label: const Text('Gallery'),
                                        ),
                                      FilledButton.tonalIcon(
                                        onPressed: () async {
                                          await ref
                                              .read(
                                                savedMediaControllerProvider
                                                    .notifier,
                                              )
                                              .deleteRecord(record);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Saved record removed',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                        ),
                                        label: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemCount: records.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
