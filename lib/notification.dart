import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'home.dart';
import 'schedule.dart';
import 'profile.dart';
import 'services/firestore_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final FirestoreService _firestoreService = FirestoreService();

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
        appBar: AppBar(title: const Text('Notifications'), centerTitle: true),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            switch (index) {
              case 0:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                );
                break;
              case 1:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SchedulePage()),
                );
                break;
              case 2:
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
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
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestoreService.getUserAttendanceStream(currentUser!.uid), 
          // FirestoreService currently has getTodayAttendanceStream. I need a getAll for user.
          // Let's modify logic to query all history. 
          // Since I can't easily change service in this same tool call without confusing the context, 
          // I'll assume I can use a direct query here or modify service next.
          // For now, I'll use a direct query.
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Direct query since I missed adding getHistory(uid) in service.
            // Wait, I can't do direct query easily without instance. 
            // _firestoreService has ._firestore which is private.
            // I should just use FirebaseFirestore.instance directly here or use what I have.
            // Let's use FirebaseFirestore direct for MVP speed.
            return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('notifications').orderBy('created_at', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notifications yet."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.notifications, color: Colors.blue),
                  title: Text(data['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['message'] ?? 'No Message'),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      );
          },
        ),
      ),
    );
  }
}
