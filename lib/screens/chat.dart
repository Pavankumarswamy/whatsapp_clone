import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:whatsup/screens/chatscreen.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  _ChatsTabState createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
  List<Map<String, dynamic>> contacts = [];
  Map<String, String> contactNameMap = {};
  bool _isLoading = true;
  late SharedPreferences _prefs;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  Map<String, int> unreadMessageCounts = {};

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _initializeData();
    _setupFirebaseMessaging(); // Setup FCM for background notifications
  }

  Future<void> _initializeNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInitSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    // Request notification permissions
    await FirebaseMessaging.instance.requestPermission();
  }

  Future<void> _setupFirebaseMessaging() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showNotification(
          message.notification!.title ?? "New Message",
          message.notification!.body ?? "You have a new message",
        );
        _updateChatListFromMessage(message);
      }
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle when app is opened from a terminated state via notification
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _updateChatListFromMessage(initialMessage);
    }

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _updateChatListFromMessage(message);
    });

    // Subscribe to user-specific topic for notifications
    await FirebaseMessaging.instance.subscribeToTopic('user_$currentUserId');
  }

  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    // Initialize SharedPreferences in background
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Extract message data
    String? chatId = message.data['chatId'];
    String? contactName =
        message.notification?.title?.replaceFirst("New Message from ", "");
    String? messageText = message.notification?.body;

    if (chatId != null && contactName != null && messageText != null) {
      // Load existing contacts
      String? cachedContacts = prefs.getString('contacts');
      List<Map<String, dynamic>> contacts = cachedContacts != null
          ? List<Map<String, dynamic>>.from(jsonDecode(cachedContacts))
          : [];

      String contactId = chatId
          .replaceAll(FirebaseAuth.instance.currentUser?.uid ?? "", "")
          .replaceAll("_", "");
      int index = contacts.indexWhere((contact) => contact['id'] == contactId);

      // Update last read timestamp and unread count
      String? lastReadTimestampStr = prefs.getString('lastRead_$chatId');
      int lastReadTimestamp =
          lastReadTimestampStr != null ? int.parse(lastReadTimestampStr) : 0;
      int newTimestamp = DateTime.now().millisecondsSinceEpoch;

      if (index != -1) {
        contacts[index]['message'] = messageText.length > 15
            ? '${messageText.substring(0, 15)}....'
            : messageText;
        contacts[index]['time'] = _formatTimestampStatic(newTimestamp);

        // Update unread count
        Map<String, int> unreadCounts = Map<String, int>.from(
            jsonDecode(prefs.getString('unreadCounts') ?? '{}'));
        unreadCounts[contactId] = (unreadCounts[contactId] ?? 0) + 1;
        await prefs.setString('unreadCounts', jsonEncode(unreadCounts));

        await prefs.setString('contacts', jsonEncode(contacts));
      }

      // Show notification
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings androidInitSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings =
          InitializationSettings(android: androidInitSettings);
      await flutterLocalNotificationsPlugin.initialize(initSettings);

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'chat_channel',
        'Chat Notifications',
        importance: Importance.high,
        priority: Priority.high,
      );
      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidDetails);

      await flutterLocalNotificationsPlugin.show(
        0,
        "New Message from $contactName",
        messageText,
        notificationDetails,
      );
    }
  }

  static String _formatTimestampStatic(int timestamp) {
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    DateTime now = DateTime.now();
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return date.toString().substring(11, 16);
    }
    return date.toString().substring(0, 10);
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }

  Future<void> _updateChatListFromMessage(RemoteMessage message) async {
    String? chatId = message.data['chatId'];
    if (chatId == null || !chatId.contains(currentUserId)) return;

    String contactId = chatId.replaceAll(currentUserId, "").replaceAll("_", "");
    int index = contacts.indexWhere((contact) => contact['id'] == contactId);

    if (index != -1) {
      String messageText = message.notification?.body ?? "New message";
      var lastMessageData = {
        'message': messageText.length > 15
            ? '${messageText.substring(0, 15)}....'
            : messageText,
        'time': _formatTimestamp(DateTime.now().millisecondsSinceEpoch),
      };
      int unreadCount = await _getUnreadMessageCount(contactId);

      setState(() {
        contacts[index]['message'] = lastMessageData['message'];
        contacts[index]['time'] = lastMessageData['time'];
        contacts.sort((a, b) => b['time'].compareTo(a['time']));
        unreadMessageCounts[contactId] = unreadCount;
      });
      await _prefs.setString('contacts', jsonEncode(contacts));
      await _prefs.setString('unreadCounts', jsonEncode(unreadMessageCounts));
      print(
          "Updated chat list for ${contacts[index]['name']} with $unreadCount unread messages");
    }
  }

  Future<void> _initializeData() async {
    _prefs = await SharedPreferences.getInstance();
    await _fetchContactsFromDevice();
    await _loadContacts();
    // Load unread counts from storage
    String? unreadCountsJson = _prefs.getString('unreadCounts');
    if (unreadCountsJson != null) {
      unreadMessageCounts = Map<String, int>.from(jsonDecode(unreadCountsJson));
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchContactsFromDevice() async {
    try {
      if (await Permission.contacts.request().isGranted) {
        await FlutterContacts.requestPermission();
        List<Contact> deviceContacts =
            await FlutterContacts.getContacts(withProperties: true);
        for (Contact contact in deviceContacts) {
          if (contact.phones.isNotEmpty) {
            for (Phone phone in contact.phones) {
              String normalizedNumber = _normalizePhoneNumber(phone.number);
              contactNameMap[normalizedNumber] = contact.displayName;
            }
          }
        }
        await _prefs.setString('contactNameMap', jsonEncode(contactNameMap));
      } else {
        print("Contacts permission denied");
      }
    } catch (e) {
      print("Error fetching contacts: $e");
    }
  }

  Future<void> _loadContacts() async {
    String? cachedContactNames = _prefs.getString('contactNameMap');
    if (cachedContactNames != null) {
      contactNameMap = Map<String, String>.from(jsonDecode(cachedContactNames));
    }

    String? cachedContacts = _prefs.getString('contacts');
    if (cachedContacts != null) {
      List<Map<String, dynamic>> loadedContacts =
          List<Map<String, dynamic>>.from(jsonDecode(cachedContacts));
      contacts = loadedContacts.map((contact) {
        String normalizedNumber = _normalizePhoneNumber(contact['name']);
        if (contactNameMap.containsKey(normalizedNumber)) {
          return {
            ...contact,
            'name': contactNameMap[normalizedNumber]!,
            'isFromDevice': true,
          };
        }
        return contact;
      }).toList();
      print("Loaded and mapped contacts from local storage");
      setState(() => _isLoading = false);
    } else {
      await _fetchContactsAndMessagesFromFirebase();
    }
  }

  void _listenForUserUpdates() {
    _databaseRef.child("users").onChildChanged.listen((event) {
      String userId = event.snapshot.key!;
      int index = contacts.indexWhere((contact) => contact['id'] == userId);
      if (index != -1) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null && data['avatar'] != null) {
          setState(() {
            contacts[index]['avatar'] = data['avatar'].toString();
          });
          _prefs.setString('contacts', jsonEncode(contacts));
          print("Updated avatar for ${contacts[index]['name']}");
        }
      }
    });
  }

  Future<int> _getUnreadMessageCount(String contactId) async {
    String chatId = _getChatId(currentUserId, contactId);
    String? lastReadTimestampStr = _prefs.getString('lastRead_$chatId');
    int lastReadTimestamp =
        lastReadTimestampStr != null ? int.parse(lastReadTimestampStr) : 0;

    DataSnapshot snapshot = await _databaseRef
        .child("chats")
        .child(chatId)
        .child("messages")
        .orderByChild("timestamp")
        .startAfter(lastReadTimestamp)
        .get();

    if (snapshot.exists) {
      Map<dynamic, dynamic> messages = snapshot.value as Map<dynamic, dynamic>;
      return messages.length;
    }
    return 0;
  }

  Future<void> _fetchContactsAndMessagesFromFirebase() async {
    try {
      DataSnapshot snapshot = await _databaseRef.child("users").get();
      final usersData = snapshot.value as Map<dynamic, dynamic>?;
      if (usersData == null) return;

      List<Map<String, dynamic>> tempContacts = [];

      for (var entry in usersData.entries) {
        String userId = entry.key;
        var value = entry.value as Map<dynamic, dynamic>;
        String mobileNumber = value['mobile']?.toString() ?? 'Unknown';
        String normalizedNumber = _normalizePhoneNumber(mobileNumber);
        String? avatarUrl = value['avatar']?.toString();
        var lastMessageData = await _fetchLastMessage(userId);
        int unreadCount = await _getUnreadMessageCount(userId);

        bool isMatched = contactNameMap.containsKey(normalizedNumber);
        String displayName =
            isMatched ? contactNameMap[normalizedNumber]! : mobileNumber;

        Map<String, dynamic> contactData = {
          'id': userId,
          'name': displayName,
          'message': lastMessageData['message'],
          'time': lastMessageData['time'],
          'avatar': avatarUrl,
          'isFromDevice': isMatched,
        };

        tempContacts.add(contactData);
        unreadMessageCounts[userId] = unreadCount;
      }

      if (mounted) {
        setState(() {
          contacts = tempContacts;
          contacts.sort((a, b) => b['time'].compareTo(a['time']));
        });
        await _prefs.setString('contacts', jsonEncode(contacts));
        await _prefs.setString('unreadCounts', jsonEncode(unreadMessageCounts));
        print("Fetched and cached contacts from Firebase");
      }
    } catch (e) {
      print("Error fetching contacts and messages from Firebase: $e");
    }
    _listenForUserUpdates();
  }

  String _normalizePhoneNumber(String number) {
    String cleaned = number.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('+') && cleaned.length > 1) {
      cleaned = '+' + cleaned.substring(1).replaceFirst(RegExp(r'^0+'), '');
    }
    return cleaned;
  }

  Future<Map<String, dynamic>> _fetchLastMessage(String userId) async {
    String chatId = _getChatId(currentUserId, userId);
    DataSnapshot chatSnapshot = await _databaseRef
        .child("chats")
        .child(chatId)
        .child("messages")
        .orderByChild("timestamp")
        .limitToLast(1)
        .get();

    if (chatSnapshot.exists) {
      Map<dynamic, dynamic> messages =
          chatSnapshot.value as Map<dynamic, dynamic>;
      var lastMessageEntry = messages.entries.first;
      Map<String, dynamic> messageData =
          Map<String, dynamic>.from(lastMessageEntry.value);
      String rawMessage = messageData['image']?.isNotEmpty == true
          ? 'Image'
          : messageData['text'] ?? 'Tap to chat';
      return {
        'message': rawMessage.length > 15
            ? '${rawMessage.substring(0, 15)}....'
            : rawMessage,
        'time': _formatTimestamp(messageData['timestamp']),
      };
    }
    return {'message': 'Tap to chat', 'time': 'Now'};
  }

  String _getChatId(String user1, String user2) {
    return user1.hashCode <= user2.hashCode
        ? "${user1}_$user2"
        : "${user2}_$user1";
  }

  String _formatTimestamp(int timestamp) {
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    DateTime now = DateTime.now();
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return date.toString().substring(11, 16);
    }
    return date.toString().substring(0, 10);
  }

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    File imageFile = File(pickedFile.path);
    String fileName =
        "$currentUserId${DateTime.now().millisecondsSinceEpoch}.jpg";

    try {
      TaskSnapshot snapshot =
          await _storage.ref("avatars/$fileName").putFile(imageFile);
      String imageUrl = await snapshot.ref.getDownloadURL();
      await _databaseRef
          .child("users")
          .child(currentUserId)
          .update({"avatar": imageUrl});
      int index =
          contacts.indexWhere((contact) => contact['id'] == currentUserId);
      if (index != -1) {
        setState(() {
          contacts[index]['avatar'] = imageUrl;
        });
        await _prefs.setString('contacts', jsonEncode(contacts));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Avatar updated successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to upload avatar: $e")),
      );
    }
  }

  Future<void> _syncContacts() async {
    setState(() => _isLoading = true);
    await _fetchContactsFromDevice();
    await _fetchContactsAndMessagesFromFirebase();
    setState(() => _isLoading = false);
  }

  void _showAvatarDialog(
      BuildContext context, String? avatarUrl, bool isCurrentUser) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: Stack(
            children: [
              avatarUrl != null && avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      width: 300,
                      height: 300,
                      fit: BoxFit.cover,
                    )
                  : const CircleAvatar(
                      radius: 150,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white, size: 100),
                    ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              if (isCurrentUser)
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _uploadAvatar();
                    },
                    child: const Text("Upload Avatar"),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _syncContacts,
              child: ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  bool isCurrentUser = contacts[index]['id'] == currentUserId;
                  String? avatarUrl = contacts[index]['avatar'];
                  int unreadCount =
                      unreadMessageCounts[contacts[index]['id']] ?? 0;

                  return ListTile(
                    leading: GestureDetector(
                      onTap: () =>
                          _showAvatarDialog(context, avatarUrl, isCurrentUser),
                      child: avatarUrl != null && avatarUrl.isNotEmpty
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(avatarUrl))
                          : const CircleAvatar(
                              backgroundColor: Colors.grey,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                    ),
                    title: Text(
                      isCurrentUser
                          ? '${contacts[index]['name']} (You)'
                          : contacts[index]['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(contacts[index]['message']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          contacts[index]['time'],
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.green,
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () async {
                      String chatId =
                          _getChatId(currentUserId, contacts[index]['id']);
                      await _prefs.setString('lastRead_$chatId',
                          DateTime.now().millisecondsSinceEpoch.toString());
                      setState(() {
                        unreadMessageCounts[contacts[index]['id']] = 0;
                      });
                      await _prefs.setString(
                          'unreadCounts', jsonEncode(unreadMessageCounts));

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            contactId: contacts[index]['id'],
                            contactName: contacts[index]['name'],
                          ),
                        ),
                      ).then((_) {
                        _fetchContactsAndMessagesFromFirebase();
                      });
                    },
                  );
                },
              ),
            ),
    );
  }
}
// import 'package:flutter/material.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:image_picker/image_picker.dart';
// import 'dart:io';
// import 'package:whatsup/screens/chatscreen.dart';
// import 'package:flutter_contacts/flutter_contacts.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// class ChatsTab extends StatefulWidget {
//   const ChatsTab({super.key});

