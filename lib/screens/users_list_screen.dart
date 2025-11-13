import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'private_chat_screen.dart';
import '../models/user_model.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  Future<String> _createOrGetConversation(String otherUserId) async {
    // Check if conversation already exists
    final existingConversations = await FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: currentUser!.uid)
        .where('isGroup', isEqualTo: false)
        .get();

    for (var doc in existingConversations.docs) {
      final participants = List<String>.from(doc.data()['participants']);
      if (participants.contains(otherUserId) && participants.length == 2) {
        return doc.id;
      }
    }

    // Create new conversation
    final newConversation = await FirebaseFirestore.instance
        .collection('conversations')
        .add({
      'participants': [currentUser!.uid, otherUserId],
      'lastMessage': '',
      'lastMessageTime': Timestamp.now(),
      'unreadCount': {
        currentUser!.uid: 0,
        otherUserId: 0,
      },
      'createdAt': Timestamp.now(),
      'isGroup': false,
    });

    return newConversation.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select contact',
              style: TextStyle(fontSize: 19),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('uid', isNotEqualTo: currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                return Text(
                  '${snapshot.data!.docs.length} contacts',
                  style: const TextStyle(fontSize: 13),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() {
                _searchQuery = _searchQuery.isEmpty ? ' ' : '';
              });
            },
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                child: Text('Invite a friend'),
              ),
              const PopupMenuItem(
                child: Text('Contacts'),
              ),
              const PopupMenuItem(
                child: Text('Refresh'),
              ),
              const PopupMenuItem(
                child: Text('Help'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar (shown when search is active)
          if (_searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.grey[50],
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by name or phone',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
          // Quick actions
          ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF25D366),
              child: const Icon(Icons.group_add, color: Colors.white),
            ),
            title: const Text(
              'New group',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () {
              // Navigate to new group screen
            },
          ),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF25D366),
              child: const Icon(Icons.person_add, color: Colors.white),
            ),
            title: const Text(
              'New contact',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.qr_code),
            onTap: () {
              // Add new contact
            },
          ),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF25D366),
              child: const Icon(Icons.groups, color: Colors.white),
            ),
            title: const Text(
              'New community',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () {
              // Create community
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            width: double.infinity,
            child: Text(
              'Contacts on WhatsApp',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Contacts list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('uid', isNotEqualTo: currentUser!.uid)
                  .orderBy('uid')
                  .orderBy('username')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF25D366),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No contacts found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () {
                            // Invite friends
                          },
                          child: const Text(
                            'Invite friends to WhatsApp',
                            style: TextStyle(
                              color: Color(0xFF25D366),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                var users = snapshot.data!.docs;
                
                // Filter based on search query
                if (_searchQuery.isNotEmpty && _searchQuery != ' ') {
                  users = users.where((doc) {
                    final userData = doc.data() as Map<String, dynamic>;
                    final username = (userData['username'] ?? '').toString().toLowerCase();
                    final phone = (userData['phone'] ?? '').toString().toLowerCase();
                    final status = (userData['status'] ?? '').toString().toLowerCase();
                    
                    return username.contains(_searchQuery) ||
                           phone.contains(_searchQuery) ||
                           status.contains(_searchQuery);
                  }).toList();
                }

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No results found for "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userDoc = users[index];
                    final user = UserModel.fromMap(
                      userDoc.data() as Map<String, dynamic>,
                      userDoc.id,
                    );

                    return ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: user.profileImage.isNotEmpty
                                ? NetworkImage(user.profileImage)
                                : null,
                            child: user.profileImage.isEmpty
                                ? Text(
                                    user.username.isNotEmpty
                                        ? user.username[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          if (user.isOnline)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        user.username,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        user.status,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () async {
                        // Create or get existing conversation
                        final conversationId = await _createOrGetConversation(user.uid);
                        
                        // Navigate to chat
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PrivateChatScreen(
                                conversationId: conversationId,
                                otherUserId: user.uid,
                                otherUserName: user.username,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF25D366),
        onPressed: () {
          // Show help or invite
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Invite friends'),
              content: const Text('Share WhatsApp with your friends!'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Share app link
                  },
                  child: const Text('Share'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.message, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}