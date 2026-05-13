import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/geofencing_service.dart';
import '../models/student_model.dart';
import '../models/timetable.dart';
import 'leave_screen.dart';

class HomeScreen extends StatefulWidget {
  final String uid;
  final String email;

  const HomeScreen({super.key, required this.uid, required this.email});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final AuthService _authService = AuthService();
  final GeofencingService _geofencingService = GeofencingService();
  late Student _student;
  bool _isProfileLoading = true;
  Uint8List? _profileImageBytes; // Local bytes for Web robustness

  String _currentTime = '';
  String _currentDate = '';
  late Timer _timer;

  // Today's classes
  List<ClassSlot> _todayClasses = [];
  Set<String> _markedSubjects = {}; // Subject codes already marked today
  String? _loadingSubjectCode; // Which subject is being marked right now
  int _totalPresent = 0;

  // Per-subject stats
  Map<String, Map<String, int>> _subjectStats = {};

  @override
  void initState() {
    super.initState();
    _student = Student.mock();
    _todayClasses = Timetable.getTodayClasses();
    _loadProfile();
    _loadTodayStatus();
    _loadStats();
    _startGeofencing();

    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authService.getStudentProfile(widget.uid);
      if (profile != null && mounted) {
        setState(() { _student = profile; _isProfileLoading = false; });
        _loadProfileImageBytes(widget.uid);
      } else if (mounted) {
        setState(() => _isProfileLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isProfileLoading = false);
    }
  }

  Future<void> _loadProfileImageBytes(String uid) async {
    if (uid.isEmpty) return;
    final bytes = await _authService.getProfileImageBytes(uid);
    if (mounted && bytes != null) {
      setState(() => _profileImageBytes = bytes);
    }
  }

  Future<void> _loadTodayStatus() async {
    final marked = await _attendanceService.getTodayMarkedSubjects(widget.uid);
    if (mounted) setState(() => _markedSubjects = marked);
  }

  Future<void> _loadStats() async {
    final stats = await _attendanceService.getAttendanceStats(widget.uid);
    final subjectStats = await _attendanceService.getSubjectStats(widget.uid);
    if (mounted) {
      setState(() {
        _totalPresent = stats['present'] ?? 0;
        _subjectStats = subjectStats;
      });
    }
  }

  Future<void> _startGeofencing() async {
    final started = await _geofencingService.start();
    if (started && mounted) {
      // Listen for geofence status changes to rebuild UI
      _geofencingService.statusNotifier.addListener(_onGeofenceUpdate);
    }
  }

  void _onGeofenceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer.cancel();
    _geofencingService.statusNotifier.removeListener(_onGeofenceUpdate);
    _geofencingService.stop();
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

