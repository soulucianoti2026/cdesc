import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/repository.dart';
import 'ui/app.dart';
import 'ui/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.white,
    ),
  );
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: SplashScreen()),
  );
  try {
    // Keep the identity visible briefly while initialization runs in parallel.
    final repository = createRepository();
    await Future.wait<void>([
      repository.then<void>((_) {}),
      Future<void>.delayed(const Duration(milliseconds: 1400)),
    ]);
    runApp(CdeApp(repository: await repository));
  } catch (_) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Não foi possível iniciar o aplicativo.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: main,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
