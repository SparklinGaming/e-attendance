import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart'; // Added for BarChart
import 'home.dart';
import 'schedule.dart';
import 'login.dart';

import 'package:e_attend/utils/stats_helper.dart';
import 'package:e_attend/services/firestore_service.dart'; // Import Service
import 'package:intl/intl.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Added for _buildProfileHeader
  final StatsHelper _statsHelper = StatsHelper(); // Added for stats calculation
  
  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: Color(0xffFFD95A),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            switch (index) {
              case 0:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                );
                break;
              case 1:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SchedulePage()),
                );
                break;
              case 2:
                break; // Already on Profile
            }
          },

          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'schedule',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'profile'),
          ],
          selectedItemColor: Colors.black,
        ),
      body: FutureBuilder<Map<String, int>?>(
        future: FirestoreService().getWorkSettings(), // Fetch settings once
        builder: (context, settingsSnapshot) {
           final workSettings = settingsSnapshot.data;
           
           return StreamBuilder<QuerySnapshot>(
            stream: _statsHelper.getUserAttendanceStream(currentUser!.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              final stats = _statsHelper.calculateStats(docs, workSettings: workSettings);
              final weeklyData = _statsHelper.calculateWeeklyData(docs);

          
          final int present = stats['present'] ?? 0;
          final int late = stats['late'] ?? 0;
          final int absence = stats['absence'] ?? 0;

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildProfileHeader(currentUser!.uid), 
                const SizedBox(height: 30),
                
                // Attendance Stats Box
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xffC07F00),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Absence', absence.toString()),
                      _buildVerticalDivider(),
                      _buildStatItem('Present', present.toString()),
                      _buildVerticalDivider(),
                      _buildStatItem('Late', late.toString()),
                    ],
                  ),
                ),
                
                // Late Warning
                if (late > 3)
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning, color: Colors.red),
                        SizedBox(width: 10),
                        Expanded(child: Text("Warning: You have been late more than 3 times this month!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),

                 // Chart Section
                 Container(
                   margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                   height: 200,
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     color: Colors.white,
                     borderRadius: BorderRadius.circular(16)
                   ),
                   child: Column(
                     children: [
                       const Text("Weekly Work Hours", style: TextStyle(fontWeight: FontWeight.bold)),
                       const SizedBox(height: 10),
                       Expanded(
                         child: BarChart(
                           BarChartData(
                             alignment: BarChartAlignment.spaceAround,
                             maxY: 12,
                             barTouchData: BarTouchData(enabled: false),
                             titlesData: FlTitlesData(
                               show: true,
                               bottomTitles: AxisTitles(
                                 sideTitles: SideTitles(
                                   showTitles: true,
                                   getTitlesWidget: (value, meta) {
                                      return Text(["M","T","W","T","F","S","S"][value.toInt() % 7]); 
                                   },
                                 ),
                               ),
                               leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                               topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                               rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                             ),
                             gridData: FlGridData(show: false),
                             borderData: FlBorderData(show: false),
                             barGroups: weeklyData.asMap().entries.map((e) {
                               return BarChartGroupData(
                                 x: e.key,
                                 barRods: [
                                   BarChartRodData(toY: e.value, color: Colors.orange, width: 14)
                                 ],
                               );
                             }).toList(),
                           ),
                         ),
                       ),
                     ],
                   ),
                 ),

                 // Attendance History List
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 20.0),
                   child: const Align(
                     alignment: Alignment.centerLeft,
                     child: Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   ),
                 ),
                 ListView.builder(
                   shrinkWrap: true,
                   physics: const NeverScrollableScrollPhysics(),
                   itemCount: docs.length,
                   itemBuilder: (context, index) {
                      // Sort desc locally to show latest first
                      docs.sort((a,b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));
                      
                      var data = docs[index].data() as Map<String, dynamic>;
                      bool isCheckIn = data['type'] == 'in';
                      Timestamp ts = data['timestamp'];
                      String date = DateFormat('yyyy-MM-dd').format(ts.toDate());
                      String time = DateFormat('hh:mm a').format(ts.toDate());

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          leading: Icon(
                            isCheckIn ? Icons.login : Icons.logout,
                            color: isCheckIn ? Colors.green : Colors.red,
                          ),
                          title: Text(isCheckIn ? "Check In" : "Check Out", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(date),
                          trailing: Text(time, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      );
                   },
                 ),

                const SizedBox(height: 20),
                GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder:
                              (_) => AlertDialog(
                                title: const Text('Confirm Logout'),
                                content: const Text(
                                  'Are you sure you want to logout?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.of(context).pop();
                                      await FirebaseAuth.instance.signOut();
                                      Navigator.of(context).pushReplacement(
                                          MaterialPageRoute(
                                            builder: (_) => const LoginPage(),
                                          ),
                                      );
                                    },
                                    child: const Text(
                                      'Logout',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14, // Changed from 12 to 14 for consistency
                          horizontal: 20, // Changed from 25 to 20 for consistency
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xfffff3cd),
                          border: Border.all(color: Colors.red),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: Colors.red),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Log Out',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.red,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
              ],
            ),
          );
        },
      );
     },
    ),
      ),
    );
  }
  // Helper: Profile Header
  Widget _buildProfileHeader(String uid) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
         if (!snapshot.hasData) return const CircularProgressIndicator();
         var data = snapshot.data!.data() as Map<String, dynamic>?;
         String name = data?['name'] ?? 'User';
         String role = data?['role'] ?? 'Employee';
         String email = data?['email'] ?? '';
         
         return Column(
           children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.orange[100],
                child: const Icon(Icons.person, size: 50, color: Colors.orange),
              ),
              const SizedBox(height: 10),
              Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(role.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
              Text(email, style: const TextStyle(fontSize: 14, color: Colors.black45)),
           ],
         );
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.white30);
  }
} 
