import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';
import 'package:bkey_uikit/bkey_uikit.dart';

import 'config/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize BMONI SDK — 6-digit PIN, PIN required for all signing
  BmoniEmbeddedSdk.initialize(pinLength: 6, requirePin: true);

  runApp(
    const ProviderScope(
      child: WayaApp(),
    ),
  );
}

class WayaApp extends ConsumerWidget {
  const WayaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Waya',
      debugShowCheckedModeBanner: false,
      theme: BMoniTheme.darkTheme(),
      routerConfig: router,
    );
  }
}
