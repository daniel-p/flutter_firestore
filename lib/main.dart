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
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));
    return MaterialApp(
      title: 'Flutters',
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          elevation: 1.2,
          brightness: Brightness.light,
          color: Colors.white,
          textTheme: Theme.of(context).textTheme.apply(bodyColor: Colors.black),
          iconTheme: Theme.of(context)
              .iconTheme
              .copyWith(color: Theme.of(context).primaryColor),
        ),
        iconTheme: Theme.of(context)
            .iconTheme
            .copyWith(color: Theme.of(context).primaryColor),
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

  Future<Null> _showAlert(String content, [String title = "Oops!"]) {
    return showDialog<Null>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: <Widget>[
              FlatButton(
                key: Key("okAlertButton"),
                child: Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  Future<bool> _showPrompt(String content, [String title = "Hey!"]) {
    return showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: <Widget>[
              FlatButton(
                key: Key("cancelPromptButton"),
                child: Text("Cancel"),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              FlatButton(
                key: Key("okPromptButton"),
                child: Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
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
      await _showAlert(e.code);
    } catch (e) {
      await _showAlert(e.toString());
    }
    return false;
  }

  Future<bool> _signOut() async {
    try {
      if (await _firebaseAuth.currentUser() != null) {
        if (await _showPrompt("Sign out?") != true) {
          return false;
        }
        await _firebaseAuth.signOut();
      }
      if (_googleSignIn.currentUser != null) {
        await _googleSignIn.signOut();
        await _showAlert("You have signed out", "Cya!");
      }
      return true;
    } on PlatformException catch (e) {
      await _showAlert(e.code);
    } catch (e) {
      await _showAlert(e.toString());
    }
    return false;
  }

  Future<Null> _send(String content, String imageUrl) async {
    if ((content == null || content.trim().isEmpty) && imageUrl == null) {
      return;
    }

    if (await _signIn() != true) {
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

  Future<Null> _sendPhoto(ImageSource source) async {
    var imageFile = await ImagePicker.pickImage(
        source: source, maxWidth: 200, maxHeight: 400);
    if (imageFile == null) {
      return;
    }
    if (await _signIn() != true) {
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
                    style: TextStyle(color: Colors.white, fontSize: 20),
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
                    color: Colors.black54,
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
                        width: 200,
                        height: 200,
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
            color: Colors.grey[100],
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
        actions: <Widget>[
          IconButton(
            key: Key("signOutButton"),
            icon: Icon(Icons.exit_to_app),
            onPressed: () => _signOut(),
          ),
        ],
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
                return Scrollbar(
                  child: ListView.separated(
                    key: Key("messagesListView"),
                    separatorBuilder: (context, index) => Container(
                          height: 4,
                        ),
                    itemBuilder: (context, index) =>
                        _buildListItem(context, snapshot.data.documents[index]),
                    itemCount: snapshot.data.documents.length,
                    reverse: true,
                    padding: EdgeInsets.all(8),
                  ),
                );
              },
            ),
          ),
          Divider(height: 1),
          Container(
            child: Scrollbar(
              child: TextField(
                key: Key("messageTextField"),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (s) => _sendText(textController.text),
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
                key: Key("galleryButton"),
                icon: Icon(Icons.photo),
                onPressed: () => _sendPhoto(ImageSource.gallery),
              ),
              IconButton(
                key: Key("cameraButton"),
                icon: Icon(Icons.camera_alt),
                onPressed: () => _sendPhoto(ImageSource.camera),
              ),
              IconButton(
                key: Key("sendButton"),
                icon: Icon(Icons.send),
                onPressed: () => _sendText(textController.text),
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
