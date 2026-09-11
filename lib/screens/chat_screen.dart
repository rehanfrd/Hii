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
  final List<String> quickEmojis = ['😂', '❤️', '🔥', '👍', '🥺', '🎉'];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            CircleAvatar(radius: 18, backgroundColor: const Color(0xFF38BDF8), child: Text(widget.peerUsername[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 16))),
            const SizedBox(width: 12),
            Text('@${widget.peerUsername}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
          ],
        ),
        actions: [
          // === YEH RAHA TERA 3-DOTS MENU ===
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF1E293B),
            onSelected: (value) {
              if (value == 'delete') {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete Chat feature agle update mein aayega!')));
              } else if (value == 'block') {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Block feature agle update mein aayega!')));
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(leading: Icon(Icons.delete, color: Colors.redAccent), title: Text('Clear Chat', style: TextStyle(color: Colors.redAccent)), contentPadding: EdgeInsets.zero),
              ),
              const PopupMenuItem<String>(
                value: 'block',
                child: ListTile(leading: Icon(Icons.block, color: Colors.white70), title: Text('Block User', style: TextStyle(color: Colors.white)), contentPadding: EdgeInsets.zero),
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
                      onLongPress: () => setState(() => replyToMessage = messages[index]),
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
