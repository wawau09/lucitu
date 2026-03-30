const String supabaseUrl = 'https://mgebziaamxgrhudurklz.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1nZWJ6aWFhbXhncmh1ZHVya2x6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk1MzU5MjUsImV4cCI6MjA2NTExMTkyNX0.mKMtBL4j2wQwO7FR-2OWtjthxzfiYNuGGEqpmYr3QCM';

const String supabaseStorageBucket = String.fromEnvironment(
  'SUPABASE_STORAGE_BUCKET',
  defaultValue: 'stores',
);
