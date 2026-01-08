import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper to get formatted date
  String get _todayDate => DateFormat('yyyy-MM-dd').format(DateTime.now());

  // Check In
  Future<void> checkIn(String uid, {String? notes}) async {
    try {
      final now = DateTime.now();
      // Fetch user name
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      String name = (userDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Unknown';

      await _firestore.collection('attendance').add({
        'uid': uid,
        'name': name,
        'date': _todayDate,
        'type': 'in',
        'notes': notes,
        'timestamp': Timestamp.fromDate(now),
      });
    } catch (e) {
      print("CheckIn Error: $e");
      rethrow;
    }
  }

  // Check Out
  Future<void> checkOut(String uid, {String? notes}) async {
    try {
      final now = DateTime.now();
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      String name = (userDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Unknown';

      await _firestore.collection('attendance').add({
         'uid': uid,
         'name': name,
         'date': _todayDate,
         'type': 'out',
         'notes': notes,
         'timestamp': Timestamp.fromDate(now),
      });
    } catch (e) {
       print("CheckOut Error: $e");
       rethrow;
    }
  }

  // Get all attendance for a user (client-side filtering for today)
  Stream<QuerySnapshot> getUserAttendanceStream(String uid) {
    return _firestore
        .collection('attendance')
        .where('uid', isEqualTo: uid)
        .snapshots();
  }

  // Get employee list (Admin)
  Stream<QuerySnapshot> getEmployees() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .snapshots();
  }

  // --- Admin: Work Settings ---
  Future<void> setWorkSettings(TimeOfDay start, TimeOfDay end) async {
    await _firestore.collection('settings').doc('work_timing').set({
      'start_hour': start.hour,
      'start_minute': start.minute,
      'end_hour': end.hour,
      'end_minute': end.minute,
    });
  }

  Future<Map<String, int>?> getWorkSettings() async {
    var doc = await _firestore.collection('settings').doc('work_timing').get();
    if (doc.exists) {
       var data = doc.data() as Map<String, dynamic>;
       return {
         'start_hour': data['start_hour'],
         'start_minute': data['start_minute'],
         'end_hour': data['end_hour'],
         'end_minute': data['end_minute'],
       };
    }
    return null;
  }

  // --- Admin: Leave Management (Now Request System) ---
  
  // Employee Submits Request
  Future<void> submitRequest(String uid, String type, String date, String reason) async {
    // Determine name for easier display
    var userDoc = await _firestore.collection('users').doc(uid).get();
    String name = userDoc.exists && userDoc.data() != null ? (userDoc.data() as Map<String, dynamic>)['name'] : 'Unknown';

    await _firestore.collection('leaves').add({
      'uid': uid,
      'name': name,
      'type': type,
      'date': date,
      'reason': reason,
      'status': 'Pending', 
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Notify Admin (General notification or specific admin id if we had one. For now just a generic 'admin' topic or just rely on Mailbox UI)
    // Since we don't have Admin UIDs hardcoded for notifications, we can store it in a way Admin page reads it.
    // The "Mail" page IS the notification for Admin.
    // But if we truly want to use the notification system:
    await _firestore.collection('notifications').add({
       'title': 'New Request',
       'message': '$name requested $type for $date',
       'created_at': FieldValue.serverTimestamp(),
       'target': 'admin', // Flag for admin only? For MVP, let's just create it.
    });
  }

  Stream<QuerySnapshot> getPendingLeaves() {
    return _firestore.collection('leaves')
      .where('status', isEqualTo: 'Pending')
      .orderBy('date', descending: true)
      .snapshots();
  }

  // Admin Approves/Rejects
  Future<void> updateRequestStatus(String docId, String status, String uid, String type) async {
    await _firestore.collection('leaves').doc(docId).update({
      'status': status,
    });

    // Notify Employee
    await _firestore.collection('notifications').add({
      'title': 'Request Updated',
      'message': 'Your $type request has been $status.',
      'created_at': FieldValue.serverTimestamp(),
      'uid': uid, // Target specific user? Our notification page currently fetches ALL notifications. 
                  // We need to update Notification Page to filter by UID if we want private notifs.
                  // For now, let's just save it.
    });
  }

  Future<void> deleteLeave(String docId) async {
    await _firestore.collection('leaves').doc(docId).delete();
  }

  // Get attendance records (Admin)
  Stream<QuerySnapshot> getAttendanceRecords(String? date) {
    Query query = _firestore.collection('attendance').orderBy('timestamp', descending: true);
    if (date != null) {
      query = query.where('date', isEqualTo: date);
    }
    return query.snapshots();
  }

  // Get stats (Admin)
  Future<Map<String, int>> getStats() async {
    final usersSnapshot = await _firestore.collection('users').where('role', isEqualTo: 'employee').get();
    final int totalEmployees = usersSnapshot.size;

    final attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('date', isEqualTo: _todayDate)
        .where('type', isEqualTo: 'in')
        .get();
    
    // Distinct users who checked in today
    final presentUserIds = attendanceSnapshot.docs.map((doc) => doc['uid']).toSet();
    final int presentToday = presentUserIds.length;

    return {
      'totalEmployees': totalEmployees,
      'presentToday': presentToday,
    };
  }

  // --- Admin: Notifications ---
  Future<void> addNotification(String title, String message) async {
    await _firestore.collection('notifications').add({
      'title': title,
      'message': message,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getNotifications() {
    return _firestore
        .collection('notifications')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Future<void> deleteNotification(String docId) async {
    await _firestore.collection('notifications').doc(docId).delete();
  }
}
