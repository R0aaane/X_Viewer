abstract final class XApiConstants {
  static const baseUrl = 'https://api.x.com/2';
  static const reverseChronologicalTimelinePath =
      '/users/{id}/timelines/reverse_chronological';
  static const maxResults = 40;

  static const expansions = <String>[
    'attachments.media_keys',
    'author_id',
    'referenced_tweets.id',
    'referenced_tweets.id.attachments.media_keys',
    'referenced_tweets.id.author_id',
  ];

  static const tweetFields = <String>[
    'attachments',
    'author_id',
    'created_at',
    'entities',
    'id',
    'note_tweet',
    'referenced_tweets',
    'text',
  ];

  static const mediaFields = <String>[
    'height',
    'media_key',
    'preview_image_url',
    'type',
    'url',
    'width',
  ];

  static const userFields = <String>[
    'id',
    'name',
    'username',
  ];

  static const defaultExclude = <String>[
    'replies',
  ];
}
