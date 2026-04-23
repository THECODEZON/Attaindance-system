import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/leave_model.dart';
import '../services/leave_service.dart';
import '../services/auth_service.dart';

class AdminLeaveScreen extends StatefulWidget {
  const AdminLeaveScreen({super.key});

  @override
  State<AdminLeaveScreen> createState() => _AdminLeaveScreenState();
}

class _AdminLeaveScreenState extends State<AdminLeaveScreen> with SingleTickerProviderStateMixin {
  final LeaveService _leaveService = LeaveService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open document link.')));
      }
    }
  }

  Widget _buildStatCard(String title, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(count.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveList(List<LeaveRequest> allLeaves, String statusFilter) {
    final filteredLeaves = allLeaves.where((l) => l.status == statusFilter).toList();

    if (filteredLeaves.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              statusFilter == 'Pending' ? Icons.inbox : statusFilter == 'Approved' ? Icons.check_circle_outline : Icons.cancel_outlined, 
              size: 70, 
              color: Colors.grey.shade300
            ),
            const SizedBox(height: 16),
            Text("No $statusFilter leave requests.", style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredLeaves.length,
      itemBuilder: (context, index) {
        final leave = filteredLeaves[index];
        final isPending = leave.status == 'Pending';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.deepPurple.shade50,
                      child: Text(
                        leave.studentName.isNotEmpty ? leave.studentName[0].toUpperCase() : '?',
                        style: TextStyle(color: Colors.deepPurple.shade700, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(leave.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("${leave.subjectCode} • ${leave.dateKey}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPending ? Colors.orange.shade50 : (leave.status == 'Approved' ? Colors.green.shade50 : Colors.red.shade50),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        leave.status,
                        style: TextStyle(
                          color: isPending ? Colors.orange.shade800 : (leave.status == 'Approved' ? Colors.green.shade700 : Colors.red.shade700),
                          fontWeight: FontWeight.bold,
                          fontSize: 12
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text('"${leave.reason}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                ),
                if (leave.documentUrl != null && leave.documentUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _launchUrl(leave.documentUrl!),
                    child: Row(
                      children: [
                        Icon(Icons.attachment, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text("View Attached Document", style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                      ],
                    ),
                  ),
                ],
                if (isPending) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _leaveService.updateLeaveStatus(leave.id, 'Rejected'),
                        icon: const Icon(Icons.close, color: Colors.red, size: 18),
                        label: const Text("Reject", style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _leaveService.updateLeaveStatus(leave.id, 'Approved'),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text("Approve"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 0),
                      ),
                    ],
                  )
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Leave Dashboard'),
        backgroundColor: Colors.deepPurple.shade800,
        elevation: 0,
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authService = AuthService();
              await authService.signOut();
            },
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Pending"),
            Tab(text: "Approved"),
            Tab(text: "Rejected"),
          ],
        ),
      ),
      body: StreamBuilder<List<LeaveRequest>>(
        stream: _leaveService.getAllLeaves(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allLeaves = snapshot.data ?? [];
          final pendingCount = allLeaves.where((l) => l.status == 'Pending').length;
          final approvedCount = allLeaves.where((l) => l.status == 'Approved').length;
          final rejectedCount = allLeaves.where((l) => l.status == 'Rejected').length;

          return Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildStatCard("Pending", pendingCount, Colors.orange.shade700, Icons.hourglass_empty),
                    const SizedBox(width: 12),
                    _buildStatCard("Approved", approvedCount, Colors.green.shade600, Icons.check_circle_outline),
                    const SizedBox(width: 12),
                    _buildStatCard("Rejected", rejectedCount, Colors.red.shade600, Icons.cancel_outlined),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLeaveList(allLeaves, 'Pending'),
                    _buildLeaveList(allLeaves, 'Approved'),
                    _buildLeaveList(allLeaves, 'Rejected'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
