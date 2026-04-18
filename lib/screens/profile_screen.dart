import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../services/auth_service.dart';
import '../models/student_model.dart';

class ProfileScreen extends StatefulWidget {
  final String uid;

  const ProfileScreen({super.key, required this.uid});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  TextEditingController? _nameController;
  TextEditingController? _phoneController;
  TextEditingController? _addressController;
  TextEditingController? _regNoController;
  TextEditingController? _sectionController;
  String _photoUrl = "";
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploading = false;
  Student? _student;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _authService.getStudentProfile(widget.uid);
    setState(() {
      _student = profile ?? Student.mock();
      _nameController = TextEditingController(text: _student!.name);
      _phoneController = TextEditingController(text: _student!.phone);
      _addressController = TextEditingController(text: _student!.address);
      _photoUrl = _student!.photoUrl;
      _isLoading = false;
    });
  }

  Future<void> _pickAndUploadImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Profile Photo", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceOption(Icons.camera_alt, "Camera", ImageSource.camera),
                _buildSourceOption(Icons.photo_library, "Gallery", ImageSource.gallery),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption(IconData icon, String label, ImageSource source) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            Navigator.pop(context);
            _executePickAndUpload(source);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.orange.shade700, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Future<void> _executePickAndUpload(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 500,
      );

      if (image == null) return;

      setState(() => _isUploading = true);
      final Uint8List bytes = await image.readAsBytes();
      final String downloadUrl = await _authService.uploadProfileImage(widget.uid, bytes);
      
      if (_student != null) {
        final updatedProfile = _student!.copyWith(
          photoUrl: downloadUrl,
          lastUpdated: DateTime.now().millisecondsSinceEpoch,
        );
        await _authService.updateStudentProfile(updatedProfile);
      }

      setState(() {
        _photoUrl = "$downloadUrl&t=${DateTime.now().millisecondsSinceEpoch}";
        _isUploading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile photo updated instantly!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _nameController?.dispose();
    _phoneController?.dispose();
    _addressController?.dispose();
    _regNoController?.dispose();
    _sectionController?.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updatedStudent = Student(
      uid: widget.uid,
      name: _nameController!.text.trim(),
      email: _student?.email ?? "",
      photoUrl: _photoUrl,
      regNo: _regNoController!.text.trim(),
      section: _sectionController!.text.trim(),
      cgpa: _student?.cgpa ?? 0.0,
      address: _addressController?.text.trim() ?? "",
      phone: _phoneController?.text.trim() ?? "",
      lastUpdated: _student?.lastUpdated ?? DateTime.now().millisecondsSinceEpoch,
    );

    try {
      await _authService.updateStudentProfile(updatedStudent);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating profile: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Student?>(
      stream: _authService.getStudentStream(widget.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data != null) {
          final liveStudent = snapshot.data!;
          // Initialize controllers only once or if data is missing
          if (_student == null) {
            _student = liveStudent;
            _nameController = TextEditingController(text: _student!.name);
            _phoneController = TextEditingController(text: _student!.phone);
            _addressController = TextEditingController(text: _student!.address);
            _regNoController = TextEditingController(text: _student!.regNo);
            _sectionController = TextEditingController(text: _student!.section);
            _photoUrl = _student!.photoUrl;
            _isLoading = false;
          } else {
            // Update photo URL if it changed externally (e.g. from upload)
            final newUrl = liveStudent.photoUrl.contains('?') 
                ? "${liveStudent.photoUrl}&v=${liveStudent.lastUpdated}"
                : "${liveStudent.photoUrl}?v=${liveStudent.lastUpdated}";

            if (_photoUrl.isEmpty || (_photoUrl != newUrl && !_isUploading)) {
              _photoUrl = newUrl;
            }
            _student = liveStudent; // Keep metadata fresh
          }
        } else if (!snapshot.hasData && _isLoading) {
           // Handle case where profile isn't in Firestore yet
           _student = Student.mock();
           _nameController = TextEditingController(text: _student!.name);
           _phoneController = TextEditingController(text: _student!.phone);
           _addressController = TextEditingController(text: _student!.address);
           _regNoController = TextEditingController(text: _student!.regNo);
           _sectionController = TextEditingController(text: _student!.section);
           _photoUrl = _student!.photoUrl;
           _isLoading = false;
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: Colors.orange.shade700,
            elevation: 0,
            actions: [
                if (_isSaving)
                  const Padding(padding: EdgeInsets.all(15), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                else
                  IconButton(icon: const Icon(Icons.check, color: Colors.white), onPressed: _saveProfile),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Header with Avatar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: _isUploading ? null : _pickAndUploadImage,
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 56,
                                backgroundImage: NetworkImage(_photoUrl.isEmpty ? "https://api.dicebear.com/7.x/initials/png?seed=Profile" : _photoUrl),
                                child: _isUploading 
                                  ? const CircularProgressIndicator(color: Colors.orange) 
                                  : null,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              elevation: 4,
                              child: InkWell(
                                onTap: _isUploading ? null : _pickAndUploadImage,
                                customBorder: const CircleBorder(),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(Icons.camera_alt, color: Colors.orange.shade700, size: 20),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(_nameController?.text ?? "", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(_student?.email ?? "", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _isUploading ? null : _pickAndUploadImage,
                        icon: const Icon(Icons.photo_library, color: Colors.white, size: 16),
                        label: const Text("Change Photo", style: TextStyle(color: Colors.white, fontSize: 13)),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),

                // Form
                Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle("Personal Information"),
                        const SizedBox(height: 20),
                        _buildTextField("Full Name", _nameController!, Icons.person_outline),
                        _buildTextField("Phone Number", _phoneController!, Icons.phone_android_outlined, keyboardType: TextInputType.phone),
                        _buildTextField("Home Address", _addressController!, Icons.location_on_outlined, maxLines: 2),

                        const SizedBox(height: 20),
                        _buildSectionTitle("Academic Details"),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(child: _buildTextField("Reg No", _regNoController!, Icons.badge_outlined)),
                            const SizedBox(width: 15),
                            Expanded(child: _buildTextField("Section", _sectionController!, Icons.groups_outlined)),
                          ],
                        ),
                        
                        const SizedBox(height: 15),
                        _buildSectionTitle("Account Settings"),
                        const SizedBox(height: 15),
                        _buildLogoutButton(),

                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 3,
                            ),
                            child: _isSaving 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("SAVE CHANGES", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.2),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: (val) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.orange.shade700),
          labelStyle: TextStyle(color: Colors.grey.shade600),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.orange.shade700, width: 2)),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return "This field cannot be empty";
          return null;
        },
      ),
    );
  }

  Widget _buildLogoutButton() {
    return OutlinedButton.icon(
      onPressed: () => _authService.signOut(),
      icon: const Icon(Icons.logout, color: Colors.red),
      label: const Text("Sign Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.red),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
