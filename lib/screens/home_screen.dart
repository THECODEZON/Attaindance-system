import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../models/student_model.dart';
import '../models/subject_attendance.dart';
import '../models/attendance_record.dart';

class HomeScreen extends StatefulWidget {
  final String uid;
  final String email;

  const HomeScreen({super.key, required this.uid, required this.email});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final AttendanceService _attendanceService = AttendanceService();
  final AuthService _authService = AuthService();
  late Student _student;
  late List<SubjectAttendance> _subjects;
  bool _isProfileLoading = true;

  bool _isLoading = false;
  String _statusMessage = 'Tap the button to mark your attendance';
  bool _isSuccess = false;
  bool _isError = false;
  bool _alreadyMarkedToday = false;
  String _currentTime = '';
  String _currentDate = '';
  late Timer _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Stats
  int _totalPresent = 0;
  int _totalRejected = 0;

  @override
  void initState() {
    super.initState();
    _student = Student.mock();
    _subjects = SubjectAttendance.mockList();
    _loadProfile();
    _checkTodayStatus();
    _loadStats();

    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authService.getStudentProfile(widget.uid);
      if (profile != null && mounted) {
        setState(() {
          _student = profile;
          _isProfileLoading = false;
        });
      } else if (mounted) {
        setState(() => _isProfileLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isProfileLoading = false);
    }
  }

  Future<void> _checkTodayStatus() async {
    final record = await _attendanceService.getTodayRecord(widget.uid);
    if (record != null && mounted) {
      setState(() {
        _alreadyMarkedToday = true;
        _isSuccess = true;
        _statusMessage = 'Attendance already marked today at ${record.markedAt != null ? DateFormat('hh:mm a').format(record.markedAt!) : "earlier"}';
      });
    }
  }

  Future<void> _loadStats() async {
    final stats = await _attendanceService.getAttendanceStats(widget.uid);
    if (mounted) {
      setState(() {
        _totalPresent = stats['present'] ?? 0;
        _totalRejected = stats['rejected'] ?? 0;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('hh:mm:ss a').format(now);
        _currentDate = DateFormat('EEEE, MMM dd').format(now);
      });
    }
  }

  void _markAttendance() async {
    if (_alreadyMarkedToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You have already marked attendance today!'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Verifying location & WiFi...';
      _isSuccess = false;
      _isError = false;
    });

    final result = await _attendanceService.markAttendance(widget.uid, widget.email);

    final bool success = result['success'] ?? false;
    final String message = result['message'] ?? 'Unknown error';
    final bool alreadyMarked = result['alreadyMarked'] ?? false;

    setState(() {
      _isLoading = false;
      _statusMessage = message;
      _isSuccess = success;
      _isError = !success;
      if (success || alreadyMarked) {
        _alreadyMarkedToday = true;
      }
    });

    // Reload stats after marking
    if (success) {
      _loadStats();
    }

