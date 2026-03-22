import '../../../../domain/models/media_post.dart';

class TimelineState {
  const TimelineState({
    required this.items,
    required this.nextCursor,
    required this.isLoadingMore,
    required this.hasMore,
    required this.errorMessage,
  });

  final List<MediaPost> items;
  final String? nextCursor;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;

  TimelineState copyWith({
    List<MediaPost>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return TimelineState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }

  static const empty = TimelineState(
    items: [],
    nextCursor: null,
    isLoadingMore: false,
    hasMore: false,
    errorMessage: null,
  );
}
