import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lurk_app/core/theme/app_theme.dart';

import 'package:lurk_app/features/authentication/widgets/auth_gate.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_service.dart';

//supabase
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Supabase.initialize(
    url: 'https://vrbibdwpuzszsqsgvthk.supabase.co',
    publishableKey: 'sb_publishable_e_dHYpo8ZLdNRmmTflA69w_zEoIOiuO',
    accessToken: () async {
      return FirebaseAuth.instance.currentUser?.getIdToken();
    },
  );

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await GoogleSignIn.instance.initialize();
  }
  if (NotificationService.supported) {
    FirebaseMessaging.onBackgroundMessage(notificationBackgroundHandler);
  }
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lurk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AuthGate(),
    );
  }
}
