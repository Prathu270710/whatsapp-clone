import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Login type
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isOtpLogin = false; // Toggle between OTP and Password login
  bool _obscurePassword = true; // Password visibility toggle
  
  // Form fields
  String _userEmail = '';
  String _userName = '';
  String _userPassword = '';
  String _userPhone = '';
  String _verificationId = '';
  String _otpCode = '';
  
  // Controllers for OTP
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // Check if phone number is registered
  Future<bool> _isPhoneRegistered(String phoneNumber) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking phone: $e');
      return false;
    }
  }

  // Send OTP - Updated with user verification
  void _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Format phone number with country code if not present
      String phoneNumber = _userPhone.trim();
      if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+1$phoneNumber'; // Default to US, change as needed
      }

      // FOR LOGIN: Check if phone is registered
      if (_isLogin) {
        bool isRegistered = await _isPhoneRegistered(phoneNumber);
        if (!isRegistered) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No account found with this phone number. Please sign up first.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      // FOR SIGNUP: Check if phone already exists
      if (!_isLogin) {
        bool isRegistered = await _isPhoneRegistered(phoneNumber);
        if (isRegistered) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Phone number already registered. Please login instead.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      // Proceed with OTP sending
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-sign in on Android
          await _handlePhoneAuth(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
          });
          String errorMessage = 'Failed to send OTP';
          if (e.code == 'invalid-phone-number') {
            errorMessage = 'Invalid phone number format';
          } else if (e.code == 'too-many-requests') {
            errorMessage = 'Too many requests. Please try again later.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
          });
          // Show OTP input dialog
          _showOTPDialog();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Handle phone authentication
  Future<void> _handlePhoneAuth(PhoneAuthCredential credential) async {
    try {
      final authResult = await _auth.signInWithCredential(credential);
      
      if (authResult.user != null) {
        if (_isLogin) {
          // Login: Update existing user's online status
          await _updateUserOnlineStatus(authResult.user!.uid);
        } else {
          // Signup: Create new user document
          await _createUserDocument(authResult.user!);
        }
      }
    } catch (e) {
      throw e;
    }
  }

  // Create user document for new signup
  Future<void> _createUserDocument(User user) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'username': _userName.isNotEmpty ? _userName : 'User${user.uid.substring(0, 6)}',
      'phone': _userPhone.trim().startsWith('+') ? _userPhone.trim() : '+1${_userPhone.trim()}',
      'email': user.email ?? '',
      'profileImage': '',
      'status': 'Hey there! I am using WhatsApp Clone',
      'createdAt': Timestamp.now(),
      'lastSeen': Timestamp.now(),
      'isOnline': true,
      'uid': user.uid,
    });
  }

  // Update user online status
  Future<void> _updateUserOnlineStatus(String uid) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
      'isOnline': true,
      'lastSeen': Timestamp.now(),
    });
  }

  // Verify OTP
  void _verifyOTP() async {
    String otp = _otpControllers.map((e) => e.text).join();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter complete OTP'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );

      await _handlePhoneAuth(credential);
      Navigator.pop(context); // Close OTP dialog
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid OTP. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show OTP Input Dialog
  void _showOTPDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Column(
          children: [
            Icon(
              Icons.phone_android,
              size: 50,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 10),
            const Text(
              'Enter OTP',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'We have sent a 6-digit OTP to',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              _userPhone,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 40,
                  child: TextFormField(
                    controller: _otpControllers[index],
                    focusNode: _otpFocusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 5) {
                        _otpFocusNodes[index + 1].requestFocus();
                      } else if (value.isEmpty && index > 0) {
                        _otpFocusNodes[index - 1].requestFocus();
                      }
                      // Auto-submit when all 6 digits are entered
                      if (index == 5 && value.isNotEmpty) {
                        String otp = _otpControllers.map((e) => e.text).join();
                        if (otp.length == 6) {
                          _verifyOTP();
                        }
                      }
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _sendOTP,
              child: const Text('Resend OTP'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              for (var controller in _otpControllers) {
                controller.clear();
              }
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _verifyOTP,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF075E54),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Verify', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Password login/signup
  void _trySubmit() async {
    final isValid = _formKey.currentState!.validate();
    FocusScope.of(context).unfocus();

    if (isValid) {
      _formKey.currentState!.save();
      
      setState(() {
        _isLoading = true;
      });

      try {
        if (_isLogin) {
          // Login with email and password
          await _auth.signInWithEmailAndPassword(
            email: _userEmail,
            password: _userPassword,
          );
          
          // Update online status
          await _updateUserOnlineStatus(_auth.currentUser!.uid);
        } else {
          // Register user
          final authResult = await _auth.createUserWithEmailAndPassword(
            email: _userEmail,
            password: _userPassword,
          );
          
          // Store user data in Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(authResult.user!.uid)
              .set({
            'username': _userName,
            'email': _userEmail,
            'phone': _userPhone,
            'status': 'Hey there! I am using WhatsApp Clone',
            'profileImage': '',
            'createdAt': Timestamp.now(),
            'lastSeen': Timestamp.now(),
            'isOnline': true,
            'uid': authResult.user!.uid,
          });

          // Update display name
          await authResult.user!.updateDisplayName(_userName);
        }
      } on FirebaseAuthException catch (err) {
        var message = 'An error occurred, please check your credentials!';
        
        if (err.code == 'weak-password') {
          message = 'The password provided is too weak.';
        } else if (err.code == 'email-already-in-use') {
          message = 'An account already exists for that email.';
        } else if (err.code == 'user-not-found') {
          message = 'No user found for that email.';
        } else if (err.code == 'wrong-password') {
          message = 'Wrong password provided.';
        } else if (err.message != null) {
          message = err.message!;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        
        setState(() {
          _isLoading = false;
        });
      } catch (err) {
        print('Error: $err');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('An unexpected error occurred'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  // Logo and Title
                  Hero(
                    tag: 'logo',
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF075E54),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF075E54).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.message,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'WhatsApp Clone',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isLogin ? 'Welcome back!' : 'Create your account',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Login Method Toggle (Only for Login)
                  if (_isLogin)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isOtpLogin = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !_isOtpLogin ? const Color(0xFF075E54) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      color: !_isOtpLogin ? Colors.white : Colors.grey[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Password',
                                      style: TextStyle(
                                        color: !_isOtpLogin ? Colors.white : Colors.grey[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isOtpLogin = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _isOtpLogin ? const Color(0xFF075E54) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.phone_android,
                                      color: _isOtpLogin ? Colors.white : Colors.grey[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'OTP',
                                      style: TextStyle(
                                        color: _isOtpLogin ? Colors.white : Colors.grey[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (_isLogin) const SizedBox(height: 30),
                  
                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // OTP Login Fields
                        if (_isLogin && _isOtpLogin) ...[
                          // Phone field for OTP
                          TextFormField(
                            key: const ValueKey('phone_otp'),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value!.isEmpty || value.length < 10) {
                                return 'Please enter a valid phone number';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              hintText: '+1 650-555-3434 (test)',
                              prefixIcon: Icon(
                                Icons.phone_outlined,
                                color: Theme.of(context).primaryColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            onSaved: (value) {
                              _userPhone = value!.trim();
                            },
                          ),
                        ]
                        // OTP Signup Fields
                        else if (!_isLogin && _isOtpLogin) ...[
                          // Username for OTP signup
                          TextFormField(
                            key: const ValueKey('username_otp'),
                            autocorrect: true,
                            textCapitalization: TextCapitalization.words,
                            validator: (value) {
                              if (value!.isEmpty || value.length < 3) {
                                return 'Username must be at least 3 characters';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: Theme.of(context).primaryColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            onSaved: (value) {
                              _userName = value!.trim();
                            },
                          ),
                          const SizedBox(height: 15),
                          // Phone for OTP signup
                          TextFormField(
                            key: const ValueKey('phone_otp_signup'),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value!.isEmpty || value.length < 10) {
                                return 'Please enter a valid phone number';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              hintText: 'Enter your phone number',
                              prefixIcon: Icon(
                                Icons.phone_outlined,
                                color: Theme.of(context).primaryColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            onSaved: (value) {
                              _userPhone = value!.trim();
                            },
                          ),
                        ]
                        // Password Login / Signup Fields
                        else ...[
                          // Email field (for password login)
                          if (!_isOtpLogin)
                            TextFormField(
                              key: const ValueKey('email'),
                              autocorrect: false,
                              textCapitalization: TextCapitalization.none,
                              enableSuggestions: false,
                              validator: (value) {
                                if (value!.isEmpty || !value.contains('@')) {
                                  return 'Please enter a valid email address.';
                                }
                                return null;
                              },
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email address',
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: Theme.of(context).primaryColor,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).primaryColor,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              onSaved: (value) {
                                _userEmail = value!.trim();
                              },
                            ),
                          
                          if (!_isOtpLogin) const SizedBox(height: 15),
                          
                          // Username field (signup only)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: !_isLogin && !_isOtpLogin ? 80 : 0,
                            child: AnimatedOpacity(
                              opacity: !_isLogin && !_isOtpLogin ? 1 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: TextFormField(
                                key: const ValueKey('username'),
                                enabled: !_isLogin && !_isOtpLogin,
                                autocorrect: true,
                                textCapitalization: TextCapitalization.words,
                                validator: !_isLogin && !_isOtpLogin
                                    ? (value) {
                                        if (value!.isEmpty || value.length < 3) {
                                          return 'Username must be at least 3 characters';
                                        }
                                        return null;
                                      }
                                    : null,
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Theme.of(context).primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                onSaved: (value) {
                                  _userName = value?.trim() ?? '';
                                },
                              ),
                            ),
                          ),
                          
                          // Phone field (signup only)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: !_isLogin && !_isOtpLogin ? 80 : 0,
                            child: AnimatedOpacity(
                              opacity: !_isLogin && !_isOtpLogin ? 1 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: TextFormField(
                                key: const ValueKey('phone'),
                                enabled: !_isLogin && !_isOtpLogin,
                                keyboardType: TextInputType.phone,
                                validator: !_isLogin && !_isOtpLogin
                                    ? (value) {
                                        if (value!.isEmpty || value.length < 10) {
                                          return 'Please enter a valid phone number';
                                        }
                                        return null;
                                      }
                                    : null,
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  prefixIcon: Icon(
                                    Icons.phone_outlined,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Theme.of(context).primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                onSaved: (value) {
                                  _userPhone = value?.trim() ?? '';
                                },
                              ),
                            ),
                          ),
                          
                          if (!_isOtpLogin) const SizedBox(height: 15),
                          
                          // Password field (for password login)
                          if (!_isOtpLogin)
                            TextFormField(
                              key: const ValueKey('password'),
                              validator: (value) {
                                if (value!.isEmpty || value.length < 6) {
                                  return 'Password must be at least 6 characters long.';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: Theme.of(context).primaryColor,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).primaryColor,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              obscureText: _obscurePassword,
                              onSaved: (value) {
                                _userPassword = value!.trim();
                              },
                            ),
                        ],
                        
                        const SizedBox(height: 30),
                        
                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: Stack(
                            children: [
                              // Button layer
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                opacity: _isLoading ? 0.5 : 1.0,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF075E54),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    elevation: 5,
                                  ),
                                  onPressed: _isLoading 
                                      ? null 
                                      : (_isOtpLogin ? _sendOTP : _trySubmit),
                                  icon: Icon(
                                    _isOtpLogin 
                                        ? Icons.phone_android 
                                        : (_isLogin ? Icons.login : Icons.person_add),
                                  ),
                                  label: Text(
                                    _isOtpLogin 
                                        ? 'Send OTP' 
                                        : (_isLogin ? 'Login' : 'Sign Up'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              // Loading indicator layer
                              if (_isLoading)
                                const Positioned.fill(
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Switch between login and signup
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLogin
                                  ? "Don't have an account?"
                                  : 'Already have an account?',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _isLogin = !_isLogin;
                                        // Keep OTP mode when switching
                                      });
                                    },
                              child: Text(
                                _isLogin ? 'Sign Up' : 'Login',
                                style: TextStyle(
                                  color: _isLoading
                                      ? Colors.grey
                                      : const Color(0xFF25D366),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}