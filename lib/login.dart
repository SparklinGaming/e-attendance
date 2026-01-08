import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';
import 'home.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginFormKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  Future<void> _login() async {
    try {
      await _authService.signIn(
        _emailController.text,
        _passwordController.text,
      );
      // No need to navigate manually; AuthWrapper handles it via Stream
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No user found with that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e'), duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Page'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        // padding: const EdgeInsets.all(70.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Image.asset(
                'assets/images/Logo.png',
                // alignment: Alignment.bottomCenter,
                height: 100,
              ),
              SizedBox(height: 100),
              Form(
                key: _loginFormKey,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: <Widget>[
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z.-]+\.[a-zA-Z]{2,}$',
                          ).hasMatch(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                        onFieldSubmitted: (value) {
                          if (_loginFormKey.currentState!.validate()) {
                            _login();
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (!RegExp(
                                r'(?=.*[A-Z])(?=.*[a-z])(?=.*\d)',
                              ).hasMatch(value) ||
                              value.length < 8) {
                            return 'Password must be at least 8 characters long and must contain upper/lower case and number';
                          }
                          return null;
                        },
                        onFieldSubmitted: (value) {
                          if (_loginFormKey.currentState!.validate()) {
                            _login();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_loginFormKey.currentState!.validate()) {
                    _login();
                  }
                  // Navigate to another page or perform login action
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 80,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Login'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () async {
                  String result = await _authService.seedTestUsers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result)),
                  );
                },
                child: const Text('Dev: Seed Test Users (admin@test.com / employee@test.com)', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Color(0xffFFD95A),
    );
  }
}
