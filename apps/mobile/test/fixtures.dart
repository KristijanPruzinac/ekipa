const eventJson = {
  'id': 'student-concert',
  'title': 'Studentski koncert',
  'description': 'Koncert u dvorištu kampusa.',
  'startsAt': '2026-10-03T18:00:00Z',
  'endsAt': null,
  'venue': 'Kampus Osijek',
  'address': null,
  'city': 'Osijek',
  'category': 'music',
  'price': null,
  'status': 'scheduled',
  'sources': [
    {'sourceName': 'Organizator', 'url': 'https://example.org/koncert'},
  ],
  'discovery': {
    'audiences': ['students'],
    'audienceEvidence': [
      {
        'audience': 'students',
        'reason': 'Organizator izričito poziva studente.',
        'sourceUrl': 'https://example.org/koncert',
      },
    ],
    'prominence': null,
    'free': false,
  },
};

Map<String, dynamic> feedJson() => {
  'events': [
    eventJson,
    {
      ...eventJson,
      'id': 'theatre',
      'title': 'Gradska predstava',
      'startsAt': '2026-10-03T16:00:00Z',
      'category': 'theatre',
      'discovery': null,
    },
  ],
  'meta': {
    'now': '2026-10-03T12:00:00Z',
    'lastCheckedAt': '2026-10-03T10:00:00Z',
    'timezone': 'Europe/Zagreb',
    'city': 'Osijek',
    'sourceCount': 1,
    'totalUpcoming': 2,
  },
};
