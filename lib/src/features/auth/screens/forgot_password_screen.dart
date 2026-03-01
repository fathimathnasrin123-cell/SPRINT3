import 'package:flutter/material.dart';

import 'package:carenow/l10n/app_localizations.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isSent = false;

  void _handleReset() {
    setState(() {
      _isSent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.resetPassword)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _isSent
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.check_circle, color: Colors.green, size: 64),
                   const SizedBox(height: 16),
                   Text(l10n.checkEmail, style: Theme.of(context).textTheme.headlineSmall),
                   const SizedBox(height: 8),
                   Text(l10n.sentRecoveryInstructions, textAlign: TextAlign.center),
                   const SizedBox(height: 24),
                   ElevatedButton(onPressed: () => Navigator.pop(context), child: Text(l10n.backToLogin)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.enterEmailForReset),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: l10n.emailAddress, prefixIcon: const Icon(Icons.email)),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _handleReset,
                    child: Text(l10n.sendResetLink),
                  ),
                ],
              ),
      ),
    );
  }
}
