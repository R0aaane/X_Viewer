class DummyXApiClient {
  Future<List<Map<String, dynamic>>> fetchHomeTimeline({String? cursor}) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    return [
      {
        'id': '1900111001',
        'text': 'Spring sketch set with four color variations.',
        'created_at': '2026-03-22T09:00:00Z',
        'author': {
          'name': 'Aki Canvas',
          'username': 'aki_canvas',
        },
        'media': [
          {
            'media_key': '3_1001',
            'type': 'photo',
            'url':
                'https://images.unsplash.com/photo-1515405295579-ba7b45403062?auto=format&fit=crop&w=900&q=80',
            'width': 900,
            'height': 1200,
          },
          {
            'media_key': '3_1002',
            'type': 'photo',
            'url':
                'https://images.unsplash.com/photo-1511300636408-a63a89df3482?auto=format&fit=crop&w=900&q=80',
            'width': 900,
            'height': 1200,
          },
        ],
      },
      {
        'id': '1900111002',
        'text': 'Work in progress note.',
        'created_at': '2026-03-21T12:30:00Z',
        'author': {
          'name': 'LineDraft',
          'username': 'line_draft',
        },
        'media': [],
      },
      {
        'id': '1900111003',
        'text': 'New cover art is ready.',
        'created_at': '2026-03-20T04:10:00Z',
        'author': {
          'name': 'Mina Works',
          'username': 'mina_works',
        },
        'media': [
          {
            'media_key': '3_1003',
            'type': 'photo',
            'url':
                'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?auto=format&fit=crop&w=900&q=80',
            'width': 900,
            'height': 900,
          },
        ],
      },
      {
        'id': '1900111004',
        'text': 'Reference video.',
        'created_at': '2026-03-18T15:45:00Z',
        'author': {
          'name': 'Motion Lab',
          'username': 'motion_lab',
        },
        'media': [
          {
            'media_key': '7_9999',
            'type': 'video',
            'url': 'https://example.com/video.mp4',
            'width': 1280,
            'height': 720,
          },
        ],
      },
    ];
  }
}
