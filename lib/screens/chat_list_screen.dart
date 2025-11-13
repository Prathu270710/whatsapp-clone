import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'private_chat_screen.dart';
import 'users_list_screen.dart';
import '../models/conversation_model.dart';
import '../models/user_model.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _updateOnlineStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateOnlineStatus(false);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateOnlineStatus(true);
    } else if (state == AppLifecycleState.paused) {
      _updateOnlineStatus(false);
    }
  }

  void _updateOnlineStatus(bool isOnline) async {
    if (currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({
        'isOnline': isOnline,
        'lastSeen': Timestamp.now(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'WhatsApp',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () {
              // Implement camera
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Implement search
            },
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new_group',
                child: Text('New group'),
              ),
              const PopupMenuItem(
                value: 'new_broadcast',
                child: Text('New broadcast'),
              ),
              const PopupMenuItem(
                value: 'linked_devices',
                child: Text('Linked devices'),
              ),
              const PopupMenuItem(
                value: 'starred_messages',
                child: Text('Starred messages'),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Text('Settings'),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                _updateOnlineStatus(false);
                FirebaseAuth.instance.signOut();
              }
              // Handle other menu items
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'CHATS'),
            Tab(text: 'STATUS'),
            Tab(text: 'CALLS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatsTab(),
          _buildStatusTab(),
          _buildCallsTab(),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildFAB() {
    IconData icon;
    VoidCallback onPressed;

    switch (_tabController.index) {
      case 0: // Chats
        icon = Icons.message;
        onPressed = () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UsersListScreen(),
            ),
          );
        };
        break;
      case 1: // Status
        icon = Icons.camera_alt;
        onPressed = () {
          // Add status
        };
        break;
      case 2: // Calls
        icon = Icons.add_call;
        onPressed = () {
          // Make call
        };
        break;
      default:
        icon = Icons.message;
        onPressed = () {};
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: FloatingActionButton(
        key: ValueKey(_tabController.index),
        backgroundColor: const Color(0xFF25D366),
        onPressed: onPressed,
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _buildChatsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: currentUser!.uid)
          .orderBy('lastMessageTime', descending: true)
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
          return _buildEmptyChats();
        }

        final conversations = snapshot.data!.docs;

        return ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conversationDoc = conversations[index];
            final conversation = ConversationModel.fromMap(
              conversationDoc.data() as Map<String, dynamic>,
              conversationDoc.id,
            );

            if (conversation.isGroup) {
              return _buildGroupChatTile(conversation);
            } else {
              return _buildPrivateChatTile(conversation);
            }
          },
        );
      },
    );
  }

  Widget _buildPrivateChatTile(ConversationModel conversation) {
    final otherUserId = conversation.participants.firstWhere(
      (id) => id != currentUser!.uid,
      orElse: () => '',
    );

    if (otherUserId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final userData = UserModel.fromMap(
          snapshot.data!.data() as Map<String, dynamic>,
          otherUserId,
        );

        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.grey[300],
                backgroundImage: userData.profileImage.isNotEmpty
                    ? NetworkImage(userData.profileImage)
                    : null,
                child: userData.profileImage.isEmpty
                    ? Text(
                        userData.username.isNotEmpty
                            ? userData.username[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              if (userData.isOnline)
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
            userData.username,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: Row(
            children: [
              if (conversation.lastMessage.isNotEmpty)
                Expanded(
                  child: Text(
                    conversation.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                )
              else
                Text(
                  'Tap to chat',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(conversation.lastMessageTime),
                style: TextStyle(
                  fontSize: 12,
                  color: (conversation.unreadCount[currentUser!.uid] ?? 0) > 0
                      ? const Color(0xFF25D366)
                      : Colors.grey[600],
                  fontWeight: (conversation.unreadCount[currentUser!.uid] ?? 0) > 0
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              if ((conversation.unreadCount[currentUser!.uid] ?? 0) > 0)
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFF25D366),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    conversation.unreadCount[currentUser!.uid]! > 99
                        ? '99+'
                        : conversation.unreadCount[currentUser!.uid].toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PrivateChatScreen(
                  conversationId: conversation.id,
                  otherUserId: otherUserId,
                  otherUserName: userData.username,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGroupChatTile(ConversationModel conversation) {
    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[400],
        backgroundImage: conversation.groupImage != null && conversation.groupImage!.isNotEmpty
            ? NetworkImage(conversation.groupImage!)
            : null,
        child: conversation.groupImage == null || conversation.groupImage!.isEmpty
            ? const Icon(Icons.group, color: Colors.white, size: 25)
            : null,
      ),
      title: Text(
        conversation.groupName ?? 'Group',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        conversation.lastMessage.isNotEmpty
            ? conversation.lastMessage
            : 'No messages yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.grey[600],
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(conversation.lastMessageTime),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          if ((conversation.unreadCount[currentUser!.uid] ?? 0) > 0)
            Container(
              margin: const EdgeInsets.only(top: 5),
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Color(0xFF25D366),
                shape: BoxShape.circle,
              ),
              child: Text(
                conversation.unreadCount[currentUser!.uid]!.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        // Navigate to group chat
      },
    );
  }

  Widget _buildEmptyChats() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          Text(
            'No chats yet',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Start messaging your contacts!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UsersListScreen(),
                ),
              );
            },
            icon: const Icon(Icons.message),
            label: const Text('Start a chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab() {
    return ListView(
      children: [
        ListTile(
          leading: Stack(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey,
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF25D366),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          title: const Text(
            'My Status',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text('Tap to add status update'),
          onTap: () {
            // Add status
          },
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Recent updates',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'No status updates',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCallsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.phone_disabled,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          Text(
            'No calls yet',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
}