import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../domain/models/save_location_type.dart';
import '../../../../services/service_providers.dart';
import '../../../../widgets/section_empty_view.dart';
import '../providers/saved_media_controller.dart';

class SavedMediaDetailScreen extends ConsumerWidget {
  const SavedMediaDetailScreen({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(savedMediaRecordProvider(recordId));

    if (record == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const SectionEmptyView(
          title: 'Saved item not found',
          message: 'The record may have been deleted.',
        ),
      );
    }

    final previewFile = File(record.previewFilePath);
    return Scaffold(
      appBar: AppBar(
        title: Text('@${record.authorUsername}'),
        actions: [
          IconButton(
            onPressed: () => ref
                .read(savedMediaControllerProvider.notifier)
                .toggleFavorite(record.recordId),
            icon: Icon(
              record.favorite ? Icons.favorite : Icons.favorite_border,
            ),
            tooltip: 'Toggle favorite',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: previewFile.existsSync()
                        ? Image.file(previewFile, fit: BoxFit.contain)
                        : const ColoredBox(
                            color: Color(0xFFE5E7EB),
                            child: Icon(Icons.image_not_supported_outlined),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.authorName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${record.authorUsername}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => _openPost(context, ref, record.originalPostUrl),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Open post'),
                        ),
                        if (record.saveLocationType == SaveLocationType.gallery)
                          FilledButton.tonalIcon(
                            onPressed: () => _openGallery(context, ref),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Gallery'),
                          ),
                      ],
                    ),
                  ],
                ),
                if (record.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(record.text, style: Theme.of(context).textTheme.bodyLarge),
                ],
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Tags',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...record.tags.map((tag) {
                            return InputChip(
                              label: Text('#$tag'),
                              onDeleted: () => ref
                                  .read(savedMediaControllerProvider.notifier)
                                  .removeTag(recordId: record.recordId, tag: tag),
                            );
                          }),
                          ActionChip(
                            onPressed: () => _showAddTagDialog(context, ref, record.recordId),
                            avatar: const Icon(Icons.add_rounded),
                            label: const Text('Add tag'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Saved info',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'Saved at', value: DateFormatter.shortDateTime(record.savedAt)),
                      _InfoRow(label: 'Post time', value: DateFormatter.shortDateTime(record.createdAt)),
                      _InfoRow(
                        label: 'Favorite',
                        value: record.favorite ? 'Yes' : 'No',
                      ),
                      _InfoRow(
                        label: 'Save location',
                        value: record.saveLocationType == SaveLocationType.gallery
                            ? 'Gallery'
                            : 'App storage',
                      ),
                      _InfoRow(label: 'Saved path', value: record.localSavedPath),
                      _InfoRow(label: 'Preview path', value: record.previewFilePath),
                      _InfoRow(label: 'Image URL', value: record.imageUrl),
                      _InfoRow(label: 'Source URL', value: record.sourceImageUrl),
                      if ((record.galleryContentUri ?? '').isNotEmpty)
                        _InfoRow(
                          label: 'Gallery URI',
                          value: record.galleryContentUri!,
                        ),
                      if ((record.galleryDisplayName ?? '').isNotEmpty)
                        _InfoRow(
                          label: 'Gallery name',
                          value: record.galleryDisplayName!,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddTagDialog(
    BuildContext context,
    WidgetRef ref,
    String recordId,
  ) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add tag'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'example',
              prefixText: '#',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (value == null || value.trim().isEmpty) {
      return;
    }

    await ref
        .read(savedMediaControllerProvider.notifier)
        .addTag(recordId: recordId, rawTag: value);
  }

  Future<void> _openPost(BuildContext context, WidgetRef ref, String url) async {
    try {
      await ref.read(linkLauncherServiceProvider).openExternal(url);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _openGallery(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(savedMediaControllerProvider.notifier).openGalleryApp();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          SelectableText(value),
        ],
      ),
    );
  }
}
