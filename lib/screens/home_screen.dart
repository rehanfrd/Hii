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

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, String>> chats = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _checkForUpdates();
    _setupNotifications();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthCheck()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // === YEH RAHA TERA 3-LINE MENU (DRAWER) ===
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F172A),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1E293B)),
              accountName: Text('@${widget.username}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              accountEmail: const Text('Premium User', style: TextStyle(color: Color(0xFF38BDF8))),
              currentAccountPicture: CircleAvatar(backgroundColor: const Color(0xFF38BDF8), child: Text(widget.username[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: Colors.white))),
            ),
            ListTile(
              leading: const Icon(Icons.color_lens, color: Colors.white70),
              title: const Text('Theme Options', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Themes update aane wala hai!')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.white70),
              title: const Text('Profile Settings', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile update aane wala hai!')));
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Center(child: Text('@${widget.username}', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold))),
          )
        ],
      ),
      extendBodyBehindAppBar: true,
      body: BackgroundGradient(
        child: Column(
          children: [
            const SizedBox(height: 80), // AppBar space
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