//   @override
//   _ChatsTabState createState() => _ChatsTabState();
// }

// class _ChatsTabState extends State<ChatsTab> {
//   final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
//   final FirebaseStorage _storage = FirebaseStorage.instance;
//   final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
//   List<Map<String, dynamic>> contacts = [];
//   Map<String, String> contactNameMap = {};
//   bool _isLoading = true;
//   late SharedPreferences _prefs;
//   late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
//   Map<String, int> unreadMessageCounts = {}; // Track unread messages per chat

//   @override
//   void initState() {
//     super.initState();
//     _initializeNotifications();
//     _initializeData();
//     _listenForNewMessages(); // Start listening for new messages
//   }

//   void _initializeNotifications() {
//     flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
//     const AndroidInitializationSettings androidInitSettings =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
//     const InitializationSettings initSettings =
//         InitializationSettings(android: androidInitSettings);
//     flutterLocalNotificationsPlugin.initialize(initSettings);
//   }

//   Future<void> _showNotification(String contactName, String message) async {
//     const AndroidNotificationDetails androidDetails =
//         AndroidNotificationDetails(
//       'chat_channel',
//       'Chat Notifications',
//       importance: Importance.high,
//       priority: Priority.high,
//     );
//     const NotificationDetails notificationDetails =
//         NotificationDetails(android: androidDetails);

