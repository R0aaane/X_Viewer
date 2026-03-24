import 'package:flutter/material.dart';

import '../models/saved_media_filter_state.dart';

class SavedMediaFilterBar extends StatelessWidget {
  const SavedMediaFilterBar({
    super.key,
    required this.filter,
    required this.authors,
    required this.suggestedTags,
    required this.tagQueryController,
    required this.onSelectAuthor,
    required this.onToggleFavoritesOnly,
    required this.onTagQueryChanged,
    required this.onClearFilters,
  });

  final SavedMediaFilterState filter;
  final List<String> authors;
  final List<String> suggestedTags;
  final TextEditingController tagQueryController;
  final ValueChanged<String?> onSelectAuthor;
  final VoidCallback onToggleFavoritesOnly;
  final ValueChanged<String> onTagQueryChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  value: filter.authorUsername,
                  decoration: const InputDecoration(
                    labelText: 'Author',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All authors'),
                    ),
                    ...authors.map(
                      (author) => DropdownMenuItem<String?>(
                        value: author,
                        child: Text('@$author'),
                      ),
                    ),
                  ],
                  onChanged: onSelectAuthor,
                ),
              ),
              SizedBox(
                width: 260,
                child: TextFormField(
                  controller: tagQueryController,
                  decoration: const InputDecoration(
                    labelText: 'Search tag',
                    hintText: 'art, ref, memo...',
                    prefixIcon: Icon(Icons.tag_rounded),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: onTagQueryChanged,
                ),
              ),
              FilterChip(
                selected: filter.onlyFavorites,
                onSelected: (_) => onToggleFavoritesOnly(),
                label: const Text('Favorites only'),
                avatar: const Icon(Icons.favorite_border),
              ),
              if (filter.hasActiveFilters)
                TextButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Clear'),
                ),
            ],
          ),
          if (suggestedTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestedTags.take(12).map((tag) {
                final isActive = filter.tagQuery == tag;
                return ActionChip(
                  onPressed: () => onTagQueryChanged(isActive ? '' : tag),
                  label: Text('#$tag'),
                  backgroundColor: isActive
                      ? theme.colorScheme.secondaryContainer
                      : null,
                );
              }).toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}
