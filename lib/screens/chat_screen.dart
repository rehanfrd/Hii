import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../main.dart';
import 'auth_screen.dart';

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
  
  bool isPeerOnline = false;
  String lastSeenText = "Connecting...";
  String? peerUid;

  final List<String> quickEmojis = ['😂', '❤️', '🔥', '👍', '🥺', '🎉'];

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _getPeerStatus(); 
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchMessages();
      if(peerUid != null) _getPeerStatusFromUid(); 
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _getPeerStatus() async {
    final res = await http.get(Uri.parse('${HiiApp.dbUrl}/usernames/${widget.peerUsername}.json?auth=${widget.token}'));
    if (res.statusCode == 200 && res.body != 'null') {
      peerUid = jsonDecode(res.body);
      _getPeerStatusFromUid();
    }
  }

  Future<void> _getPeerStatusFromUid() async {
    if (peerUid == null) return;
    final res = await http.get(Uri.parse('${HiiApp.dbUrl}/users/$peerUid/status.json?auth=${widget.token}'));
    if (res.statusCode == 200 && res.body != 'null') {
      final status = jsonDecode(res.body);
      setState(() {
        isPeerOnline = status['isOnline'] ?? false;
        if (!isPeerOnline) {
          int timestamp = status['lastSeen'] ?? 0;
          if (timestamp == 0) {
            lastSeenText = "Offline";
          } else {
            DateTime dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
            lastSeenText = "Last seen at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
          }
        }
      });
    } else {
      setState(() => lastSeenText = "Offline");
    }
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
    } else {
      if (mounted) setState(() => messages = []); // Agar chat delete ho jaye to screen khali ho jaye
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;
    String pushId = DateTime.now().millisecondsSinceEpoch.toString();
    msgController.clear();
    Map<String, dynamic> msg = {
      'sender': widget.username, 
      'text': text, 
      'type': 'text', 
      'time': pushId,
      if (replyToMessage != null) 'replyText': replyToMessage!['text'],
      if (replyToMessage != null) 'replySender': replyToMessage!['sender'],
    };
    setState(() { messages.insert(0, msg); replyToMessage = null; });
    await http.put(Uri.parse('${HiiApp.dbUrl}/chats/${widget.chatId}/$pushId.json?auth=${widget.token}'), body: jsonEncode(msg));
  }

  // === NEW: CLEAR FULL CHAT ===
  Future<void> _clearChat() async {
    await http.delete(Uri.parse('${HiiApp.dbUrl}/chats/${widget.chatId}.json?auth=${widget.token}'));
    setState(() => messages.clear());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat Cleared!')));
  }

  // === NEW: DELETE SINGLE MESSAGE ===
  Future<void> _deleteMessage(String msgId) async {
    await http.delete(Uri.parse('${HiiApp.dbUrl}/chats/${widget.chatId}/$msgId.json?auth=${widget.token}'));
    _fetchMessages();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message Deleted')));
  }

  // === NEW: BOTTOM SHEET FOR LONG PRESS (REPLY / DELETE) ===
  void _showMessageOptions(Map<String, dynamic> msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: Color(0xFF38BDF8)),
              title: const Text('Reply', style: TextStyle(color: Colors.white, fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                setState(() => replyToMessage = msg);
              },
            ),
            // Sirf apne bheje hue message par hi delete ka option aayega
            if (msg['sender'] == widget.username)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                title: const Text('Delete Message', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(msg['id']);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            CircleAvatar(radius: 20, backgroundColor: const Color(0xFF38BDF8), child: Text(widget.peerUsername[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${widget.peerUsername}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
                Text(
                  isPeerOnline ? 'Online' : lastSeenText, 
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: isPeerOnline ? FontWeight.bold : FontWeight.normal,
                    color: isPeerOnline ? const Color(0xFF4ADE80) : Colors.white54
                  )
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF1E293B),
            onSelected: (value) {
              if (value == 'delete') {
                showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: const Color(0xFF0F172A),
                    title: const Text('Clear Chat?', style: TextStyle(color: Colors.white)),
                    content: const Text('Are you sure you want to delete all messages?', style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        onPressed: () {
                          Navigator.pop(c);
                          _clearChat();
                        },
                        child: const Text('Clear', style: TextStyle(color: Colors.white)),
                      )
                    ],
                  )
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(leading: Icon(Icons.delete, color: Colors.redAccent), title: Text('Clear Chat', style: TextStyle(color: Colors.redAccent)), contentPadding: EdgeInsets.zero),
              ),
            ],
          ),
        ],
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
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: GestureDetector(
                      // Yahan long press par naya menu khulega
                      onLongPress: () => _showMessageOptions(messages[index]),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          gradient: isMe ? const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF2563EB)]) : const LinearGradient(colors: [Color(0xFF334155), Color(0xFF1E293B)]),
                          borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: Radius.circular(isMe ? 20 : 5), bottomRight: Radius.circular(isMe ? 5 : 20)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (messages[index]['replyText'] != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10), border: const Border(left: BorderSide(color: Colors.white, width: 3))),
                                child: Text(messages[index]['replyText'], style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            Text(messages[index]['text'], style: const TextStyle(color: Colors.white, fontSize: 16)),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.reply, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 15),
                    Expanded(child: Text(replyToMessage!['text'], style: const TextStyle(color: Colors.white70), maxLines: 1)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => setState(() => replyToMessage = null))
                  ],
                ),
              ),
            GlassyContainer(
              borderRadius: 0,
              padding: const EdgeInsets.only(top: 10, bottom: 15, left: 10, right: 10),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: quickEmojis.map((emoji) => GestureDetector(onTap: () => msgController.text += emoji, child: Text(emoji, style: const TextStyle(fontSize: 24)))).toList(),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: msgController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(hintText: 'Message...', hintStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(backgroundColor: const Color(0xFF38BDF8), child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () => _sendMessage(msgController.text.trim()))),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
