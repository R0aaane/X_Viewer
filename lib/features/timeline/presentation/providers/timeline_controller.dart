import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/adapters/x_timeline_adapter.dart';
import '../../../../data/datasources/dummy_x_api_client.dart';
import '../../../../data/repositories/timeline_repository_impl.dart';
import '../../../../domain/models/media_post.dart';
import '../../../../domain/repositories/timeline_repository.dart';
import '../../../../services/timeline_media_extractor.dart';

final dummyXApiClientProvider = Provider<DummyXApiClient>(
  (ref) => DummyXApiClient(),
);

final xTimelineAdapterProvider = Provider<XTimelineAdapter>(
  (ref) => XTimelineAdapter(),
);

final timelineMediaExtractorProvider = Provider<TimelineMediaExtractor>(
  (ref) => TimelineMediaExtractor(),
);

final timelineRepositoryProvider = Provider<TimelineRepository>((ref) {
  return TimelineRepositoryImpl(
    ref.watch(dummyXApiClientProvider),
    ref.watch(xTimelineAdapterProvider),
    ref.watch(timelineMediaExtractorProvider),
  );
});

final timelineControllerProvider =
    AsyncNotifierProvider<TimelineController, List<MediaPost>>(
  TimelineController.new,
);

class TimelineController extends AsyncNotifier<List<MediaPost>> {
  @override
  Future<List<MediaPost>> build() {
    return ref.read(timelineRepositoryProvider).fetchTimelinePosts();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(timelineRepositoryProvider).fetchTimelinePosts(),
    );
  }
}
