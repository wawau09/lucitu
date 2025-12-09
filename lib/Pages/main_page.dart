import 'package:flutter/material.dart';
import 'package:placelist/DB/store_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class MainPage extends StatefulWidget{
  const MainPage({super.key});

  @override
  State<MainPage> createState() => Main();
}

class Main extends State<MainPage> {
  final storesDatabase = StoreDatabase();
  final storeController = TextEditingController();

  final supabase = Supabase.instance.client;

  Future<String> getID(int id) async {
    final response = await supabase
        .from('stores')
        .select('name')
        .eq('id', id)
        .maybeSingle();

    return response?['name']?.toString() ?? "NULL";
  }

  Future<String> getImageID(int id) async {
        final response = await supabase
        .from('stores')
        .select('image_id')
        .eq('id', id)
        .maybeSingle();

    return response?['image_id']?.toString() ?? "0";
  }

  Future<String> getFolder(int id) async {
    final response = await supabase
        .from('stores')
        .select('folder_name')
        .eq('id', id)   // 'name' 대신 'id' 컬럼과 비교합니다.
        .maybeSingle();

    return response?['folder_name']?.toString() ?? "0";
  }

  String getImage(String name) {
    final publicUrl = supabase.storage
    .from('image')
    .getPublicUrl('test/$name.jpeg');

    return publicUrl;
  }

  String getFolderImage(String folder, String name) {
    final publicUrl = supabase.storage
    .from('image')
    .getPublicUrl('$folder/$name.jpeg');

    return publicUrl;
  }

  Future<List<String>> getFolders() async {
    final response = await supabase.storage
        .from('your-bucket')
        .list(path: ''); // 루트 경로

    // response는 List<StorageItem>
    return response
        .where((item) => item.metadata == null) // 폴더는 metadata == null 이다
        .map((item) => item.name)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
    return const Center(
      child: Text(
        '검색 기능 개발 진행중',
        style: TextStyle(fontSize: 16),
      ),
    );
  }

    return Scaffold(
      backgroundColor: Colors.white,        
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
          ),
          StreamBuilder(
            stream: storesDatabase.stream,
            builder: (context, snapshot) {
              if(!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final stores = snapshot.data!;

              return SizedBox(
                height: 250,
                child: ListView.builder(
                  padding: EdgeInsets.all(5),
                  scrollDirection: Axis.horizontal,
                  itemCount: stores.length,
                  itemBuilder: (context, index) {
                    Padding(padding: EdgeInsets.all(100));
                    return buildCard(index);
                  },
                ),
              );
            }
          )
        ],
      )
    );
  }

  Widget buildCard(int index) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: FutureBuilder<String>(
          future: getFolder(index),
          builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
            if(!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            } else {
              return SizedBox(width: 200, height: 200, child: Image.network(getFolderImage(snapshot.data ?? 'test', "1")));
            }
          }
        )
      ),
      const SizedBox(height: 10, child: Padding(padding: EdgeInsets.only(right: 220))),
      FutureBuilder<String>(
        future: getID(index),
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          if(!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return Text(overflow: TextOverflow.ellipsis, snapshot.data ?? '');
          }
        },
      ),
    ],
  );
}