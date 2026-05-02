import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../domain/models/creator_search_target.dart';

class CreatorSiteResolverService {
  CreatorSiteResolverService(this._dio);

  static const List<String> _kemonoOrigins = [
    'https://kemono.su',
    'https://kemono.cr',
  ];

  final Dio _dio;
  final Map<String, Future<List<CreatorSearchMatch>>> _cache = {};
  final Map<String, Future<Object?>> _kemonoCreatorListCache = {};

  Future<List<CreatorSearchMatch>> resolve({
    required String authorName,
    required String authorUsername,
  }) {
    final cacheKey = '${authorName.trim()}|${authorUsername.trim()}';
    return _cache.putIfAbsent(cacheKey, () {
      return _resolveUncached(
        authorName: authorName,
        authorUsername: authorUsername,
      );
    });
  }

  Future<List<CreatorSearchMatch>> _resolveUncached({
    required String authorName,
    required String authorUsername,
  }) async {
    final candidates = _buildCandidates(authorName, authorUsername);
    if (candidates.isEmpty) {
      return const <CreatorSearchMatch>[];
    }

    final results = await Future.wait<CreatorSearchMatch?>([
      _resolveHitomi(candidates),
      _resolveKemono(candidates),
      _resolveDddSmart(candidates),
    ]);
    return results.whereType<CreatorSearchMatch>().toList(growable: false);
  }

  Future<CreatorSearchMatch?> _resolveHitomi(List<String> candidates) async {
    final romanCandidates = candidates
        .where((candidate) => RegExp(r'^[a-zA-Z0-9_. -]+$').hasMatch(candidate))
        .toList(growable: false);
    if (romanCandidates.isEmpty) {
      return null;
    }

    final pages = romanCandidates
        .map((candidate) => candidate.trim().toLowerCase())
        .where((candidate) => candidate.isNotEmpty)
        .map((candidate) => candidate[0])
        .map((first) => RegExp(r'[a-z]').hasMatch(first) ? first : '123')
        .toSet();

    for (final page in pages) {
      try {
        final response = await _dio.get<String>(
          'https://hitomi.la/allartists-$page.html',
          options: _plainOptions(),
        );
        final html = response.data ?? '';
        final match = _findBestHitomiMatch(html, romanCandidates);
        if (match != null) {
          return match;
        }
      } catch (error) {
        debugPrint('[xviewer][flutter] hitomi creator lookup failed: $error');
      }
    }
    return null;
  }