    if (mounted) {
      _showResultDialog(success, message, result);
    }
  }

  void _showResultDialog(bool success, String message, Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              success ? 'Attendance Marked!' : 'Attendance Failed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: success ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 14)),
            if (result.containsKey('distance')) ...[
              const SizedBox(height: 12),
              _buildDialogInfoRow(
                Icons.location_on,
                'Distance',
                '${(result['distance'] as double).toStringAsFixed(0)}m from campus',
                success ? Colors.green : Colors.red,
              ),
            ],
            if (result.containsKey('wifiName')) ...[
              const SizedBox(height: 8),
              _buildDialogInfoRow(
                Icons.wifi,
                'WiFi',
                result['wifiName'],
                success ? Colors.green : Colors.red,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Student?>(
      stream: _authService.getStudentStream(widget.uid),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          _student = snapshot.data!;
        }
        
        return Scaffold(
          backgroundColor: Colors.white,
          body: CustomScrollView(
            slivers: [
              // Orange Header Sliver
              SliverAppBar(
                expandedHeight: 220,
                floating: false,
                pinned: true,
                backgroundColor: Colors.orange.shade700,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.orange.shade800, Colors.orange.shade600],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 42,
                              backgroundImage: NetworkImage(
                                _student.photoUrl.contains('?') 
                                  ? "${_student.photoUrl}&v=${_student.lastUpdated}"
                                  : "${_student.photoUrl}?v=${_student.lastUpdated}"
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _student.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Reg: ${_student.regNo} | Sec: ${_student.section}",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () => _authService.signOut(),
                  ),
                ],
              ),
              // Main Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Info Grid — now shows attendance stats
                      Row(
                        children: [
                          _buildInfoCard("Present", _totalPresent.toString(), Icons.check_circle_outline, Colors.green),
                          const SizedBox(width: 15),
                          _buildInfoCard("CGPA", _student.cgpa.toString(), Icons.analytics, Colors.orange),
                        ],
                      ),
                      const SizedBox(height: 25),
                      // ─── Attendance Marker Card ───
                      _buildAttendanceMarker(),
                      const SizedBox(height: 25),
                      // ─── Verification Requirements ───
                      _buildRequirementsCard(),
                      const SizedBox(height: 30),
                      const Text(
                        "Subject-wise Attendance",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 15),
                      // Subject Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _subjects.length,
                        itemBuilder: (context, index) {
                          return _buildSubjectCard(_subjects[index]);
                        },
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        "Contact Details",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 15),
                      _buildDetailTile(Icons.phone, "Phone", _student.phone),
                      _buildDetailTile(Icons.location_on, "Address", _student.address),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  // ─── Verification Requirements Card ────────────────────────────────
  Widget _buildRequirementsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Attendance Requirements',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRequirementRow(
            Icons.location_on,
            'GPS Location',
            'Must be within 300m of LPU Campus',
          ),
          const SizedBox(height: 8),
          _buildRequirementRow(
            Icons.wifi,
            'WiFi Network',
            'Must be connected to "${_attendanceService.allowedWifiName}"',
          ),
          const SizedBox(height: 8),
          _buildRequirementRow(
            Icons.calendar_today,
            'One per day',
            'Attendance can only be marked once per day',
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.computer, size: 16, color: Colors.amber.shade800),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Web mode: GPS & WiFi checks are simulated. Attendance is auto-approved.',
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequirementRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.blue.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
              children: [
                TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceMarker() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentDate, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  Text(_currentTime, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  if (kIsWeb)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Text("SIMULATION", style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  if (_alreadyMarkedToday)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text("PRESENT", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20)),
                      child: Text("LPU Phagwara", style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 25),
          GestureDetector(
            onTap: _isLoading ? null : _markAttendance,
            child: ScaleTransition(
              scale: (_isLoading || _alreadyMarkedToday) ? const AlwaysStoppedAnimation(1.0) : _pulseAnimation,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _alreadyMarkedToday
                      ? Colors.green
                      : (_isError ? Colors.red : Colors.orange.shade700),
                  boxShadow: [
                    BoxShadow(
                      color: (_alreadyMarkedToday ? Colors.green : Colors.orange).withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(25),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : Icon(
                        _alreadyMarkedToday
                            ? Icons.check
                            : (_isError ? Icons.close : Icons.fingerprint),
                        color: Colors.white,
                        size: 45,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _alreadyMarkedToday
                ? "Marked Present ✓"
                : (_isError ? "Try Again" : "Mark Attendance"),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _alreadyMarkedToday
                  ? Colors.green
                  : (_isError ? Colors.red : Colors.orange.shade800),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(SubjectAttendance subject) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subject.subjectName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("P: ${subject.present}", style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
              Text("A: ${subject.absent}", style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: subject.percentage / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                subject.percentage > 75 ? Colors.orange.shade600 : Colors.red.shade400,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text("${subject.percentage.toStringAsFixed(0)}%", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange, size: 20),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
