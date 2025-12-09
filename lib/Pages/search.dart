import 'package:flutter/material.dart';
import 'package:placelist/DB/store_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SearchPage extends StatefulWidget{
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => Search();
}

class Search extends State<SearchPage> {
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

  String getFolderImage(String folder, String name) {
    final publicUrl = supabase.storage
    .from('image')
    .getPublicUrl('$folder/$name.jpeg');

    return publicUrl;
  }

  Future<String> getFolder(int id) async {
    final response = await supabase
        .from('stores')
        .select('folder_name')
        .eq('id', id)   // 'name' 대신 'id' 컬럼과 비교합니다.
        .maybeSingle();

    return response?['folder_name']?.toString() ?? "0";
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder(
        stream: storesDatabase.stream,
        builder: (context, snapshot) {
          if(!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stores = snapshot.data!;
          
          return GridView.builder(
            itemCount: stores.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2), 
            itemBuilder: (context, index) {
              // return Padding(
              //   padding: const EdgeInsets.all(8.0),
              //   child: Container(
              //     height: 200,
              //     width: 200,
              //     child: Image.network(getFolderImage(snapshot.data ?? 'test', "1"))
              //   ),
              // );
              return buildCard(index);
            }
          );
        }
      )
    );
  }
}