import 'package:flutter/material.dart';

class CallsTab extends StatelessWidget {
  const CallsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Ensures the background is white
      body: ListView(
        children: const [
          ListTile(
            leading: CircleAvatar(child: Icon(Icons.person)),
            title: Text('Bob Johnson'),
            subtitle: Row(
              children: [
                Icon(Icons.call_received, size: 16, color: Colors.red),
                SizedBox(width: 5),
                Text('Yesterday, 10:45 PM'),
              ],
            ),
            trailing: Icon(Icons.call),
          ),
        ],
      ),
    );
  }
}
