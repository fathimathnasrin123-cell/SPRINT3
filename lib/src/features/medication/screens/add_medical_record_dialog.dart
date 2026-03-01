import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../services/medical_record_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../features/appointments/data/doctor_data.dart';

class AddMedicalRecordDialog extends StatefulWidget {
  final String patientId;
  final String currentUserRole;

  const AddMedicalRecordDialog({
    Key? key,
    required this.patientId,
    required this.currentUserRole,
  }) : super(key: key);

  @override
  _AddMedicalRecordDialogState createState() => _AddMedicalRecordDialogState();
}

class _AddMedicalRecordDialogState extends State<AddMedicalRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedDoctorId;

  DateTime _recordDate = DateTime.now();
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  String? _uploadError;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true, // Need this for Web
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      setState(() {
        _selectedFile = file;
        _uploadError = null; // Clear error on new selection
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _recordDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _recordDate) {
      setState(() {
        _recordDate = picked;
      });
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUploading = true;
        _uploadError = null;
      });

      try {
        Uint8List? fileData = _selectedFile!.bytes;
        // On mobile, bytes might be null even with withData: true, so read from path if needed
        if (fileData == null && !kIsWeb && _selectedFile!.path != null) {
          fileData = await File(_selectedFile!.path!).readAsBytes();
        }

        if (fileData == null) {
          throw Exception(
            "Could not read file data. Please try selecting the file again.",
          );
        }

        final ext = _selectedFile!.extension?.toLowerCase() ?? '';
        final doc = DoctorData.doctors.firstWhere(
          (d) => d['id'] == _selectedDoctorId,
        );

        await MedicalRecordService().addMedicalRecord(
          elderlyId: widget.patientId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          doctorId: _selectedDoctorId!,
          doctorName: doc['name_en'],
          department: doc['department_en'],
          recordDate: _recordDate,
          uploadedByRole: widget.currentUserRole,
          fileBytes: fileData,
          fileName: _selectedFile!.name,
          fileSize: _selectedFile!.size,
          fileType: ext, // use normalized extension
        );

        // Staff Notification Logic
        if (widget.currentUserRole == 'elderly' ||
            widget.currentUserRole == 'caregiver') {
          await NotificationService().logNotificationToDb(
            userId: 'staff_broadcast',
            title: 'New Medical Record Uploaded',
            message:
                'Patient [ID: ${widget.patientId}] has uploaded a new medical record.',
            notificationType: 'medical_record',
            targetRole: 'hospitalStaff',
          );
        }

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Medical record uploaded successfully."),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isUploading = false;
            _uploadError = e.toString().replaceAll('Exception: ', '');
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload Medical Record'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_uploadError != null)
                  Container(
                    color: Colors.red.shade100,
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _uploadError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Record Title *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Title is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description / Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Doctor Name *',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedDoctorId,
                  items: DoctorData.doctors.map((doc) {
                    return DropdownMenuItem<String>(
                      value: doc['id'],
                      child: Text(doc['name_en']),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedDoctorId = val;
                    });
                  },
                  validator: (val) =>
                      val == null ? 'Please select a doctor' : null,
                ),
                if (_selectedDoctorId != null) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: DoctorData.doctors.firstWhere(
                      (d) => d['id'] == _selectedDoctorId,
                    )['department_en'],
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                    enabled: false,
                  ),
                ],
                const SizedBox(height: 12),
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of Record',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(DateFormat('MMM dd, yyyy').format(_recordDate)),
                  ),
                ),
                const SizedBox(height: 12),
                FormField<PlatformFile>(
                  validator: (value) {
                    if (_selectedFile == null)
                      return "Please select a file to upload.";
                    final allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];
                    final ext = _selectedFile!.extension?.toLowerCase();
                    if (ext == null || !allowedExtensions.contains(ext)) {
                      return "File type not supported.";
                    }
                    if (_selectedFile!.size > 15 * 1024 * 1024) {
                      return "File exceeds 15MB limit.";
                    }
                    return null;
                  },
                  builder: (state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedFile == null)
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _pickFile();
                              state.didChange(_selectedFile);
                              state.validate();
                            },
                            icon: const Icon(Icons.attach_file),
                            label: const Text('Select File'),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                if (['jpg', 'jpeg', 'png'].contains(
                                      _selectedFile!.extension?.toLowerCase(),
                                    ) &&
                                    _selectedFile!.bytes != null)
                                  Image.memory(
                                    _selectedFile!.bytes!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                  )
                                else if (['jpg', 'jpeg', 'png'].contains(
                                  _selectedFile!.extension?.toLowerCase(),
                                ))
                                  const Icon(Icons.image, size: 40)
                                else
                                  const Icon(
                                    Icons.picture_as_pdf,
                                    size: 40,
                                    color: Colors.red,
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedFile!.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    setState(() {
                                      _selectedFile = null;
                                    });
                                    state.didChange(null);
                                    state.validate();
                                  },
                                ),
                              ],
                            ),
                          ),
                        if (state.hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                            child: Text(
                              state.errorText!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                if (_isUploading)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _submit,
          child: _isUploading
              ? const Text('Uploading...')
              : const Text('Upload'),
        ),
      ],
    );
  }
}
