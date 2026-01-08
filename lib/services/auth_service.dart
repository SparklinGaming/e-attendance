import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign In
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // Create Employee Account (Admin only)
  // This uses a secondary Firebase App instance so the Admin doesn't get logged out
  Future<String?> createEmployeeAccount(String email, String password, String name) async {
    FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'tempApp',
      options: Firebase.app().options,
    );
    
    try {
      UserCredential result = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(email: email, password: password);
          
      if (result.user != null) {
        // Store user details in main Firestore
        await _firestore.collection('users').doc(result.user!.uid).set({
          'uid': result.user!.uid,
          'email': email,
          'name': name,
          'role': 'employee',
        });
        
        await tempApp.delete(); // Cleanup
        return null; // Success
      }
      return "Failed to create user";
    } catch (e) {
      await tempApp.delete();
      return e.toString();
    }
  }
  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get user role
  Future<String> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['role'] ?? 'employee'; 
      }
      return 'employee'; // Default to employee
    } catch (e) {
      print("Error fetching user role: $e");
      return 'employee';
    }
  }

  // Creating a user document if it doesn't exist
  Future<void> createUserDoc(String uid, String email, String name, String role) async {
    await _firestore.collection('users').doc(uid).set({
      'email': email,
      'name': name,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
  
  // Seed Test Users (Dev Helper)
  Future<String> seedTestUsers() async {
    try {
      // Create Admin
      try {
        UserCredential adminCred = await _auth.createUserWithEmailAndPassword(
          email: 'admin@test.com',
          password: 'password123',
        );
        await createUserDoc(adminCred.user!.uid, 'admin@test.com', 'Admin User', 'admin');
      } catch (e) { 
        // Ignore if already exists, but try to update doc
        // Note: Can't easily get UID if auth fails, but for dev seed we assume fresh or ignoring.
        print('Admin creation skipped (likely exists): $e');
      }

      // Create Employee
      try {
        UserCredential empCred = await _auth.createUserWithEmailAndPassword(
          email: 'employee@test.com',
          password: 'password123',
        );
        await createUserDoc(empCred.user!.uid, 'employee@test.com', 'John Employee', 'employee');
      } catch (e) {
        print('Employee creation skipped (likely exists): $e');
      }
      return 'Seeding attempt complete. Try logging in.';
    } catch (e) {
      return 'Seeding failed: $e';
    }
  }
}
