import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// === बैकग्राउंड नोटिफिकेशन हैंडलर (जब ऐप बंद हो) ===
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Background message received: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    print("Firebase init error: $e");
  }
  runApp(const HiiApp());
}

class HiiApp extends StatelessWidget {
  const HiiApp({super.key});

  static const String apiKey = 'AIzaSyA1Dg_ospNbgXatGj4xnWq-1njNc5Y0dCY';
  static const String dbUrl = 'https://irsad-b0b2d-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const int currentAppVersion = 3;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'hii',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF818CF8),
        ),
      ),
      home: const AuthCheck(),
    );
  }
}

// ================= GLASSY CONTAINER =================
class GlassyContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final double opacity;

  const GlassyContainer({
    super.key, 
    required this.child, 
    this.borderRadius = 20, 
    this.padding = const EdgeInsets.all(20), 
    this.opacity = 0.1
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class BackgroundGradient extends StatelessWidget {
  final Widget child;
  const BackgroundGradient({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF312E81), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

// ================= AUTH SCREEN =================
class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});
  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  bool isLoading = true;
  String? token, uid, username;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token');
    uid = prefs.getString('auth_uid');
    username = prefs.getString('auth_username');
    
    if (token != null && uid != null) {
      if (username == null || username!.isEmpty) {
        final res = await http.get(Uri.parse('${HiiApp.dbUrl}/users/$uid/username.json?auth=$token'));
        if (res.statusCode == 200 && res.body != 'null') {
          username = jsonDecode(res.body);
          await prefs.setString('auth_username', username!);
          if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen(token: token!, uid: uid!, username: username!)));
        } else {
          if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => UsernameScreen(token: token!, uid: uid!)));
        }
      } else {
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen(token: token!, uid: uid!, username: username!)));
      }
    } else {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: BackgroundGradient(child: Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))));
    return const AuthScreen();
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true, isLoading = false;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> _authenticate() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) return;
    setState(() => isLoading = true);
    
    final url = isLogin 
        ? 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${HiiApp.apiKey}'
        : 'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${HiiApp.apiKey}';

    try {
      final res = await http.post(Uri.parse(url), body: jsonEncode({'email': emailController.text.trim(), 'password': passwordController.text.trim(), 'returnSecureToken': true}));
      final data = jsonDecode(res.body);
      
      if (data['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error']['message'])));
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['idToken']);
        await prefs.setString('auth_uid', data['localId']);
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => UsernameScreen(token: data['idToken'], uid: data['localId'])));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Internet Error!')));
    }
    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundGradient(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: GlassyContainer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('hii', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -2)),
                  const SizedBox(height: 30),
                  TextField(controller: emailController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Email', labelStyle: const TextStyle(color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
                  const SizedBox(height: 15),
                  TextField(controller: passwordController, obscureText: true, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Password', labelStyle: const TextStyle(color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
                  const SizedBox(height: 25),
                  isLoading 
                    ? const CircularProgressIndicator(color: Color(0xFF38BDF8)) 
                    : SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: _authenticate, child: Text(isLogin ? 'Login' : 'Sign Up', style: const TextStyle(color: Colors.white, fontSize: 18)))),
                  TextButton(onPressed: () => setState(() => isLogin = !isLogin), child: Text(isLogin ? 'Create Account' : 'Back to Login', style: const TextStyle(color: Colors.white70)))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================= SETUP USERNAME =================
class UsernameScreen extends StatefulWidget {
  final String token, uid;
  const UsernameScreen({super.key, required this.token, required this.uid});
  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final usernameController = TextEditingController();
  bool isLoading = false;

  Future<void> _saveUsername() async {
    String un = usernameController.text.trim().toLowerCase();
    if (un.isEmpty || un.contains(' ')) return;
    setState(() => isLoading = true);

    final checkRes = await http.get(Uri.parse('${HiiApp.dbUrl}/usernames/$un.json?auth=${widget.token}'));
    if (checkRes.body != 'null') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username already taken!')));
      setState(() => isLoading = false);
      return;
    }