  CreatorSearchMatch? _findBestHitomiMatch(
    String html,
    List<String> candidates,
  ) {
    final artistPattern = RegExp(
      r'<a[^>]+href="([^"]*/artist/([^"]+)-all\.html)"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    );
    CreatorSearchMatch? bestMatch;
    var bestScore = 0.0;

    for (final entry in artistPattern.allMatches(html)) {
      final label = _stripHtml(entry.group(3) ?? '');
      final normalizedLabel = _normalizeForMatch(label);
      if (normalizedLabel.isEmpty) {
        continue;
      }

      for (final candidate in candidates) {
        final score = _scoreMatch(normalizedLabel, _normalizeForMatch(candidate));
        if (score > bestScore) {
          bestScore = score;
          bestMatch = CreatorSearchMatch(
            target: CreatorSearchTarget.hitomi,
            title: label,
            url: CreatorSearchTarget.hitomi.buildUri(label).toString(),
          );
        }
      }
    }

    return bestScore >= 0.78 ? bestMatch : null;
  }

  Future<CreatorSearchMatch?> _resolveKemono(List<String> candidates) async {
    for (final candidate in candidates) {
      try {
        final uri = Uri.https(
          'kemono-api.mbaharip.com',
          '/search',
          {'keyword': candidate, 'itemsPerPage': '10'},
        );
        final response = await _dio.get<String>(
          uri.toString(),
          options: _plainOptions(),
        );
        final match = _findBestKemonoApiMatch(
          jsonDecode(response.data ?? ''),
          candidates,
          'https://kemono.cr',
        );
        if (match != null) {
          return match;
        }
      } catch (error) {
        debugPrint(
          '[xviewer][flutter] kemono search API lookup failed: $error',
        );
      }
    }

    for (final origin in _kemonoOrigins) {
      for (final endpoint in const [
        '/api/v1/creators',
        '/api/v1/creators.txt',
      ]) {
        try {
          final match = _findBestKemonoApiMatch(
            await _fetchKemonoCreatorList(origin, endpoint),
            candidates,
            origin,
          );
          if (match != null) {
            return match;
          }
        } catch (error) {
          debugPrint(
            '[xviewer][flutter] kemono creator API lookup failed: $error',
          );
        }
      }
    }

    for (final origin in _kemonoOrigins) {
      for (final candidate in candidates) {
        try {
          final uri = Uri.parse(origin).replace(
            path: '/artists',
            queryParameters: {'q': candidate},
          );
          final response = await _dio.get<String>(
            uri.toString(),
            options: _plainOptions(),
          );
          final match = _findFirstKemonoHtmlMatch(
            response.data ?? '',
            candidate,
            origin,
          );
          if (match != null) {
            return match;
          }
        } catch (error) {
          debugPrint('[xviewer][flutter] kemono creator lookup failed: $error');
        }
      }
    }
    return null;
  }

  Future<Object?> _fetchKemonoCreatorList(String origin, String endpoint) {
    final url = '$origin$endpoint';
    return _kemonoCreatorListCache.putIfAbsent(url, () async {
      try {
        final response = await _dio.get<String>(
          url,
          options: _plainOptions(),
        );
        return jsonDecode(response.data ?? '');
      } catch (_) {
        _kemonoCreatorListCache.remove(url);
        rethrow;
      }
    });
  }

  CreatorSearchMatch? _findBestKemonoApiMatch(
    Object? data,
    List<String> candidates,
    String origin,
  ) {
    final entries = data is Map ? data['data'] : data;
    if (entries is! List) {
      return null;
    }

    CreatorSearchMatch? bestMatch;
    var bestScore = 0.0;

    for (final entry in entries.whereType<Map>()) {
      final name = (entry['name'] ?? '').toString();
      final service = (entry['service'] ?? '').toString();
      final id = (entry['id'] ?? entry['user_id'] ?? '').toString();
      if (name.isEmpty || service.isEmpty || id.isEmpty) {
        continue;
      }

      for (final candidate in candidates) {
        final score = _scoreFlexibleMatch(name, candidate);
        if (score > bestScore) {
          bestScore = score;
          bestMatch = CreatorSearchMatch(
            target: CreatorSearchTarget.kemono,
            title: name,
            url: '$origin/$service/user/$id',
          );
        }
      }
    }

    return bestScore >= 0.78 ? bestMatch : null;
  }

  CreatorSearchMatch? _findFirstKemonoHtmlMatch(
    String html,
    String candidate,
    String origin,
  ) {
    final linkPattern = RegExp(
      r'href="(/(?:patreon|fanbox|fantia|gumroad|subscribestar|dlsite|discord|boosty|afdian)/user/[^"]+)"',
      caseSensitive: false,
    );
    for (final match in linkPattern.allMatches(html)) {
      final start = (match.start - 220).clamp(0, html.length).toInt();
      final end = (match.end + 220).clamp(0, html.length).toInt();
      final surroundingText = _stripHtml(html.substring(start, end));
      if (_scoreFlexibleMatch(surroundingText, candidate) < 0.70) {
        continue;
      }
      return CreatorSearchMatch(
        target: CreatorSearchTarget.kemono,
        title: candidate,
        url: _absoluteUrl(origin, match.group(1) ?? ''),
      );
    }
    return null;
  }

  Future<CreatorSearchMatch?> _resolveDddSmart(List<String> candidates) async {
    for (final candidate in candidates) {
      try {
        final uri = CreatorSearchTarget.dddSmart.buildUri(candidate);
        final response = await _dio.get<String>(
          uri.toString(),
          options: _plainOptions(),
        );
        final match = _findFirstDddSmartMatch(response.data ?? '', candidate);
        if (match != null) {
          return match;
        }
      } catch (error) {
        debugPrint('[xviewer][flutter] ddd-smart creator lookup failed: $error');
      }
    }
    return null;
  }

  CreatorSearchMatch? _findFirstDddSmartMatch(String html, String candidate) {
    final linkPattern = RegExp(
      r'<a[^>]+href="([^"]*circle_index\.php\?h=[^"]+)"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in linkPattern.allMatches(html)) {
      final label = _stripHtml(match.group(2) ?? '');
      if (_scoreFlexibleMatch(label, candidate) < 0.84) {
        continue;
      }

      return CreatorSearchMatch(
        target: CreatorSearchTarget.dddSmart,
        title: label,
        url: _absoluteUrl('https://ddd-smart.net', match.group(1) ?? ''),
      );
    }
    return null;
  }

  List<String> _buildCandidates(String authorName, String authorUsername) {
    final values = <String>[
      authorName,
      ..._nameVariants(authorName),
      authorUsername,
      authorUsername.replaceAll('_', ' '),
      authorUsername.replaceAll('_', ''),
    ];
    return values
        .map((value) => value.trim().replaceFirst(RegExp(r'^@+'), ''))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  List<String> _nameVariants(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const <String>[];
    }

    final withoutDecorations = trimmed
        .replaceAll(RegExp(r'[\(\[].*?[\)\]]'), ' ')
        .replaceAll(RegExp(r'@[a-zA-Z0-9_]+'), ' ')
        .trim();
    final splitParts = withoutDecorations
        .split(RegExp(r'[/|,\s]+'))
        .map((part) => part.trim())
        .where((part) => part.length >= 2);

    return <String>[
      withoutDecorations,
      ...splitParts,
    ];
  }

  Options _plainOptions() {
    return Options(
      responseType: ResponseType.plain,
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      headers: const {
        'user-agent': 'XViewer creator lookup',
      },
    );
  }

  double _scoreMatch(String label, String candidate) {
    if (label.isEmpty || candidate.isEmpty) {
      return 0;
    }
    if (label == candidate) {
      return 1;
    }
    if (candidate.length >= 4 && label.contains(candidate)) {
      return 0.92;
    }
    if (label.length >= 4 && candidate.contains(label)) {
      return 0.86;
    }
    return _similarity(label, candidate);
  }

  double _scoreFlexibleMatch(String label, String candidate) {
    final normalizedLabel = _normalizeForMatch(label);
    final normalizedCandidate = _normalizeForMatch(candidate);
    final rawLabel = _normalizeText(label);
    final rawCandidate = _normalizeText(candidate);

    return [
      _scoreMatch(normalizedLabel, normalizedCandidate),
      _scoreTextContainment(rawLabel, rawCandidate),
    ].reduce((value, element) => value > element ? value : element);
  }

  double _scoreTextContainment(String label, String candidate) {
    if (label.isEmpty || candidate.isEmpty) {
      return 0;
    }
    if (label == candidate) {
      return 1;
    }
    if (candidate.length >= 2 && label.contains(candidate)) {
      return 0.92;
    }
    if (label.length >= 2 && candidate.contains(label)) {
      return 0.84;
    }
    return 0;
  }

  double _similarity(String a, String b) {
    final distance = _levenshtein(a, b);
    final maxLength = a.length > b.length ? a.length : b.length;
    if (maxLength == 0) {
      return 1;
    }
    return 1 - (distance / maxLength);
  }

  int _levenshtein(String a, String b) {
    final previous = List<int>.generate(b.length + 1, (index) => index);
    final current = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i += 1) {
      current[0] = i + 1;
      for (var j = 0; j < b.length; j += 1) {
        final cost = a[i] == b[j] ? 0 : 1;
        current[j + 1] = [
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + cost,
        ].reduce((value, element) => value < element ? value : element);
      }
      previous.setAll(0, current);
    }
    return previous[b.length];
  }

  String _normalizeForMatch(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  String _normalizeText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  String _stripHtml(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  String _absoluteUrl(String origin, String href) {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      return href;
    }
    if (href.startsWith('/')) {
      return '$origin$href';
    }
    return '$origin/$href';
  }
}
