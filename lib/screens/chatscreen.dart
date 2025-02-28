// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart';

// class ChatScreen extends StatefulWidget {
//   final String contactId;
//   final String contactName;

//   const ChatScreen({
//     super.key,
//     required this.contactId,
//     required this.contactName,
//   });

//   @override
//   _ChatScreenState createState() => _ChatScreenState();
// }

// class _ChatScreenState extends State<ChatScreen> {
//   final TextEditingController _messageController = TextEditingController();
//   final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
//   final FirebaseStorage _storage = FirebaseStorage.instance;
//   final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
//   late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
//   final Set<String> _processedMessageIds = {};
//   late int _startTimestamp;
//   late ScrollController _scrollController;
//   String? contactAvatarUrl; // Store contact's avatar URL

//   @override
//   void initState() {
//     super.initState();
//     _startTimestamp = DateTime.now().millisecondsSinceEpoch;
//     _initializeNotifications();
//     _listenForNewMessages();
//     _scrollController = ScrollController();
//     _fetchContactAvatar(); // Fetch avatar on initialization
//   }

//   @override
//   void dispose() {
//     _scrollController.dispose();
//     _messageController.dispose();
//     super.dispose();
//   }

//   void _fetchContactAvatar() {
//     _databaseRef.child("users").child(widget.contactId).once().then((event) {
//       final data = event.snapshot.value as Map<dynamic, dynamic>?;
//       if (data != null && data['avatar'] != null) {
//         setState(() {
//           contactAvatarUrl = data['avatar'].toString();
//         });
//       }
//     });
//   }

//   void _scrollToBottom() {
//     if (_scrollController.hasClients) {
//       _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
//     }
//   }

//   void _initializeNotifications() {
//     flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
//     const AndroidInitializationSettings androidInitSettings =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
//     const InitializationSettings initSettings =
//         InitializationSettings(android: androidInitSettings);
//     flutterLocalNotificationsPlugin.initialize(initSettings);
//   }

//   Future<void> _showNotification(String message, {String? imageUrl}) async {
//     const AndroidNotificationDetails androidBaseDetails =
//         AndroidNotificationDetails(
//       'chat_channel',
//       'Chat Notifications',
//       importance: Importance.high,
//       priority: Priority.high,
//     );

//     if (imageUrl != null && imageUrl.isNotEmpty) {
//       File? imageFile = await _downloadImage(imageUrl);
//       if (imageFile != null) {
//         final BigPictureStyleInformation bigPictureStyle =
//             BigPictureStyleInformation(
//           FilePathAndroidBitmap(imageFile.path),
//           largeIcon: FilePathAndroidBitmap(imageFile.path),
//           contentTitle: "New Image from ${widget.contactName}",
//           summaryText: "Image received",
//         );

//         final AndroidNotificationDetails androidImageDetails =
//             AndroidNotificationDetails(
//           'chat_channel',
//           'Chat Notifications',
//           importance: Importance.high,
//           priority: Priority.high,
//           styleInformation: bigPictureStyle,
//         );

//         await flutterLocalNotificationsPlugin.show(
//           0,
//           "New Image from ${widget.contactName}",
//           "Image received",
//           NotificationDetails(android: androidImageDetails),
//         );
//         return;
//       }
//     }

//     await flutterLocalNotificationsPlugin.show(
//       0,
//       "New Message from ${widget.contactName}",
//       message,
//       const NotificationDetails(android: androidBaseDetails),
//     );
//   }

//   Future<File?> _downloadImage(String url) async {
//     try {
//       final response = await http.get(Uri.parse(url));
//       if (response.statusCode == 200) {
//         final tempDir = await getTemporaryDirectory();
//         final file = File(
//             '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
//         await file.writeAsBytes(response.bodyBytes);
//         return file;
//       }
//     } catch (e) {
//       print("Failed to download image: $e");
//     }
//     return null;
//   }

//   void _listenForNewMessages() {
//     String chatId = _getChatId(currentUserId, widget.contactId);
//     DatabaseReference chatRef =
//         _databaseRef.child("chats").child(chatId).child("messages");

//     chatRef.orderByChild("timestamp").onChildAdded.listen((event) {
//       if (event.snapshot.value == null) return;

//       Map<String, dynamic> message =
//           Map<String, dynamic>.from(event.snapshot.value as Map);
//       String messageId = event.snapshot.key!;
//       int messageTimestamp = message["timestamp"];

//       if (messageTimestamp <= _startTimestamp ||
//           _processedMessageIds.contains(messageId) ||
//           message["sender"] == currentUserId) {
//         return;
//       }

