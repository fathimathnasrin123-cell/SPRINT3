import 'package:flutter/material.dart';
import 'package:carenow/l10n/app_localizations.dart';

class RejectionDialog extends StatefulWidget {
  final Function(String) onConfirm;

  const RejectionDialog({super.key, required this.onConfirm});

  @override
  State<RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends State<RejectionDialog> {
  String? selectedReasonKey;
  final TextEditingController customReasonController = TextEditingController();

  @override
  void dispose() {
    customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final Map<String, String> reasons = {
      'reasonDoctorUnavailable': l10n.reasonDoctorUnavailable,
      'reasonSlotFull': l10n.reasonSlotFull,
      'reasonIncompleteDetails': l10n.reasonIncompleteDetails,
      'reasonReschedule': l10n.reasonReschedule,
      'reasonEmergencyPriority': l10n.reasonEmergencyPriority,
      'reasonOther': l10n.reasonOther, 
    };

    return AlertDialog(
      title: Text(l10n.rejectAppointmentTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: selectedReasonKey,
              hint: Text(l10n.reasonLabel),
              isExpanded: true,
              items: reasons.entries.map((e) {
                return DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  selectedReasonKey = val;
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            if (selectedReasonKey == 'reasonOther') ...[
              const SizedBox(height: 12),
              TextField(
                controller: customReasonController,
                decoration: InputDecoration(
                  hintText: l10n.rejectionReasonHint,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            String finalReason = "";
            if (selectedReasonKey == 'reasonOther') {
                finalReason = customReasonController.text.trim();
                if (finalReason.isEmpty || finalReason.length < 3) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reason required (min 3 chars)")));
                  return; 
                }
            } else if (selectedReasonKey != null) {
                finalReason = selectedReasonKey!;
            } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a reason")));
                return;
            }

            widget.onConfirm(finalReason);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text(l10n.reject, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
