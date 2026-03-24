import '../../../../domain/models/media_post.dart';

class TimelineState {
  const TimelineState({
    required this.items,
    required this.lastNewestId,
    required this.nextToken,
    required this.hasMore,
    required this.isRefreshing,
    required this.isLoadingMore,
    required this.lastSyncedAt,
    required this.lastUsedPaginationToken,
    required this.errorMessage,
  });

  final List<MediaPost> items;
  final String? lastNewestId;
  final String? nextToken;
  final bool hasMore;
  final bool isRefreshing;
  final bool isLoadingMore;
  final DateTime? lastSyncedAt;
  final String? lastUsedPaginationToken;
  final String? errorMessage;

  TimelineState copyWith({
    List<MediaPost>? items,
    String? lastNewestId,
    bool clearLastNewestId = false,
    String? nextToken,
    bool clearNextToken = false,
    bool? hasMore,
    bool? isRefreshing,
    bool? isLoadingMore,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
    String? lastUsedPaginationToken,
    bool clearLastUsedPaginationToken = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return TimelineState(
      items: items ?? this.items,
      lastNewestId: clearLastNewestId
          ? null
          : lastNewestId ?? this.lastNewestId,
      nextToken: clearNextToken ? null : nextToken ?? this.nextToken,
      hasMore: hasMore ?? this.hasMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lastSyncedAt: clearLastSyncedAt
          ? null
          : lastSyncedAt ?? this.lastSyncedAt,
      lastUsedPaginationToken: clearLastUsedPaginationToken
          ? null
          : lastUsedPaginationToken ?? this.lastUsedPaginationToken,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(growable: false),
      'lastNewestId': lastNewestId,
      'nextToken': nextToken,
      'hasMore': hasMore,
      'isRefreshing': isRefreshing,
      'isLoadingMore': isLoadingMore,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'lastUsedPaginationToken': lastUsedPaginationToken,
      'errorMessage': errorMessage,
    };
  }

  factory TimelineState.fromJson(Map<String, dynamic> json) {
    return TimelineState(
      items: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(MediaPost.fromJson)
          .toList(growable: false),
      lastNewestId: json['lastNewestId'] as String?,
      nextToken: json['nextToken'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
      isRefreshing: false,
      isLoadingMore: false,
      lastSyncedAt: json['lastSyncedAt'] == null
          ? null
          : DateTime.tryParse(json['lastSyncedAt'] as String),
      lastUsedPaginationToken: json['lastUsedPaginationToken'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  static const empty = TimelineState(
    items: <MediaPost>[],
    lastNewestId: null,
    nextToken: null,
    hasMore: false,
    isRefreshing: false,
    isLoadingMore: false,
    lastSyncedAt: null,
    lastUsedPaginationToken: null,
    errorMessage: null,
  );
}
