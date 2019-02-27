import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) {
      return '';
    }
    DateTime date;
    if (timestamp is DateTime) {
      date = timestamp;
    } else if (timestamp is int) {
      date = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
    } else {
      return '';
    }
    return DateFormat('EEE H:mm').format(date);
  }

  void _showAlert(String content) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Oops!"),
            content: Text(content),
            actions: <Widget>[
              FlatButton(
                child: Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        });
  }

  Future<bool> _signIn() async {
    try {
      var user = _googleSignIn.currentUser;
      if (user == null) {
        _googleSignIn.signInSilently();
      }
      if (user == null) {
        user = await _googleSignIn.signIn();
      }
      if (user == null) {
        return false;
      }
      if (await _firebaseAuth.currentUser() == null) {
        var auth = await user.authentication;
        var credential = GoogleAuthProvider.getCredential(
          accessToken: auth.accessToken,
          idToken: auth.idToken,
        );
        await _firebaseAuth.signInWithCredential(credential);
      }
      return true;
    } on PlatformException catch (e) {
      _showAlert(e.code);
    } catch (e) {
      _showAlert(e.toString());
    }
    return false;
  }

  Future<Null> _send(String content, String imageUrl) async {
    if ((content == null || content.trim().isEmpty) && imageUrl == null) {
      return;
    }

    var result = await _signIn();
    if (!result) {
      return;
    }

    Firestore.instance.collection('messages').document().setData({
      'timestamp': FieldValue.serverTimestamp(),
      'from': _googleSignIn.currentUser.displayName,
      'avatar': _googleSignIn.currentUser.photoUrl,
      'content': content?.trim(),
      'img': imageUrl,
    });
    textController.clear();
  }

  Future<Null> _sendText(String content) async {
    await _send(content, null);
  }

  Future<Null> _sendPhoto() async {
    var imageFile = await ImagePicker.pickImage(
        source: ImageSource.gallery, maxWidth: 200, maxHeight: 200);
    if (imageFile == null) {
      return;
    }
    var ref = FirebaseStorage.instance
        .ref()
        .child(DateTime.now().toUtc().millisecondsSinceEpoch.toString());
    await ref.putFile(imageFile).onComplete;
    String downloadUrl = await ref.getDownloadURL();
    _send(null, downloadUrl);
  }

  Widget _buildListItem(BuildContext context, DocumentSnapshot document) {
    return Row(
      children: <Widget>[
        document['avatar'] != null
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: document['avatar'],
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              )
            : Container(
                child: Center(
                  child: Text(
                    document['from'][0],
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(16)),
              ),
        Container(
          child: Column(
            children: <Widget>[
              Text(
                document['from'] +
                    ' ' +
                    _formatTimestamp(document['timestamp']),
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              document['content'] != null
                  ? Text(
                      document['content'],
                      style: TextStyle(fontSize: 16),
                    )
                  : null,
              document['img'] != null
                  ? SizedBox(
                      child: CachedNetworkImage(
                        imageUrl: document['img'],
                        placeholder: (context, url) =>
                            Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) =>
                            Center(child: Icon(Icons.error)),
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
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 56),
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
                  return Center(child: CircularProgressIndicator());
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
          Container(
            child: Scrollbar(
              child: TextField(
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (s) async {
                  await _sendText(textController.text);
                },
                controller: textController,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Type a message...',
                  contentPadding: EdgeInsets.fromLTRB(12, 12, 6, 6),
                ),
              ),
            ),
            constraints: BoxConstraints(
              maxHeight: 96,
            ),
          ),
          Row(
            children: <Widget>[
              IconButton(
                icon: Icon(Icons.photo, color: Theme.of(context).primaryColor),
                onPressed: _sendPhoto,
              ),
              IconButton(
                icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                onPressed: () async {
                  await _sendText(textController.text);
                },
              ),
            ],
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
          ),
        ],
        crossAxisAlignment: CrossAxisAlignment.start,
      ),
    );
  }
}
