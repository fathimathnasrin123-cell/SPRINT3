import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../auth/services/auth_provider.dart';
import '../services/shared_medical_document_service.dart';

class SharedMedicalDocumentsWidget extends StatefulWidget {
  final String elderlyId;

  const SharedMedicalDocumentsWidget({super.key, required this.elderlyId});

  @override
  State<SharedMedicalDocumentsWidget> createState() =>
      _SharedMedicalDocumentsWidgetState();
}

class _SharedMedicalDocumentsWidgetState
    extends State<SharedMedicalDocumentsWidget> {
  final _service = SharedMedicalDocumentService();
  bool _isUploading = false;

  Future<void> _launchURL(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $url');
      }
    } catch (e) {
      debugPrint('Launch ERROR $e');
    }
  }

  Future<void> _uploadFile() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result != null && result.files.first.bytes != null) {
        setState(() => _isUploading = true);

        final fileBytes = result.files.first.bytes!;
        final fileName = result.files.first.name;
        final fileExt = result.files.first.extension ?? 'pdf';

        await _service.uploadMedicalDocument(
          elderlyId: widget.elderlyId,
          fileName: fileName,
          fileBytes: fileBytes,
          fileType: fileExt,
          uploadedById: user.id,
          uploadedByName: user.name,
          uploadedByRole: user.role.name, // (elderly/caregiver/family/staff)
        );

        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Document uploaded successfully!")),
          );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Upload error: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload Button Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.folder, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                const Text(
                  "Medical Documents",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            _isUploading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : ElevatedButton.icon(
                    onPressed: _uploadFile,
                    icon: const Icon(Icons.upload, size: 16),
                    label: const Text("Upload"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade50,
                      foregroundColor: Colors.teal.shade800,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
          ],
        ),
        const SizedBox(height: 12),

        // List Stream
        StreamBuilder<QuerySnapshot>(
          stream: _service.getMedicalDocuments(widget.elderlyId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text(
                  "No documents uploaded yet.",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc =
                    snapshot.data!.docs[index].data() as Map<String, dynamic>;
                final fileName = doc['fileName'] ?? 'Document File';
                final fileUrl = doc['fileUrl'] ?? '';
                final uploaderName = doc['uploadedByName'] ?? 'Unknown';
                final uploaderRole = doc['uploadedByRole'] ?? 'User';

                String dateStr = 'Unknown date';
                if (doc['uploadedAt'] != null) {
                  final ts = doc['uploadedAt'] as Timestamp;
                  dateStr = DateFormat('dd-MM-yyyy').format(ts.toDate());
                }

                Color roleColor = Colors.blue;
                if (uploaderRole.toLowerCase() == 'caregiver')
                  roleColor = Colors.green;
                if (uploaderRole.toLowerCase() == 'staff')
                  roleColor = Colors.purple;
                if (uploaderRole.toLowerCase() == 'elderly')
                  roleColor = Colors.orange;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.description,
                              color: Colors.teal,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fileName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        "Uploaded by: $uploaderName",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: roleColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          uploaderRole.toUpperCase(),
                                          style: TextStyle(
                                            color: roleColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Date: $dateStr",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _launchURL(fileUrl),
                              icon: const Icon(Icons.visibility, size: 16),
                              label: const Text("View"),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _launchURL(fileUrl),
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text("Download"),
                              style: ElevatedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                elevation: 0,
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
