import 'package:flutter/material.dart';

class AlarmDismissedScreen extends StatelessWidget {
  final int attempts;
  const AlarmDismissedScreen({super.key, required this.attempts});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 60, color: Colors.green),
              ),
              const SizedBox(height: 30),
              const Text("Alarm dismissed", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("You read and understood today's passage.\nHave a focused morning.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                      children: [
                        Text("$attempts", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text("Attempt", style: TextStyle(color: Colors.grey))
                      ]
                  ),
                ],
              ),
              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  onPressed: () => Navigator.popUntil(context, (route) => route.isFirst), // Goes back to Home
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text("Back to alarms", style: TextStyle(color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}