    await http.put(Uri.parse('${HiiApp.dbUrl}/usernames/$un.json?auth=${widget.token}'), body: jsonEncode(widget.uid));
    await http.put(Uri.parse('${HiiApp.dbUrl}/users/${widget.uid}/username.json?auth=${widget.token}'), body: jsonEncode(un));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_username', un);

    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen(token: widget.token, uid: widget.uid, username: un)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundGradient(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: GlassyContainer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.alternate_email, size: 60, color: Colors.white),
                  const SizedBox(height: 20),
                  const Text('Create Your Username', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 20),
                  TextField(controller: usernameController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(prefixText: '@', prefixStyle: const TextStyle(color: Colors.white70, fontSize: 16), labelText: 'Unique Username', labelStyle: const TextStyle(color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
                  const SizedBox(height: 20),
                  isLoading ? const CircularProgressIndicator(color: Color(0xFF38BDF8)) : SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)), onPressed: _saveUsername, child: const Text('Save & Continue', style: TextStyle(color: Colors.white)))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================= HOME SCREEN =================
class HomeScreen extends StatefulWidget {
  final String token, uid, username;
  const HomeScreen({super.key, required this.token, required this.uid, required this.username});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, String>> chats = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _checkForUpdates();
    _setupNotifications(); // नोटिफिकेशन्स चालू करने का फंक्शन
  }

  // --- नोटिफिकेशन सेटअप ---
  Future<void> _setupNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(); // यूज़र से परमिशन मांगना

