import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:whatsup/authentication/login.dart';
import 'package:whatsup/screens/animatedicons.dart';
import 'package:whatsup/screens/call.dart';
import 'package:whatsup/screens/chat.dart';
import 'package:whatsup/screens/communities.dart';
import 'package:whatsup/screens/status.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  late PageController _pageController;
  int unreadMessages = 0; // Dummy unread message count

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _pageController = PageController(initialPage: _selectedIndex);
    _searchController.addListener(() {
      setState(() {}); // Rebuild when search text changes
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _getFab() {
    if (_selectedIndex == 0) {
      return FloatingActionButton(
        backgroundColor: const Color(0xFF25D366),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Starting a new chat...')),
          );
        },
        child: const Icon(Icons.message, color: Colors.white),
      );
    } else if (_selectedIndex == 1) {
      return FloatingActionButton(
        backgroundColor: const Color(0xFF25D366),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Posting a new status...')),
          );
        },
        child: const Icon(Icons.camera_alt, color: Colors.white),
      );
    } else if (_selectedIndex == 3) {
      return FloatingActionButton(
        backgroundColor: const Color(0xFF25D366),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Starting a new call...')),
          );
        },
        child: const Icon(Icons.add_call, color: Colors.white),
      );
    }
    return Container(); // No FAB for Communities tab
  }

  void _onSearchSubmitted(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Searching for: $value')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, // WhatsApp's light theme background
        elevation: 0, // Remove shadow
        title: Row(
          children: [
            const Text(
              'WhatsUP',
              style: TextStyle(
                color: Color(0xFF075E54), // WhatsApp Green
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.black87),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Scanning QR code...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.black87),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening camera...')),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (value) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(value)),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'New Group', child: Text('New Group')),
              const PopupMenuItem(value: 'Settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white, // Background of the search bar container
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Ask Meta AI or Search',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors
                      .grey[200], // Keeps the TextField's background light grey
                ),
                onChanged: (text) {
                  setState(() {}); // Refresh UI when text changes
                },
                onSubmitted: _onSearchSubmitted,
              ),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                  _tabController.animateTo(index);
                });
              },
              children: const [
                ChatsTab(),
                StatusTab(),
                CommunitiesScreen(),
                CallsTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(color: Colors.green),
        unselectedLabelStyle: const TextStyle(color: Colors.grey),
        backgroundColor: Colors.white,
        items: [
          BottomNavigationBarItem(
            icon: SizedBox(
              width: 24, // Matches default icon size
              height: 24,
              child: Stack(
                children: [
                  Center(
                    child: AnimatedIconWidget(
                      icon: Icons.chat_bubble,
                      isSelected: _selectedIndex == 0,
                    ),
                  ),
                  if (unreadMessages > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadMessages',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: AnimatedIconWidget(
              icon: Icons.notifications,
              isSelected: _selectedIndex == 1,
            ),
            label: 'Status',
          ),
          BottomNavigationBarItem(
            icon: AnimatedIconWidget(
              icon: Icons.group,
              isSelected: _selectedIndex == 2,
            ),
            label: 'Communities',
          ),
          BottomNavigationBarItem(
            icon: AnimatedIconWidget(
              icon: Icons.call,
              isSelected: _selectedIndex == 3,
            ),
            label: 'Calls',
          ),
        ],
      ),
      floatingActionButton: _getFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
