import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'config/theme.dart';
import 'features/ai/chat/chat_message_store.dart';
import 'features/ai/queue/annotation_queue.dart';
import 'features/ai/queue/sqflite_annotation_queue.dart';
import 'features/ai/review/review_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/rag_chat_provider.dart';
import 'providers/incident_provider.dart';
import 'providers/resident_provider.dart';
import 'providers/alert_provider.dart';
import 'services/notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/home_shell.dart';
import 'widgets/common/loading_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  await FlutterGemma.initialize();
  await SqfliteAnnotationQueue.instance.open();
  await ChatMessageStore.instance.open();
  runApp(CarePackageApp(queue: SqfliteAnnotationQueue.instance));
}

class CarePackageApp extends StatelessWidget {
  final AnnotationQueueStore queue;
  const CarePackageApp({super.key, required this.queue});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..bootstrap()),
        ChangeNotifierProvider(create: (_) => ResidentProvider()),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
        ChangeNotifierProvider(create: (_) => IncidentProvider()),
        ChangeNotifierProvider(create: (_) => AiProvider()),
        ChangeNotifierProxyProvider<AiProvider, RagChatProvider>(
          create: (ctx) => RagChatProvider(ctx.read<AiProvider>()),
          update: (_, ai, prev) => prev!,
        ),
        ChangeNotifierProvider(
          create: (_) => ReviewProvider(queueStore: queue),
        ),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: LoadingView(message: 'Starting…'));
      case AuthStatus.authenticated:
        return const HomeShell();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