  // ─── Mark Attendance for a specific class ──────────────────────────
  void _markSubjectAttendance(ClassSlot classSlot) async {
    if (_markedSubjects.contains(classSlot.subjectCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Already marked for ${classSlot.subjectName} today!'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _loadingSubjectCode = classSlot.subjectCode);

    final result = await _attendanceService.markAttendance(widget.uid, widget.email, classSlot);
    final bool success = result['success'] ?? false;
    final String message = result['message'] ?? 'Unknown error';

    if (success) {
      setState(() {
        _markedSubjects.add(classSlot.subjectCode);
      });
      _loadStats(); // Refresh stats
    }

    setState(() => _loadingSubjectCode = null);

    if (mounted) {
      _showResultDialog(success, message, result, classSlot);
    }
  }

  void _showResultDialog(bool success, String message, Map<String, dynamic> result, ClassSlot classSlot) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.error, color: success ? Colors.green : Colors.red, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                success ? 'Marked Present!' : 'Failed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: success ? Colors.green.shade700 : Colors.red.shade700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Icon(Icons.book, color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(classSlot.subjectName, style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('${classSlot.timeRange} • ${classSlot.room}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(fontSize: 14)),
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Student?>(
      stream: _authService.getStudentStream(widget.uid),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
           if (_student.photoUrl != snapshot.data!.photoUrl) {
             _loadProfileImageBytes(widget.uid);
           }
           _student = snapshot.data!;
        }

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LeaveScreen(student: _student)),
              );
            },
            backgroundColor: Colors.blue.shade700,
            icon: const Icon(Icons.edit_document, color: Colors.white),
            label: const Text('Apply Leave', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          body: CustomScrollView(
            slivers: [
              // ─── Header ────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 200,
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
                          const SizedBox(height: 10),
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: Colors.white,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, spreadRadius: 1)],
                              ),
                              child: ClipOval(
                                child: _profileImageBytes != null
                                    ? Image.memory(
                                        _profileImageBytes!,
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.network(
                                        _student.photoUrl.isEmpty 
                                            ? "https://api.dicebear.com/7.x/initials/png?seed=${_student.name}&backgroundColor=fb8c00"
                                            : _student.photoUrl.contains('?')
                                                ? "${_student.photoUrl}&v=${_student.lastUpdated}"
                                                : "${_student.photoUrl}?v=${_student.lastUpdated}",
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 70,
                                            height: 70,
                                            color: Colors.orange.shade100,
                                            child: Icon(Icons.person, color: Colors.orange.shade700, size: 36),
                                          );
                                        },
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(_student.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          Text("Reg: ${_student.regNo} | B.Tech CSE", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () => _authService.signOut()),
                ],
              ),

              // ─── Main Content ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time + Stats Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_currentDate, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  Text(_currentTime, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildStatChip("Classes", "${_markedSubjects.length}/${_todayClasses.length}", Colors.green),
                          const SizedBox(width: 8),
                          _buildStatChip("Total", "$_totalPresent", Colors.orange),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ─── Geofence Campus Status Banner ─────────────
                      _buildCampusStatusBanner(),
                      
                      // ─── Smart Next Class Banner ───────────────────
                      _buildNextClassBanner(),

                      // ─── Today's Classes ───────────────────────────
                      Row(
                        children: [
                          const Text("Today's Classes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.radar, size: 11, color: Colors.green.shade700),
                                const SizedBox(width: 4),
                                Text("GEOFENCED", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_todayClasses.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.weekend, size: 50, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text("No classes today!", style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                              Text("Enjoy your day off 🎉", style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                            ],
                          ),
                        )
                      else
                        ...List.generate(_todayClasses.length, (index) {
                          return _buildClassCard(_todayClasses[index], index);
                        }),

                      const SizedBox(height: 24),

                      // ─── Subject-wise Attendance Stats ─────────────
                      const Text("Subject-wise Attendance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...Timetable.allSubjects.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final subjectName = entry.value;
                        final code = Timetable.allSubjectCodes[idx];
                        final stats = _subjectStats[code];
                        final present = stats?['present'] ?? 0;
                        final rejected = stats?['rejected'] ?? 0;
                        final total = present + rejected;
                        final pct = total == 0 ? 0.0 : (present / total) * 100;
                        return _buildSubjectStatsCard(subjectName, code, present, total, pct);
                      }),

                      const SizedBox(height: 20),

                      // ─── Requirements Info ─────────────────────────
                      _buildRequirementsCard(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Smart Next Class Banner ───────────────────────────────────────
  Widget _buildNextClassBanner() {
    final current = Timetable.getCurrentClass();
    final next = Timetable.getNextClass();

    if (current == null && next == null) {
      return const SizedBox.shrink();
    }

    final isCurrent = current != null;
    final slot = current ?? next!;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCurrent 
              ? [Colors.orange.shade700, Colors.orange.shade500]
              : [Colors.blue.shade700, Colors.blue.shade500],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: (isCurrent ? Colors.orange : Colors.blue).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(isCurrent ? Icons.play_arrow : Icons.upcoming, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrent ? "Active Now" : "Coming Up Next",
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  slot.subjectName,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  "${slot.timeRange} • ${slot.room}",
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                ),
              ],
            ),
          ),
          if (isCurrent && !_markedSubjects.contains(slot.subjectCode))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Mark Now",
                style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Class Card with Mark Button ───────────────────────────────────
  Widget _buildClassCard(ClassSlot slot, int index) {
    final now = DateTime.now();
    final isActive = slot.isActive(now);
    final hasEnded = slot.hasEnded(now);
    final isMarked = _markedSubjects.contains(slot.subjectCode);
    final isLoading = _loadingSubjectCode == slot.subjectCode;

    Color cardColor = Colors.white;
    Color borderColor = Colors.grey.shade200;
    Color accentColor = Colors.grey;

    if (isMarked) {
      cardColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
      accentColor = Colors.green;
    } else if (isActive) {
      cardColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade300;
      accentColor = Colors.orange.shade700;
    } else if (hasEnded) {
      accentColor = Colors.grey.shade400;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: isActive ? [BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 10)] : null,
      ),
      child: Row(
        children: [
          // Time column
          Column(
            children: [
              Text(
                slot.timeRange.split(' - ')[0],
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor),
              ),
              Container(
                width: 2,
                height: 20,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: accentColor.withOpacity(0.3),
              ),
              Text(
                slot.timeRange.split(' - ')[1],
                style: TextStyle(fontSize: 11, color: accentColor),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Subject info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        slot.subjectName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: hasEnded && !isMarked ? Colors.grey : Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        slot.subjectCode,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${slot.faculty} • ${slot.room}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (isActive && !isMarked)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text("Class in progress", style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Action button
          if (isMarked)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 20),
            )
          else if (isLoading)
            const SizedBox(width: 40, height: 40, child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
          else
            GestureDetector(
              onTap: () => _markSubjectAttendance(slot),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isActive || kIsWeb) ? Colors.orange.shade700 : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.fingerprint,
                  color: (isActive || kIsWeb) ? Colors.white : Colors.grey.shade500,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Subject Stats Card ────────────────────────────────────────────
  Widget _buildSubjectStatsCard(String name, String code, int present, int total, double pct) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : present / total,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      pct >= 75 ? Colors.green : (pct >= 50 ? Colors.orange : Colors.red),
                    ),
                    minHeight: 6,
                  ),
                ),
                if (total > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Builder(
                      builder: (context) {
                        String msg = "";
                        Color c = Colors.grey.shade600;
                        if (pct >= 75) {
                          int canSkip = (present / 0.75).floor() - total;
                          msg = "Safe to skip: $canSkip classes";
                          c = Colors.green.shade700;
                        } else {
                          int needAttend = ((0.75 * total - present) / 0.25).ceil();
                          msg = "Attend next $needAttend classes to reach 75%";
                          c = Colors.red.shade700;
                        }
                        return Row(
                          children: [
                            Icon(pct >= 75 ? Icons.shield_outlined : Icons.warning_amber_rounded, size: 12, color: c),
                            const SizedBox(width: 4),
                            Text(msg, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c)),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("$present/$total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: pct >= 75 ? Colors.green : Colors.orange)),
              Text("${pct.toStringAsFixed(0)}%", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  // ─── Live Campus Status Banner (Geofencing) ───────────────────────
  Widget _buildCampusStatusBanner() {
    final isInside = _geofencingService.isInsideCampus;
    final statusText = _geofencingService.statusText;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isInside
              ? [Colors.green.shade600, Colors.green.shade400]
              : [Colors.red.shade600, Colors.red.shade400],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: (isInside ? Colors.green : Colors.red).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isInside ? Icons.location_on : Icons.location_off,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GEOFENCE STATUS',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isInside ? Colors.greenAccent : Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isInside ? 'ACTIVE' : 'AWAY',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
              const SizedBox(width: 8),
              Text('Attendance Rules', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
            ],
          ),
          const SizedBox(height: 10),
          _reqRow(Icons.radar, 'Geofencing: Must be inside LPU Campus (${GeofencingService.campusRadiusMeters.toStringAsFixed(0)}m radius)'),
          const SizedBox(height: 6),
          _reqRow(Icons.wifi, 'Must be on "${_attendanceService.allowedWifiName}" WiFi'),
          const SizedBox(height: 6),
          _reqRow(Icons.schedule, 'Mark during class hour only'),
          const SizedBox(height: 6),
          _reqRow(Icons.block, 'One mark per subject per day'),
          const SizedBox(height: 6),
          _reqRow(Icons.gps_off, 'Mock/Fake GPS is blocked'),
          if (kIsWeb) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.computer, size: 14, color: Colors.amber.shade800),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Web mode: Geofence simulated — all classes can be marked', style: TextStyle(fontSize: 10, color: Colors.amber.shade900))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reqRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.blue.shade400),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 11, color: Colors.grey.shade700))),
      ],
    );
  }
}
