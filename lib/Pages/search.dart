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
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20.0), // 모든 모서리를 20픽셀 둥글게
                  ),
                ),
              );
            }
          );
        }
      )
    );
  }
}