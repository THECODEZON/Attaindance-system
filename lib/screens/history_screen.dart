import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/attendance_service.dart';
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
        title: Text("Attendance History"),
        backgroundColor: Colors.orange.shade700,
        elevation: 0,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _attendanceService.getUserAttendance(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error fetching history."));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No attendance records found.",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              
              // Formatting Timestamp
              Timestamp? timestamp = data['time'] as Timestamp?;
              String dateTimeStr = "Pending...";
              if (timestamp != null) {
                 final date = timestamp.toDate();
                 dateTimeStr = DateFormat('MMM dd, yyyy - hh:mm a').format(date);
              }

              return Card(
                elevation: 2,
                margin: EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withAlpha(50),
                    child: const Icon(Icons.check, color: Colors.green),
                  ),
                  title: Text(
                    "Present",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(dateTimeStr),
                  trailing: Icon(Icons.location_on, color: Colors.blueAccent),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