//     await flutterLocalNotificationsPlugin.show(
//       0, // Notification ID (can be unique per message if needed)
//       "New Message from $contactName",
//       message,
//       notificationDetails,
//     );
//   }

//   Future<void> _initializeData() async {
//     _prefs = await SharedPreferences.getInstance();
//     await _fetchContactsFromDevice();
//     await _loadContacts();
//     if (mounted) {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _fetchContactsFromDevice() async {
//     try {
//       if (await Permission.contacts.request().isGranted) {
//         await FlutterContacts.requestPermission();
//         List<Contact> deviceContacts =
//             await FlutterContacts.getContacts(withProperties: true);
//         for (Contact contact in deviceContacts) {
//           if (contact.phones.isNotEmpty) {
//             for (Phone phone in contact.phones) {
//               String normalizedNumber = _normalizePhoneNumber(phone.number);
//               contactNameMap[normalizedNumber] = contact.displayName;
//             }
//           }
//         }
//         await _prefs.setString('contactNameMap', jsonEncode(contactNameMap));
//       } else {
//         print("Contacts permission denied");
//       }
//     } catch (e) {
//       print("Error fetching contacts: $e");
//     }
//   }

//   Future<void> _loadContacts() async {
//     String? cachedContactNames = _prefs.getString('contactNameMap');
//     if (cachedContactNames != null) {
//       contactNameMap = Map<String, String>.from(jsonDecode(cachedContactNames));
//     }

