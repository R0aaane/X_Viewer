import 'package:flutter/material.dart';

enum CreatorSearchTarget {
  hitomi,
  kemono,
  dddSmart,
  crossSiteSearch,
}

extension CreatorSearchTargetDetails on CreatorSearchTarget {
  String get label {
    return switch (this) {
      CreatorSearchTarget.hitomi => 'hitomi',
      CreatorSearchTarget.kemono => 'kemono',
      CreatorSearchTarget.dddSmart => 'ddd-smart',
      CreatorSearchTarget.crossSiteSearch => 'Google',
    };
  }

  String get description {
    return switch (this) {
      CreatorSearchTarget.hitomi => 'Search hitomi by creator name',
      CreatorSearchTarget.kemono => 'Search kemono creators',
      CreatorSearchTarget.dddSmart => 'Search ddd-smart circles',
      CreatorSearchTarget.crossSiteSearch => 'Search all configured sites',
    };
  }

  IconData get icon {
    return switch (this) {
      CreatorSearchTarget.hitomi => Icons.image_search_rounded,
      CreatorSearchTarget.kemono => Icons.person_search_rounded,
      CreatorSearchTarget.dddSmart => Icons.menu_book_rounded,
      CreatorSearchTarget.crossSiteSearch => Icons.travel_explore_rounded,
    };
  }

  Uri buildUri(String creatorName) {
    final query = creatorName.trim();
    return switch (this) {
      CreatorSearchTarget.hitomi => Uri.parse(
        'https://hitomi.la/search.html?${Uri.encodeComponent(query)}',
      ),
      CreatorSearchTarget.kemono => Uri.https(
        'kemono.su',
        '/artists',
        {'q': query},
      ),
      CreatorSearchTarget.dddSmart => Uri.parse(
        'https://ddd-smart.net/list2.php?'
        'keyword=${Uri.encodeQueryComponent(query)}'
        '&s=%E6%A4%9C%E7%B4%A2&type=3',
      ),
      CreatorSearchTarget.crossSiteSearch => Uri.https(
        'www.google.com',
        '/search',
        {
          'q':
              '$query (site:hitomi.la OR site:kemono.su OR site:ddd-smart.net)',
        },
      ),
    };
  }
}
