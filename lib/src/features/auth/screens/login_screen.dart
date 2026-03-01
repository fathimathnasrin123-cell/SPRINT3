import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Ensure UserRole is imported
import '../services/auth_provider.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart'; 
import 'package:carenow/l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController(); // Changed from email
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  String? _nameError; // Changed from emailError
  String? _passwordError;

  Future<void> _handleLogin() async {
    setState(() {
      _nameError = null;
      _passwordError = null;
    });

    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();

    bool isValid = true;
    if (name.isEmpty) {
      setState(() => _nameError = AppLocalizations.of(context)!.usernameError);
      isValid = false;
    }
    if (password.isEmpty) {
      setState(() => _passwordError = AppLocalizations.of(context)!.incorrectPassword);
      isValid = false;
    }

    if (!isValid) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // Using Name-Based Login (Auto-detect role)
      await authProvider.loginByName(name, password);

      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => const DashboardScreenWrapper())
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().toLowerCase();
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          if (errorMsg.contains('usernotregistered') || errorMsg.contains('not found')) {
            _nameError = l10n.userNotRegistered;
          } else if (errorMsg.contains('incorrectpassword') || errorMsg.contains('wrong-password')) {
            _passwordError = l10n.incorrectPassword; 
          } else if (errorMsg.contains('accountdisabled')) {
            _nameError = l10n.accountDisabled;
          } else {
             _nameError = e.toString();
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.health_and_safety, size: 80, color: Theme.of(context).primaryColor),
              const SizedBox(height: 24),
              Text(
                l10n.welcomeBack,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 32),
              // Role Selection Removed per instructions
              /*
              DropdownButtonFormField<UserRole>( ... )
              */
              const SizedBox(height: 16),
              // Name Field
              TextField(
                controller: _nameController,
                keyboardType: TextInputType.name,
                decoration: InputDecoration(
                  labelText: l10n.username,
                  prefixIcon: const Icon(Icons.person),
                  errorText: _nameError,
                  errorStyle: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 16),
              // Password Field
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: l10n.password,
                  prefixIcon: const Icon(Icons.lock),
                  errorText: _passwordError,
                  errorStyle: const TextStyle(color: Colors.red),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                  },
                  child: Text(l10n.forgotPasswordQuestion),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(l10n.login),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                child: Text(l10n.createAccountQuestion),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
