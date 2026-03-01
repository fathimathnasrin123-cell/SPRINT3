import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medical_record.dart';
import '../services/medical_record_service.dart';
import '../../../features/appointments/data/doctor_data.dart';

class EditMedicalRecordDialog extends StatefulWidget {
  final MedicalRecord record;

  const EditMedicalRecordDialog({Key? key, required this.record})
    : super(key: key);

  @override
  _EditMedicalRecordDialogState createState() =>
      _EditMedicalRecordDialogState();
}

class _EditMedicalRecordDialogState extends State<EditMedicalRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String? _selectedDoctorId;
  late DateTime _recordDate;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.record.title);
    _descriptionController = TextEditingController(
      text: widget.record.description,
    );
    _selectedDoctorId = widget.record.doctorId;
    _recordDate = widget.record.recordDate;
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
        _isSaving = true;
      });

      try {
        await MedicalRecordService().updateMedicalRecord(widget.record.id, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'doctorId': _selectedDoctorId!,
          'doctorName': DoctorData.doctors.firstWhere(
            (d) => d['id'] == _selectedDoctorId,
          )['name_en'],
          'department': DoctorData.doctors.firstWhere(
            (d) => d['id'] == _selectedDoctorId,
          )['department_en'],
          'recordDate': _recordDate,
        });

        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        setState(() {
          _isSaving = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Details'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                if (_isSaving)
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
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
