📖 About The Project
This WhatsApp clone is a fully functional messaging application that replicates the core features of WhatsApp. Built with Flutter for cross-platform compatibility and Firebase for backend services, it provides a seamless messaging experience across iOS, Android, and Web platforms.
✨ Features

🔐 Authentication: Secure user authentication with Firebase Auth
💬 Real-time Messaging: Instant message delivery using Cloud Firestore
👤 User Profiles: Customizable user profiles with status updates
📱 Cross-Platform: Works on iOS, Android, and Web
🎨 WhatsApp-like UI: Familiar and intuitive user interface
📅 Message Timestamps: Track when messages were sent
🔔 Online Status: See when users are online
📝 Chat List: Organized conversations with last message preview

## 🛠️ Tech Stack

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)
![Android Studio](https://img.shields.io/badge/Android%20Studio-3DDC84.svg?style=for-the-badge&logo=android-studio&logoColor=white)
![VS Code](https://img.shields.io/badge/Visual%20Studio%20Code-0078d7.svg?style=for-the-badge&logo=visual-studio-code&logoColor=white)
![Git](https://img.shields.io/badge/git-%23F05033.svg?style=for-the-badge&logo=git&logoColor=white)
![GitHub](https://img.shields.io/badge/github-%23121011.svg?style=for-the-badge&logo=github&logoColor=white)

🚀 Getting Started
Prerequisites
Before you begin, ensure you have the following installed:

Flutter SDK (^3.0.0)
Dart SDK
Android Studio / Xcode (for mobile development)
Firebase CLI
Git

bash# Check Flutter installation
flutter doctor
Installation

Clone the repository

bash   git clone https://github.com/YOUR_USERNAME/whatsapp-clone-flutter.git
   cd whatsapp-clone-flutter

Install dependencies

bash   flutter pub get

Firebase Setup
a. Create a new Firebase project at Firebase Console
b. Enable Authentication (Email/Password or Phone)
c. Enable Cloud Firestore
d. Add your app to Firebase:

bash   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli
   
   # Configure Firebase for your project
   flutterfire configure

Run the application

bash   # For debug mode
   flutter run
   
   # For web
   flutter run -d chrome
   
   # For release build
   flutter build apk  # Android
   flutter build ios  # iOS
   flutter build web  # Web
🏗️ Project Structure
chat_app/
├── lib/
│   ├── main.dart           # Application entry point
│   ├── models/             # Data models
│   ├── screens/            # UI screens
│   ├── widgets/            # Reusable widgets
│   ├── services/           # Firebase services
│   └── utils/              # Helper functions
├── assets/                 # Images, fonts, etc.
├── web/                    # Web-specific files
├── android/                # Android-specific files
├── ios/                    # iOS-specific files
└── pubspec.yaml           # Project dependencies

🛠️ Built With

Flutter - UI framework for building natively compiled applications
Firebase - Backend services for authentication and database

Firebase Auth - User authentication
Cloud Firestore - Real-time database
Firebase Hosting - Web deployment


Dart - Programming language

Dependencies
yamldependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.8.1
  firebase_auth: ^5.3.3
  cloud_firestore: ^5.5.1
  cupertino_icons: ^1.0.8
  intl: ^0.19.0
🔧 Configuration
Firebase Security Rules
Update your Firestore security rules:
javascriptrules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    match /chats/{chatId} {
      allow read, write: if request.auth != null;
    }
    match /messages/{chatId}/messages/{messageId} {
      allow read, write: if request.auth != null;
    }
  }
}
🚢 Deployment
Deploy to Firebase Hosting (Web)
bash# Build for web
flutter build web

# Deploy to Firebase Hosting
firebase deploy --only hosting
Build for Mobile
bash# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

👤 Author
Prathamesh Parab

💼 LinkedIn: https://www.linkedin.com/in/prathamesh-parab-3a1b32236/
📧 Email: prparab@syr.edu

🙏 Acknowledgments

Flutter Team for the amazing framework
Firebase Team for the backend services
WhatsApp for the inspiration
Flutter Community for resources and support
Shields.io for badges

📞 Support
prparab@syr.edu
