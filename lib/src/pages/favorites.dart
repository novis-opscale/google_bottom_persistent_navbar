import 'package:flutter/material.dart';
import 'package:hn_app/src/favorites.dart';
import 'package:provider/provider.dart';
import 'package:hn_app/src/widgets/hn_page.dart';

class FavoritesPage extends StatefulWidget {
  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late List<Favorite> _favorites;

  @override
  void initState() {
    super.initState();
    _favorites = [];
  }

  @override
  Widget build(BuildContext context) {
    var myDatabase = Provider.of<MyDatabase>(context);

    // TODO: add comments to the favorites page.
    return Scaffold(
      appBar: AppBar(
        title: Text("FAVORITES"),
      ),
      body: Text('Hello')
    );
  }
}
