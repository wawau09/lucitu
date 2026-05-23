import 'dart:io';
import 'package:supabase/supabase.dart';
import 'lib/supabase_config.dart';

void main() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  
  try {
    print('Testing store update with select...');
    final response = await client.from('stores').update({
      'reviews': [
        {'drink': 5.0, 'hygiene': 4.0, 'atmosphere': 5.0, 'final': 4.5}
      ]
    }).eq('id', 18).select();
    
    print('Update response: $response');
  } catch (e) {
    print('Update error: $e');
  }

  exit(0);
}
