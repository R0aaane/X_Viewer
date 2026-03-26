import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitterviewer/data/adapters/x_timeline_adapter.dart';
import 'package:twitterviewer/data/datasources/x_api_client.dart';
import 'package:twitterviewer/data/mappers/x_timeline_includes_mapper.dart';
import 'package:twitterviewer/data/models/x_api_timeline_response.dart';
import 'package:twitterviewer/data/repositories/reposted_image_repository_impl.dart';
import 'package:twitterviewer/domain/models/auth_session.dart';
import 'package:twitterviewer/domain/models/login_mode.dart';
import 'package:twitterviewer/services/auth_persistence_service.dart';
import 'package:twitterviewer/services/secure_token_storage_service.dart';
import 'package:twitterviewer/services/timeline_media_extractor.dart';
import 'package:twitterviewer/services/x_timeline_request_builder.dart';

void main() {
  group('RepostedImageRepositoryImpl.fetchNext', () {
    late _FakeXApiClient apiClient;
    late RepostedImageRepositoryImpl repository;

    setUp(() {
      apiClient = _FakeXApiClient();
      repository = RepostedImageRepositoryImpl(
        apiClient,
        XTimelineAdapter(const XTimelineIncludesMapper()),
        TimelineMediaExtractor(),
        _FakeAuthPersistenceService(),
      );
    });

    test('continues pagination when first page has no image reposts', () async {
      apiClient.enqueueResponse(
        _response(
          data: [
            _nonImageTweet(id: 'tweet-1'),
          ],
          meta: {
            'result_count': 1,
            'next_token': 'next-2',
          },
        ),
      );
      apiClient.enqueueResponse(
        _response(
          data: [
            _retweetWrapper(id: 'wrapper-2', originalId: 'original-2'),
          ],
          includes: {
            'tweets': [
              _imageTweet(
                id: 'original-2',
                authorId: 'user-original',
                mediaKey: 'media-2',
              ),
            ],
            'users': [
              _user(id: 'user-self', username: 'self'),
              _user(id: 'user-original', username: 'alice'),
            ],
            'media': [
              _media(key: 'media-2'),
            ],
          },
          meta: {
            'result_count': 1,
            'next_token': 'next-3',
          },
        ),
      );

      final page = await repository.fetchNext(paginationToken: 'next-1');

      expect(apiClient.requestedPaginationTokens, ['next-1', 'next-2']);
      expect(page.posts, hasLength(1));
      expect(page.posts.single.postId, 'original-2');
      expect(page.nextCursor, 'next-3');
      expect(page.hasNextPage, isTrue);
    });

    test('keeps scanning across multiple empty pages until image repost appears', () async {
      apiClient.enqueueResponse(
        _response(
          data: [_nonImageTweet(id: 'tweet-1')],
          meta: {'result_count': 1, 'next_token': 'next-2'},
        ),
      );
      apiClient.enqueueResponse(
        _response(
          data: [_nonImageTweet(id: 'tweet-2')],
          meta: {'result_count': 1, 'next_token': 'next-3'},
        ),
      );
      apiClient.enqueueResponse(
        _response(
          data: [
            _retweetWrapper(id: 'wrapper-3', originalId: 'original-3'),
          ],
          includes: {
            'tweets': [
              _imageTweet(
                id: 'original-3',
                authorId: 'user-original',
                mediaKey: 'media-3',
              ),
            ],
            'users': [
              _user(id: 'user-self', username: 'self'),
              _user(id: 'user-original', username: 'alice'),
            ],
            'media': [
              _media(key: 'media-3'),
            ],
          },
          meta: {'result_count': 1},
        ),
      );

      final page = await repository.fetchNext(paginationToken: 'next-1');

      expect(apiClient.requestedPaginationTokens, ['next-1', 'next-2', 'next-3']);
      expect(page.posts, hasLength(1));
      expect(page.hasNextPage, isFalse);
    });

    test('only reports end when next token is missing', () async {
      apiClient.enqueueResponse(
        _response(
          data: [_nonImageTweet(id: 'tweet-end')],
          meta: {'result_count': 1},
        ),
      );

      final page = await repository.fetchNext(paginationToken: 'next-end');

      expect(apiClient.requestedPaginationTokens, ['next-end']);
      expect(page.posts, isEmpty);
      expect(page.hasNextPage, isFalse);
      expect(page.nextCursor, isNull);
    });
  });

  group('XTimelineRequestBuilder.buildUserTweets', () {
    test('does not include exclude=retweets for repost lookup', () {
      final parameters = const XTimelineRequestBuilder().buildUserTweets(
        type: TimelineRequestType.next,
        paginationToken: 'next-token',
      );

      expect(parameters.containsKey('exclude'), isFalse);
      expect(parameters['pagination_token'], 'next-token');
    });
  });
}

class _FakeXApiClient extends XApiClient {
  _FakeXApiClient()
      : super(
          dio: Dio(),
          requestBuilder: const XTimelineRequestBuilder(),
        );

  final List<XApiTimelineResponse> _responses = <XApiTimelineResponse>[];
  final List<String> requestedPaginationTokens = <String>[];

  void enqueueResponse(XApiTimelineResponse response) {
    _responses.add(response);
  }

  @override
  Future<XApiTimelineResponse> fetchUserTweets({
    required String accessToken,
    required String userId,
    required TimelineRequestType requestType,
    required String requestReason,
    String? sinceId,
    String? paginationToken,
  }) async {
    requestedPaginationTokens.add(paginationToken ?? '');
    return _responses.removeAt(0);
  }
}

class _FakeAuthPersistenceService extends AuthPersistenceService {
  _FakeAuthPersistenceService() : super(const SecureTokenStorageService());

  @override
  Future<AuthSession?> getSession() async {
    return const AuthSession(
      userId: 'user-self',
      username: 'self',
      displayName: 'Self',
      loginMode: LoginMode.xOAuth,
      accessToken: 'token',
    );
  }
}

XApiTimelineResponse _response({
  required List<Map<String, dynamic>> data,
  Map<String, List<Map<String, dynamic>>> includes =
      const <String, List<Map<String, dynamic>>>{},
  Map<String, dynamic> meta = const <String, dynamic>{},
}) {
  return XApiTimelineResponse(
    data: data,
    includes: includes,
    meta: meta,
    errors: const [],
  );
}

Map<String, dynamic> _nonImageTweet({required String id}) {
  return {
    'id': id,
    'author_id': 'user-self',
    'text': 'plain text',
    'created_at': '2026-03-24T10:00:00.000Z',
  };
}

Map<String, dynamic> _retweetWrapper({
  required String id,
  required String originalId,
}) {
  return {
    'id': id,
    'author_id': 'user-self',
    'text': 'RT',
    'created_at': '2026-03-24T10:01:00.000Z',
    'referenced_tweets': [
      {
        'type': 'retweeted',
        'id': originalId,
      },
    ],
  };
}

Map<String, dynamic> _imageTweet({
  required String id,
  required String authorId,
  required String mediaKey,
}) {
  return {
    'id': id,
    'author_id': authorId,
    'text': 'image post',
    'created_at': '2026-03-24T09:00:00.000Z',
    'attachments': {
      'media_keys': [mediaKey],
    },
  };
}

Map<String, dynamic> _user({
  required String id,
  required String username,
}) {
  return {
    'id': id,
    'name': username,
    'username': username,
  };
}

Map<String, dynamic> _media({required String key}) {
  return {
    'media_key': key,
    'type': 'photo',
    'url': 'https://example.com/$key.jpg',
    'width': 120,
    'height': 120,
  };
}
