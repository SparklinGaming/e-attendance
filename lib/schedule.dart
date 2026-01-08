import 'package:flutter/material.dart';
import 'package:e_attend/request_form.dart';
import 'home.dart';
import 'profile.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  @override
  Widget build(BuildContext context) {
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
                // Already on Schedule
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
        appBar: AppBar(title: const Text('Schedule Page'), centerTitle: true),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_time_filled, size: 64, color: Colors.orange),
              const SizedBox(height: 20),
              const Text(
                'Regular Shift',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Monday - Friday\n09:00 AM - 05:00 PM',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const RequestFormPage()));
          },
          label: const Text("Request"),
          icon: const Icon(Icons.add),
          backgroundColor: Colors.blue,
        ),
      ),
    );
  }
}
