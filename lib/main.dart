import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutters',
      theme: ThemeData(
        primarySwatch: Colors.teal,
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
  GoogleSignIn _googleSignIn = GoogleSignIn();
  FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final textController = TextEditingController();

  Future<bool> _signIn() async {
    if (_googleSignIn.currentUser == null || await _firebaseAuth.currentUser() == null) {
      try {
        var user = await _googleSignIn.signIn();
        var auth = await user.authentication;
        var credential = GoogleAuthProvider.getCredential(
          accessToken: auth.accessToken,
          idToken: auth.idToken,
        );
        await _firebaseAuth.signInWithCredential(credential);
      } catch (e) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("Oops!"),
              content: Text(e.toString()),
              actions: <Widget>[
                FlatButton(
                  child: Text("OK"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                )
              ],
            );
          }
        );
        return false;
      }
    }
    return true;
  }

  Future<Null> _send(String content, String imageUrl) async {
    if ((content == null || content.isEmpty) && (imageUrl == null || imageUrl.isEmpty)) {
      return;
    }

    var result = await _signIn();
    if (!result) {
      return;
    }

    Firestore.instance.collection('messages').document().setData({
      'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch,
      'from': _googleSignIn.currentUser.displayName,
      'avatar': _googleSignIn.currentUser.photoUrl,
      'content': content,
      'img': imageUrl,
    });
    textController.clear();
  }

  Future<Null> _sendText(String content) async {
    await _send(content, null);
  }

  Future<Null> _sendPhoto() async {
    var imageFile = await ImagePicker.pickImage(source: ImageSource.gallery);
    var ref = FirebaseStorage.instance.ref().child(DateTime.now().toUtc().millisecondsSinceEpoch.toString());
    await ref.putFile(imageFile).onComplete;
    String downloadUrl = await ref.getDownloadURL();
    _send(null, downloadUrl);
  }

  Widget _buildListItem(BuildContext context, DocumentSnapshot document) {
    return Row(
      children: <Widget>[
        document['avatar'] != null ?
          ClipOval(
            child: CachedNetworkImage(
              imageUrl: document['avatar'],
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          )
        :
        Container(child:
          Center(child:
            Text(
              document['from'][0],
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: Colors.green, borderRadius: BorderRadius.circular(16)
          )
        ),
        Container(
          child: Column(
            children: <Widget>[
              Text(
                document['from'] + ' ' + DateFormat('EEE H:mm').format(DateTime.fromMillisecondsSinceEpoch(document['timestamp'])),
                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              document['content'] != null ?
                Text(
                  document['content'],
                  style: TextStyle(fontSize: 16),
                )
              : null,
              document['img'] != null ?
                SizedBox(
                  child: CachedNetworkImage(
                    imageUrl: document['img'],
                    placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => Center(child: Icon(Icons.error)),
                    fit: BoxFit.cover,
                  ),
                  width: 200,
                  height: 200,
                )
              : null,
            ].where((w) => w != null).toList(),
            crossAxisAlignment: CrossAxisAlignment.start,
          ),
          margin: EdgeInsets.only(left: 8),
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: Colors.grey[200], borderRadius: BorderRadius.circular(4)
          ),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 56),
        ),
      ],
      crossAxisAlignment: CrossAxisAlignment.start,
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
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: Text('Loading...'));
                }
                return ListView.separated(
                  separatorBuilder: (context, index) => Container(
                        height: 4,
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
                    onSubmitted: (s) async {
                      await _sendText(textController.text);
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
                onPressed: () async {
                  await _sendText(textController.text);
                },
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.photo, color: Theme.of(context).primaryColor),
            onPressed: _sendPhoto,
          ),
        ],
        crossAxisAlignment: CrossAxisAlignment.start,
      ),
    );
  }
}