//       _showNotification(
//         message["text"] ?? "Image received",
//         imageUrl: message["image"],
//       );
//       _processedMessageIds.add(messageId);
//     });
//   }

//   void _sendMessage({String? imageUrl}) {
//     if (_messageController.text.isEmpty && imageUrl == null) return;

//     String chatId = _getChatId(currentUserId, widget.contactId);
//     DatabaseReference chatRef =
//         _databaseRef.child("chats").child(chatId).child("messages").push();

//     chatRef.set({
//       "sender": currentUserId,
//       "text": imageUrl == null ? _messageController.text : "",
//       "image": imageUrl ?? "",
//       "timestamp": DateTime.now().millisecondsSinceEpoch,
//     });

//     _messageController.clear();
//   }

//   Future<void> _pickAndUploadImage() async {
//     final picker = ImagePicker();
//     final pickedFile = await picker.pickImage(source: ImageSource.gallery);
//     if (pickedFile == null) return;

//     File imageFile = File(pickedFile.path);
//     String fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";

//     try {
//       TaskSnapshot snapshot =
//           await _storage.ref("chat_images/$fileName").putFile(imageFile);
//       String imageUrl = await snapshot.ref.getDownloadURL();
//       _sendMessage(imageUrl: imageUrl);
//     } catch (e) {
//       print("Image upload failed: $e");
//     }
//   }

//   String _getChatId(String user1, String user2) {
//     return user1.hashCode <= user2.hashCode
//         ? "${user1}_$user2"
//         : "${user2}_$user1";
//   }

//   @override
//   Widget build(BuildContext context) {
//     String chatId = _getChatId(currentUserId, widget.contactId);
//     DatabaseReference chatRef =
//         _databaseRef.child("chats").child(chatId).child("messages");

