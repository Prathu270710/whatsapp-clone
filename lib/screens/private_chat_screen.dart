import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/conversation_model.dart';
import '../models/user_model.dart';

class PrivateChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;

  const PrivateChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> with WidgetsBindingObserver {
  final currentUser = FirebaseAuth.instance.currentUser;
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _message = '';
  bool _isTyping = false;
  UserModel? otherUser;
  String? _selectedMessageId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _markMessagesAsRead();
    _loadOtherUser();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markMessagesAsRead();
    }
  }

  void _loadOtherUser() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.otherUserId)
        .get();
    
    if (doc.exists) {
      setState(() {
        otherUser = UserModel.fromMap(doc.data()!, widget.otherUserId);
      });
    }
  }

  // Mark messages as read and update status to double blue tick
  void _markMessagesAsRead() async {
    // Update unread count
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .update({
      'unreadCount.${currentUser!.uid}': 0,
    });

    // Mark messages as read with timestamp
    final messages = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUser!.uid)
        .where('status', isLessThan: 3) // Not yet read
        .get();

    for (var doc in messages.docs) {
      await doc.reference.update({
        'status': MessageStatus.read.index,
        'readBy.${currentUser!.uid}': Timestamp.now(),
      });
    }
  }

  // Send message with status tracking
  void _sendMessage() async {
    if (_message.trim().isEmpty) return;

    final messageText = _message.trim();
    _messageController.clear();
    setState(() {
      _message = '';
    });

    // Add message with 'sent' status (single tick)
    final messageRef = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .add({
      'text': messageText,
      'senderId': currentUser!.uid,
      'timestamp': Timestamp.now(),
      'status': MessageStatus.sent.index, // Single tick
      'type': 0, // MessageType.text
      'isDeleted': false,
      'deletedFor': [],
      'readBy': {},
    });

    // Update conversation
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .update({
      'lastMessage': messageText,
      'lastMessageTime': Timestamp.now(),
      'unreadCount.${widget.otherUserId}': FieldValue.increment(1),
    });

    // Update to delivered status (double grey tick) after a short delay
    Future.delayed(const Duration(milliseconds: 500), () async {
      await messageRef.update({
        'status': MessageStatus.delivered.index,
      });
    });
  }

  // Delete message
  void _deleteMessage(Message message, bool deleteForEveryone) async {
    if (deleteForEveryone && !message.canBeDeleted()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Messages can only be deleted within 1 hour of sending'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final messageRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .doc(message.id);

    if (deleteForEveryone) {
      // Delete for everyone
      await messageRef.update({
        'isDeleted': true,
        'text': '🚫 This message was deleted',
      });

      // Update last message if this was the last message
      final lastMessageDoc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .get();
      
      if (lastMessageDoc.data()?['lastMessage'] == message.text) {
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversationId)
            .update({
          'lastMessage': '🚫 This message was deleted',
        });
      }
    } else {
      // Delete for me only
      final currentDeletedFor = message.deletedFor ?? [];
      currentDeletedFor.add(currentUser!.uid);
      
      await messageRef.update({
        'deletedFor': currentDeletedFor,
      });
    }

    setState(() {
      _selectedMessageId = null;
    });
  }

  // Show delete options
  void _showDeleteOptions(Message message) {
    final canDeleteForEveryone = message.senderId == currentUser!.uid && message.canBeDeleted();
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.senderId == currentUser!.uid && !message.isDeleted) ...[
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete for me'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message, false);
                },
              ),
              if (canDeleteForEveryone)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete for everyone'),
                  subtitle: Text(
                    message.getDeleteTimeRemaining(),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(message, true);
                  },
                )
              else if (message.senderId == currentUser!.uid)
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.grey),
                  title: const Text(
                    'Delete for everyone',
                    style: TextStyle(color: Colors.grey),
                  ),
                  subtitle: const Text(
                    'Time limit exceeded (1 hour)',
                    style: TextStyle(fontSize: 12),
                  ),
                  enabled: false,
                ),
            ],
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy message'),
              onTap: () {
                // Copy to clipboard
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Message info'),
              subtitle: Text(
                'Sent at ${DateFormat('HH:mm').format(message.timestamp)}',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        leadingWidth: 70,
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            if (otherUser != null)
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[300],
                backgroundImage: otherUser!.profileImage.isNotEmpty
                    ? NetworkImage(otherUser!.profileImage)
                    : null,
                child: otherUser!.profileImage.isEmpty
                    ? Text(
                        otherUser!.username[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      )
                    : null,
              ),
          ],
        ),
        title: InkWell(
          onTap: () {
            // View profile
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.otherUserName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (otherUser != null)
                Text(
                  otherUser!.isOnline
                      ? 'online'
                      : 'last seen ${_formatLastSeen(otherUser!.lastSeen)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {},
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(child: Text('View contact')),
              const PopupMenuItem(child: Text('Media, links, and docs')),
              const PopupMenuItem(child: Text('Search')),
              const PopupMenuItem(child: Text('Mute notifications')),
              const PopupMenuItem(child: Text('Disappearing messages')),
              const PopupMenuItem(child: Text('Wallpaper')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(widget.conversationId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
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
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3C2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🔒 Messages are end-to-end encrypted. No one outside of this chat can read them.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.brown[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final messages = snapshot.data!.docs;
                
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageDoc = messages[index];
                    final message = Message.fromMap(
                      messageDoc.data() as Map<String, dynamic>,
                      messageDoc.id,
                    );
                    
                    // Check if message is deleted for current user
                    if (message.deletedFor?.contains(currentUser!.uid) ?? false) {
                      return const SizedBox.shrink();
                    }
                    
                    final isMe = message.senderId == currentUser!.uid;

                    // Check if we should show date separator
                    bool showDate = false;
                    if (index == messages.length - 1) {
                      showDate = true;
                    } else {
                      final nextMessage = Message.fromMap(
                        messages[index + 1].data() as Map<String, dynamic>,
                        messages[index + 1].id,
                      );
                      showDate = !_isSameDay(message.timestamp, nextMessage.timestamp);
                    }

                    return Column(
                      children: [
                        if (showDate) _buildDateChip(message.timestamp),
                        GestureDetector(
                          onLongPress: () => _showDeleteOptions(message),
                          child: _buildMessageBubble(message, isMe),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildDateChip(DateTime date) {
    String text;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      text = 'TODAY';
    } else if (messageDate == yesterday) {
      text = 'YESTERDAY';
    } else {
      text = DateFormat('MMMM d, yyyy').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 15),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    // Get status icon
    Widget statusIcon = const SizedBox.shrink();
    if (isMe) {
      switch (message.status) {
        case MessageStatus.sending:
          statusIcon = const Icon(Icons.schedule, size: 16, color: Colors.grey);
          break;
        case MessageStatus.sent:
          statusIcon = const Icon(Icons.done, size: 16, color: Colors.grey); // Single tick
          break;
        case MessageStatus.delivered:
          statusIcon = const Icon(Icons.done_all, size: 16, color: Colors.grey); // Double grey tick
          break;
        case MessageStatus.read:
          statusIcon = const Icon(Icons.done_all, size: 16, color: Colors.blue); // Double blue tick
          break;
        case MessageStatus.failed:
          statusIcon = const Icon(Icons.error, size: 16, color: Colors.red);
          break;
      }
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 80 : 0,
          right: isMe ? 0 : 80,
          bottom: 5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: message.isDeleted 
              ? Colors.grey[300] 
              : (isMe ? const Color(0xFFDCF8C6) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(10),
            topRight: const Radius.circular(10),
            bottomLeft: isMe ? const Radius.circular(10) : const Radius.circular(0),
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 16,
                fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                color: message.isDeleted ? Colors.grey[600] : Colors.black87,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(message.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                if (isMe && !message.isDeleted) ...[
                  const SizedBox(width: 3),
                  statusIcon,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey[600]),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _message = value;
                        });
                      },
                    ),
                  ),
                  if (_message.isEmpty) ...[
                    IconButton(
                      icon: Icon(Icons.attach_file, color: Colors.grey[600]),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: Icon(Icons.camera_alt, color: Colors.grey[600]),
                      onPressed: () {},
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),
          CircleAvatar(
            backgroundColor: const Color(0xFF075E54),
            radius: 25,
            child: IconButton(
              icon: Icon(
                _message.trim().isEmpty ? Icons.mic : Icons.send,
                color: Colors.white,
              ),
              onPressed: _message.trim().isEmpty ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('dd/MM/yyyy').format(lastSeen);
    }
  }
}