//     String? cachedContacts = _prefs.getString('contacts');
//     if (cachedContacts != null) {
//       List<Map<String, dynamic>> loadedContacts =
//           List<Map<String, dynamic>>.from(jsonDecode(cachedContacts));
//       contacts = loadedContacts.map((contact) {
//         String normalizedNumber = _normalizePhoneNumber(contact['name']);
//         if (contactNameMap.containsKey(normalizedNumber)) {
//           return {
//             ...contact,
//             'name': contactNameMap[normalizedNumber]!,
//             'isFromDevice': true,
//           };
//         }
//         return contact;
//       }).toList();
//       print("Loaded and mapped contacts from local storage");
//       setState(() => _isLoading = false);
//     } else {
//       await _fetchContactsAndMessagesFromFirebase();
//     }
//   }

//   void _listenForNewMessages() {
//     _databaseRef.child("chats").onChildChanged.listen((event) async {
//       String chatId = event.snapshot.key!;
//       if (!chatId.contains(currentUserId)) return;

//       String contactId =
//           chatId.replaceAll(currentUserId, "").replaceAll("_", "");
//       int index = contacts.indexWhere((contact) => contact['id'] == contactId);

//       if (index != -1) {
//         var lastMessageData = await _fetchLastMessage(contactId);
//         int unreadCount = await _getUnreadMessageCount(contactId);

