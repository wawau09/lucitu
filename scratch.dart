import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

void main() async {
  await Supabase.initialize(
    url: 'https://mgebziaamxgrhudurklz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1nZWJ6aWFhbXhncmh1ZHVya2x6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk1MzU5MjUsImV4cCI6MjA2NTExMTkyNX0.mKMtBL4j2wQwO7FR-2OWtjthxzfiYNuGGEqpmYr3QCM',
  );
  
  final client = Supabase.instance.client;
  final data = await client.from('store').select().limit(1);
  print(data);
  exit(0);
}
