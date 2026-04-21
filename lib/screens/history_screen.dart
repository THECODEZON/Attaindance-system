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
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
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
                child: Text(
                  "Error fetching history: ${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            );
          }

          final records = snapshot.data ?? [];

          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    "No attendance records found.",
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Mark your first attendance from the Dashboard!",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),
                ],
              ),
            );
          }

          // Count stats
          int presentCount = records.where((r) => r.status == 'Present').length;
          int rejectedCount = records.where((r) => r.status == 'Rejected').length;

          return Column(
            children: [
              // Stats bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                color: Colors.orange.shade700,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn("Total", records.length.toString(), Colors.white),
                    Container(width: 1, height: 30, color: Colors.white30),
                    _buildStatColumn("Present", presentCount.toString(), Colors.greenAccent),
                    Container(width: 1, height: 30, color: Colors.white30),
                    _buildStatColumn("Rejected", rejectedCount.toString(), Colors.redAccent.shade100),
                  ],
                ),
              ),
              // List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    return _buildRecordCard(records[index]);
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
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
      ],
    );
  }

  Widget _buildRecordCard(AttendanceRecord record) {
    final bool isPresent = record.status == 'Present';
    final Color statusColor = isPresent ? Colors.green : Colors.red;

    // Format timestamp
    String dateTimeStr = "Pending...";
    if (record.markedAt != null) {
      dateTimeStr = DateFormat('MMM dd, yyyy — hh:mm a').format(record.markedAt!);
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: status + time
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withOpacity(0.12),
                  child: Icon(
                    isPresent ? Icons.check_circle : Icons.cancel,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.status,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        dateTimeStr,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                if (record.isSimulated)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'SIM',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Details row
            Row(
              children: [
                _buildDetailChip(Icons.location_on, '${record.distanceFromCampus.toStringAsFixed(0)}m', Colors.blue),
                const SizedBox(width: 8),
                Flexible(
                  child: _buildDetailChip(Icons.wifi, record.wifiName, Colors.orange),
                ),
              ],
            ),
            // Show rejection reason if present
            if (!isPresent && record.rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  record.rejectionReason,
                  style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