//         setState(() {
//           contacts[index]['message'] = lastMessageData['message'];
//           contacts[index]['time'] = lastMessageData['time'];
//           contacts.sort((a, b) => b['time'].compareTo(a['time']));
//           unreadMessageCounts[contactId] = unreadCount;
//         });
//         await _prefs.setString('contacts', jsonEncode(contacts));

//         // Show notification for new message
//         if (unreadCount > 0) {
//           _showNotification(
//             contacts[index]['name'],
//             lastMessageData['message'],
//           );
//         }

//         print("Updated last message for ${contacts[index]['name']}");
//       }
//     });

//     // Listen for avatar updates
//     _databaseRef.child("users").onChildChanged.listen((event) {
//       String userId = event.snapshot.key!;
//       int index = contacts.indexWhere((contact) => contact['id'] == userId);
//       if (index != -1) {
//         final data = event.snapshot.value as Map<dynamic, dynamic>?;
//         if (data != null && data['avatar'] != null) {
//           setState(() {
//             contacts[index]['avatar'] = data['avatar'].toString();
//           });
//           _prefs.setString('contacts', jsonEncode(contacts));
//           print("Updated avatar for ${contacts[index]['name']}");
//         }
//       }
//     });
//   }

//   Future<int> _getUnreadMessageCount(String contactId) async {
//     String chatId = _getChatId(currentUserId, contactId);
//     String? lastReadTimestampStr = _prefs.getString('lastRead_$chatId');
//     int lastReadTimestamp =
//         lastReadTimestampStr != null ? int.parse(lastReadTimestampStr) : 0;

//     DataSnapshot snapshot = await _databaseRef
//         .child("chats")
//         .child(chatId)
//         .child("messages")
//         .orderByChild("timestamp")
//         .startAfter(lastReadTimestamp)
//         .get();

//     if (snapshot.exists) {
//       Map<dynamic, dynamic> messages = snapshot.value as Map<dynamic, dynamic>;
//       return messages.length;
//     }
//     return 0;
//   }

//   Future<void> _fetchContactsAndMessagesFromFirebase() async {
//     try {
//       DataSnapshot snapshot = await _databaseRef.child("users").get();
//       final usersData = snapshot.value as Map<dynamic, dynamic>?;
//       if (usersData == null) return;

