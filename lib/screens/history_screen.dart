import 'package:flutter/material.dart';
import '../services/attendance_service.dart';
import '../models/attendance_record.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatelessWidget {
  final String uid;

  HistoryScreen({super.key, required this.uid});

  final AttendanceService _attendanceService = AttendanceService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Attendance History"),
        backgroundColor: Colors.orange.shade700,
        elevation: 0,
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<AttendanceRecord>>(
        stream: _attendanceService.getUserAttendanceRecords(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text("Error: ${snapshot.error}", textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700)),
              ),
            );
          }

          final records = snapshot.data ?? [];

          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 70, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("No attendance records yet.", style: TextStyle(fontSize: 17, color: Colors.grey.shade500)),
                  const SizedBox(height: 6),
                  Text("Mark your first class from the Dashboard!", style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                ],
              ),
            );
          }

          int presentCount = records.where((r) => r.status == 'Present').length;
          int rejectedCount = records.where((r) => r.status == 'Rejected').length;
          int absentCount = records.where((r) => r.status == 'Absent').length;

          // Group by date
          final grouped = <String, List<AttendanceRecord>>{};
          for (var r in records) {
            final key = r.markedAt != null ? DateFormat('MMM dd, yyyy').format(r.markedAt!) : 'Unknown Date';
            grouped.putIfAbsent(key, () => []);
            grouped[key]!.add(r);
          }

          return Column(
            children: [
              // Stats bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: Colors.orange.shade700,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn("Total", records.length.toString(), Colors.white),
                    Container(width: 1, height: 28, color: Colors.white30),
                    _buildStatColumn("Present", presentCount.toString(), Colors.greenAccent),
                    Container(width: 1, height: 28, color: Colors.white30),
                    _buildStatColumn("Rejected", rejectedCount.toString(), Colors.redAccent.shade100),
                    Container(width: 1, height: 28, color: Colors.white30),
                    _buildStatColumn("Absent", absentCount.toString(), Colors.orangeAccent.shade100),
                  ],
                ),
              ),
              // Grouped list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final dateKey = grouped.keys.toList()[index];
                    final dayRecords = grouped[dateKey]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date header
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Text(dateKey, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                  '${dayRecords.where((r) => r.status == "Present").length} classes',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...dayRecords.map((record) => _buildRecordCard(record)),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
      ],
    );
  }

  Widget _buildRecordCard(AttendanceRecord record) {
    final bool isPresent = record.status == 'Present';
    final Color statusColor = isPresent ? Colors.green : Colors.red;

    String timeStr = "";
    if (record.markedAt != null) {
      timeStr = DateFormat('hh:mm a').format(record.markedAt!);
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Status icon
            CircleAvatar(
              radius: 16,
              backgroundColor: statusColor.withOpacity(0.12),
              child: Icon(isPresent ? Icons.check : Icons.close, color: statusColor, size: 18),
            ),
            const SizedBox(width: 12),
            // Subject & details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.subjectName.isNotEmpty ? record.subjectName : 'General',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      if (record.subjectCode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                          child: Text(record.subjectCode, style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (record.slotTime.isNotEmpty) ...[
                        Icon(Icons.schedule, size: 11, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text(record.slotTime, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                        const SizedBox(width: 8),
                      ],
                      Text(timeStr, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                  if (!isPresent && record.rejectionReason.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(record.rejectionReason, style: TextStyle(fontSize: 10, color: Colors.red.shade600)),
                    ),
                ],
              ),
            ),
            // Badges
            Column(
              children: [
                Text(record.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                if (record.isSimulated)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('SIM', style: TextStyle(fontSize: 8, color: Colors.blue.shade600, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
