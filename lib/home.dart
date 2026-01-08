import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'services/firestore_service.dart';
import 'notification.dart';
import 'schedule.dart';
import 'profile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class Eattend extends StatelessWidget {
  const Eattend({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      initialRoute: '/',
      routes: {'/': (context) => HomePage()},
    );
  }
}

class _HomePageState extends State<HomePage> {
  final FirestoreService _firestoreService = FirestoreService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Color(0xffFFD95A),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          switch (index) {
            case 0:
              break; // Already on Home
            case 1:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SchedulePage()),
              );
              break;
            case 2:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            backgroundColor: Color.fromARGB(0, 0, 0, 0),
            label: 'home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'schedule',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'profile'),
        ],
        selectedItemColor: Colors.black,
      ),
      appBar: AppBar(
        title: const Text('Home Page'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getUserAttendanceStream(currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
             return Center(child: Text("Error: ${snapshot.error}"));
          }

          // Parse attendance data
          List<QueryDocumentSnapshot> allDocs = snapshot.data?.docs ?? [];
          
          // Client-side sort descending
          allDocs.sort((a, b) {
             Timestamp tA = a['timestamp'];
             Timestamp tB = b['timestamp'];
             return tB.compareTo(tA); // Descending
          });

          // Filter for TODAY for the status card
          String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
          List<QueryDocumentSnapshot> todayDocs = allDocs.where((doc) {
            return doc['date'] == todayDate;
          }).toList();

          String? checkInTime;
          String? checkOutTime;
          
          // Logic for today's status
          List<QueryDocumentSnapshot> ins = todayDocs.where((d) => d['type'] == 'in').toList();
          List<QueryDocumentSnapshot> outs = todayDocs.where((d) => d['type'] == 'out').toList();

          if (ins.isNotEmpty) {
            // Take the FIRST check-in of the day (earliest)
            // Since todayDocs is sorted Descending, the LAST item is the earliest.
            Timestamp ts = ins.last['timestamp']; 
            checkInTime = DateFormat('hh:mm a').format(ts.toDate());
          }

          if (outs.isNotEmpty) {
             // Take the LAST check-out (most recent)
             // todayDocs is sorted Descending, so FIRST item is latest.
             Timestamp ts = outs.first['timestamp']; 
             checkOutTime = DateFormat('hh:mm a').format(ts.toDate());
          }
          
          // Determine Check In button state
          // If no events today -> Show Check In
          // If Checked In but not Checked Out -> Show Check Out
          // If Checked Out -> Show Check In (allow multiple shifts? or restricted? MVP usually allows 1 cycle or multiple)
          // Let's rely on the most recent event of today.
          String lastType = todayDocs.isNotEmpty ? todayDocs.first['type'] : 'out';
          
          DateTime? checkInTimestamp;
          if (ins.isNotEmpty) {
             checkInTimestamp = (ins.last['timestamp'] as Timestamp).toDate();
          }

          return Column(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _builderHeader(),
                  _buildCheckInOutCard(
                    checkInTime, 
                    checkOutTime, 
                    lastType == 'out',
                    checkInDateTime: checkInTimestamp
                  ),
                ],
              ),
              Expanded(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       _buildRecentActivity(allDocs), // Pass ALL history to recent activity
                    ],
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _builderHeader() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hi,',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                DateFormat('dd MMM yyyy').format(DateTime.now()), 
                style: const TextStyle(fontSize: 16)
              ),
            ],
          ),
          Row(
            children: [
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfilePage(),
                    ),
                  );
                },
                child: const CircleAvatar(
                  radius: 25,
                  backgroundImage: AssetImage('assets/images/Logo.png'),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () {
                  Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (context) => const NotificationPage(),
                     ),
                   );
                },
                child: const Icon(
                  Icons.notifications,
                  size: 30,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInOutCard(String? checkInTime, String? checkOutTime, bool showCheckInButton, {DateTime? checkInDateTime}) {
    return FutureBuilder<Map<String, int>?>(
      future: _firestoreService.getWorkSettings(),
      builder: (context, snapshot) {
        bool isNowLate = false; // For the button (if not checked in yet)
        bool wasLateCheckIn = false; // For the text (if already checked in)

        if (snapshot.hasData && snapshot.data != null) {
          int startHour = snapshot.data!['start_hour']!;
          int startMinute = snapshot.data!['start_minute']!;
          
          DateTime now = DateTime.now();
          DateTime startTime = DateTime(now.year, now.month, now.day, startHour, startMinute);
          
          // Check if NOW is late (for button)
          if (now.isAfter(startTime)) {
             isNowLate = true;
          }

          // Check if ACTUAL CHECK IN was late (for status text)
          if (checkInDateTime != null) {
             DateTime checkInThreshold = DateTime(
               checkInDateTime.year, checkInDateTime.month, checkInDateTime.day,
               startHour, startMinute
             );
             if (checkInDateTime.isAfter(checkInThreshold)) {
                wasLateCheckIn = true;
             }
          }
        }

        String checkInStatus = '';
        if (checkInTime != null) {
           checkInStatus = wasLateCheckIn ? 'Late' : 'Present';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Row(
            children: [
              Expanded(
                child: _buildCheckCard(
                  isNowLate && showCheckInButton ? 'Late Check In' : 'Check In',
                  checkInTime ?? '--:--',
                  checkInStatus, // Dynamic Status
                  wasLateCheckIn && !showCheckInButton 
                      ? Colors.orange[100] // Checked in Late -> Orange
                      : (isNowLate && showCheckInButton ? Colors.orange[100] : Colors.green[100]),
                  showCheckInButton ? (isNowLate ? 'Late Check In' : 'Check In') : null,
                  () => _showAttendanceDialog('Check In'),
                  isLate: isNowLate && showCheckInButton,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCheckCard(
                  'Check Out',
                  checkOutTime ?? '--:--',
                  checkOutTime != null ? 'Completed' : '',
                  Colors.red[100],
                  !showCheckInButton ? 'Check Out' : null,
                  () => _showAttendanceDialog('Check Out'),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  bool _isWithinCheckInWindow(Map<String, int>? settings) {
    if (settings == null) return true; // Default allow if no settings
    
    DateTime now = DateTime.now();
    
    // Construct Start Time for Today
    DateTime startTime = DateTime(
      now.year, now.month, now.day,
      settings['start_hour']!, settings['start_minute']!
    );
    
    // Window: 30 mins before start
    DateTime windowStart = startTime.subtract(const Duration(minutes: 30));
    
    // Allow if Now >= WindowStart
    return now.isAfter(windowStart) || now.isAtSameMomentAs(windowStart);
  }

  Future<void> _showAttendanceDialog(String type) async {
    // Check Window Logic for Check-in
    if (type == 'Check In') {
       var settings = await _firestoreService.getWorkSettings();
       if (!_isWithinCheckInWindow(settings)) {
          // Show error
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Check-in is only allowed 30 minutes before work start time."),
            backgroundColor: Colors.red,
          ));
          return;
       }
    }

    final TextEditingController notesController = TextEditingController();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(type),
          content: TextField(
            controller: notesController,
            decoration: const InputDecoration(
              labelText: "Add Notes (Optional)",
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                 Navigator.pop(context);
                 try {
                   if (type == 'Check In') {
                     await _firestoreService.checkIn(currentUser!.uid, notes: notesController.text);
                   } else {
                     await _firestoreService.checkOut(currentUser!.uid, notes: notesController.text);
                   }
                   if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$type Successful!"), backgroundColor: Colors.green));
                   }
                 } catch (e) {
                   if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                   }
                 }
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCheckCard(
    String title,
    String time,
    String status,
    Color? color,
    String? buttonText,
    VoidCallback? onPressed, {
    bool isLate = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                title == 'Check In' ? Icons.login : Icons.logout,
                color: Colors.black54,
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            time,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Text(status, style: const TextStyle(fontSize: 12)),
          if (buttonText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: title == 'Check In' ? Colors.green[200] : Colors.red[200],
                  shape: const StadiumBorder(),
                ),
                child: Text(buttonText),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(List<QueryDocumentSnapshot> docs) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                 Icon(Icons.history_outlined),
                 SizedBox(width: 8),
                 Text(
                   'Recent Activity',
                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                 ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: docs.isEmpty
                  ? const Text("No activity.")
                  : ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        Map<String, dynamic> data = docs[index].data() as Map<String, dynamic>;
                        bool isCheckIn = data['type'] == 'in';
                        String time = DateFormat('hh:mm a').format((data['timestamp'] as Timestamp).toDate());
                        
                        return _buildRecentActivityRow(
                          isCheckIn: isCheckIn,
                          time: time,
                          date: data['date'],
                          status: isCheckIn ? 'Check In' : 'Check Out',
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityRow({
    required bool isCheckIn,
    required String time,
    required String date,
    required String status,
  }) {
    final icon = isCheckIn ? Icons.arrow_forward : Icons.arrow_back;
    final iconColor = isCheckIn ? Colors.green : Colors.red;
    final title = isCheckIn ? 'Check In' : 'Check Out';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withOpacity(0.15),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                status,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
  // Widget _buildSchedule() {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         const Text(
  //           'Schedule',
  //           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  //         ),
  //         const SizedBox(height: 8),
  //         // Add your schedule list here
  //       ],
  //     ),
  //   );
  // }

