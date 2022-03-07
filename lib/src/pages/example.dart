import 'package:flutter/material.dart';
import 'package:hn_app/src/favorites.dart';
import 'package:provider/provider.dart';
import 'package:hn_app/src/widgets/hn_page.dart';

class ExamplePage extends StatefulWidget {
  @override
  _ExamplePageState createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {

  @override
  Widget build(BuildContext context) {
    print('Inside example widget');
    // TODO: add comments to the favorites page.
    return Scaffold(
      appBar: AppBar(
        title: Text("FAVORITES"),
      ),
      body: Text('Example')
    );
  }
}
