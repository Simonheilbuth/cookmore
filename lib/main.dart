import 'package:flutter/material.dart';

import 'app.dart';
import 'app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final services = await AppServices.create();
    runApp(CookMoreApp(services: services));
  } catch (error) {
    // Without the local database the app cannot work. Show a friendly
    // message instead of a crash, and only log the details.
    debugPrint('CookMore failed to start: $error');
    runApp(const _StartupErrorApp());
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'CookMore could not start.\nPlease restart the app.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
