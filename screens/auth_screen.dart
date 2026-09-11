import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import 'home_screen.dart'; 

// ================= GLASSY CONTAINER =================
class GlassyContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final double opacity;

  const GlassyContainer({super.key, required this.child, this.borderRadius = 24, this.padding = const EdgeInsets.all(20), this.opacity = 0.1});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
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
        gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF0F172A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: SafeArea(child: child),
    );
  }
}

// ================= AUTH CHECK =================
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

// ================= AUTH SCREEN =================
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
    final url = isLogin ? 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${HiiApp.apiKey}' : 'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${HiiApp.apiKey}';

    try {
      final res = await http.post(Uri.parse(url), body: jsonEncode({'email': emailController.text.trim(), 'password': passwordController.text.trim(), 'returnSecureToken': true}));
      final data = jsonDecode(res.body);
      if (data['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error']['message'])));
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['idToken']);
        await prefs.setString('auth_uid', data['localId']);
        
        final userRes = await http.get(Uri.parse('${HiiApp.dbUrl}/users/${data['localId']}/username.json?auth=${data['idToken']}'));
        if (userRes.statusCode == 200 && userRes.body != 'null') {
          String existingUsername = jsonDecode(userRes.body);
          await prefs.setString('auth_username', existingUsername);
          if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen(token: data['idToken'], uid: data['localId'], username: existingUsername)));
        } else {
          if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => UsernameScreen(token: data['idToken'], uid: data['localId'])));
        }
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
                  const Text('hii', style: TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -2)),
                  const SizedBox(height: 30),
                  TextField(controller: emailController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email_rounded, color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)))),
                  const SizedBox(height: 15),
                  TextField(controller: passwordController, obscureText: true, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_rounded, color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)))),
                  const SizedBox(height: 25),
                  isLoading ? const CircularProgressIndicator(color: Color(0xFF38BDF8)) : SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), onPressed: _authenticate, child: Text(isLogin ? 'Login' : 'Sign Up', style: const TextStyle(color: Colors.white, fontSize: 18)))),
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
                  const Icon(Icons.person_pin_rounded, size: 70, color: Color(0xFF38BDF8)),
                  const SizedBox(height: 20),
                  const Text('Set Username', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 20),
                  TextField(controller: usernameController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(prefixText: '@', hintText: 'unique_name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)))),
                  const SizedBox(height: 20),
                  isLoading ? const CircularProgressIndicator() : SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), onPressed: _saveUsername, child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 16)))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
