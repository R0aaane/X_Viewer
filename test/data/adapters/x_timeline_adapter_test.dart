import 'package:flutter_test/flutter_test.dart';
import 'package:twitterviewer/data/adapters/x_timeline_adapter.dart';
import 'package:twitterviewer/data/mappers/x_timeline_includes_mapper.dart';
import 'package:twitterviewer/data/models/x_api_timeline_response.dart';

void main() {
  late XTimelineAdapter adapter;

  setUp(() {
    adapter = XTimelineAdapter(const XTimelineIncludesMapper());
  });

  group('XTimelineAdapter.fromApiResponse', () {
    test('keeps normal posts unchanged', () {
      final response = XApiTimelineResponse.fromJson({
        'data': [
          {
            'id': 'tweet-1',
            'author_id': 'user-1',
            'text': 'normal post',
            'created_at': '2026-03-24T10:00:00.000Z',
            'attachments': {
              'media_keys': ['media-1'],
            },
          },
        ],
        'includes': {
          'users': [
            {
              'id': 'user-1',
              'name': 'Alice',
              'username': 'alice',
            },
          ],
          'media': [
            {
              'media_key': 'media-1',
              'type': 'photo',
              'url': 'https://example.com/1.jpg',
              'width': 100,
              'height': 200,
            },
          ],
        },
        'meta': {'result_count': 1},
      });

      final page = adapter.fromApiResponse(response);

      expect(page.posts, hasLength(1));
      final post = page.posts.single;
      expect(post.postId, 'tweet-1');
      expect(post.authorName, 'Alice');
      expect(post.authorUsername, 'alice');
      expect(post.originalAuthorName, 'Alice');
      expect(post.originalAuthorUsername, 'alice');
      expect(post.reposterName, isNull);
      expect(post.reposterUsername, isNull);
      expect(post.text, 'normal post');
      expect(post.images, hasLength(1));
    });

    test('uses original post author for retweets', () {
      final response = XApiTimelineResponse.fromJson({
        'data': [
          {
            'id': 'tweet-retweet',
            'author_id': 'user-reposter',
            'text': 'RT @original',
            'created_at': '2026-03-24T10:05:00.000Z',
            'referenced_tweets': [
              {
                'type': 'retweeted',
                'id': 'tweet-original',
              },
            ],
          },
        ],
        'includes': {
          'tweets': [
            {
              'id': 'tweet-original',
              'author_id': 'user-original',
              'text': 'original post',
              'created_at': '2026-03-24T09:00:00.000Z',
              'attachments': {
                'media_keys': ['media-1'],
              },
            },
          ],
          'users': [
            {
              'id': 'user-reposter',
              'name': 'Bob',
              'username': 'bob',
            },
            {
              'id': 'user-original',
              'name': 'Alice',
              'username': 'alice',
            },
          ],
          'media': [
            {
              'media_key': 'media-1',
              'type': 'photo',
              'url': 'https://example.com/1.jpg',
              'width': 100,
              'height': 200,
            },
          ],
        },
        'meta': {'result_count': 1},
      });

      final page = adapter.fromApiResponse(response);

      expect(page.posts, hasLength(1));
      final post = page.posts.single;
      expect(post.postId, 'tweet-original');
      expect(post.authorName, 'Alice');
      expect(post.authorUsername, 'alice');
      expect(post.originalAuthorName, 'Alice');
      expect(post.originalAuthorUsername, 'alice');
      expect(post.reposterName, 'Bob');
      expect(post.reposterUsername, 'bob');
      expect(post.text, 'original post');
      expect(post.originalPostUrl, 'https://x.com/alice/status/tweet-original');
    });

    test('falls back safely when retweeted source tweet is missing', () {
      final response = XApiTimelineResponse.fromJson({
        'data': [
          {
            'id': 'tweet-retweet',
            'author_id': 'user-reposter',
            'text': 'fallback post',
            'created_at': '2026-03-24T10:05:00.000Z',
            'referenced_tweets': [
              {
                'type': 'retweeted',
                'id': 'tweet-original-missing',
              },
            ],
            'attachments': {
              'media_keys': ['media-1'],
            },
          },
        ],
        'includes': {
          'users': [
            {
              'id': 'user-reposter',
              'name': 'Bob',
              'username': 'bob',
            },
          ],
          'media': [
            {
              'media_key': 'media-1',
              'type': 'photo',
              'url': 'https://example.com/1.jpg',
              'width': 100,
              'height': 200,
            },
          ],
        },
        'meta': {'result_count': 1},
      });

      final page = adapter.fromApiResponse(response);

      expect(page.posts, hasLength(1));
      final post = page.posts.single;
      expect(post.postId, 'tweet-retweet');
      expect(post.authorName, 'Bob');
      expect(post.authorUsername, 'bob');
      expect(post.originalAuthorName, 'Bob');
      expect(post.originalAuthorUsername, 'bob');
      expect(post.reposterName, isNull);
      expect(post.reposterUsername, isNull);
      expect(post.text, 'fallback post');
    });

    test('uses original tweet media keys for retweets with images', () {
      final response = XApiTimelineResponse.fromJson({
        'data': [
          {
            'id': 'tweet-retweet',
            'author_id': 'user-reposter',
            'text': 'retweet wrapper',
            'created_at': '2026-03-24T10:05:00.000Z',
            'attachments': {
              'media_keys': ['media-wrapper'],
            },
            'referenced_tweets': [
              {
                'type': 'retweeted',
                'id': 'tweet-original',
              },
            ],
          },
        ],
        'includes': {
          'tweets': [
            {
              'id': 'tweet-original',
              'author_id': 'user-original',
              'text': 'original with images',
              'created_at': '2026-03-24T09:00:00.000Z',
              'attachments': {
                'media_keys': ['media-original'],
              },
            },
          ],
          'users': [
            {
              'id': 'user-reposter',
              'name': 'Bob',
              'username': 'bob',
            },
            {
              'id': 'user-original',
              'name': 'Alice',
              'username': 'alice',
            },
          ],
          'media': [
            {
              'media_key': 'media-wrapper',
              'type': 'photo',
              'url': 'https://example.com/wrapper.jpg',
              'width': 100,
              'height': 200,
            },
            {
              'media_key': 'media-original',
              'type': 'photo',
              'url': 'https://example.com/original.jpg',
              'width': 300,
              'height': 400,
            },
          ],
        },
        'meta': {'result_count': 1},
      });

      final page = adapter.fromApiResponse(response);

      expect(page.posts, hasLength(1));
      final post = page.posts.single;
      expect(post.images, hasLength(1));
      expect(post.images.single.mediaKey, 'media-original');
      expect(post.images.single.imageUrl, 'https://example.com/original.jpg');
      expect(post.authorName, 'Alice');
      expect(post.reposterName, 'Bob');
    });
  });
}
