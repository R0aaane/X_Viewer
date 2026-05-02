import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/creator_search_target.dart';
import '../../../../domain/models/saved_media_record.dart';
import '../../../../services/service_providers.dart';
import '../providers/saved_media_controller.dart';

class CreatorSiteBadges extends ConsumerWidget {
  const CreatorSiteBadges({
    super.key,
    required this.record,
    this.compact = false,
  });

  final SavedMediaRecord record;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<_CreatorSiteBadgeState>(
      future: _loadState(ref),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final matches = data?.matches ?? const <CreatorSearchMatch>[];
        final needsDisplayName = data?.needsDisplayName ??
            _needsDisplayName(record.authorName, record.authorUsername);
        if (matches.isEmpty && !needsDisplayName) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.only(top: compact ? 4 : 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...matches.map((match) {
                return _CreatorSiteBadge(
                  match: match,
                  compact: compact,
                );
              }),
              if (needsDisplayName)
                _DisplayNameLookupBadge(
                  record: record,
                  compact: compact,
                ),
            ],
          ),
        );
      },
    );
  }

  Future<_CreatorSiteBadgeState> _loadState(WidgetRef ref) async {
    final displayNameService = ref.read(creatorDisplayNameServiceProvider);
    final localName = await displayNameService.findLocalDisplayName(
      record.authorUsername,
    );
    final effectiveAuthorName = (localName ?? record.authorName).trim();
    final matches = await ref.read(creatorSiteResolverServiceProvider).resolve(
          authorName: effectiveAuthorName,
          authorUsername: record.authorUsername,
        );

    return _CreatorSiteBadgeState(
      matches: matches,
      needsDisplayName: _needsDisplayName(
        effectiveAuthorName,
        record.authorUsername,
      ),
    );
  }

  bool _needsDisplayName(String authorName, String authorUsername) {
    final name = authorName.trim();
    final username = authorUsername.trim();
    return name.isEmpty ||
        name == 'Unknown' ||
        name == 'unknown_user' ||
        _normalizeUsername(name) == _normalizeUsername(username);
  }

  String _normalizeUsername(String value) {
    return value.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
  }
}

class _CreatorSiteBadgeState {
  const _CreatorSiteBadgeState({
    required this.matches,
    required this.needsDisplayName,
  });

  final List<CreatorSearchMatch> matches;
  final bool needsDisplayName;
}

class _CreatorSiteBadge extends ConsumerWidget {
  const _CreatorSiteBadge({
    required this.match,
    required this.compact,
  });

  final CreatorSearchMatch match;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = _badgeColors(context, match.target);
    return Tooltip(
      message: 'Open ${match.target.label}: ${match.title}',
      child: Material(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _open(context, ref),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 5 : 6,
              vertical: compact ? 4 : 5,
            ),
            child: Image.network(
              match.target.faviconUrl,
              width: compact ? 14 : 16,
              height: compact ? 14 : 16,
              errorBuilder: (context, error, stackTrace) {
                return Text(
                  match.target.mark,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.$2,
                        fontWeight: FontWeight.w700,
                      ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  (Color, Color) _badgeColors(
    BuildContext context,
    CreatorSearchTarget target,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (target) {
      CreatorSearchTarget.hitomi => (
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
        ),
      CreatorSearchTarget.kemono => (
          colorScheme.tertiaryContainer,
          colorScheme.onTertiaryContainer,
        ),
      CreatorSearchTarget.dddSmart => (
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
        ),
      CreatorSearchTarget.crossSiteSearch => (
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurface,
        ),
    };
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(linkLauncherServiceProvider).openExternal(
            match.url,
            debugLabel: '${match.target.label} creator page',
            failureMessage: 'Could not open creator page',
          );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _DisplayNameLookupBadge extends ConsumerWidget {
  const _DisplayNameLookupBadge({
    required this.record,
    required this.compact,
  });

  final SavedMediaRecord record;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Find X display name',
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _lookup(context, ref),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 5 : 6,
              vertical: compact ? 4 : 5,
            ),
            child: Icon(
              Icons.manage_search_rounded,
              size: compact ? 14 : 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _lookup(BuildContext context, WidgetRef ref) async {
    final service = ref.read(creatorDisplayNameServiceProvider);
    final candidates = await service.searchDisplayNameCandidates(
      record.authorUsername,
    );
    if (!context.mounted) {
      return;
    }

    final selected = await _showDisplayNameDialog(
      context: context,
      authorUsername: record.authorUsername,
      candidates: candidates,
    );
    if (selected == null || selected.trim().isEmpty) {
      return;
    }

    await ref.read(savedMediaControllerProvider.notifier).applyAuthorDisplayName(
          authorUsername: record.authorUsername,
          displayName: selected,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved display name: $selected')),
      );
    }
  }

  Future<String?> _showDisplayNameDialog({
    required BuildContext context,
    required String authorUsername,
    required List<String> candidates,
  }) async {
    final controller = TextEditingController();
    try {
      return showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('@$authorUsername'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (candidates.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('No display name candidates found.'),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          final candidate = candidates[index];
                          return ListTile(
                            dense: true,
                            title: Text(candidate),
                            onTap: () => Navigator.of(context).pop(candidate),
                          );
                        },
                      ),
                    ),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
                    onSubmitted: (value) => Navigator.of(context).pop(value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }
}
