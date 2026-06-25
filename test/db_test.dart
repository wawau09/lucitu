import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:placelist/supabase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyLocalStorage extends LocalStorage {
  const MyLocalStorage();
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() async => null;
  @override
  Future<bool> hasAccessToken() async => false;
  @override
  Future<void> persistSession(String session) async {}
  @override
  Future<void> removePersistedSession() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Check database tables and columns', () async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    
    final client = Supabase.instance.client;
    try {
      final List<dynamic> data = await client.from('cafes').select('id, name').order('id');
      print('Total stores fetched: ${data.length}');
      for (var row in data) {
        print('Store ID ${row['id']} (${row['name']})');
      }
    } catch (e) {
      print('Error querying stores table: $e');
    }
  });
}
