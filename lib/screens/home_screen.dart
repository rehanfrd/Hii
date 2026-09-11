import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'auth_screen.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  final String token, uid, username;
  const HomeScreen({super.key, required this.token, required this.uid, required this.username});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// WidgetsBindingObserver se hum track karenge ki app open hai ya background mein
class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Map<String, String>> chats = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateOnlineStatus(true); // App khulte hi online
    _loadChats();
    _checkForUpdates();
    _setupNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateOnlineStatus(true);
    } else {
      _updateOnlineStatus(false);
    }
  }

  Future<void> _updateOnlineStatus(bool isOnline) async {
    final ref = Uri.parse('${HiiApp.dbUrl}/users/${widget.uid}/status.json?auth=${widget.token}');
    await http.put(ref, body: jsonEncode({
      'isOnline': isOnline,
      'lastSeen': DateTime.now().millisecondsSinceEpoch
    }));
  }

  Future<void> _setupNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${message.notification!.title}: ${message.notification!.body}', style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF38BDF8),
        ));
      }
    });
  }

  Future<void> _checkForUpdates() async {
    try {
      final res = await http.get(Uri.parse('${HiiApp.dbUrl}/app_config.json'));
      if (res.statusCode == 200 && res.body != 'null') {
        final data = jsonDecode(res.body);
        int latestVersion = data['latest_version'] ?? 1;
        String updateUrl = data['update_url'] ?? '';
        if (latestVersion > HiiApp.currentAppVersion && updateUrl.isNotEmpty && mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (c) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text('Update Available! 🚀', style: TextStyle(color: Colors.white)),
              content: const Text('A new version is ready.', style: TextStyle(color: Colors.white70)),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
                  onPressed: () => launchUrl(Uri.parse(updateUrl), mode: LaunchMode.externalApplication),
                  child: const Text('Download', style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          );
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
        title: const Text('New Chat', style: TextStyle(color: Colors.white)),
        content: TextField(controller: searchController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: '@username')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
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
            child: const Text('Message'),
          )
        ],
      ),
    );
  }

  Future<void> _logout() async {
    _updateOnlineStatus(false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthCheck()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F172A),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1E293B)),
              accountName: Text('@${widget.username}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              accountEmail: const Text('Premium User', style: TextStyle(color: Color(0xFF38BDF8))),
              currentAccountPicture: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(radius: 40, backgroundColor: const Color(0xFF38BDF8), child: Text(widget.username[0].toUpperCase(), style: const TextStyle(fontSize: 30, color: Colors.white))),
                  Container(
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.add_circle, color: Color(0xFF38BDF8), size: 24),
                  )
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.color_lens, color: Colors.white70),
              title: const Text('Theme Options', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Themes update jaldi aayega!')));
              },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
              onTap: _logout,
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('hii', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -1)),
      ),
      extendBodyBehindAppBar: true,
      body: BackgroundGradient(
        child: Column(
          children: [
            const SizedBox(height: 80),
            Expanded(
              child: isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                : chats.isEmpty
                  ? const Center(child: Text('No chats yet. Tap + to start!', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(token: widget.token, uid: widget.uid, username: widget.username, peerUsername: chats[index]['peerUsername']!, chatId: chats[index]['chatId']!))),
                            child: GlassyContainer(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  CircleAvatar(radius: 25, backgroundColor: const Color(0xFF38BDF8), child: Text(chats[index]['peerUsername']![0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                                  const SizedBox(width: 15),
                                  Text('@${chats[index]['peerUsername']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
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
      floatingActionButton: FloatingActionButton(backgroundColor: const Color(0xFF38BDF8), onPressed: _showAddUserDialog, child: const Icon(Icons.edit_square, color: Colors.white)),
    );
  }
}
