import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StatsHelper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch all attendance for a user
  Stream<QuerySnapshot> getUserAttendanceStream(String uid) {
    return _firestore
        .collection('attendance')
        .where('uid', isEqualTo: uid)
        .snapshots();
  }

  // Calculate Monthly Stats
  // Now accepts optional workSettings from Firestore
  Map<String, dynamic> calculateStats(List<QueryDocumentSnapshot> docs, {Map<String, int>? workSettings}) {
    int present = 0;
    int late = 0;
    int absence = 0; 
    // If we had leave records here, we could count approved leaves as 'Excused' or separate category
    // For MVP, if check-in exists -> Present/Late. If not -> Absence (simplified).

    DateTime now = DateTime.now();
    String currentMonth = DateFormat('yyyy-MM').format(now);

    // Filter for current month
    List<QueryDocumentSnapshot> monthDocs = docs.where((doc) {
      String date = doc['date']; // yyyy-MM-dd
      return date.startsWith(currentMonth);
    }).toList();

    Set<String> presentDays = {};
    
    // Default 9:00 AM if not set
    int startHour = workSettings?['start_hour'] ?? 9;
    int startMinute = workSettings?['start_minute'] ?? 0;

    for (var doc in monthDocs) {
      if (doc['type'] == 'in') {
        presentDays.add(doc['date']);
        
        // Dynamic Late Check
        Timestamp ts = doc['timestamp'];
        DateTime dt = ts.toDate();
        
        // Late if Hour > startHour OR (Hour == startHour AND Minute > startMinute)
        // With a small buffer maybe? Strict for now.
        if (dt.hour > startHour || (dt.hour == startHour && dt.minute > startMinute)) {
           late++;
        }
      }
    }
    
    present = presentDays.length;
    
    return {
      'present': present,
      'late': late,
      'absence': 0, 
    };
  }

  // Calculate Weekly Data for Graph (Last 7 days)
  List<double> calculateWeeklyData(List<QueryDocumentSnapshot> docs) {
    // Return list of 7 doubles representing hours worked or just binary present?
    // User asked "graph for each days". 
    // Let's show "Hours Worked" per day for the last 7 days.
    
    DateTime now = DateTime.now();
    List<double> weeklyHours = List.filled(7, 0.0); // Index 0 = 6 days ago, Index 6 = Today
    
    for (int i = 0; i < 7; i++) {
       DateTime targetDate = now.subtract(Duration(days: 6 - i));
       String dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
       
       // Find In and Out for this date
       var daysDocs = docs.where((d) => d['date'] == dateStr).toList();
       var ins = daysDocs.where((d) => d['type'] == 'in').toList();
       var outs = daysDocs.where((d) => d['type'] == 'out').toList();
       
       if (ins.isNotEmpty && outs.isNotEmpty) {
         // Sort to ensure we get earliest in and latest out
         ins.sort((a,b) => (a['timestamp'] as Timestamp).compareTo(b['timestamp']));
         outs.sort((a,b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp'])); // desc

         DateTime inTime = (ins.first['timestamp'] as Timestamp).toDate();
         DateTime outTime = (outs.first['timestamp'] as Timestamp).toDate();
         
         if (outTime.isAfter(inTime)) {
            double hours = outTime.difference(inTime).inMinutes / 60.0;
            weeklyHours[i] = hours > 12 ? 12 : hours; // Cap at 12 for chart visual?
         }
       }
    }
    
    return weeklyHours;
  }
}