//       List<Map<String, dynamic>> tempContacts = [];

//       for (var entry in usersData.entries) {
//         String userId = entry.key;
//         var value = entry.value as Map<dynamic, dynamic>;
//         String mobileNumber = value['mobile']?.toString() ?? 'Unknown';
//         String normalizedNumber = _normalizePhoneNumber(mobileNumber);
//         String? avatarUrl = value['avatar']?.toString();
//         var lastMessageData = await _fetchLastMessage(userId);
//         int unreadCount = await _getUnreadMessageCount(userId);

//         bool isMatched = contactNameMap.containsKey(normalizedNumber);
//         String displayName =
//             isMatched ? contactNameMap[normalizedNumber]! : mobileNumber;

//         Map<String, dynamic> contactData = {
//           'id': userId,
//           'name': displayName,
//           'message': lastMessageData['message'],
//           'time': lastMessageData['time'],
//           'avatar': avatarUrl,
//           'isFromDevice': isMatched,
//         };

//         tempContacts.add(contactData);
//         unreadMessageCounts[userId] = unreadCount;
//       }

//       if (mounted) {
//         setState(() {
//           contacts = tempContacts;
//           contacts.sort((a, b) => b['time'].compareTo(a['time']));
//         });
//         await _prefs.setString('contacts', jsonEncode(contacts));
//         print("Fetched and cached contacts from Firebase");
//       }
//     } catch (e) {
//       print("Error fetching contacts and messages from Firebase: $e");
//     }
//   }

//   String _normalizePhoneNumber(String number) {
//     String cleaned = number.replaceAll(RegExp(r'[^\d+]'), '');
//     if (cleaned.startsWith('+') && cleaned.length > 1) {
//       cleaned = '+' + cleaned.substring(1).replaceFirst(RegExp(r'^0+'), '');
//     }
//     return cleaned;
//   }

//   Future<Map<String, dynamic>> _fetchLastMessage(String userId) async {
//     String chatId = _getChatId(currentUserId, userId);
//     DataSnapshot chatSnapshot = await _databaseRef
//         .child("chats")
//         .child(chatId)
//         .child("messages")
//         .orderByChild("timestamp")
//         .limitToLast(1)
//         .get();

//     if (chatSnapshot.exists) {
//       Map<dynamic, dynamic> messages =
//           chatSnapshot.value as Map<dynamic, dynamic>;
//       var lastMessageEntry = messages.entries.first;
//       Map<String, dynamic> messageData =
//           Map<String, dynamic>.from(lastMessageEntry.value);
//       String rawMessage = messageData['image']?.isNotEmpty == true
//           ? 'Image'
//           : messageData['text'] ?? 'Tap to chat';
//       return {
//         'message': rawMessage.length > 15
//             ? '${rawMessage.substring(0, 15)}....'
//             : rawMessage,
//         'time': _formatTimestamp(messageData['timestamp']),
//       };
//     }
//     return {'message': 'Tap to chat', 'time': 'Now'};
//   }

//   String _getChatId(String user1, String user2) {
//     return user1.hashCode <= user2.hashCode
//         ? "${user1}_$user2"
//         : "${user2}_$user1";
//   }

//   String _formatTimestamp(int timestamp) {
//     DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
//     DateTime now = DateTime.now();
//     if (date.day == now.day &&
//         date.month == now.month &&
//         date.year == now.year) {
//       return date.toString().substring(11, 16);
//     }
//     return date.toString().substring(0, 10);
//   }

//   Future<void> _uploadAvatar() async {
//     final picker = ImagePicker();
//     final pickedFile = await picker.pickImage(source: ImageSource.gallery);
//     if (pickedFile == null) return;

//     File imageFile = File(pickedFile.path);
//     String fileName =
//         "$currentUserId${DateTime.now().millisecondsSinceEpoch}.jpg";

//     try {
//       TaskSnapshot snapshot =
//           await _storage.ref("avatars/$fileName").putFile(imageFile);
//       String imageUrl = await snapshot.ref.getDownloadURL();
//       await _databaseRef
//           .child("users")
//           .child(currentUserId)
//           .update({"avatar": imageUrl});
//       int index =
//           contacts.indexWhere((contact) => contact['id'] == currentUserId);
//       if (index != -1) {
//         setState(() {
//           contacts[index]['avatar'] = imageUrl;
//         });
//         await _prefs.setString('contacts', jsonEncode(contacts));
//       }
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Avatar updated successfully")),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Failed to upload avatar: $e")),
//       );
//     }
//   }

