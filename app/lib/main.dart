import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'auth/login_page.dart';
import 'auth/register_page.dart';
import 'chat/chat_page.dart';
import 'core/theme.dart';
import 'home/home_page.dart';
import 'jobs/create_job_page.dart';
import 'jobs/job_detail_page.dart';
import 'jobs/job_list_page.dart';
import 'profile/become_tukang_page.dart';
import 'profile/profile_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ??
      dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ??
      '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ??
      dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ??
      '';

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }

  runApp(const ProviderScope(child: MyApp()));
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(
      path: '/become-tukang',
      builder: (context, state) => const BecomeTukangPage(),
    ),
    GoRoute(
      path: '/create-job',
      builder: (context, state) {
        final categoryId = state.uri.queryParameters['categoryId'];
        return CreateJobPage(initialCategoryId: categoryId);
      },
    ),
    GoRoute(
      path: '/jobs',
      builder: (context, state) => const JobListPage(),
    ),
    GoRoute(
      path: '/jobs/:id',
      builder: (context, state) {
        final jobId = state.pathParameters['id'] ?? '';
        return JobDetailPage(jobId: jobId);
      },
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) {
        final jobId = state.uri.queryParameters['jobId'] ?? '';
        return ChatPage(jobId: jobId);
      },
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: appRouter,
      title: 'Beres',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
    );
  }
}
