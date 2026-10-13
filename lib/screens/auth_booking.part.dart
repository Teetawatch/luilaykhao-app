part of 'customer_app_screen.dart';

class AuthScreen extends StatelessWidget {
  final VoidCallback? afterLogin;

  const AuthScreen({super.key, this.afterLogin});

  @override
  Widget build(BuildContext context) {
    return LoginScreen(onLoginSuccess: afterLogin, popOnSuccess: false);
  }
}
