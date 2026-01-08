import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'package:e_attend/admin/employee_list.dart';
import 'package:e_attend/admin/attendance_records.dart';
import 'package:e_attend/admin/admin_settings.dart';
import 'package:e_attend/admin/leave_management.dart';
import 'package:e_attend/admin/admin_notifications.dart';
import '../login.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Color(0xFFFFD95A),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
             // AuthWrapper handles nav
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _firestoreService.getStats(),
        builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
           }
           
           int total = snapshot.data?['totalEmployees'] ?? 0;
           int present = snapshot.data?['presentToday'] ?? 0;

           return Padding(
             padding: const EdgeInsets.all(16.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.stretch,
               children: [
                 const Text('Welcome Admin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 20),
                 Row(
                   children: [
                     Expanded(child: _buildStatCard('Total Employees', total.toString(), Colors.blue[100]!)),
                     const SizedBox(width: 16),
                     Expanded(child: _buildStatCard('Present Today', present.toString(), Colors.green[100]!)),
                   ],
                 ),
                 const SizedBox(height: 30),
                 SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.list_alt),
                label: const Text('View All Employees'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                onPressed: () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeListPage()));
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.history),
                label: const Text('Attendance Logs'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                onPressed: () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => const AttendanceRecordsPage()));
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.mail),
                label: const Text('Mail (Requests)'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.orange),
                onPressed: () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminMailBoxPage()));
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.access_time), // Settings Icon
                label: const Text('Work Timing Settings'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.grey[800], foregroundColor: Colors.white),
                onPressed: () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSettingsPage()));
                },
              ),
            ),   ],
             ),
           );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          Text(title, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
