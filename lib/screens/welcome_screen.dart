import 'package:flutter/material.dart';
import 'home_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    // FIXED: withOpacity to withValues
                    boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.1), blurRadius: 20)]
                ),
                child: const Icon(Icons.alarm, size: 64, color: Color(0xFF1E3A8A)),
              ),
              const SizedBox(height: 30),
              const Text("Welcome", style: TextStyle(fontSize: 18, color: Colors.grey)),
              const Text("AttentioClock", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
              const SizedBox(height: 10),
              const Text("Wake up with a clear mind.", style: TextStyle(fontSize: 16, color: Colors.black54)),
              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text("Get started", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}