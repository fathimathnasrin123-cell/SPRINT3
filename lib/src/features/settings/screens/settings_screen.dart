import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/services/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../auth/screens/login_screen.dart';
import '../../../core/services/notification_service.dart';
import '../../notifications/screens/notification_settings_screen.dart';

import 'package:carenow/l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Mock State for Elderly Mode until we lift it to higher provider
  bool _isLargeText = false; 
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = NotificationService().areNotificationsEnabled;
  } 

  void _showChangePasswordDialog(BuildContext context) {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) {
        bool obscureCurrent = true;
        bool obscureNew = true;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.changePassword),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPassController, 
                    obscureText: obscureCurrent, 
                    decoration: InputDecoration(
                       labelText: l10n.currentPassword,
                       suffixIcon: IconButton(
                         icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                         onPressed: () => setState(() => obscureCurrent = !obscureCurrent),
                       ),
                    ),
                  ),
                  TextField(
                    controller: newPassController, 
                    obscureText: obscureNew, 
                    decoration: InputDecoration(
                      labelText: l10n.newPassword,
                      suffixIcon: IconButton(
                         icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                         onPressed: () => setState(() => obscureNew = !obscureNew),
                       ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await Provider.of<AuthProvider>(context, listen: false)
                          .changePassword(currentPassController.text, newPassController.text);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordChanged)));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                    }
                  },
                  child: Text(l10n.update),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showManageElderlyDialog(BuildContext context, User localUser) {
    // Note: localUser might be stale effectively for rendering, we should rely on provider state in builder
    final idController = TextEditingController();
    
    showDialog(
      context: context, 
      builder: (ctx) {
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setState) {
             final authProvider = Provider.of<AuthProvider>(context); 
             // Access the latest user state
             // We use authProvider.linkedProfiles to display details.
             
             return AlertDialog(
              title: Text(AppLocalizations.of(context)!.manageLinkedElderly),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // List Section
                    if (authProvider.linkedProfiles.isNotEmpty) 
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: authProvider.linkedProfiles.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                             final p = authProvider.linkedProfiles[index];
                             return ListTile(
                               contentPadding: EdgeInsets.zero,
                               title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                               subtitle: Text(p.uniqueId ?? "ID: ${p.id.substring(0,6)}..."),
                               trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                     await authProvider.unlinkElderly(p.id); // Assuming this uses UID or we might need uniqueId depending on implementation
                                     // State updates automatically via provider notification, but we need to ensure this dialog rebuilds if it depends on external state
                                     setState(() {});
                                  },
                               ),
                             );
                          },
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    // Input Section
                    TextField(
                      controller: idController, 
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.addElderlyId,
                        border: const OutlineInputBorder(),
                        errorText: errorMessage, // Inline Error Display
                      ),
                      onChanged: (_) {
                        if (errorMessage != null) {
                           setState(() => errorMessage = null);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.close)),
                ElevatedButton(
                   onPressed: () async {
                      final l10n = AppLocalizations.of(context)!;
                      if (authProvider.linkedProfiles.length >= 5) {
                         setState(() => errorMessage = l10n.limitReached);
                         return;
                      }
                      if (idController.text.isNotEmpty) {
                         try {
                             await authProvider.linkElderly(idController.text.trim());
                             idController.clear();
                             setState(() => errorMessage = null);
                             // Success
                         } catch (e) {
                            String errorMsg = e.toString();
                            if (errorMsg.contains('userDoesNotExist')) {
                               errorMsg = l10n.userDoesNotExist;
                            } else if (errorMsg.contains('accountAlreadyLinked')) {
                               errorMsg = l10n.accountAlreadyLinked;
                            } else if (errorMsg.contains('alreadyLinkedByYou')) {
                               errorMsg = l10n.alreadyLinkedByYou;
                            }
                            setState(() => errorMessage = errorMsg);
                         }
                      }
                   },
                   child: Text(AppLocalizations.of(context)!.add),
                )
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          // UNIQUE ID SECTION (For Elderly)
          if (user?.role == UserRole.elderly && user?.uniqueId != null)
            ListTile(
              tileColor: Colors.teal.shade50,
              leading: const Icon(Icons.badge, color: Colors.teal),
              title: Text(l10n.uniqueId, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(user!.uniqueId!, style: const TextStyle(fontSize: 18, color: Colors.teal)),
            ),

          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(authProvider.currentLocale.languageCode == 'ml' ? 'Malayalam' : 'English'),
            onTap: () {
               showDialog(context: context, builder: (context) => SimpleDialog(
                 title: Text(l10n.selectLanguage),
                 children: [
                   SimpleDialogOption(child: const Text("English"), onPressed: () { authProvider.setLanguage(const Locale('en')); Navigator.pop(context); }),
                   SimpleDialogOption(child: const Text("Malayalam (മലയാളം)"), onPressed: () { authProvider.setLanguage(const Locale('ml')); Navigator.pop(context); }),
                 ],
               ));
            },

          ),
          
          // NOTIFICATIONS SETTINGS
          ListTile(
            leading: const Icon(Icons.notifications),
            title: Text(l10n.notifications),
             subtitle: Text(l10n.notificationsEnabled), // Or "Manage preferences"
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
               Navigator.push(
                 context, 
                 MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
               ).then((_) {
                 // Refresh state when coming back
                 setState(() {
                   _notificationsEnabled = NotificationService().areNotificationsEnabled;
                 });
               });
            },
          ),
          
          // ELDERLY MODE TOGGLE (Only for Elderly Role)
          if (user?.role == UserRole.elderly)
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: Text(l10n.elderlyMode),
              subtitle: Text(l10n.elderlyModeDesc),
              trailing: Switch(
                value: authProvider.textScaleFactor > 1.0, 
                onChanged: (val) async {
                   await authProvider.toggleElderlyMode(val);
                }
              ),
            ),
          
          // CAREGIVER MANAGER
          if (user?.role == UserRole.caregiver)
            ListTile(
              leading: const Icon(Icons.family_restroom),
              title: Text(l10n.manageLinkedElderly),
              subtitle: Text("${user?.linkedElderlyIds.length ?? 0} / 5 linked"),
              onTap: () async {
                 await authProvider.fetchLinkedElderlyProfiles();
                 _showManageElderlyDialog(context, authProvider.currentUser!);
              },
            ),

          // CHANGE PASSWORD (IN-APP)
          ListTile(
            leading: const Icon(Icons.password),
            title: Text(l10n.changePassword),
            onTap: () => _showChangePasswordDialog(context),
          ),

          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
            onTap: () async {
              await authProvider.logout();
              Navigator.pushAndRemoveUntil(
                context, 
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
