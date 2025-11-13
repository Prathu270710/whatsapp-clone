import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCount;
  final DateTime createdAt;
  final bool isGroup;
  final String? groupName;
  final String? groupImage;
  final String? groupDescription;
  final String? createdBy;
  final List<String>? admins;

  ConversationModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.createdAt,
    this.isGroup = false,
    this.groupName,
    this.groupImage,
    this.groupDescription,
    this.createdBy,
    this.admins,
  });

  factory ConversationModel.fromMap(Map<String, dynamic> map, String id) {
    return ConversationModel(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isGroup: map['isGroup'] ?? false,
      groupName: map['groupName'],
      groupImage: map['groupImage'],
      groupDescription: map['groupDescription'],
      createdBy: map['createdBy'],
      admins: map['admins'] != null ? List<String>.from(map['admins']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'unreadCount': unreadCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'isGroup': isGroup,
      if (groupName != null) 'groupName': groupName,
      if (groupImage != null) 'groupImage': groupImage,
      if (groupDescription != null) 'groupDescription': groupDescription,
      if (createdBy != null) 'createdBy': createdBy,
      if (admins != null) 'admins': admins,
    };
  }
}

class Message {
  final String id;
  final String text;
  final String senderId;
  final DateTime timestamp;
  final MessageStatus status; // Updated from isRead to status
  final String? imageUrl;
  final String? videoUrl;
  final String? audioUrl;
  final String? documentUrl;
  final String? fileName;
  final MessageType type;
  final String? replyTo;
  final bool isDeleted;
  final List<String>? deletedFor; // Track who deleted the message
  final Map<String, DateTime>? readBy; // Track who read and when

  Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    required this.status,
    this.imageUrl,
    this.videoUrl,
    this.audioUrl,
    this.documentUrl,
    this.fileName,
    this.type = MessageType.text,
    this.replyTo,
    this.isDeleted = false,
    this.deletedFor,
    this.readBy,
  });

  factory Message.fromMap(Map<String, dynamic> map, String id) {
    // Convert readBy map from Timestamp to DateTime
    Map<String, DateTime>? readByConverted;
    if (map['readBy'] != null) {
      readByConverted = {};
      (map['readBy'] as Map<String, dynamic>).forEach((key, value) {
        if (value is Timestamp) {
          readByConverted![key] = value.toDate();
        }
      });
    }

    return Message(
      id: id,
      text: map['text'] ?? '',
      senderId: map['senderId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: MessageStatus.values[map['status'] ?? 0],
      imageUrl: map['imageUrl'],
      videoUrl: map['videoUrl'],
      audioUrl: map['audioUrl'],
      documentUrl: map['documentUrl'],
      fileName: map['fileName'],
      type: MessageType.values[map['type'] ?? 0],
      replyTo: map['replyTo'],
      isDeleted: map['isDeleted'] ?? false,
      deletedFor: map['deletedFor'] != null ? List<String>.from(map['deletedFor']) : null,
      readBy: readByConverted,
    );
  }

  Map<String, dynamic> toMap() {
    // Convert readBy DateTime to Timestamp
    Map<String, dynamic>? readByTimestamp;
    if (readBy != null) {
      readByTimestamp = {};
      readBy!.forEach((key, value) {
        readByTimestamp![key] = Timestamp.fromDate(value);
      });
    }

    return {
      'text': text,
      'senderId': senderId,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status.index,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (documentUrl != null) 'documentUrl': documentUrl,
      if (fileName != null) 'fileName': fileName,
      'type': type.index,
      if (replyTo != null) 'replyTo': replyTo,
      'isDeleted': isDeleted,
      if (deletedFor != null) 'deletedFor': deletedFor,
      if (readBy != null) 'readBy': readByTimestamp,
    };
  }

  // Check if message can be deleted (within 1 hour)
  bool canBeDeleted() {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    return difference.inHours < 1;
  }

  // Get time remaining for deletion
  String getDeleteTimeRemaining() {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    final remaining = 60 - difference.inMinutes;
    
    if (remaining <= 0) return 'Cannot delete';
    if (remaining == 1) return '1 minute left';
    return '$remaining minutes left';
  }
}

enum MessageType {
  text,
  image,
  video,
  audio,
  document,
  location,
  contact,
}

enum MessageStatus {
  sending,    // Message is being sent
  sent,       // Message delivered to server (single tick)
  delivered,  // Message delivered to recipient (double grey tick)
  read,       // Message read by recipient (double blue tick)
  failed,     // Message failed to send
}