import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firestore_service.dart';

class RequestFormPage extends StatefulWidget {
  const RequestFormPage({super.key});

  @override
  State<RequestFormPage> createState() => _RequestFormPageState();
}

class _RequestFormPageState extends State<RequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  String _selectedType = 'AL'; // Annual Leave
  final List<String> _types = ['AL', 'EL', 'MC', 'Overtime'];
  
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
       setState(() {
         _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
       });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Submit Request")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Request Type", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              
              const Text("Date", style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                onTap: () => _selectDate(context),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
              ),
              const SizedBox(height: 16),

              const Text("Reason", style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Enter reason..."),
                validator: (val) => val == null || val.isEmpty ? "Please enter a reason" : null,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                       try {
                         await _firestoreService.submitRequest(
                           currentUser!.uid, 
                           _selectedType, 
                           _dateController.text, 
                           _reasonController.text
                         );
                         if (mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Submitted!")));
                           Navigator.pop(context);
                         }
                       } catch (e) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                       }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text("Submit", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
