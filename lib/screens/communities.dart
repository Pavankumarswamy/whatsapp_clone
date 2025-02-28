import 'package:flutter/material.dart';

class CommunitiesScreen extends StatelessWidget {
  const CommunitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Ensures the background is white
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Placeholder for community items
          _buildCommunityItem(
            context,
            'Flutter Devs',
            'Discussing Flutter tips and tricks',
            'https://via.placeholder.com/150', // Placeholder image URL
          ),
          _buildCommunityItem(
            context,
            'Open Source Enthusiasts',
            'Contributing to OSS projects',
            'https://via.placeholder.com/150',
          ),
          _buildCommunityItem(
            context,
            'AI Innovators',
            'Exploring AI advancements',
            'https://via.placeholder.com/150',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add functionality to create a new community
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Create new community')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCommunityItem(
      BuildContext context, String name, String description, String imageUrl) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(imageUrl),
        ),
        title: Text(name),
        subtitle: Text(description),
        onTap: () {
          // Navigate to community details or chat
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tapped on $name')),
          );
        },
      ),
    );
  }
}