//   Future<void> _syncContacts() async {
//     setState(() => _isLoading = true);
//     await _fetchContactsFromDevice();
//     await _fetchContactsAndMessagesFromFirebase();
//     setState(() => _isLoading = false);
//   }

//   void _showAvatarDialog(
//       BuildContext context, String? avatarUrl, bool isCurrentUser) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           contentPadding: EdgeInsets.zero,
//           content: Stack(
//             children: [
//               avatarUrl != null && avatarUrl.isNotEmpty
//                   ? Image.network(
//                       avatarUrl,
//                       width: 300,
//                       height: 300,
//                       fit: BoxFit.cover,
//                     )
//                   : const CircleAvatar(
//                       radius: 150,
//                       backgroundColor: Colors.grey,
//                       child: Icon(Icons.person, color: Colors.white, size: 100),
//                     ),
//               Positioned(
//                 top: 10,
//                 right: 10,
//                 child: IconButton(
//                   icon: const Icon(Icons.close),
//                   onPressed: () => Navigator.of(context).pop(),
//                 ),
//               ),
//               if (isCurrentUser)
//                 Positioned(
//                   bottom: 10,
//                   right: 10,
//                   child: ElevatedButton(
//                     onPressed: () async {
//                       Navigator.of(context).pop();
//                       await _uploadAvatar();
//                     },
//                     child: const Text("Upload Avatar"),
//                   ),
//                 ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: Colors.white,
//       child: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : RefreshIndicator(
//               onRefresh: _syncContacts,
//               child: ListView.builder(
//                 itemCount: contacts.length,
//                 itemBuilder: (context, index) {
//                   bool isCurrentUser = contacts[index]['id'] == currentUserId;
//                   String? avatarUrl = contacts[index]['avatar'];
//                   int unreadCount =
//                       unreadMessageCounts[contacts[index]['id']] ?? 0;

//                   return ListTile(
//                     leading: GestureDetector(
//                       onTap: () =>
//                           _showAvatarDialog(context, avatarUrl, isCurrentUser),
//                       child: avatarUrl != null && avatarUrl.isNotEmpty
//                           ? CircleAvatar(
//                               backgroundImage: NetworkImage(avatarUrl))
//                           : const CircleAvatar(
//                               backgroundColor: Colors.grey,
//                               child: Icon(Icons.person, color: Colors.white),
//                             ),
//                     ),
//                     title: Text(
//                       isCurrentUser
//                           ? '${contacts[index]['name']} (You)'
//                           : contacts[index]['name'],
//                       style: const TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                     subtitle: Text(contacts[index]['message']),
//                     trailing: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Text(
//                           contacts[index]['time'],
//                           style:
//                               const TextStyle(color: Colors.grey, fontSize: 12),
//                         ),
//                         if (unreadCount > 0) ...[
//                           const SizedBox(width: 8),
//                           CircleAvatar(
//                             radius: 10,
//                             backgroundColor: Colors.green,
//                             child: Text(
//                               unreadCount.toString(),
//                               style: const TextStyle(
//                                   color: Colors.white, fontSize: 12),
//                             ),
//                           ),
//                         ],
//                       ],
//                     ),
//                     onTap: () async {
//                       // Update last read timestamp when opening chat
//                       String chatId =
//                           _getChatId(currentUserId, contacts[index]['id']);
//                       await _prefs.setString('lastRead_$chatId',
//                           DateTime.now().millisecondsSinceEpoch.toString());
//                       setState(() {
//                         unreadMessageCounts[contacts[index]['id']] = 0;
//                       });

//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => ChatScreen(
//                             contactId: contacts[index]['id'],
//                             contactName: contacts[index]['name'],
//                           ),
//                         ),
//                       ).then((_) {
//                         // Refresh unread count when returning
//                         _fetchContactsAndMessagesFromFirebase();
//                       });
//                     },
//                   );
//                 },
//               ),
//             ),
//     );
//   }
// }
