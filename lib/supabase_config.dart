const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://mgebziaamxgrhudurklz.supabase.co',
);

const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1nZWJ6aWFhbXhncmh1ZHVya2x6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk1MzU5MjUsImV4cCI6MjA2NTExMTkyNX0.mKMtBL4j2wQwO7FR-2OWtjthxzfiYNuGGEqpmYr3QCM',
);

const String supabaseStorageBucket = String.fromEnvironment(
  'SUPABASE_STORAGE_BUCKET',
  defaultValue: 'image',
);

const String naverMapClientId = String.fromEnvironment(
  'NAVER_MAP_CLIENT_ID',
  defaultValue: '0w1sxphr42', // 모바일 앱 (Android, iOS)
);

const String naverMapWebClientId = String.fromEnvironment(
  'NAVER_MAP_WEB_CLIENT_ID',
  defaultValue: 'yai391e7li', // 웹 (Web Dynamic Map)
);

