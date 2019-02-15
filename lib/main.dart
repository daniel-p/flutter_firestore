import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutters',
      theme: ThemeData(
        primarySwatch: Colors.cyan,
        canvasColor: Colors.white,
      ),
      home: MyHomePage(title: 'Flutters'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final textController = TextEditingController();

  void _send(String content) {
    if (content.isNotEmpty) {
      Firestore.instance.collection('messages').document().setData({
        'content': content,
        'from': 'Me',
        'timestamp': new DateTime.now().millisecondsSinceEpoch
      });
      textController.clear();
      FocusScope.of(context).requestFocus(new FocusNode());
    }
  }

  Widget _buildListItem(BuildContext context, DocumentSnapshot document) {
    return Row(
      children: <Widget>[
        Container(
          child: Column(
            children: <Widget>[
              Text(
                document['from'],
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                document['content'],
                style: TextStyle(fontSize: 16),
              ),
            ],
            crossAxisAlignment: CrossAxisAlignment.start,
          ),
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
              color: Colors.grey[200], borderRadius: BorderRadius.circular(4)
          ),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 16),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: StreamBuilder(
              stream: Firestore.instance
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text('Loading...');
                }
                return ListView.separated(
                  separatorBuilder: (context, index) => Container(
                        height: 5,
                      ),
                  itemBuilder: (context, index) =>
                      _buildListItem(context, snapshot.data.documents[index]),
                  itemCount: snapshot.data.documents.length,
                  reverse: true,
                  padding: EdgeInsets.all(8),
                );
              },
            ),
          ),
          Divider(height: 1),
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  child: TextField(
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    onSubmitted: (s) {
                      _send(textController.text);
                    },
                    controller: textController,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Type a message...',
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                onPressed: () {
                  _send(textController.text);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
