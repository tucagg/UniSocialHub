import 'package:flutter/material.dart';
import 'package:gtu/route/route_constants.dart';
import 'package:gtu/route/router.dart' as router;
import 'package:gtu/theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'database/database_helper.dart' as database;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database/s3_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await database.DatabaseHelper().init();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      debugPrint('Firebase zaten başlatılmış');
    } else {
      rethrow;
    }
  }
  
  await S3Service().init();
  
  final user = FirebaseAuth.instance.currentUser;
  String initialRoute = logInScreenRoute;

  if (user != null && user.emailVerified) {
    final userData = await database.DatabaseHelper().getUserData(user.email!);
    
    if (userData['disabled'] == true) {
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }
    else if (userData['username'] != null && userData['username'].isNotEmpty) {
      initialRoute = entryPointScreenRoute;
    }
  }
  
  runApp(MyApp(initialRoute: initialRoute));
}

// Thanks for using our template. You are using the free version of the template.
// 🔗 Full template: https://theflutterway.gumroad.com/l/fluttershop

class MyApp extends StatelessWidget {
  final String initialRoute;
  
  const MyApp({super.key, required this.initialRoute});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kampus',
      theme: AppTheme.lightTheme(context),
      themeMode: ThemeMode.light,
      onGenerateRoute: router.generateRoute,
      initialRoute: initialRoute,
    );
  }
}
