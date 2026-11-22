import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart'; // Generated locally by flutterfire configure.
import 'screens/auth_screen.dart';
import 'screens/board_screen.dart';
import 'services/auth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MessageBoardApp());
}

class MessageBoardApp extends StatelessWidget {
  const MessageBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Board',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const StartupGate(),
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});
  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late Future<void> _startup;

  @override
  void initState() {
    super.initState();
    _startup = _initialize();
  }

  Future<void> _initialize() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // Enable with: flutter run --dart-define=USE_EMULATORS=true
    const emulators = bool.fromEnvironment('USE_EMULATORS', defaultValue: false);
    if (emulators) {
      const host = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off, size: 54),
                const SizedBox(height: 12),
                const Text('Firebase could not start.'),
                Text('${snapshot.error}', textAlign: TextAlign.center),
                ElevatedButton(onPressed: () => setState(() => _startup = _initialize()),
                    child: const Text('Retry')),
              ]),
            )),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(Icons.forum_rounded, size: 72, color: Colors.indigo),
              SizedBox(height: 14), Text('Campus Board', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
              SizedBox(height: 18), CircularProgressIndicator()],
          )));
        }
        return StreamBuilder<User?>(
          stream: AuthService().authStateChanges,
          builder: (context, auth) {
            if (auth.hasError) return const Scaffold(body: Center(child: Text('Authentication error.')));
            if (auth.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return auth.data == null ? const AuthScreen() : const BoardScreen();
          },
        );
      },
    );
  }
}
