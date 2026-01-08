import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final FirestoreService _firestoreService = FirestoreService();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    var settings = await _firestoreService.getWorkSettings();
    if (settings != null) {
      setState(() {
        _startTime = TimeOfDay(hour: settings['start_hour']!, minute: settings['start_minute']!);
        _endTime = TimeOfDay(hour: settings['end_hour']!, minute: settings['end_minute']!);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    await _firestoreService.setWorkSettings(_startTime, _endTime);
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings Saved!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Work Timing Settings")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                   const Text("Set Standard Work Hours", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 20),
                   ListTile(
                     title: const Text("Start Time (Check In)"),
                     trailing: Text(_startTime.format(context), style: const TextStyle(fontSize: 16)),
                     onTap: () => _selectTime(true),
                   ),
                   const Divider(),
                   ListTile(
                     title: const Text("End Time (Check Out)"),
                     trailing: Text(_endTime.format(context), style: const TextStyle(fontSize: 16)),
                     onTap: () => _selectTime(false),
                   ),
                   const SizedBox(height: 40),
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton(
                       style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.blue, 
                         padding: const EdgeInsets.symmetric(vertical: 15)
                       ),
                       onPressed: _saveSettings,
                       child: const Text("Save Settings", style: TextStyle(color: Colors.white, fontSize: 16)),
                     ),
                   )
                ],
              ),
            ),
    );
  }
}