//     return Scaffold(
//       appBar: AppBar(
//         title: Row(
//           children: [
//             Padding(
//               padding: const EdgeInsets.only(left: 10),
//               child: contactAvatarUrl != null && contactAvatarUrl!.isNotEmpty
//                   ? CircleAvatar(
//                       backgroundImage: NetworkImage(contactAvatarUrl!),
//                     )
//                   : const CircleAvatar(
//                       backgroundColor: Colors.grey,
//                       child: Icon(Icons.person, color: Colors.white),
//                     ),
//             ),
//             const SizedBox(width: 10),
//             Expanded(
//               child: Text(
//                 widget.contactName.length > 7
//                     ? "${widget.contactName.substring(0, 6)}..."
//                     : widget.contactName,
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
//           IconButton(icon: const Icon(Icons.call), onPressed: () {}),
//           IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
//         ],
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: StreamBuilder(
//               stream: chatRef.orderByChild("timestamp").onValue,
//               builder: (context, snapshot) {
//                 if (!snapshot.hasData ||
//                     snapshot.data?.snapshot.value == null) {
//                   return const Center(child: Text("No messages yet"));
//                 }

//                 Map<dynamic, dynamic> messages =
//                     (snapshot.data?.snapshot.value as Map<dynamic, dynamic>?) ??
//                         {};
//                 List<Map<String, dynamic>> messageList = messages.entries
//                     .map((entry) => {
//                           "key": entry.key.toString(),
//                           ...Map<String, dynamic>.from(entry.value)
//                         })
//                     .toList();
//                 messageList
//                     .sort((a, b) => a["timestamp"].compareTo(b["timestamp"]));

//                 WidgetsBinding.instance.addPostFrameCallback((_) {
//                   _scrollToBottom();
//                 });

//                 return ListView.builder(
//                   controller: _scrollController,
//                   padding: const EdgeInsets.all(8.0),
//                   itemCount: messageList.length,
//                   itemBuilder: (context, index) {
//                     Map<String, dynamic> message = messageList[index];
//                     bool isSentByMe = message["sender"] == currentUserId;

//                     return Align(
//                       alignment: isSentByMe
//                           ? Alignment.centerRight
//                           : Alignment.centerLeft,
//                       child: Container(
//                         margin: const EdgeInsets.symmetric(vertical: 4.0),
//                         padding: const EdgeInsets.all(10.0),
//                         decoration: BoxDecoration(
//                           color: isSentByMe
//                               ? const Color(0xFFD9FDD3)
//                               : Colors.white,
//                           borderRadius: BorderRadius.circular(8.0),
//                         ),
//                         child: Column(
//                           crossAxisAlignment: isSentByMe
//                               ? CrossAxisAlignment.end
//                               : CrossAxisAlignment.start,
//                           children: [
//                             if (message["image"] != null &&
//                                 message["image"].isNotEmpty)
//                               ClipRRect(
//                                 borderRadius: BorderRadius.circular(8),
//                                 child:
//                                     Image.network(message["image"], width: 200),
//                               )
//                             else
//                               Text(message["text"]),
//                             const SizedBox(height: 4),
//                             Text(
//                               DateTime.fromMillisecondsSinceEpoch(
//                                       message["timestamp"])
//                                   .toString()
//                                   .substring(11, 16),
//                               style: const TextStyle(
//                                   fontSize: 10, color: Colors.grey),
//                             ),
//                           ],
//                         ),
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//           _buildMessageInput(),
//         ],
//       ),
//     );
//   }

//   Widget _buildMessageInput() {
//     return Container(
//       padding: const EdgeInsets.all(8.0),
//       color: Colors.white,
//       child: Row(
//         children: [
//           IconButton(icon: const Icon(Icons.emoji_emotions), onPressed: () {}),
//           Expanded(
//             child: TextField(
//               controller: _messageController,
//               decoration: InputDecoration(
//                 hintText: 'Type a message',
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(20.0),
//                   borderSide: BorderSide.none,
//                 ),
//                 filled: true,
//                 fillColor: Colors.grey[200],
//               ),
//             ),
//           ),
//           IconButton(
//               icon: const Icon(Icons.attach_file),
//               onPressed: _pickAndUploadImage),
//           IconButton(
//               icon: const Icon(Icons.send), onPressed: () => _sendMessage()),
//         ],
//       ),
//     );
//   }
// }
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  final String contactId;
  final String contactName;

  const ChatScreen({
    super.key,
    required this.contactId,
    required this.contactName,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  final Set<String> _processedMessageIds = {};
  late int _lastTimestamp;
  late ScrollController _scrollController;
  String? contactAvatarUrl;
  late SharedPreferences _prefs;
  List<Map<String, dynamic>> _cachedMessages = [];

  @override
  void initState() {
    super.initState();
    _lastTimestamp = 0;
    _scrollController = ScrollController();
    _initializeNotifications();
    _fetchContactAvatar();
    _initializePrefs();
  }

  Future<void> _initializePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadCachedMessages();
    _listenForNewMessages();
    // Scroll to bottom after initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Future<void> _loadCachedMessages() async {
    String chatId = _getChatId(currentUserId, widget.contactId);
    String? cachedMessages = _prefs.getString('chat_$chatId');

    if (cachedMessages != null) {
      setState(() {
        _cachedMessages =
            List<Map<String, dynamic>>.from(jsonDecode(cachedMessages));
        if (_cachedMessages.isNotEmpty) {
          _lastTimestamp = _cachedMessages.last['timestamp'];
          for (var message in _cachedMessages) {
            _processedMessageIds.add(message['key']);
          }
        }
      });
      print(
          "Messages fetched from local storage: ${_cachedMessages.length} messages");
    }
  }

  Future<void> _saveMessagesToCache(List<Map<String, dynamic>> messages) async {
    String chatId = _getChatId(currentUserId, widget.contactId);
    await _prefs.setString('chat_$chatId', jsonEncode(messages));
    print("Messages stored in local storage: ${messages.length} messages");
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _fetchContactAvatar() {
    _databaseRef.child("users").child(widget.contactId).once().then((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && data['avatar'] != null) {
        setState(() {
          contactAvatarUrl = data['avatar'].toString();
        });
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _initializeNotifications() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInitSettings);
    flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  Future<void> _showNotification(String message, {String? imageUrl}) async {
    const AndroidNotificationDetails androidBaseDetails =
        AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    if (imageUrl != null && imageUrl.isNotEmpty) {
      File? imageFile = await _downloadImage(imageUrl);
      if (imageFile != null) {
        final BigPictureStyleInformation bigPictureStyle =
            BigPictureStyleInformation(
          FilePathAndroidBitmap(imageFile.path),
          largeIcon: FilePathAndroidBitmap(imageFile.path),
          contentTitle: "New Image from ${widget.contactName}",
          summaryText: "Image received",
        );

        final AndroidNotificationDetails androidImageDetails =
            AndroidNotificationDetails(
          'chat_channel',
          'Chat Notifications',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: bigPictureStyle,
        );

        await flutterLocalNotificationsPlugin.show(
          0,
          "New Image from ${widget.contactName}",
          "Image received",
          NotificationDetails(android: androidImageDetails),
        );
        return;
      }
    }

    await flutterLocalNotificationsPlugin.show(
      0,
      "New Message from ${widget.contactName}",
      message,
      const NotificationDetails(android: androidBaseDetails),
    );
  }

  Future<File?> _downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File(
            '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
    } catch (e) {
      print("Failed to download image: $e");
    }
    return null;
  }

  void _listenForNewMessages() {
    String chatId = _getChatId(currentUserId, widget.contactId);
    DatabaseReference chatRef =
        _databaseRef.child("chats").child(chatId).child("messages");

    chatRef
        .orderByChild("timestamp")
        .startAfter(_lastTimestamp)
        .onChildAdded
        .listen((event) {
      if (event.snapshot.value == null) return;

      Map<String, dynamic> message =
          Map<String, dynamic>.from(event.snapshot.value as Map);
      String messageId = event.snapshot.key!;

      if (_processedMessageIds.contains(messageId)) {
        print("Duplicate message detected and skipped: $messageId");
        return;
      }

      setState(() {
        _cachedMessages.add({"key": messageId, ...message});
        _cachedMessages
            .sort((a, b) => a["timestamp"].compareTo(b["timestamp"]));
        _lastTimestamp = message["timestamp"];
      });
      _saveMessagesToCache(_cachedMessages);
      print(
          "New message fetched and stored: ${message["text"] ?? "Image"} from ${message["sender"]}");

      if (message["sender"] != currentUserId) {
        _showNotification(
          message["text"] ?? "Image received",
          imageUrl: message["image"],
        );
      }
      _processedMessageIds.add(messageId);

      // Schedule scroll after UI update
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    });
  }

  void _sendMessage({String? imageUrl}) {
    if (_messageController.text.isEmpty && imageUrl == null) return;

    String chatId = _getChatId(currentUserId, widget.contactId);
    DatabaseReference chatRef =
        _databaseRef.child("chats").child(chatId).child("messages").push();

    String messageId = chatRef.key!;
    _processedMessageIds.add(messageId);

    Map<String, dynamic> messageData = {
      "sender": currentUserId,
      "text": imageUrl == null ? _messageController.text : "",
      "image": imageUrl ?? "",
      "timestamp": DateTime.now().millisecondsSinceEpoch,
    };

    setState(() {
      _cachedMessages.add({"key": messageId, ...messageData});
      _cachedMessages.sort((a, b) => a["timestamp"].compareTo(b["timestamp"]));
      _lastTimestamp = messageData["timestamp"];
    });
    _saveMessagesToCache(_cachedMessages);

    chatRef.set(messageData).then((_) {
      print("Message sent and stored: ${messageData["text"] ?? "Image"}");
    }).catchError((error) {
      print("Failed to send message: $error");
      setState(() {
        _cachedMessages.removeWhere((msg) => msg["key"] == messageId);
      });
      _processedMessageIds.remove(messageId);
      _saveMessagesToCache(_cachedMessages);
    });

    _messageController.clear();

    // Schedule scroll after UI update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    File imageFile = File(pickedFile.path);
    String fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";

    try {
      TaskSnapshot snapshot =
          await _storage.ref("chat_images/$fileName").putFile(imageFile);
      String imageUrl = await snapshot.ref.getDownloadURL();
      _sendMessage(imageUrl: imageUrl);
    } catch (e) {
      print("Image upload failed: $e");
    }
  }

  String _getChatId(String user1, String user2) {
    return user1.hashCode <= user2.hashCode
        ? "${user1}_$user2"
        : "${user2}_$user1";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: contactAvatarUrl != null && contactAvatarUrl!.isNotEmpty
                  ? CircleAvatar(
                      backgroundImage: NetworkImage(contactAvatarUrl!))
                  : const CircleAvatar(
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.contactName.length > 7
                    ? "${widget.contactName.substring(0, 6)}..."
                    : widget.contactName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _cachedMessages.length,
              itemBuilder: (context, index) {
                Map<String, dynamic> message = _cachedMessages[index];
                bool isSentByMe = message["sender"] == currentUserId;

                return Align(
                  alignment:
                      isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color:
                          isSentByMe ? const Color(0xFFD9FDD3) : Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      crossAxisAlignment: isSentByMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (message["image"] != null &&
                            message["image"].isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(message["image"], width: 200),
                          )
                        else
                          Text(message["text"]),
                        const SizedBox(height: 4),
                        Text(
                          DateTime.fromMillisecondsSinceEpoch(
                                  message["timestamp"])
                              .toString()
                              .substring(11, 16),
                          style:
                              const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.emoji_emotions), onPressed: () {}),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
          IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _pickAndUploadImage),
          IconButton(
              icon: const Icon(Icons.send), onPressed: () => _sendMessage()),
        ],
      ),
    );
  }
}
