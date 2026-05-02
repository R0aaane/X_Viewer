import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/creator_search_target.dart';
import '../../../../domain/models/saved_media_record.dart';
import '../../../../services/service_providers.dart';

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
    return FutureBuilder<List<CreatorSearchMatch>>(
      future: ref.read(creatorSiteResolverServiceProvider).resolve(
            authorName: record.authorName,
            authorUsername: record.authorUsername,
          ),
      builder: (context, snapshot) {
        final matches = snapshot.data ?? const <CreatorSearchMatch>[];
        if (matches.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.only(top: compact ? 4 : 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: matches.map((match) {
              return _CreatorSiteBadge(
                match: match,
                compact: compact,
              );
            }).toList(growable: false),
          ),
        );
      },
    );
  }
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
              horizontal: compact ? 7 : 9,
              vertical: compact ? 3 : 5,
            ),
            child: Text(
              match.target.mark,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.$2,
                    fontWeight: FontWeight.w700,
                  ),
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
