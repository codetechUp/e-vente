import 'package:flutter/material.dart';

import 'app_routes.dart';
import '../views/home_view.dart';
import '../views/login_view.dart';
import '../views/register_view.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginView());
      case AppRoutes.register:
        return MaterialPageRoute(builder: (_) => const RegisterView());
      case AppRoutes.home:
      default:
        return MaterialPageRoute(builder: (_) => const HomeView());
    }
  }
}
