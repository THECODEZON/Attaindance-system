import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/leave_model.dart';
import '../models/student_model.dart';
import '../services/leave_service.dart';
import '../models/timetable.dart';

class LeaveScreen extends StatefulWidget {
  final Student student;

  const LeaveScreen({super.key, required this.student});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  final LeaveService _leaveService = LeaveService();
  final _formKey = GlobalKey<FormState>();
  
  DateTime? _selectedDate;
  String _selectedSubject = 'Full Day';
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
      });
    }
  }

  void _submitRequest() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and enter a reason.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    String? documentUrl;
    try {
      if (_selectedImage != null) {
        final ref = FirebaseStorage.instance.ref().child('leave_docs/${widget.student.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        
        if (kIsWeb) {
          final bytes = await _selectedImage!.readAsBytes();
          await ref.putData(bytes);
        } else {
          await ref.putFile(File(_selectedImage!.path));
        }
        documentUrl = await ref.getDownloadURL();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload document: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isSubmitting = false);
      return;
    }

    final req = LeaveRequest(
      uid: widget.student.uid,
      studentName: widget.student.name,
      dateKey: DateFormat('yyyy-MM-dd').format(_selectedDate!),
      reason: _reasonController.text.trim(),
      subjectCode: _selectedSubject,
      documentUrl: documentUrl,
    );

    final res = await _leaveService.submitLeaveRequest(req);

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (res['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave applied successfully!'), backgroundColor: Colors.green),
        );
        _reasonController.clear();
        setState(() {
          _selectedDate = null;
          _selectedImage = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Leave Management'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Apply for Leave", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.calendar_today, color: Colors.blue.shade700),
                      title: Text(_selectedDate == null ? 'Select Date' : DateFormat('EEE, MMM dd, yyyy').format(_selectedDate!)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: _pickDate,
                    ),
                    const Divider(),
                    // Subject Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedSubject,
                      decoration: const InputDecoration(
                        labelText: 'Subject / Type',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.book),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'Full Day', child: Text('Full Day')),
                        ...Timetable.allSubjectCodes.map((code) => DropdownMenuItem(value: code, child: Text(code))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSubject = val);
                      },
                    ),
                    const Divider(),
                    // Reason Text Field
                    TextFormField(
                      controller: _reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason for leave',
                        hintText: 'e.g., Medical checkup, family emergency...',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.edit_note),
                      ),
                      maxLines: 2,
                      validator: (val) => (val == null || val.isEmpty) ? 'Enter a reason' : null,
                    ),
                    const Divider(),
                    // Attach Document
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.attach_file, color: Colors.blue.shade700),
                      title: Text(_selectedImage == null ? 'Attach Document (Optional)' : 'Document Attached'),
                      trailing: _selectedImage != null 
                          ? IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: () => setState(() => _selectedImage = null))
                          : const Icon(Icons.add_photo_alternate, size: 20),
                      onTap: _pickImage,
                    ),
                    if (_selectedImage != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 40, bottom: 10),
                        child: Text(_selectedImage!.name, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Submit Application', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            const Text("My Leave Requests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            StreamBuilder<List<LeaveRequest>>(
              stream: _leaveService.getUserLeaveRequests(widget.student.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                }
                final leaves = snapshot.data ?? [];
                if (leaves.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(30),
                    alignment: Alignment.center,
                    child: Text("No leave requests found.", style: TextStyle(color: Colors.grey.shade500)),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: leaves.length,
                  itemBuilder: (context, index) {
                    final leave = leaves[index];
                    Color statusColor = Colors.orange;
                    IconData statusIcon = Icons.hourglass_empty;
                    if (leave.status == 'Approved') { statusColor = Colors.green; statusIcon = Icons.check_circle; }
                    else if (leave.status == 'Rejected') { statusColor = Colors.red; statusIcon = Icons.cancel; }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
                              child: Icon(statusIcon, color: statusColor, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(leave.dateKey, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const Spacer(),
                                      Text(leave.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text("${leave.subjectCode} • ${leave.reason}", style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                ],
                              ),
                            ),
                            if (leave.status == 'Pending')
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () => _leaveService.deleteRequest(leave.id),
                              )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