    // जब ऐप खुला हो और नया मैसेज आए
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${message.notification!.title}: ${message.notification!.body}', style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF38BDF8),
          behavior: SnackBarBehavior.floating,
        ));
      }
    });
  }

  // --- इन-ऐप अपडेट सिस्टम ---
  Future<void> _checkForUpdates() async {
    try {
      final res = await http.get(Uri.parse('${HiiApp.dbUrl}/app_config.json'));
      if (res.statusCode == 200 && res.body != 'null') {
        final data = jsonDecode(res.body);
        int latestVersion = data['latest_version'] ?? 1;
        String updateUrl = data['update_url'] ?? '';
        
        if (latestVersion > HiiApp.currentAppVersion && updateUrl.isNotEmpty) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (c) => AlertDialog(
                backgroundColor: const Color(0xFF1E293B),
                title: const Text('Update Available! 🚀', style: TextStyle(color: Colors.white)),
                content: const Text('A new, faster version of hii is ready. Update now to continue chatting without losing any data.', style: TextStyle(color: Colors.white70)),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
                    onPressed: () async {
                      if (!await launchUrl(Uri.parse(updateUrl), mode: LaunchMode.externalApplication)) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open download link!')));
                      }
                    },
                    child: const Text('Download Update', style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            );
          }
        }
      }
    } catch (e) {}
  }

  Future<void> _loadChats() async {
    final res = await http.get(Uri.parse('${HiiApp.dbUrl}/users/${widget.uid}/chats.json?auth=${widget.token}'));
    if (res.statusCode == 200 && res.body != 'null') {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      chats.clear();
      data.forEach((key, value) {
        chats.add({'chatId': key, 'peerUsername': value.toString()});
      });
    }
    if (mounted) setState(() => isLoading = false);
  }

  void _showAddUserDialog() {
    final searchController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Add User', style: TextStyle(color: Colors.white)),
        content: TextField(controller: searchController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Enter username', hintStyle: TextStyle(color: Colors.white54))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
            onPressed: () async {
              String target = searchController.text.trim().toLowerCase();
              if (target.isEmpty || target == widget.username) return;
              
              final res = await http.get(Uri.parse('${HiiApp.dbUrl}/usernames/$target.json?auth=${widget.token}'));
              if (res.body != 'null') {
                String targetUid = jsonDecode(res.body);
                String chatId = widget.uid.compareTo(targetUid) < 0 ? '${widget.uid}_$targetUid' : '${targetUid}_${widget.uid}';
                
                await http.put(Uri.parse('${HiiApp.dbUrl}/users/${widget.uid}/chats/$chatId.json?auth=${widget.token}'), body: jsonEncode(target));
                await http.put(Uri.parse('${HiiApp.dbUrl}/users/$targetUid/chats/$chatId.json?auth=${widget.token}'), body: jsonEncode(widget.username));
                
                if (mounted) {
                  Navigator.pop(dialogContext);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(token: widget.token, uid: widget.uid, username: widget.username, peerUsername: target, chatId: chatId)));
                  _loadChats();
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found!')));
              }
            },
            child: const Text('Chat', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundGradient(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('hii', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -1)),
                  GlassyContainer(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), child: Text('@${widget.username}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
                ],
              ),
            ),
            Expanded(
              child: isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                : chats.isEmpty
                  ? const Center(child: Text('No chats yet. Tap + to add friends!', style: TextStyle(color: Colors.white70)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(token: widget.token, uid: widget.uid, username: widget.username, peerUsername: chats[index]['peerUsername']!, chatId: chats[index]['chatId']!))),
                            child: GlassyContainer(
                              padding: const EdgeInsets.all(15),
                              child: Row(
                                children: [
                                  CircleAvatar(backgroundColor: const Color(0xFF38BDF8), child: Text(chats[index]['peerUsername']![0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                  const SizedBox(width: 15),
                                  Text('@${chats[index]['peerUsername']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(backgroundColor: const Color(0xFF38BDF8), onPressed: _showAddUserDialog, child: const Icon(Icons.chat_bubble_outline, color: Colors.white)),
    );
  }
}

// ================= CHAT SCREEN =================
class ChatScreen extends StatefulWidget {
  final String token, uid, username, peerUsername, chatId;
  const ChatScreen({super.key, required this.token, required this.uid, required this.username, required this.peerUsername, required this.chatId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final msgController = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  Map<String, dynamic>? replyToMessage;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) => _fetchMessages());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    final res = await http.get(Uri.parse('${HiiApp.dbUrl}/chats/${widget.chatId}.json?auth=${widget.token}'));
    if (res.statusCode == 200 && res.body != 'null') {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      List<Map<String, dynamic>> temp = [];
      data.forEach((key, value) {
        temp.add({
          'id': key, 
          'sender': value['sender'], 
          'text': value['text'], 
          'type': value['type'], 
          'time': value['time'],
          'replyText': value['replyText'],
          'replySender': value['replySender']
        });
      });
      temp.sort((a, b) => b['time'].compareTo(a['time']));
      if (mounted) setState(() => messages = temp);
    }
  }

  Future<void> _sendMessage(String text, String type) async {
    if (text.isEmpty) return;
    String pushId = DateTime.now().millisecondsSinceEpoch.toString();
    msgController.clear();
    
    Map<String, dynamic> msg = {
      'sender': widget.username, 
      'text': text, 
      'type': type, 
      'time': pushId,
      if (replyToMessage != null) 'replyText': replyToMessage!['text'],
      if (replyToMessage != null) 'replySender': replyToMessage!['sender'],
    };
    
    setState(() {
      messages.insert(0, msg);
      replyToMessage = null; 
    });
    
    await http.put(Uri.parse('${HiiApp.dbUrl}/chats/${widget.chatId}/$pushId.json?auth=${widget.token}'), body: jsonEncode(msg));
  }

  void _sendPhotoUrl() {
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Send Photo', style: TextStyle(color: Colors.white)),
        content: TextField(controller: urlController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Paste Image URL here...', hintStyle: TextStyle(color: Colors.white54))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
            onPressed: () {
              Navigator.pop(dialogContext);
              _sendMessage(urlController.text.trim(), 'image');
            },
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('@${widget.peerUsername}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: BackgroundGradient(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(15),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  bool isMe = messages[index]['sender'] == widget.username;
                  bool isImage = messages[index]['type'] == 'image';
                  bool isReply = messages[index]['replyText'] != null;

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: GestureDetector(
                      onLongPress: () {
                        setState(() => replyToMessage = messages[index]);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF38BDF8) : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(15), 
                            topRight: const Radius.circular(15), 
                            bottomLeft: Radius.circular(isMe ? 15 : 0), 
                            bottomRight: Radius.circular(isMe ? 0 : 15)
                          ),
                          border: isMe ? null : Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isReply)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: const Border(left: BorderSide(color: Colors.white, width: 3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('@${messages[index]['replySender']}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(messages[index]['replyText'], style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            isImage
                                ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(messages[index]['text'], fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white)))
                                : Text(messages[index]['text'], style: const TextStyle(color: Colors.white, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (replyToMessage != null)
              Container(
                color: const Color(0xFF1E293B),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.reply, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Replying to @${replyToMessage!['sender']}', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(replyToMessage!['text'], style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => setState(() => replyToMessage = null),
                    )
                  ],
                ),
              ),
            GlassyContainer(
              borderRadius: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.image, color: Colors.white70), onPressed: _sendPhotoUrl),
                  Expanded(
                    child: TextField(
                      controller: msgController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type a message...', 
                        hintStyle: const TextStyle(color: Colors.white54), 
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), 
                        filled: true, 
                        fillColor: Colors.white.withOpacity(0.1), 
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15)
                      ),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send, color: Color(0xFF38BDF8)), onPressed: () => _sendMessage(msgController.text.trim(), 'text')),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
