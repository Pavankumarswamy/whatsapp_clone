import 'package:flutter/material.dart';

class StatusTab extends StatelessWidget {
  const StatusTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // Ensures the background is white
      child: ListView(
        children: [
          const ListTile(
            leading: CircleAvatar(child: Icon(Icons.person)),
            title: Text('My Status'),
            subtitle: Text('Tap to add status update'),
          ),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Recent updates', style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: const CircleAvatar(child: Icon(Icons.person)),
            ),
            title: const Text('Alice Smith'),
            subtitle: const Text('2 minutes ago'),
          ),
        ],
      ),
    );
  }
}
