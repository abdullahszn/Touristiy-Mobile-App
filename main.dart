import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:touristiy/firebase_options.dart';
import 'vertex_ai.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() async {
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Error loading .env file: $e");
    // .env dosyası bulunamazsa, varsayılan bir değer kullanabilirsiniz
  }
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Çevrimdışı desteği etkinleştir
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug, // Parantez yok, sadece enum değeri
    appleProvider: AppleProvider
        .debug, // Parantez yok, sadece enum değeri     // Web için reCAPTCHA (isteğe bağlı)
  );
  FirebaseApi().initNotification().then((_) {
    runApp(const MyApp());
  }).catchError((error) {
    print("Bildirim başlatma hatası: $error");
    runApp(const MyApp());
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguageCode = prefs.getString('language_code');
    if (savedLanguageCode != null) {
      setState(() {
        _locale = Locale(savedLanguageCode);
      });
    } else {
      final deviceLocale = WidgetsBinding.instance.window.locale;
      setState(() {
        _locale = Locale(deviceLocale.languageCode == 'tr' ? 'tr' : 'en');
      });
    }
  }

  void setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: SplashScreen(onLocaleChange: setLocale),
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  final Function(Locale) onLocaleChange;
  const SplashScreen({super.key, required this.onLocaleChange});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAppStatus();
  }

  Future<void> _checkAppStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
    final bool rememberMe = prefs.getBool('rememberMe') ?? false;
    final String? email = prefs.getString('email');
    final String? password = prefs.getString('password');

    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null ||
        (rememberMe && email != null && password != null)) {
      try {
        if (currentUser == null) {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email!,
            password: password!,
          );
        }
        // Otomatik giriş yapan kullanıcıyı MainMenuPage'e yönlendir
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainMenuPage(
              onLocaleChange: widget.onLocaleChange,
            ),
          ),
        );
        return;
      } catch (e) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AuthScreen(
              isLogin: true,
              onLocaleChange: widget.onLocaleChange,
            ),
          ),
        );
        return;
      }
    }

    if (isFirstLaunch) {
      await prefs.setBool('isFirstLaunch', false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AuthScreen(
            isLogin: false,
            onLocaleChange: widget.onLocaleChange,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AuthScreen(
            isLogin: true,
            onLocaleChange: widget.onLocaleChange,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Center(
                child: Image.asset(
                  'assets/logoWhite.png',
                  width: 300,
                ),
              ),
            ),
            const Expanded(
              flex: 1,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  final bool isLogin;
  final Function(Locale) onLocaleChange;
  const AuthScreen(
      {super.key, required this.isLogin, required this.onLocaleChange});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isLogin;
  bool _isPasswordVisible = false;
  String _errorMessage = '';
  bool _rememberMe = false;
  bool _isLanguageDropdownOpen = false;
  String _selectedLanguage = 'en';

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedGender;

  final List<String> _validDomains = [
    '@gmail.com',
    '@outlook.com',
    '@hotmail.com',
    '@yahoo.com',
    '@icloud.com',
    '@aol.com',
    '@protonmail.com',
    '@zoho.com',
    '@mail.com',
    '@gmx.com',
    '@touristiy.com',
  ];

  final Map<String, Map<String, dynamic>> _languages = {
    'en': {
      'name': 'English',
      'flag': 'assets/uk_flag.png',
      'locale': const Locale('en')
    },
    'tr': {
      'name': 'Türkçe',
      'flag': 'assets/tr_flag.png',
      'locale': const Locale('tr')
    },
    'de': {
      'name': 'Deutsch',
      'flag': 'assets/de_flag.png',
      'locale': const Locale('de')
    },
    'es': {
      'name': 'Español',
      'flag': 'assets/es_flag.png',
      'locale': const Locale('es')
    },
    'fr': {
      'name': 'Français',
      'flag': 'assets/fr_flag.png',
      'locale': const Locale('fr')
    },
    'it': {
      'name': 'Italiano',
      'flag': 'assets/it_flag.png',
      'locale': const Locale('it')
    },
    'ja': {
      'name': '日本語',
      'flag': 'assets/jp_flag.png',
      'locale': const Locale('ja')
    },
    'pt': {
      'name': 'Português',
      'flag': 'assets/pt_flag.png',
      'locale': const Locale('pt')
    },
    'ru': {
      'name': 'Русский',
      'flag': 'assets/ru_flag.png',
      'locale': const Locale('ru')
    },
    'zh': {
      'name': '中文',
      'flag': 'assets/zh_flag.png',
      'locale': const Locale('zh')
    },
  };

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;
    _selectedLanguage = 'en';
  }

  bool _isEmailDomainValid(String email) {
    return _validDomains.any((domain) => email.toLowerCase().endsWith(domain));
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('email', _emailController.text.trim());
      await prefs.setString('password', _passwordController.text.trim());
      await prefs.setBool('rememberMe', true);
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  MainMenuPage(onLocaleChange: widget.onLocaleChange)),
        );
      }
    } catch (e) {
      print("Google Sign-In Hatası: $e"); // Hata detayını logla
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.unknownError;
      });
    }
  }

  Widget buildCustomTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        color: Color.fromARGB(255, 0, 0, 0),
        fontFamily: 'Poppins',
        fontWeight: FontWeight.bold,
      ),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(
          color: Color.fromARGB(255, 150, 150, 150),
          fontFamily: 'Poppins',
          fontWeight: FontWeight.bold,
        ),
        prefixIcon: Icon(icon, color: const Color.fromARGB(255, 0, 0, 0)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        filled: true,
        fillColor: const Color.fromARGB(255, 255, 255, 255),
      ),
    );
  }

  Widget buildGenderSelection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedGender = AppLocalizations.of(context)!.male;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _selectedGender == AppLocalizations.of(context)!.male
                  ? Colors.blue.withOpacity(0.5)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.male, color: Colors.blue, size: 40),
          ),
        ),
        const SizedBox(width: 20),
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedGender = AppLocalizations.of(context)!.female;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _selectedGender == AppLocalizations.of(context)!.female
                  ? Colors.pink.withOpacity(0.5)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.female, color: Colors.pink, size: 40),
          ),
        ),
      ],
    );
  }

  Widget buildLanguageSelector() {
    String flagPath = _languages[_selectedLanguage]!['flag'];
    String languageName = _languages[_selectedLanguage]!['name'];

    return Stack(
      children: [
        Positioned(
          top: 25,
          right: 6,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isLanguageDropdownOpen = !_isLanguageDropdownOpen;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Image.asset(
                    flagPath,
                    width: 32,
                    height: 32,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    languageName,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_drop_down,
                      color: Colors.black, size: 24),
                ],
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          top: _isLanguageDropdownOpen ? 58 : 40,
          right: 10,
          child: _isLanguageDropdownOpen
              ? Container(
                  width: 140,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: _languages.entries.map((entry) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedLanguage = entry.key;
                              _isLanguageDropdownOpen = false;
                            });
                            widget.onLocaleChange(entry.value['locale']);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 16.0),
                            child: Row(
                              children: [
                                Image.asset(entry.value['flag'],
                                    width: 24, height: 24),
                                const SizedBox(width: 8),
                                Text(
                                  entry.value['name'],
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.black,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() {
            _isLanguageDropdownOpen = false;
          });
        },
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFFFFFFF),
                        Color.fromARGB(255, 229, 229, 229),
                        Color(0xFFFFFFFF),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                              height:
                                  MediaQuery.of(context).size.height * 0.0001),
                          Image.asset('assets/logoWhite.png', height: 280),
                          const SizedBox(height: 0.1),
                          Text(
                            _isLogin
                                ? AppLocalizations.of(context)!.welcomeBack
                                : AppLocalizations.of(context)!.createAccount,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 0, 0, 0),
                              fontFamily: 'Poppins',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          if (!_isLogin) ...[
                            buildCustomTextField(
                              controller: _firstNameController,
                              labelText:
                                  AppLocalizations.of(context)!.firstName,
                              icon: Icons.person,
                            ),
                            const SizedBox(height: 12),
                            buildCustomTextField(
                              controller: _lastNameController,
                              labelText: AppLocalizations.of(context)!.lastName,
                              icon: Icons.person,
                            ),
                            const SizedBox(height: 12),
                            buildCustomTextField(
                              controller: _emailController,
                              labelText: AppLocalizations.of(context)!.email,
                              icon: Icons.email,
                            ),
                            const SizedBox(height: 12),
                            buildCustomTextField(
                              controller: _phoneController,
                              labelText:
                                  AppLocalizations.of(context)!.phoneNumber,
                              icon: Icons.phone,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_isLogin)
                            buildCustomTextField(
                              controller: _emailController,
                              labelText: AppLocalizations.of(context)!.email,
                              icon: Icons.email,
                            ),
                          const SizedBox(height: 3),
                          TextField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            style: const TextStyle(
                              color: Color.fromARGB(255, 0, 0, 0),
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.password,
                              labelStyle: const TextStyle(
                                color: Color.fromARGB(255, 150, 150, 150),
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                              ),
                              prefixIcon: const Icon(Icons.lock,
                                  color: Color.fromARGB(255, 0, 0, 0)),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30)),
                              filled: true,
                              fillColor:
                                  const Color.fromARGB(255, 255, 255, 255),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (!_isLogin) ...[
                            Text(
                              AppLocalizations.of(context)!
                                  .passwordRequirements,
                              style: const TextStyle(
                                color: Color.fromARGB(255, 0, 0, 0),
                                fontSize: 14,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 12),
                            buildGenderSelection(),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.rememberMe,
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 0, 0, 0),
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                                checkColor: Colors.lightBlueAccent,
                                activeColor:
                                    Colors.lightBlueAccent.withOpacity(0.3),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _authenticate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(255, 46, 130, 169),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                            ),
                            child: Text(
                              _isLogin
                                  ? AppLocalizations.of(context)!.signIn
                                  : AppLocalizations.of(context)!.signUp,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_errorMessage.isNotEmpty)
                            Text(
                              _errorMessage,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isLogin
                                    ? AppLocalizations.of(context)!.noAccount
                                    : AppLocalizations.of(context)!.hasAccount,
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 46, 130, 169),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              GestureDetector(
                                onTap: toggleScreen,
                                child: Text(
                                  _isLogin
                                      ? AppLocalizations.of(context)!.signUp
                                      : AppLocalizations.of(context)!.signIn,
                                  style: const TextStyle(
                                    color: Color.fromARGB(255, 46, 130, 169),
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        ResetPasswordScreen()),
                              );
                            },
                            child: Center(
                              child: Text(
                                AppLocalizations.of(context)!.forgotPassword,
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 46, 130, 169),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                  child: Divider(
                                      color: Color.fromARGB(255, 46, 130, 169),
                                      thickness: 1)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  AppLocalizations.of(context)!.or,
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 46, 130, 169),
                                    fontSize: 16,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                              Expanded(
                                  child: Divider(
                                      color: Color.fromARGB(255, 46, 130, 169),
                                      thickness: 1)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _signInWithGoogle,
                            icon: Image.asset('assets/google_logo.png',
                                height: 24, width: 24),
                            label: Text(
                              AppLocalizations.of(context)!.signInWithGoogle,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromARGB(255, 46, 130, 169)
                                  .withOpacity(0.4),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            buildLanguageSelector(),
          ],
        ),
      ),
    );
  }

  void toggleScreen() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _authenticate() async {
    String email = _emailController.text.trim();
    if (!_isEmailDomainValid(email)) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.invalidDomain;
      });
      return;
    }

    if (!_isLogin) {
      if (_firstNameController.text.isEmpty ||
          _lastNameController.text.isEmpty ||
          _phoneController.text.isEmpty ||
          _selectedGender == null) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.fillAllFields;
        });
        return;
      }
    }

    try {
      if (_isLogin) {
        // Giriş yapma durumu: MainMenuPage'e yönlendir
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: _passwordController.text.trim(),
        );
        await _saveCredentials();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainMenuPage(
              onLocaleChange: widget.onLocaleChange,
            ),
          ),
        );
      } else {
        // Kayıt olma durumu: TestPage'e yönlendir
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: _passwordController.text.trim(),
        );
        if (userCredential.user != null) {
          String userId = userCredential.user!.uid;
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'firstName': _firstNameController.text.trim(),
            'lastName': _lastNameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'gender': _selectedGender,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          });
          await _saveCredentials();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TestPage(
                onLocaleChange: widget.onLocaleChange,
              ),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = AppLocalizations.of(context)!.authError;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = AppLocalizations.of(context)!.userNotFound;
          break;
        case 'wrong-password':
          errorMessage = AppLocalizations.of(context)!.wrongPassword;
          break;
        case 'invalid-email':
          errorMessage = AppLocalizations.of(context)!.invalidEmail;
          break;
        case 'email-already-in-use':
          errorMessage = AppLocalizations.of(context)!.emailAlreadyInUse;
          break;
        case 'weak-password':
          errorMessage = AppLocalizations.of(context)!.weakPassword;
          break;
        default:
          errorMessage = AppLocalizations.of(context)!.unknownError;
          break;
      }
      setState(() {
        _errorMessage = errorMessage;
      });
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.unknownError;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

class ResetPasswordScreen extends StatelessWidget {
  final TextEditingController _emailController = TextEditingController();

  void _resetPassword(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Şifre sıfırlama bağlantısı gönderildi!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blueGrey.shade900, Colors.black],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Touristiy",
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: TextField(
                    controller: _emailController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "E-posta Adresiniz",
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      prefixIcon: Icon(Icons.email, color: Colors.white),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _resetPassword(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  ),
                  child: Text("Şifreyi Sıfırla"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SplashScreen2 extends StatefulWidget {
  const SplashScreen2({super.key});

  @override
  SplashScreen2State createState() => SplashScreen2State();
}

class SplashScreen2State extends State<SplashScreen2> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 5), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (context) => HomeScreen(
                  onLocaleChange: (Locale p1) {},
                )),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Center(
                child: Image.asset(
                  'assets/logoWhite.png',
                  width: 300,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen(
      {super.key, required Null Function(Locale p1) onLocaleChange});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final Duration _pageTransitionDuration = const Duration(milliseconds: 500);
  final Curve _pageTransitionCurve = Curves.easeInOutCubic;
  final Duration _indicatorAnimationDuration =
      const Duration(milliseconds: 300);
  final Duration _buttonAnimationDuration = const Duration(milliseconds: 700);

  final List<Map<String, String>> onboardingData = [
    {
      'titleKey': 'onboardingTitle1',
      'descriptionKey': 'onboardingDesc1',
      'image': 'assets/onboarding1.png',
    },
    {
      'titleKey': 'onboardingTitle2',
      'descriptionKey': 'onboardingDesc2',
      'image': 'assets/onboarding2.png',
    },
    {
      'titleKey': 'onboardingTitle3',
      'descriptionKey': 'onboardingDesc3',
      'image': 'assets/onboarding3.png',
    },
    {
      'titleKey': 'onboardingTitle4',
      'descriptionKey': 'onboardingDesc4',
      'image': 'assets/onboarding4.png',
    },
    {
      'titleKey': 'onboardingTitle5',
      'descriptionKey': 'onboardingDesc5',
      'image': 'assets/onboarding5.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_handlePageChange);
  }

  void _handlePageChange() {
    setState(() {
      _currentPage = _pageController.page?.round() ?? 0;
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageChange);
    _pageController.dispose();
    super.dispose();
  }

  String _getLocalizedText(String key, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (key) {
      case 'onboardingTitle1':
        return l10n.onboardingTitle1;
      case 'onboardingDesc1':
        return l10n.onboardingDesc1;
      case 'onboardingTitle2':
        return l10n.onboardingTitle2;
      case 'onboardingDesc2':
        return l10n.onboardingDesc2;
      case 'onboardingTitle3':
        return l10n.onboardingTitle3;
      case 'onboardingDesc3':
        return l10n.onboardingDesc3;
      case 'onboardingTitle4':
        return l10n.onboardingTitle4;
      case 'onboardingDesc4':
        return l10n.onboardingDesc4;
      case 'onboardingTitle5':
        return l10n.onboardingTitle5;
      case 'onboardingDesc5':
        return l10n.onboardingDesc5;
      case 'getStarted':
        return l10n.getStarted;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: onboardingData.length,
            scrollDirection: Axis.horizontal,
            pageSnapping: true,
            physics: _currentPage == onboardingData.length - 1
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final item = onboardingData[index];
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = _pageController.page! - index;
                    value = (1 - (value.abs() * 0.0)).clamp(0.0, 1.0);
                  }

                  return Transform.scale(
                    scale: Curves.easeOut.transform(value),
                    child: child,
                  );
                },
                child: _buildOnboardingPage(context, item),
              );
            },
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedSmoothIndicator(
                activeIndex: _currentPage,
                count: onboardingData.length,
                effect: const WormEffect(
                  dotHeight: 10,
                  dotWidth: 10,
                  activeDotColor: Colors.blueAccent,
                  dotColor: Colors.grey,
                  spacing: 8,
                  paintStyle: PaintingStyle.fill,
                  strokeWidth: 1.5,
                ),
                onDotClicked: (index) {
                  if (index < onboardingData.length - 1) {
                    _pageController.animateToPage(
                      index,
                      duration: _indicatorAnimationDuration,
                      curve: _pageTransitionCurve,
                    );
                  }
                },
              ),
            ),
          ),
          if (_currentPage == onboardingData.length - 1)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity:
                      _currentPage == onboardingData.length - 1 ? 1.0 : 0.0,
                  duration: _buttonAnimationDuration,
                  child: AnimatedSlide(
                    offset: _currentPage == onboardingData.length - 1
                        ? Offset.zero
                        : const Offset(0, 0.5),
                    duration: _buttonAnimationDuration,
                    curve: _pageTransitionCurve,
                    child: _buildGetStartedButton(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOnboardingPage(BuildContext context, Map<String, String> item) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey, Colors.lightBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          Hero(
            tag: 'onboardingImage${item['image']}',
            child: Image.asset(
              item['image']!,
              height: 300,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 45),
          AnimatedSwitcher(
            duration: _pageTransitionDuration,
            child: Text(
              _getLocalizedText(item['titleKey']!, context),
              key: ValueKey(item['titleKey']),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: _pageTransitionDuration,
            child: Text(
              _getLocalizedText(item['descriptionKey']!, context),
              key: ValueKey(item['descriptionKey']),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGetStartedButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                TestPage(onLocaleChange: (Locale) {}),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: _pageTransitionDuration,
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 5,
        shadowColor: Colors.blueAccent.withOpacity(0.3),
      ),
      child: Text(
        _getLocalizedText('getStarted', context),
        style: const TextStyle(
          fontSize: 18,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
class TestPage extends StatefulWidget {
  final Function(Locale) onLocaleChange;

  const TestPage({super.key, required this.onLocaleChange});

  @override
  TestPageState createState() => TestPageState();
}

class TestPageState extends State<TestPage> {
  double _topPosition = 1000.0;
  double _secondBoxTopPosition = 1000.0;
  double _continueButtonTopPosition = 1000.0;

  List<bool> buttonStates = List.generate(8, (_) => false);
  String allAnswers = '';
  bool isContinueButtonVisible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() => _topPosition = 50);
    });
  }

  void _onButtonPressed(int buttonIndex) {
    setState(() {
      final startIdx = buttonIndex <= 4 ? 0 : 4;
      for (int i = startIdx; i < startIdx + 4; i++) {
        buttonStates[i] = false;
      }
      buttonStates[buttonIndex - 1] = true;
      String newAnswer = _getAnswerText(buttonIndex);
      allAnswers = allAnswers.isEmpty ? newAnswer : '$allAnswers,$newAnswer';
      if (buttonIndex <= 4) {
        _showSecondBox();
      } else {
        _showContinueButton();
      }
    });
  }

  void _showSecondBox() {
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() => _secondBoxTopPosition = _topPosition + 350);
    });
  }

  void _showContinueButton() {
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _continueButtonTopPosition = _secondBoxTopPosition + 350;
        isContinueButtonVisible = true;
      });
    });
  }

  String _getQuestionText(int questionNumber) {
    switch (questionNumber) {
      case 1:
        return AppLocalizations.of(context)!.whatDoYouExpectFromVacation;
      case 2:
        return AppLocalizations.of(context)!.howDoYouPlanTravel;
      default:
        return '';
    }
  }

  String _getButtonText(int buttonIndex) {
    switch (buttonIndex) {
      case 1:
        return AppLocalizations.of(context)!.adventureAndAdrenaline;
      case 2:
        return AppLocalizations.of(context)!.cultureAndHistory;
      case 3:
        return AppLocalizations.of(context)!.relaxationAndPeace;
      case 4:
        return AppLocalizations.of(context)!.foodAndFlavor;
      case 5:
        return AppLocalizations.of(context)!.planEveryDetail;
      case 6:
        return AppLocalizations.of(context)!.planButFlexible;
      case 7:
        return AppLocalizations.of(context)!.noPlanLiveInMoment;
      case 8:
        return AppLocalizations.of(context)!.balancedPlan;
      default:
        return '';
    }
  }

  String _getAnswerText(int buttonIndex) {
    switch (buttonIndex) {
      case 1:
        return "On Holiday I am Looking For Adventure and Adrenaline";
      case 2:
        return "On Holiday I am Looking For Culture and History";
      case 3:
        return "On Holiday I am Looking For Relaxation and Peace";
      case 4:
        return "On Holiday I am Looking For Food and Flavors";
      case 5:
        return "I Plan Every Detail in Advance";
      case 6:
        return "I Make a Plan but Love to Be Flexible";
      case 7:
        return "I Don't Plan, I Live in the Moment";
      case 8:
        return "I Prefer a Balanced Plan";
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              top: _topPosition,
              left: 25,
              right: 25,
              child: _buildQuestionBox(
                question: _getQuestionText(1),
                buttons: [1, 2, 3, 4],
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              top: _secondBoxTopPosition,
              left: 25,
              right: 25,
              child: Visibility(
                visible: _secondBoxTopPosition != 1000.0,
                child: _buildQuestionBox(
                  question: _getQuestionText(2),
                  buttons: [5, 6, 7, 8],
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              top: _continueButtonTopPosition,
              left: 25,
              right: 25,
              child: Visibility(
                visible: isContinueButtonVisible,
                child: _buildContinueButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionBox(
      {required String question, required List<int> buttons}) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(255, 99, 98, 98),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            question,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 20),
          ...buttons
              .map((index) => [
                    ElevatedButton(
                      onPressed: () => _onButtonPressed(index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonStates[index - 1]
                            ? Colors.black
                            : Colors.white.withOpacity(0.01),
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0)),
                      ),
                      child: Text(
                        _getButtonText(index),
                        style: TextStyle(
                            color: buttonStates[index - 1]
                                ? Colors.white
                                : Colors.black),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ])
              .expand((w) => w),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TestPage2(
              onLocaleChange: widget.onLocaleChange,
              allAnswers: allAnswers,
            ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        elevation: 16,
      ),
      child: Text(
        AppLocalizations.of(context)!.continueButton,
        style: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class TestPage2 extends StatefulWidget {
  final Function(Locale) onLocaleChange;
  final String allAnswers;

  const TestPage2(
      {super.key, required this.onLocaleChange, required this.allAnswers});

  @override
  TestPage2State createState() => TestPage2State();
}

class TestPage2State extends State<TestPage2> {
  double _topPosition = 1000.0;
  double _secondBoxTopPosition = 1000.0;
  double _continueButtonTopPosition = 1000.0;

  List<bool> buttonStates = List.generate(8, (_) => false);
  String allAnswers = '';
  bool isContinueButtonVisible = false;

  @override
  void initState() {
    super.initState();
    allAnswers = widget.allAnswers;
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() => _topPosition = 50);
    });
  }

  void _onButtonPressed(int buttonIndex) {
    setState(() {
      final startIdx = buttonIndex <= 4 ? 0 : 4;
      for (int i = startIdx; i < startIdx + 4; i++) {
        buttonStates[i] = false;
      }
      buttonStates[buttonIndex - 1] = true;
      String newAnswer = _getAnswerText(buttonIndex);
      allAnswers = allAnswers.isEmpty ? newAnswer : '$allAnswers,$newAnswer';
      if (buttonIndex <= 4) {
        _showSecondBox();
      } else {
        _showContinueButton();
      }
    });
  }

  void _showSecondBox() {
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() => _secondBoxTopPosition = _topPosition + 350);
    });
  }

  void _showContinueButton() {
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _continueButtonTopPosition = _secondBoxTopPosition + 350;
        isContinueButtonVisible = true;
      });
    });
  }

  String _getQuestionText(int questionNumber) {
    switch (questionNumber) {
      case 1:
        return AppLocalizations.of(context)!.whatExcitesYouMost;
      case 2:
        return AppLocalizations.of(context)!.whatIsYourBudget;
      default:
        return '';
    }
  }

  String _getButtonText(int buttonIndex) {
    switch (buttonIndex) {
      case 1:
        return AppLocalizations.of(context)!.culturalExperiences;
      case 2:
        return AppLocalizations.of(context)!.adventurousActivities;
      case 3:
        return AppLocalizations.of(context)!.entertainmentAndFun;
      case 4:
        return AppLocalizations.of(context)!.relaxationAndWellness;
      case 5:
        return AppLocalizations.of(context)!.budgetUpTo500TL;
      case 6:
        return AppLocalizations.of(context)!.budget500To2000TL;
      case 7:
        return AppLocalizations.of(context)!.budget2000To5000TL;
      case 8:
        return AppLocalizations.of(context)!.budget5000TLAndAbove;
      default:
        return '';
    }
  }

  String _getAnswerText(int buttonIndex) {
    switch (buttonIndex) {
      case 1:
        return "I am Excited by Cultural Experiences";
      case 2:
        return "I am Excited by Adventurous Activities";
      case 3:
        return "I am Excited by Entertainment and Fun";
      case 4:
        return "I am Excited by Relaxation and Wellness";
      case 5:
        return "My Budget is Up to 500 TL";
      case 6:
        return "My Budget is 500-2000 TL";
      case 7:
        return "My Budget is 2000-5000 TL";
      case 8:
        return "My Budget is 5000 TL and Above";
      default:
        return '';
    }
  }

  Future<void> _saveScoresToFirestore() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        List<String> answers = allAnswers.isEmpty ? [] : allAnswers.split(',');
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'answer3': answers.length > 2 ? answers[2] : '',
          'answer4': answers.length > 3 ? answers[3] : '',
          'lastTestTimestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Responses could not be saved: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              top: _topPosition,
              left: 25,
              right: 25,
              child: _buildQuestionBox(
                question: _getQuestionText(1),
                buttons: [1, 2, 3, 4],
                isImageBox: true,
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              top: _secondBoxTopPosition,
              left: 25,
              right: 25,
              child: Visibility(
                visible: _secondBoxTopPosition != 1000.0,
                child: _buildQuestionBox(
                  question: _getQuestionText(2),
                  buttons: [5, 6, 7, 8],
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              top: _continueButtonTopPosition,
              left: 25,
              right: 25,
              child: Visibility(
                visible: isContinueButtonVisible,
                child: _buildContinueButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionBox(
      {required String question,
      required List<int> buttons,
      bool isImageBox = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: isImageBox ? 380 : 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(255, 99, 98, 98),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 20),
          if (isImageBox)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageButton(1, 'assets/testImg1.png'),
                    _buildImageButton(2, 'assets/testImg2.png'),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageButton(3, 'assets/testImg3.png'),
                    _buildImageButton(4, 'assets/testImg4.png'),
                  ],
                ),
              ],
            )
          else
            ...buttons
                .map((index) => [
                      ElevatedButton(
                        onPressed: () => _onButtonPressed(index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonStates[index - 1]
                              ? Colors.black
                              : Colors.white.withOpacity(0.01),
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                        ),
                        child: Text(
                          _getButtonText(index),
                          style: TextStyle(
                              color: buttonStates[index - 1]
                                  ? Colors.white
                                  : Colors.black),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ])
                .expand((w) => w),
        ],
      ),
    );
  }

  Widget _buildImageButton(int index, String imagePath) {
    return GestureDetector(
      onTap: () => _onButtonPressed(index),
      child: Container(
        width: 150,
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(
            color: buttonStates[index - 1] ? Colors.black : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Image.asset(imagePath, fit: BoxFit.fill),
      ),
    );
  }

  Widget _buildContinueButton() {
    return ElevatedButton(
      onPressed: () async {
        await _saveScoresToFirestore();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TestPage3(allAnswers: allAnswers),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        elevation: 16,
      ),
      child: Text(
        AppLocalizations.of(context)!.continueButton,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class TestPage3 extends StatefulWidget {
  final String allAnswers;

  const TestPage3({super.key, required this.allAnswers});

  @override
  TestPage3State createState() => TestPage3State();
}

class TestPage3State extends State<TestPage3> {
  double _topPosition = 1000.0;
  double _secondBoxTopPosition = 1000.0;
  double _continueButtonTopPosition = 1000.0;

  List<bool> buttonStates = List.generate(4, (_) => false);
  String allAnswers = '';
  bool isContinueButtonVisible = false;

  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    allAnswers = widget.allAnswers;
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() => _topPosition = 50);
    });
  }

  void _onButtonPressed(int buttonIndex) {
    setState(() {
      for (int i = 0; i < 4; i++) {
        buttonStates[i] = false;
      }
      buttonStates[buttonIndex - 1] = true;
      String newAnswer = _getAnswerText(buttonIndex);
      allAnswers = allAnswers.isEmpty ? newAnswer : '$allAnswers,$newAnswer';
      _showSecondBox();
    });
  }

  void _showSecondBox() {
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() => _secondBoxTopPosition = _topPosition + 350);
    });
  }

  void _showContinueButton() {
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _continueButtonTopPosition = _secondBoxTopPosition + 350;
        isContinueButtonVisible = true;
      });
    });
  }

  String _getQuestionText(int questionNumber) {
    switch (questionNumber) {
      case 1:
        return AppLocalizations.of(context)!.whoDoYouTravelWith;
      case 2:
        return AppLocalizations.of(context)!.favoriteVacationMemory;
      default:
        return '';
    }
  }

  String _getButtonText(int buttonIndex) {
    switch (buttonIndex) {
      case 1:
        return AppLocalizations.of(context)!.travelAlone;
      case 2:
        return AppLocalizations.of(context)!.travelWithPartnerOrFriends;
      case 3:
        return AppLocalizations.of(context)!.travelWithFamily;
      case 4:
        return AppLocalizations.of(context)!.travelWithLargeGroup;
      default:
        return '';
    }
  }

  String _getAnswerText(int buttonIndex) {
    switch (buttonIndex) {
      case 1:
        return "I Usually Travel Alone";
      case 2:
        return "I Usually Travel with My Partner or Friends";
      case 3:
        return "I Usually Travel with My Family";
      case 4:
        return "I Usually Travel with a Large Group";
      default:
        return '';
    }
  }

  Future<void> _saveScoresToFirestore() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        List<String> answers = allAnswers.isEmpty ? [] : allAnswers.split(',');
        String finalAnswer = _textController.text.replaceAll(',', '');
        allAnswers = allAnswers.isEmpty ? finalAnswer : '$allAnswers,$finalAnswer';
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'answer5': answers.length > 4 ? answers[4] : '',
          'answer6': finalAnswer,
          'lastTestTimestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Responses could not be saved: $e")),
        );
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              top: _topPosition,
              left: 25,
              right: 25,
              child: _buildQuestionBox(
                question: _getQuestionText(1),
                buttons: [1, 2, 3, 4],
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              top: _secondBoxTopPosition,
              left: 25,
              right: 25,
              child: Visibility(
                visible: _secondBoxTopPosition != 1000.0,
                child: _buildTextInputBox(
                  question: _getQuestionText(2),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              top: _continueButtonTopPosition,
              left: 25,
              right: 25,
              child: Visibility(
                visible: isContinueButtonVisible,
                child: _buildContinueButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionBox(
      {required String question, required List<int> buttons}) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(255, 99, 98, 98),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 20),
          ...buttons
              .map((index) => [
                    ElevatedButton(
                      onPressed: () => _onButtonPressed(index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonStates[index - 1]
                            ? Colors.black
                            : Colors.white.withOpacity(0.01),
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0)),
                      ),
                      child: Text(
                        _getButtonText(index),
                        style: TextStyle(
                            color: buttonStates[index - 1]
                                ? Colors.white
                                : Colors.black),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ])
              .expand((w) => w),
        ],
      ),
    );
  }

  Widget _buildTextInputBox({required String question}) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(255, 99, 98, 98),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _textController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.favoriteVacationMemory,
              hintStyle:
                  const TextStyle(color: Color.fromARGB(184, 64, 62, 62)),
              filled: true,
              fillColor: Colors.grey.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: const BorderSide(color: Colors.black),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: const BorderSide(color: Colors.black),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: const BorderSide(color: Colors.black),
              ),
            ),
            style: const TextStyle(color: Colors.black),
            onChanged: (value) {
              setState(() {
                if (value.isNotEmpty) {
                  _showContinueButton();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return ElevatedButton(
      onPressed: () async {
        await _saveScoresToFirestore();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TestPage4(allAnswers: allAnswers),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        elevation: 16,
      ),
      child: Text(
        AppLocalizations.of(context)!.continueButton,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class TestPage4 extends StatefulWidget {
  final String allAnswers;

  const TestPage4({super.key, required this.allAnswers});

  @override
  TestPage4State createState() => TestPage4State();
}

class TestPage4State extends State<TestPage4> {
  double _topPosition = 1000.0;
  double _secondBoxTopPosition = 1000.0;
  double _continueButtonTopPosition = 1000.0;

  List<bool> buttonStates = List.generate(7, (_) => false);
  String allAnswers = '';
  bool isContinueButtonVisible = false;

  @override
  void initState() {
    super.initState();
    allAnswers = widget.allAnswers;
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() => _topPosition = 50);
    });
  }

  void _onButtonPressed(int buttonIndex) {
    setState(() {
      final startIdx = buttonIndex <= 3 ? 0 : 3;
      for (int i = startIdx; i < startIdx + (buttonIndex <= 3 ? 3 : 4); i++) {
        buttonStates[i] = false;
      }
      buttonStates[buttonIndex - 1] = true;
      String newAnswer = _getAnswerText(buttonIndex);
      allAnswers = allAnswers.isEmpty ? newAnswer : '$allAnswers,$newAnswer';
      if (buttonIndex <= 3) {
        _showSecondBox();
      } else {
        _showContinueButton();
      }
    });
  }

  void _showSecondBox() {
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() => _secondBoxTopPosition = _topPosition + 350);
    });
  }

  void _showContinueButton() {
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _continueButtonTopPosition = _secondBoxTopPosition + 350;
        isContinueButtonVisible = true;
      });
    });
  }

  String _getQuestionText(int questionNumber) {
    switch (questionNumber) {
      case 1:
        return AppLocalizations.of(context)!.howActiveOnVacation;
      case 2:
        return AppLocalizations.of(context)!.favoriteTravelSeason;
      default:
        return '';
    }
  }

  String _getButtonText(int buttonIndex) {
    switch (buttonIndex) {
      case 1:
        return AppLocalizations.of(context)!.constantlyActive;
      case 2:
        return AppLocalizations.of(context)!.moderatelyActive;
      case 3:
        return AppLocalizations.of(context)!.lazyAndMoveLittle;
      case 4:
        return AppLocalizations.of(context)!.springLivelyEnergetic;
      case 5:
        return AppLocalizations.of(context)!.summerHotSunny;
      case 6:
        return AppLocalizations.of(context)!.autumnColorfulCool;
      case 7:
        return AppLocalizations.of(context)!.winterColdSnowy;
      default:
        return '';
    }
  }

  String _getAnswerText(int buttonIndex) {
    switch (buttonIndex) {
      case 1:
        return "I am Constantly Active and Cannot Stay Still";
      case 2:
        return "I am Moderately Active and Rest a Bit";
      case 3:
        return "I Love to Be Lazy and Move Little";
      case 4:
        return "My Favorite Season is Spring: Lively and Energetic";
      case 5:
        return "My Favorite Season is Summer: Hot and Sunny";
      case 6:
        return "My Favorite Season is Autumn: Colorful and Cool";
      case 7:
        return "My Favorite Season is Winter: Cold and Snowy";
      default:
        return '';
    }
  }

  Future<void> _saveScoresToFirestore() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        List<String> answers = allAnswers.isEmpty ? [] : allAnswers.split(',');
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'answer7': answers.length > 6 ? answers[6] : '',
          'answer8': answers.length > 7 ? answers[7] : '',
          'lastTestTimestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Responses could not be saved: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              top: _topPosition,
              left: 25,
              right: 25,
              child: _buildQuestionBox(
                question: _getQuestionText(1),
                buttons: [1, 2, 3],
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              top: _secondBoxTopPosition,
              left: 25,
              right: 25,
              child: Visibility(
                visible: _secondBoxTopPosition != 1000.0,
                child: _buildQuestionBox(
                  question: _getQuestionText(2),
                  buttons: [4, 5, 6, 7],
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              top: _continueButtonTopPosition,
              left: 25,
              right: 25,
              child: Visibility(
                visible: isContinueButtonVisible,
                child: _buildContinueButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionBox(
      {required String question, required List<int> buttons}) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(255, 99, 98, 98),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 20),
          ...buttons
              .map((index) => [
                    ElevatedButton(
                      onPressed: () => _onButtonPressed(index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonStates[index - 1]
                            ? Colors.black
                            : Colors.white.withOpacity(0.01),
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0)),
                      ),
                      child: Text(
                        _getButtonText(index),
                        style: TextStyle(
                            color: buttonStates[index - 1]
                                ? Colors.white
                                : Colors.black),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ])
              .expand((w) => w),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return ElevatedButton(
      onPressed: () async {
        await _saveScoresToFirestore();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TestPage5(allAnswers: allAnswers),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        elevation: 16,
      ),
      child: Text(
        AppLocalizations.of(context)!.continueButton,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class TestPage5 extends StatefulWidget {
  final String allAnswers;

  const TestPage5({super.key, required this.allAnswers});

  @override
  TestPage5State createState() => TestPage5State();
}

class TestPage5State extends State<TestPage5> {
  double _topPosition = 1000.0;
  double _secondBoxTopPosition = 1000.0;
  double _continueButtonTopPosition = 1000.0;

  List<bool> buttonStates = List.generate(4, (_) => false);
  String allAnswers = '';
  bool isContinueButtonVisible = false;

  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    allAnswers = widget.allAnswers;
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() => _topPosition = 50);
    });
  }

  void _onButtonPressed(int buttonIndex) {
    setState(() {
      for (int i = 0; i < 4; i++) {
        buttonStates[i] = false;
      }
      buttonStates[buttonIndex - 1] = true;
      String newAnswer = _getAnswerText(buttonIndex);
      allAnswers = allAnswers.isEmpty ? newAnswer : '$allAnswers,$newAnswer';
      _showSecondBox();
    });
  }

  void _showSecondBox() {
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() => _secondBoxTopPosition = _topPosition + 350);
    });
  }

  void _showContinueButton() {
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _continueButtonTopPosition = _secondBoxTopPosition + 350;
        isContinueButtonVisible = true;
      });
    });
  }

  String _getQuestionText(int questionNumber) {
    switch (questionNumber) {
      case 1:
        return AppLocalizations.of(context)!.whatMustBeInVacation;
      case 2:
        return AppLocalizations.of(context)!.tellUsMoreAboutYourself;
      default:
        return '';
    }
  }

  String _getButtonText(int buttonIndex) {
    switch (buttonIndex) {
      case 1:
        return AppLocalizations.of(context)!.greatViewsPhotoOpportunities;
      case 2:
        return AppLocalizations.of(context)!.deliciousFoodLocalFlavors;
      case 3:
        return AppLocalizations.of(context)!.entertainmentNightlife;
      case 4:
        return AppLocalizations.of(context)!.silenceAndPeace;
      default:
        return '';
    }
  }

  String _getAnswerText(int buttonIndex) {
    switch (buttonIndex) {
      case 1:
        return "I Want Great Views and Photo Opportunities";
      case 2:
        return "I Want Delicious Food and Local Flavors";
      case 3:
        return "I Want Entertainment and Nightlife";
      case 4:
        return "I Want Silence and Peace";
      default:
        return '';
    }
  }

  Future<void> _saveScoresToFirestore() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        List<String> answers = allAnswers.isEmpty ? [] : allAnswers.split(',');
        String finalAnswer = _textController.text.replaceAll(',', '');
        allAnswers = allAnswers.isEmpty ? finalAnswer : '$allAnswers,$finalAnswer';
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'answer9': answers.length > 8 ? answers[8] : '',
          'answer10': finalAnswer,
          'allAnswers': allAnswers,
          'lastTestTimestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Responses could not be saved: $e")),
        );
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              top: _topPosition,
              left: 25,
              right: 25,
              child: _buildQuestionBox(
                question: _getQuestionText(1),
                buttons: [1, 2, 3, 4],
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              top: _secondBoxTopPosition,
              left: 25,
              right: 25,
              child: Visibility(
                visible: _secondBoxTopPosition != 1000.0,
                child: _buildTextInputBox(
                  question: _getQuestionText(2),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              top: _continueButtonTopPosition,
              left: 25,
              right: 25,
              child: Visibility(
                visible: isContinueButtonVisible,
                child: _buildContinueButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionBox(
      {required String question, required List<int> buttons}) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(255, 99, 98, 98),
            blurRadius: 15,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 20),
          ...buttons
              .map((index) => [
                    ElevatedButton(
                      onPressed: () => _onButtonPressed(index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonStates[index - 1]
                            ? Colors.black
                            : Colors.white.withOpacity(0.01),
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0)),
                      ),
                      child: Text(
                        _getButtonText(index),
                        style: TextStyle(
                            color: buttonStates[index - 1]
                                ? Colors.white
                                : Colors.black),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ])
              .expand((w) => w),
        ],
      ),
    );
  }

  Widget _buildTextInputBox({required String question}) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(255, 99, 98, 98),
            blurRadius: 15,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 30),
          TextField(
            controller: _textController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText:
                  AppLocalizations.of(context)!.whatDoYouLikeBesidesTravel,
              hintStyle:
                  const TextStyle(color: Color.fromARGB(163, 136, 136, 136)),
              filled: true,
              fillColor: Colors.grey.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: const BorderSide(color: Colors.black),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: const BorderSide(color: Colors.black),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
                borderSide: const BorderSide(color: Colors.black),
              ),
            ),
            style: const TextStyle(color: Colors.black),
            onChanged: (value) {
              setState(() {
                if (value.isNotEmpty) {
                  _showContinueButton();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return ElevatedButton(
      onPressed: () async {
        await _saveScoresToFirestore();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MainMenuPage(
              onLocaleChange: (Locale locale) {},
            ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        elevation: 18,
      ),
      child: Text(
        AppLocalizations.of(context)!.continueButton,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
     ),
);
}
}class SplashScreen3 extends StatefulWidget {
  const SplashScreen3({super.key});

  @override
  SplashScreen2State createState() => SplashScreen2State();
}

class SplashScreen3State extends State<SplashScreen3> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 5), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (context) => MainMenuPage(
                  onLocaleChange: (Locale p1) {},
                )),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Center(
                child: Image.asset(
                  'assets/logoWhite.png',
                  width: 300,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FirebaseApi {
  final _firebaseMessaging = FirebaseMessaging.instance;

  void handleMessage(RemoteMessage? message) {
    if (message == null) return;
  }

  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    print('Title: ${message.notification?.title}');
    print('body: ${message.notification?.body}');
    print('payload: ${message.data}');
  }

  Future<void> initNotification() async {
    await _firebaseMessaging.requestPermission();
    final fCMToken = await _firebaseMessaging.getToken();
    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
    if (fCMToken == null) {
      print("🚫 Token alinamadi. Null döndü.");
    } else {
      print("✅ FCM Token: $fCMToken");
    }
  }
}

class MainMenuPage extends StatefulWidget {
  final Function(Locale) onLocaleChange;

  const MainMenuPage({super.key, required this.onLocaleChange});

  @override
  _MainMenuPageState createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late AnimationController _titleController;
  late Animation<double> _titleFadeAnimation;

  final List<AnimationController> _popularControllers = [];
  final List<Animation<Offset>> _popularSlideAnimations = [];
  bool _popularSectionVisible = false;

  final List<AnimationController> _whatToEatControllers = [];
  final List<Animation<Offset>> _whatToEatSlideAnimations = [];
  bool _whatToEatSectionVisible = false;

  final List<AnimationController> _categoryControllers = [];
  final List<Animation<double>> _categoryFadeAnimations = [];
  bool _categorySectionVisible = false;

  late ScrollController _scrollController;
  final GlobalKey _blogSectionKey = GlobalKey();
  final GlobalKey _popularSectionKey = GlobalKey();
  final GlobalKey _personalizedSectionKey = GlobalKey();
  final GlobalKey _whatToEatSectionKey = GlobalKey();
  final GlobalKey _categorySectionKey = GlobalKey();

  String _userName = '';
  Map<String, String> _imageUrls = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _titleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _titleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeIn),
    );

    for (int i = 0; i < 3; i++) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      _popularControllers.add(controller);

      final slideAnimation = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );
      _popularSlideAnimations.add(slideAnimation);
    }

    for (int i = 0; i < 3; i++) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      _whatToEatControllers.add(controller);

      final slideAnimation = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );
      _whatToEatSlideAnimations.add(slideAnimation);
    }

    for (int i = 0; i < 8; i++) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );
      _categoryControllers.add(controller);

      final fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeIn),
      );
      _categoryFadeAnimations.add(fadeAnimation);
    }

    Future.delayed(Duration.zero, () {
      _checkVisibilityAndStartAnimations();
      _titleController.forward();
    });

    _preloadImageUrls();
  }

  Future<void> _preloadImageUrls() async {
    List<String> imagePaths = [
      'mainGalataKulesi.jpg',
      'mainKariyeCamii.jpg',
      'mainMisirCarsisi.jpg',
      'mainNevetIstanbul.jpg',
      'mainBaklavaByGalata.jpg',
      'mainTarihiEminonuBalikEkmek.jpg',
      'blog1.jpg',
      'blog2.jpg',
    ];

    for (String path in imagePaths) {
      try {
        String url = await FirebaseStorage.instance.ref(path).getDownloadURL();
        setState(() {
          _imageUrls[path] = url;
        });
      } catch (e) {
        print("Error loading image URL for $path: $e");
      }
    }
  }

  Future<void> _fetchUserName() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          setState(() {
            _userName = userDoc['firstName'] ??
                AppLocalizations.of(context)!.defaultUser;
          });
        }
      }
    } catch (e) {
      print("Error fetching username: $e");
    }
  }

  void _onScroll() {
    _checkVisibilityAndStartAnimations();
  }

  void _checkVisibilityAndStartAnimations() {
    final RenderBox? blogBox =
        _blogSectionKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? popularBox =
        _popularSectionKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? whatToEatBox =
        _whatToEatSectionKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? categoryBox =
        _categorySectionKey.currentContext?.findRenderObject() as RenderBox?;

    final double screenHeight = MediaQuery.of(context).size.height;
    final double scrollOffset = _scrollController.offset;

    if (blogBox != null) {
      final blogPosition = blogBox.localToGlobal(Offset.zero).dy;
      if (blogPosition >= scrollOffset - blogBox.size.height &&
          blogPosition <= scrollOffset + screenHeight) {
        _controller.forward();
      }
    }

    if (popularBox != null) {
      final popularPosition = popularBox.localToGlobal(Offset.zero).dy;
      if (popularPosition >= scrollOffset - popularBox.size.height &&
          popularPosition <= scrollOffset + screenHeight) {
        if (!_popularSectionVisible) {
          setState(() {
            _popularSectionVisible = true;
          });
          for (int i = 0; i < _popularControllers.length; i++) {
            Future.delayed(Duration(milliseconds: 300 * i), () {
              if (mounted) {
                _popularControllers[i].forward();
              }
            });
          }
        }
      } else {
        setState(() {
          _popularSectionVisible = false;
        });
      }
    }

    if (whatToEatBox != null) {
      final whatToEatPosition = whatToEatBox.localToGlobal(Offset.zero).dy;
      if (whatToEatPosition >= scrollOffset - whatToEatBox.size.height &&
          whatToEatPosition <= scrollOffset + screenHeight) {
        if (!_whatToEatSectionVisible) {
          setState(() {
            _whatToEatSectionVisible = true;
          });
          for (int i = 0; i < _whatToEatControllers.length; i++) {
            Future.delayed(Duration(milliseconds: 300 * i), () {
              if (mounted) {
                _whatToEatControllers[i].forward();
              }
            });
          }
        }
      } else {
        setState(() {
          _whatToEatSectionVisible = false;
        });
      }
    }

    if (categoryBox != null) {
      final categoryPosition = categoryBox.localToGlobal(Offset.zero).dy;
      if (categoryPosition >= scrollOffset - categoryBox.size.height &&
          categoryPosition <= scrollOffset + screenHeight) {
        if (!_categorySectionVisible) {
          setState(() {
            _categorySectionVisible = true;
          });
          for (int i = 0; i < _categoryControllers.length; i++) {
            Future.delayed(Duration(milliseconds: 300 * i), () {
              if (mounted) {
                _categoryControllers[i].forward();
              }
            });
          }
        }
      } else {
        setState(() {
          _categorySectionVisible = false;
          for (var controller in _categoryControllers) {
            controller.reset();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    _titleController.dispose();
    for (var controller in _popularControllers) {
      controller.dispose();
    }
    for (var controller in _whatToEatControllers) {
      controller.dispose();
    }
    for (var controller in _categoryControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(10),
            ),
          ),
          automaticallyImplyLeading: false,
          title: Padding(
            padding: const EdgeInsets.only(left: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.helloUser(_userName),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: () {},
                child: Stack(
                  children: [
                    const Icon(
                      Icons.notifications,
                      color: Colors.grey,
                      size: 28,
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          "0",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ProfilePage()),
                  );
                },
                child: const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey,
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 255, 255, 255),
                Color.fromARGB(255, 255, 255, 255),
                Color.fromARGB(255, 255, 255, 255),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      enabled: true,
                      decoration: InputDecoration(
                        hintText:
                            AppLocalizations.of(context)!.searchPlaceholder,
                        hintStyle: GoogleFonts.poppins(
                          fontWeight: FontWeight.w300,
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[600],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  key: _blogSectionKey,
                  margin: const EdgeInsets.only(top: 2, left: 10, right: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 185,
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Stack(
                                  children: [
                                    PageView(
                                      children: [
                                        GestureDetector(
                                          onTap: () {},
                                          child: _buildImageContainerWithText(
                                            'blog1.jpg',
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {},
                                          child: _buildImageContainerWithText(
                                            'blog2.jpg',
                                          ),
                                        ),
                                      ],
                                    ),
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 50,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 50,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  key: _categorySectionKey,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  height: 80,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildAnimatedCategorySquare(
                          Icons.hotel,
                          AppLocalizations.of(context)!.categoryHotel,
                          0,
                          _categoryControllers,
                          _categoryFadeAnimations),
                      const SizedBox(width: 10),
                      _buildAnimatedCategorySquare(
                          Icons.museum,
                          AppLocalizations.of(context)!.categoryMuseum,
                          1,
                          _categoryControllers,
                          _categoryFadeAnimations),
                      const SizedBox(width: 10),
                      _buildAnimatedCategorySquare(
                          Icons.restaurant,
                          AppLocalizations.of(context)!.categoryRestaurant,
                          2,
                          _categoryControllers,
                          _categoryFadeAnimations),
                      const SizedBox(width: 10),
                      _buildAnimatedCategorySquare(
                          Icons.local_bar,
                          AppLocalizations.of(context)!.categoryClubBar,
                          3,
                          _categoryControllers,
                          _categoryFadeAnimations),
                      const SizedBox(width: 10),
                      _buildAnimatedCategorySquare(
                          Icons.panorama,
                          AppLocalizations.of(context)!.categoryView,
                          4,
                          _categoryControllers,
                          _categoryFadeAnimations),
                      const SizedBox(width: 10),
                      _buildAnimatedCategorySquare(
                          Icons.park,
                          AppLocalizations.of(context)!.categoryPark,
                          5,
                          _categoryControllers,
                          _categoryFadeAnimations),
                      const SizedBox(width: 10),
                      _buildAnimatedCategorySquare(
                          Icons.account_balance,
                          AppLocalizations.of(context)!.categoryHistoricalPlace,
                          6,
                          _categoryControllers,
                          _categoryFadeAnimations),
                      const SizedBox(width: 10),
                      _buildAnimatedCategorySquare(
                          Icons.shopping_bag,
                          AppLocalizations.of(context)!.categoryShopping,
                          7,
                          _categoryControllers,
                          _categoryFadeAnimations),
                    ],
                  ),
                ),
                Container(
                  key: _popularSectionKey,
                  margin: const EdgeInsets.only(top: 1, left: 20, right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedBuilder(
                        animation: _titleController,
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _titleFadeAnimation,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.place,
                                        color: Colors.black, size: 24),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppLocalizations.of(context)!
                                          .popularPlaces,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 20,
                                        fontFamily: 'Poppins Bold',
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppLocalizations.of(context)!.discoverBestPlaces,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w300,
                          fontSize: 15,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 180,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildAnimatedImageWithOverlay(
                              context,
                              'mainGalataKulesi.jpg',
                              AppLocalizations.of(context)!.galataTower,
                              0.0,
                              AppLocalizations.of(context)!.beyoglu,
                              AppLocalizations.of(context)!
                                  .galataTowerDescription,
                              'img1GalataKulesi.jpg',
                              [
                                'img1GalataKulesi.jpg',
                                'img2GalataKulesi.jpg',
                                'img3GalataKulesi.jpg'
                              ],
                              0,
                              _popularControllers,
                              _popularSlideAnimations,
                            ),
                            const SizedBox(width: 10),
                            _buildAnimatedImageWithOverlay(
                              context,
                              'mainKariyeCamii.jpg',
                              AppLocalizations.of(context)!.kariyeMosque,
                              0.0,
                              AppLocalizations.of(context)!.fatih,
                              AppLocalizations.of(context)!
                                  .kariyeMosqueDescription,
                              'img1KariyeCamii.jpg',
                              [
                                'img1KariyeCamii.jpg',
                                'img2KariyeCamii.jpg',
                                'img3KariyeCamii.jpg'
                              ],
                              1,
                              _popularControllers,
                              _popularSlideAnimations,
                            ),
                            const SizedBox(width: 10),
                            _buildAnimatedImageWithOverlay(
                              context,
                              'mainMisirCarsisi.jpg',
                              AppLocalizations.of(context)!.spiceBazaar,
                              0.0,
                              AppLocalizations.of(context)!.eminonu,
                              AppLocalizations.of(context)!
                                  .spiceBazaarDescription,
                              'img1MisirCarsisi.jpg',
                              [
                                'img1MisirCarsisi.jpg',
                                'img2MisirCarsisi.jpg',
                                'img3MisirCarsisi.jpg'
                              ],
                              2,
                              _popularControllers,
                              _popularSlideAnimations,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  key: _personalizedSectionKey,
                  margin: const EdgeInsets.only(top: 20, left: 20, right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedBuilder(
                        animation: _titleController,
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _titleFadeAnimation,
                            child: Row(
                              children: [
                                const Icon(Icons.person_pin,
                                    color: Colors.black, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(context)!
                                      .personalizedSuggestions,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 20,
                                    fontFamily: 'Poppins Bold',
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppLocalizations.of(context)!.viewCustomRoadmaps,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w300,
                          fontSize: 15,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white70.withOpacity(0.99),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              AppLocalizations.of(context)!.talkWithAI,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => ChatScreen()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color.fromARGB(255, 0, 0, 0),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.touristiyAI,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  key: _whatToEatSectionKey,
                  margin: const EdgeInsets.only(top: 20, left: 20, right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedBuilder(
                        animation: _titleController,
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _titleFadeAnimation,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.restaurant,
                                        color: Colors.black, size: 24),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppLocalizations.of(context)!
                                          .whatToEatInIstanbul,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 20,
                                        fontFamily: 'Poppins Bold',
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppLocalizations.of(context)!.discoverBestFlavors,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w300,
                          fontSize: 15,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 180,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildAnimatedImageWithOverlay(
                              context,
                              'mainNevetIstanbul.jpg',
                              AppLocalizations.of(context)!.nevetKebap,
                              0.0,
                              AppLocalizations.of(context)!.sultanahmet,
                              AppLocalizations.of(context)!
                                  .nevetKebapDescription,
                              'img1NevetIstanbul.jpg',
                              [
                                'img1NevetIstanbul.jpg',
                                'img2NevetIstanbul.jpg',
                                'img3NevetIstanbul.jpg',
                              ],
                              0,
                              _whatToEatControllers,
                              _whatToEatSlideAnimations,
                            ),
                            const SizedBox(width: 10),
                            _buildAnimatedImageWithOverlay(
                              context,
                              'mainBaklavaByGalata.jpg',
                              AppLocalizations.of(context)!.baklavaByGalata,
                              0.0,
                              AppLocalizations.of(context)!.beyoglu,
                              AppLocalizations.of(context)!
                                  .baklavaByGalataDescription,
                              'img1BaklavaByGalata.jpg',
                              [
                                'img1BaklavaByGalata.jpg',
                                'img2BaklavaByGalata.jpg',
                                'img3BaklavaByGalata.jpg',
                              ],
                              1,
                              _whatToEatControllers,
                              _whatToEatSlideAnimations,
                            ),
                            const SizedBox(width: 10),
                            _buildAnimatedImageWithOverlay(
                              context,
                              'mainTarihiEminonuBalikEkmek.jpg',
                              AppLocalizations.of(context)!.eminonuFishBread,
                              0.0,
                              AppLocalizations.of(context)!.eminonu,
                              AppLocalizations.of(context)!
                                  .eminonuFishBreadDescription,
                              'img1TarihiEminonuBalikEkmek.jpg',
                              [
                                'img1TarihiEminonuBalikEkmek.jpg',
                                'img2TarihiEminonuBalikEkmek.jpg',
                                'img3TarihiEminonuBalikEkmek.jpg',
                              ],
                              2,
                              _whatToEatControllers,
                              _whatToEatSlideAnimations,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 135),
              ],
            ),
          ),
        ),
        extendBody: true,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChatScreen()),
            );
          },
          backgroundColor: const Color.fromARGB(255, 0, 39, 232),
          elevation: 6,
          shape: const CircleBorder(),
          child: const Icon(
            Icons.smart_toy_rounded,
            size: 40,
            color: Colors.white,
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6.0,
          color: Colors.white,
          elevation: 2,
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMenuButton(Icons.home, context, 0),
                _buildMenuButton(Icons.luggage_rounded, context, 1),
                const SizedBox(width: 60),
                _buildMenuButton(Icons.map_rounded, context, 2),
                _buildMenuButton(Icons.settings, context, 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(IconData icon, BuildContext context, int index) {
    bool isActive = index == 0;

    return GestureDetector(
      onTap: () {
        if (index == 0) {
          return;
        } else if (index == 1) {
          Navigator.push(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 800),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const TripsPage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;

                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);

                return SlideTransition(
                  position: offsetAnimation,
                  child: child,
                );
              },
            ),
          );
        } else if (index == 2) {
          Navigator.push(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 800),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const MapPage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;

                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);

                return SlideTransition(
                  position: offsetAnimation,
                  child: child,
                );
              },
            ),
          );
        } else if (index == 3) {
          Navigator.push(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 800),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const SettingsPage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;

                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);

                return SlideTransition(
                  position: offsetAnimation,
                  child: child,
                );
              },
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.blue : Colors.grey,
              size: 40,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedCategorySquare(
    IconData icon,
    String title,
    int index,
    List<AnimationController> controllers,
    List<Animation<double>> fadeAnimations,
  ) {
    return AnimatedBuilder(
      animation: controllers[index],
      builder: (context, child) {
        return Opacity(
          opacity: fadeAnimations[index].value,
          child: _buildCategorySquare(icon, title),
        );
      },
    );
  }

  Widget _buildCategorySquare(IconData icon, String title) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Colors.grey,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 30,
            color: Colors.black,
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildImageContainerWithText(String imagePath) {
    return SizedBox(
      height: 140,
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Colors.white,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: _imageUrls[imagePath] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: _imageUrls[imagePath]!,
                      fit: BoxFit.fitWidth,
                      placeholder: (context, url) =>
                          CircularProgressIndicator(),
                      errorWidget: (context, url, error) => Icon(Icons.error),
                    ),
                  )
                : Center(child: CircularProgressIndicator()),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 100,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedImageWithOverlay(
    BuildContext context,
    String imagePath,
    String title,
    double rating,
    String district,
    String description,
    String detailImagePath,
    List<String> imageList,
    int index,
    List<AnimationController> controllers,
    List<Animation<Offset>> slideAnimations,
  ) {
    return AnimatedBuilder(
      animation: controllers[index],
      builder: (context, child) {
        return SlideTransition(
          position: slideAnimations[index],
          child: GestureDetector(
            onTap: () {
              _showDestinationInfo(
                  context, title, description, detailImagePath, imageList);
            },
            child: _buildImageWithOverlay(imagePath, title, rating, district),
          ),
        );
      },
    );
  }

  Widget _buildImageWithOverlay(
      String imagePath, String title, double rating, String district) {
    return Stack(
      children: [
        Container(
          width: 250,
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: _imageUrls[imagePath] != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: _imageUrls[imagePath]!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => CircularProgressIndicator(),
                    errorWidget: (context, url, error) => Icon(Icons.error),
                  ),
                )
              : Center(child: CircularProgressIndicator()),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 100,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color.fromARGB(255, 0, 0, 0),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 10,
          bottom: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
            ],
          ),
        ),
        Positioned(
          right: 10,
          bottom: 10,
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white, size: 16),
              const SizedBox(width: 5),
              Text(
                district,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDestinationInfo(
    BuildContext context,
    String title,
    String description,
    String detailImagePath,
    List<String> imageList,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Stack(
          children: [
            DraggableScrollableSheet(
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                              image: AssetImage(detailImagePath),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white70,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.white,
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                AppLocalizations.of(context)!.openingHours,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              ..._buildOpeningHours(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          AppLocalizations.of(context)!.moreImages,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins Bold',
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 100,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: imageList.map((imagePath) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _buildDetailImage(imagePath),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(15),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.letsGo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildOpeningHours() {
    final Map<String, String> openingHours = {
      AppLocalizations.of(context)!.monday:
          AppLocalizations.of(context)!.openingHoursMonday,
      AppLocalizations.of(context)!.tuesday:
          AppLocalizations.of(context)!.openingHoursTuesday,
      AppLocalizations.of(context)!.wednesday:
          AppLocalizations.of(context)!.openingHoursWednesday,
      AppLocalizations.of(context)!.thursday:
          AppLocalizations.of(context)!.openingHoursThursday,
      AppLocalizations.of(context)!.friday:
          AppLocalizations.of(context)!.openingHoursFriday,
      AppLocalizations.of(context)!.saturday:
          AppLocalizations.of(context)!.openingHoursSaturday,
      AppLocalizations.of(context)!.sunday:
          AppLocalizations.of(context)!.openingHoursSunday,
    };

    return openingHours.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              entry.key,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            Text(
              entry.value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildDetailImage(String imagePath) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        imagePath,
        width: 100,
        fit: BoxFit.cover,
      ),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 2,
        title: Text(
          "Bildirimler",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: const Center(
          child: Text(
            "Bildirimlerin burada görünecek!",
            style: TextStyle(
              fontSize: 18,
              color: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}

class BlogPage1 extends StatelessWidget {
  const BlogPage1({super.key});

  Widget _buildImageContainerWithText(String imagePath, BuildContext context) {
    return SizedBox(
      height: 180,
      width: MediaQuery.of(context).size.width * 0.9,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(15)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 80),
                Center(
                  child:
                      _buildImageContainerWithText('assets/blog1.png', context),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 20, top: 10),
                  child: Text(
                    "Touristiy AI ile Tanış! En İyi Önerileri Al!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Touristiy AI ile Tanış! En İyi Önerileri Al! Burada blog içeriği yer alabilir.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              title: const Text(
                "Bloglar",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class BlogPage2 extends StatelessWidget {
  const BlogPage2({super.key});

  Widget _buildImageContainerWithText(String imagePath, BuildContext context) {
    return SizedBox(
      height: 180,
      width: MediaQuery.of(context).size.width * 0.9,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(15)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 80),
                Center(
                  child:
                      _buildImageContainerWithText('assets/blog2.png', context),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 20, top: 10),
                  child: Text(
                    "Özel Rotalar: Özel Seyahat Planını Oluştur!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Özel Rotalar: Özel Seyahat Planını Oluştur! Burada blog içeriği yer alabilir.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              title: const Text(
                "Bloglar",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class TripsPage extends StatefulWidget {
  const TripsPage({super.key});

  @override
  _TripsPageState createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> with TickerProviderStateMixin {
  String _userName = "Kullanıcı";

  late ScrollController _scrollController;
  final GlobalKey _popularTripsSectionKey = GlobalKey();
  final GlobalKey _personalizedTripsSectionKey = GlobalKey();

  final List<AnimationController> _popularTripsControllers = [];
  final List<Animation<Offset>> _popularTripsSlideAnimations = [];
  bool _popularTripsSectionVisible = false;

  final List<AnimationController> _personalizedTripsControllers = [];
  final List<Animation<Offset>> _personalizedTripsSlideAnimations = [];
  bool _personalizedTripsSectionVisible = false;

  @override
  void initState() {
    super.initState();
    _fetchUserName();

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    for (int i = 0; i < 3; i++) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      _popularTripsControllers.add(controller);

      final slideAnimation = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );
      _popularTripsSlideAnimations.add(slideAnimation);
    }
    for (int i = 0; i < 3; i++) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      _personalizedTripsControllers.add(controller);

      final slideAnimation = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );
      _personalizedTripsSlideAnimations.add(slideAnimation);
    }

    Future.delayed(Duration.zero, () {
      _checkVisibilityAndStartAnimations();
    });
  }

  Future<void> _fetchUserName() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          setState(() {
            _userName = userDoc['name'] ?? "Kullanıcı";
          });
        }
      }
    } catch (e) {
      print("Kullanıcı adı çekilirken hata oluştu: $e");
    }
  }

  void _onScroll() {
    _checkVisibilityAndStartAnimations();
  }

  void _checkVisibilityAndStartAnimations() {
    final RenderBox? popularTripsBox = _popularTripsSectionKey.currentContext
        ?.findRenderObject() as RenderBox?;
    final RenderBox? personalizedTripsBox =
        _personalizedTripsSectionKey.currentContext?.findRenderObject()
            as RenderBox?;

    final double screenHeight = MediaQuery.of(context).size.height;
    final double scrollOffset = _scrollController.offset;

    if (popularTripsBox != null) {
      final popularPosition = popularTripsBox.localToGlobal(Offset.zero).dy;
      if (popularPosition >= scrollOffset - popularTripsBox.size.height &&
          popularPosition <= scrollOffset + screenHeight) {
        if (!_popularTripsSectionVisible) {
          setState(() {
            _popularTripsSectionVisible = true;
          });
          for (int i = 0; i < _popularTripsControllers.length; i++) {
            Future.delayed(Duration(milliseconds: 300 * i), () {
              if (mounted) {
                _popularTripsControllers[i].forward();
              }
            });
          }
        }
      } else {
        if (_popularTripsSectionVisible) {
          setState(() {
            _popularTripsSectionVisible = false;
          });
          for (var controller in _popularTripsControllers) {
            controller.reset();
          }
        }
      }
    }

    if (personalizedTripsBox != null) {
      final personalizedPosition =
          personalizedTripsBox.localToGlobal(Offset.zero).dy;
      if (personalizedPosition >=
              scrollOffset - personalizedTripsBox.size.height &&
          personalizedPosition <= scrollOffset + screenHeight) {
        if (!_personalizedTripsSectionVisible) {
          setState(() {
            _personalizedTripsSectionVisible = true;
          });
          for (int i = 0; i < _personalizedTripsControllers.length; i++) {
            Future.delayed(Duration(milliseconds: 300 * i), () {
              if (mounted) {
                _personalizedTripsControllers[i].forward();
              }
            });
          }
        }
      } else {
        if (_personalizedTripsSectionVisible) {
          setState(() {
            _personalizedTripsSectionVisible = false;
          });
          for (var controller in _personalizedTripsControllers) {
            controller.reset();
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    for (var controller in _popularTripsControllers) {
      controller.dispose();
    }
    for (var controller in _personalizedTripsControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(10),
          ),
        ),
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                "Merhaba, $_userName!",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {},
              child: Stack(
                children: [
                  const Icon(
                    Icons.notifications,
                    color: Colors.grey,
                    size: 28,
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        "0",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
              child: const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey,
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 255, 255, 255),
              Color.fromARGB(255, 255, 255, 255),
              Color.fromARGB(255, 255, 255, 255),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 20, left: 20),
                child: Text(
                  "Current Trips",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    "Güncel Yolculuk Yok",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Container(
                key: _popularTripsSectionKey,
                margin: const EdgeInsets.only(left: 20, right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Popular Trips",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "En çok tercih edilen yolculukları keşfedin.",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w300,
                        fontSize: 15,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 180,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        children: [
                          _buildAnimatedMapContainer(
                            "Popüler Yolculuk 1",
                            0,
                            _popularTripsControllers,
                            _popularTripsSlideAnimations,
                          ),
                          const SizedBox(width: 10),
                          _buildAnimatedMapContainer(
                            "Popüler Yolculuk 2",
                            1,
                            _popularTripsControllers,
                            _popularTripsSlideAnimations,
                          ),
                          const SizedBox(width: 10),
                          _buildAnimatedMapContainer(
                            "Popüler Yolculuk 3",
                            2,
                            _popularTripsControllers,
                            _popularTripsSlideAnimations,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Container(
                key: _personalizedTripsSectionKey,
                margin: const EdgeInsets.only(left: 20, right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Kişiselleştirilmiş Yol Haritaları",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Size özel hazırlanmış rotaları görün.",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w300,
                        fontSize: 15,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 180,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        children: [
                          _buildAnimatedMapContainer(
                            "Yol Haritası 1",
                            0,
                            _personalizedTripsControllers,
                            _personalizedTripsSlideAnimations,
                          ),
                          const SizedBox(width: 10),
                          _buildAnimatedMapContainer(
                            "Yol Haritası 2",
                            1,
                            _personalizedTripsControllers,
                            _personalizedTripsSlideAnimations,
                          ),
                          const SizedBox(width: 10),
                          _buildAnimatedMapContainer(
                            "Yol Haritası 3",
                            2,
                            _personalizedTripsControllers,
                            _personalizedTripsSlideAnimations,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      extendBody: true,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ChatScreen()),
          );
        },
        backgroundColor: const Color.fromARGB(255, 0, 39, 232),
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(
          Icons.smart_toy_rounded,
          size: 40,
          color: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        color: Colors.white,
        elevation: 2,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMenuButton(Icons.home, context, 0),
              _buildMenuButton(Icons.luggage_rounded, context, 1),
              const SizedBox(width: 60),
              _buildMenuButton(Icons.map_rounded, context, 2),
              _buildMenuButton(Icons.settings, context, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(IconData icon, BuildContext context, int index) {
    bool isActive = index == 1;

    return GestureDetector(
      onTap: () {
        if (index == 0) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 1000),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  MainMenuPage(
                onLocaleChange: (Locale p1) {},
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(-1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;

                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);

                return SlideTransition(
                  position: offsetAnimation,
                  child: child,
                );
              },
            ),
          );
        } else if (index == 1) {
          return;
        } else if (index == 2) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 1000),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const MapPage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;

                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);

                return SlideTransition(
                  position: offsetAnimation,
                  child: child,
                );
              },
            ),
          );
        } else if (index == 3) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 1000),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const NotificationsPage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;

                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);

                return SlideTransition(
                  position: offsetAnimation,
                  child: child,
                );
              },
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.blue : Colors.grey,
              size: 40,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedMapContainer(
    String title,
    int index,
    List<AnimationController> controllers,
    List<Animation<Offset>> slideAnimations,
  ) {
    return AnimatedBuilder(
      animation: controllers[index],
      builder: (context, child) {
        return SlideTransition(
          position: slideAnimations[index],
          child: _buildMapContainer(title),
        );
      },
    );
  }

  Widget _buildMapContainer(String title) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(10),
            ),
            child: Image.asset(
              'assets/placeholder.jpg',
              width: 250,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(41.0082, 28.9784),
    zoom: 10,
  );

  final String _noPoiMapStyle = '''
  [
    {
      "featureType": "poi",
      "stylers": [
        {
          "visibility": "off" // Yer işaretlerini (Galata Kulesi vb.) gizle
        }
      ]
    }
  ]
  ''';

  GoogleMapController? _mapController;

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController!.setMapStyle(_noPoiMapStyle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 2,
        title: Text(
          "Harita",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: GoogleMap(
        initialCameraPosition: _initialPosition,
        mapType: MapType.normal,
        onMapCreated: _onMapCreated,
      ),
    );
  }
}

FirebaseApp? _firebaseApp;

class ChatbotApp extends StatelessWidget {
  const ChatbotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chatbot',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0A192F),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _chatHistory = [];
  final SpeechToText _speech = SpeechToText();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();
  final GlobalKey _bottomContainerKey = GlobalKey();
  final GlobalKey _addButtonKey = GlobalKey();
  bool _isListening = false;
  bool _isLoading = false;
  bool _isMenuOpen = false;
  String _recognizedText = '';
  String _transcript = '';
  String _chatId = '';
  String _conversationId = '';
  double _bottomContainerHeight = 0;
  OverlayEntry? _overlayEntry;
  late FirebaseApp _firebaseApp;

  @override
  void initState() {
    super.initState();
    _firebaseApp = Firebase.app();
    _chatId = DateTime.now().millisecondsSinceEpoch.toString();
    _conversationId = 'conv_$_chatId';
    print('Yeni sohbet başlatıldı, chatId: $_chatId');
    _initSpeech();
    _loadChatHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderBox? bottomContainer =
          _bottomContainerKey.currentContext?.findRenderObject() as RenderBox?;
      if (bottomContainer != null) {
        setState(() {
          _bottomContainerHeight = bottomContainer.size.height;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _textFieldFocusNode.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    var permissionStatus = await Permission.microphone.request();
    if (permissionStatus != PermissionStatus.granted) {
      print('Mikrofon izni reddedildi.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mikrofon izni gereklidir.')),
      );
      return;
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status');
        setState(() => _isListening = status == 'listening');
      },
      onError: (error) {
        print('Speech error: $error');
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Konuşma tanıma hatası: ${error.errorMsg}')),
        );
      },
    );

    if (!available) {
      print('Mikrofon başlatılamadı.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mikrofon başlatılamadı.')),
      );
    } else {
      print('Mikrofon başarıyla başlatıldı.');
    }
  }

  Future<void> _loadChatHistory() async {
    print('Firebase Authentication kontrol ediliyor...');
    User? user = FirebaseAuth.instance.currentUser;
    print('FirebaseApp is null: ${_firebaseApp == null}');
    print('User is null: ${user == null}');
    if (_firebaseApp == null) {
      throw Exception('FirebaseApp is not initialized');
    }
    if (user == null) {
      print('Kullanıcı yok, anonim giriş deneniyor...');
      try {
        UserCredential userCredential =
            await FirebaseAuth.instance.signInAnonymously();
        user = userCredential.user;
        print('Anonim giriş başarılı: ${user?.uid}');
      } catch (e) {
        print('Anonim giriş hatası: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Giriş yapılamadı: $e')),
        );
        return;
      }
    }
    try {
      final testDoc = await FirebaseFirestore.instanceFor(app: _firebaseApp)
          .collection('test')
          .doc('test')
          .get();
      print('Firestore connection successful: ${testDoc.exists}');
    } catch (e) {
      print('Firestore connection error: $e');
    }

    int retries = 3;
    while (retries > 0) {
      try {
        print('Firestore’dan sohbet geçmişi yükleniyor...');
        final chatDocs = await FirebaseFirestore.instanceFor(app: _firebaseApp!)
            .collection('users')
            .doc(user!.uid)
            .collection('chats')
            .orderBy('timestamp', descending: true)
            .get();

        setState(() {
          _chatHistory = chatDocs.docs.map((doc) {
            final data = doc.data();
            data['chatId'] = doc.id;
            return data;
          }).toList();
          print('Sohbet geçmişi yüklendi: $_chatHistory');
        });
        return;
      } catch (e) {
        print('Firestore hatası, yeniden deneniyor ($retries)...: $e');
        retries--;
        if (retries == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Firestore hatası: $e')),
          );
        }
        await Future.delayed(Duration(seconds: 2));
      }
    }
  }

  Future<void> _loadChatMessages(int index) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        user = FirebaseAuth.instance.currentUser;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Giriş yapılamadı: $e')),
        );
        return;
      }
    }

    if (user != null) {
      final chatId = _chatHistory[index]['chatId'];
      final conversationId = _chatHistory[index]['conversationId'];
      print('Yüklenen chatId: $chatId, conversationId: $conversationId');

      final messageDocs =
          await FirebaseFirestore.instanceFor(app: _firebaseApp!)
              .collection('users')
              .doc(user.uid)
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .orderBy('timestamp')
              .get();

      print('Yüklenen mesaj sayısı: ${messageDocs.docs.length}');
      setState(() {
        _messages.clear();
        _chatId = chatId;
        _conversationId = conversationId ?? '';
        _messages.addAll(messageDocs.docs.map((doc) => doc.data()).toList());
        print('Mesajlar: $_messages');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      });
    }
  }

  Future<String> _uploadFileToStorage(PlatformFile file) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated.');
      }

      final storageRef = firebase_storage.FirebaseStorage.instance
          .ref()
          .child('users/${user.uid}/files/${file.name}');
      
      final uploadTask = file.bytes != null
          ? storageRef.putData(file.bytes!)
          : storageRef.putFile(File(file.path!));

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('File uploaded to Firebase Storage: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading file to Firebase Storage: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<void> _sendMessage(String text,
      {bool fromFile = false, Map<String, dynamic>? fileData}) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await FirebaseAuth.instance.signInAnonymously();
        user = FirebaseAuth.instance.currentUser;
      }

      if (user == null) {
        throw Exception('Kullanıcı giriş yapamadı.');
      }

      if (!fromFile) {
        setState(() {
          _messages.add({
            'text': text,
            'isUser': true,
            'timestamp': DateTime.now().toIso8601String(),
          });
          print('Kullanıcı mesajı eklendi: $text');
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('chats')
            .doc(_chatId)
            .set({
          'chatId': _chatId,
          'conversationId': _conversationId,
          'title': _messages.isNotEmpty ? _messages[0]['text'] : 'Yeni Sohbet',
          'timestamp': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('chats')
            .doc(_chatId)
            .collection('messages')
            .add({
          'text': text,
          'isUser': true,
          'timestamp': FieldValue.serverTimestamp(),
        });

        _controller.clear();

        final aiResponse = await sendToVertexAI(
          _messages,
          userId: user.uid,
        );

        setState(() {
          _messages.add({
            'text': aiResponse,
            'isUser': false,
            'timestamp': DateTime.now().toIso8601String(),
          });
          print('AI yanıtı eklendi: $aiResponse');
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('chats')
            .doc(_chatId)
            .collection('messages')
            .add({
          'text': aiResponse,
          'isUser': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        if (fileData != null) {
          print('Dosya gönderiliyor: ${fileData['fileName']}');
          
          // Upload the file to Firebase Storage
          final fileUrl = await _uploadFileToStorage(PlatformFile(
            name: fileData['fileName'],
            bytes: fileData['fileBytes'],
            path: fileData['filePath'],
            size: fileData['fileBytes']?.length ?? 0,
          ));

          // Send the file content to Vertex AI
          final aiResponse = await sendToVertexAI(
            _messages,
            userId: user.uid,
            fileData: {
              'fileType': fileData['fileType'],
              'fileContent': fileData['fileContent'],
              'fileName': fileData['fileName'],
            },
          );

          // Update messages with the file URL instead of file content
          setState(() {
            _messages.add({
              'fileType': fileData['fileType'],
              'fileUrl': fileUrl,
              'fileName': fileData['fileName'],
              'isUser': true,
              'timestamp': DateTime.now().toIso8601String(),
            });
            _messages.add({
              'text': aiResponse,
              'isUser': false,
              'timestamp': DateTime.now().toIso8601String(),
            });
            print('AI yanıtı eklendi (dosya): $aiResponse');
          });

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('chats')
              .doc(_chatId)
              .set({
            'chatId': _chatId,
            'conversationId': _conversationId,
            'title': _messages.isNotEmpty ? _messages[0]['text'] : 'Yeni Sohbet',
            'timestamp': FieldValue.serverTimestamp(),
          });

          // Save file metadata (URL) to Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('chats')
              .doc(_chatId)
              .collection('messages')
              .add({
            'fileType': fileData['fileType'],
            'fileUrl': fileUrl,
            'fileName': fileData['fileName'],
            'isUser': true,
            'timestamp': FieldValue.serverTimestamp(),
          });

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('chats')
              .doc(_chatId)
              .collection('messages')
              .add({
            'text': aiResponse,
            'isUser': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        } else {
          print('fileData null, mesaj eklenmedi.');
        }
      }

      print('Mesajlar listesi: $_messages');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });

      await _loadChatHistory();
    } catch (e) {
      print('Send message error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj gönderilemedi: $e')),
      );
    }
  }

  Future<void> _pickFile() async {
    if (_isLoading) {
      setState(() {
        _isLoading = false;
      });
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'txt', 'pdf'],
    );
    if (result != null) {
      PlatformFile file = result.files.first;
      String fileName = file.name;
      String? fileType;
      String? base64Content;
      Uint8List? fileBytes;
      String? filePath;

      String extension = file.extension?.toLowerCase() ?? '';

      if (extension == 'png' || extension == 'jpg' || extension == 'jpeg') {
        fileType = 'image/$extension';
      } else if (extension == 'txt') {
        fileType = 'text/plain';
      } else if (extension == 'pdf') {
        fileType = 'application/pdf';
      }

      if (fileType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Desteklenmeyen dosya formatı: $extension')),
        );
        return;
      }

      if (file.size > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dosya boyutu 5 MB’tan büyük olamaz.')),
        );
        return;
      }

      try {
        if (file.bytes != null) {
          fileBytes = file.bytes!;
          base64Content = base64Encode(fileBytes);
        } else if (file.path != null) {
          filePath = file.path!;
          final fileContent = await File(filePath).readAsBytes();
          fileBytes = fileContent;
          base64Content = base64Encode(fileContent);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Dosya içeriği okunamadı: Dosya erişimi sağlanamadı.',
              ),
            ),
          );
          return;
        }
      } catch (e) {
        print('Dosya okuma hatası: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dosya içeriği okunamadı: $e')),
        );
        return;
      }

      if (fileType != null && base64Content != null) {
        Map<String, dynamic> fileData = {
          'fileType': fileType,
          'fileContent': base64Content,
          'fileName': fileName,
          'fileBytes': fileBytes,
          'filePath': filePath,
          'isUser': true,
          'timestamp': FieldValue.serverTimestamp(),
        };

        _hideOverlayMenu();
        await _sendMessage('', fromFile: true, fileData: fileData);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dosya okunamadı veya desteklenmeyen format.'),
          ),
        );
      }
    }
  }

  void _toggleRecording() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          print('Speech status: $status');
          setState(() => _isListening = status == 'listening');
        },
        onError: (error) {
          print('Speech error: $error');
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Konuşma tanıma hatası: ${error.errorMsg}')),
          );
        },
      );

      if (available) {
        setState(() => _isListening = true);
        await _speech.listen(
          onResult: (result) {
            setState(() {
              _transcript = result.recognizedWords;
              _controller.text = _transcript;
              if (result.finalResult && _transcript.isNotEmpty) {
                _messages.add({
                  'text': _transcript,
                  'isUser': true,
                  'timestamp': FieldValue.serverTimestamp(),
                });
                _sendMessage(_transcript);
                _controller.clear();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                });
              }
            });
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          localeId: 'tr_TR',
          partialResults: true,
        );
      } else {
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Konuşma tanıma başlatılamadı.')),
        );
      }
    } else {
      setState(() => _isListening = false);
      await _speech.stop();
      if (_transcript.isNotEmpty) {
        _messages.add({
          'text': _transcript,
          'isUser': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
        _sendMessage(_transcript);
        _controller.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    }
  }

  void _startVoiceConversation() {
    setState(() {
      _messages.add({
        'text': 'Sesli konuşma modu başlatıldı!',
        'isUser': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    });
  }

  void _showOverlayMenu(BuildContext context) async {
    var storageStatus = await Permission.storage.request();
    if (storageStatus != PermissionStatus.granted) {
      storageStatus = await Permission.photos.request();
    }

    if (storageStatus != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Depolama izni verilmedi. Dosya yükleme yapılamaz.'),
          action: SnackBarAction(
            label: 'Tekrar Dene',
            onPressed: () {
              _showOverlayMenu(context);
            },
          ),
        ),
      );
      setState(() {
        _isMenuOpen = false;
      });
      return;
    }

    final RenderBox? addButtonBox =
        _addButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (addButtonBox == null) return;

    final Offset addButtonPosition = addButtonBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: _hideOverlayMenu,
            child: Container(
              color: Colors.transparent,
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
            ),
          ),
          Positioned(
            left: addButtonPosition.dx,
            top: addButtonPosition.dy - 60,
            child: Material(
              color: const Color(0xFF06101E),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 200,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        _hideOverlayMenu();
                        _pickFile();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 16.0,
                        ),
                        child: const Text(
                          'Cihazdan karşıya yükleme',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isMenuOpen = true;
    });
  }

  void _hideOverlayMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isMenuOpen = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_textFieldFocusNode.hasFocus) {
        FocusScope.of(context).requestFocus(_textFieldFocusNode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const double appBarHeight = kToolbarHeight;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double availableHeight =
        screenHeight - statusBarHeight - appBarHeight - _bottomContainerHeight;
    final double logoTopPosition = (availableHeight - 200) / 2;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF060F1D),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(2.0),
                child: Image.asset(
                  'assets/logo.png',
                  height: 30,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Text(
                      'Logo yüklenemedi!',
                      style: TextStyle(color: Colors.red),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text('', style: TextStyle(color: Colors.white)),
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            Builder(
              builder: (BuildContext context) {
                return IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: () {
                    Scaffold.of(context).openEndDrawer();
                  },
                );
              },
            ),
          ],
        ),
        endDrawer: Drawer(
          width: MediaQuery.of(context).size.width * 0.5,
          backgroundColor: const Color(0xFF06101E),
          child: Column(
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Color(0xFF0A192F)),
                child: Center(
                  child: Text(
                    'Sohbet Geçmişi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _chatHistory.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(
                        _chatHistory[index]['title'] ?? 'Sohbet ${index + 1}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _loadChatMessages(index);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Açılıyor: ${_chatHistory[index]['title']}',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              color: const Color(0xFF0A192F),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: logoTopPosition,
              child: Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/logo.png'),
                      fit: BoxFit.contain,
                      onError: null,
                    ),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message['isUser'] as bool;
                      final fileType = message['fileType'] as String?;
                      final fileUrl = message['fileUrl'] as String?;
                      final fileName = message['fileName'] as String?;
                      final fileContent = message['fileContent'] as String?;

                      if (fileType != null && fileUrl != null) {
                        if (fileType.startsWith('image/')) {
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              child: Card(
                                color: isUser ? Colors.white : Colors.white,
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Image.network(
                                        fileUrl,
                                        width: 200,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return const Text(
                                            'Resim yüklenemedi!',
                                            style: TextStyle(color: Colors.red),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        fileName ?? 'Dosya',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        } else {
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              child: Card(
                                color: isUser ? Colors.white : Colors.white,
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Dosya yüklendi:',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        fileName ?? 'Dosya',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      } else if (fileType != null && fileContent != null) {
                        // Fallback for existing messages with fileContent
                        if (fileType.startsWith('image/')) {
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              child: Card(
                                color: isUser ? Colors.white : Colors.white,
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Image.memory(
                                        base64Decode(fileContent),
                                        width: 200,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return const Text(
                                            'Resim yüklenemedi!',
                                            style: TextStyle(color: Colors.red),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        fileName ?? 'Dosya',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      }

                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Card(
                            color: isUser ? Colors.white : Colors.white,
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: MarkdownBody(
                                data: message['text'] as String,
                                styleSheet: MarkdownStyleSheet.fromTheme(
                                  Theme.of(context),
                                ).copyWith(
                                  p: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  strong: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                  listBullet: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                Container(
                  key: _bottomContainerKey,
                  padding: const EdgeInsets.all(16.0),
                  color: const Color(0xFF0A192F),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isMenuOpen = !_isMenuOpen;
                          });
                          if (_isMenuOpen) {
                            _showOverlayMenu(context);
                          } else {
                            _hideOverlayMenu();
                          }
                        },
                        child: Container(
                          key: _addButtonKey,
                          padding: const EdgeInsets.all(12.0),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                        ),
                        onPressed: _toggleRecording,
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up, color: Colors.white),
                        onPressed: _startVoiceConversation,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: TextField(
                            controller: _controller,
                            focusNode: _textFieldFocusNode,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Mesajınızı girin',
                              labelStyle: TextStyle(color: Colors.white),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white,
                                  width: 2.0,
                                ),
                              ),
                            ),
                            onSubmitted: (text) => _sendMessage(text),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _isLoading
                            ? null
                            : () => _sendMessage(_controller.text),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  String? userName;
  String? userEmail;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        userName =
            doc.get('firstName') ?? AppLocalizations.of(context)!.defaultUser;
        userEmail =
            doc.get('email') ?? AppLocalizations.of(context)!.defaultUser;
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AuthScreen(
          isLogin: true,
          onLocaleChange: (Locale p1) {},
        ),
      ),
    );
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        final tween = Tween(begin: begin, end: end);
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );

        return SlideTransition(
          position: tween.animate(curvedAnimation),
          child: child,
        );
      },
      transitionDuration:
          Duration(milliseconds: 750), // Animasyon süresini uzatın
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(top: 70),
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 30),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.person, color: Colors.black, size: 32),
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName ?? AppLocalizations.of(context)!.loading,
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        FittedBox(
                          child: Text(
                            userEmail ?? AppLocalizations.of(context)!.loading,
                            style: GoogleFonts.poppins(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.only(left: 45, right: 16),
                leading: Icon(Icons.person, color: Colors.black),
                title: Text(
                  AppLocalizations.of(context)!.account,
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    _createRoute(AccountPage()),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.only(left: 45, right: 16),
                leading: Icon(Icons.settings, color: Colors.black),
                title: Text(
                  AppLocalizations.of(context)!.settings,
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    _createRoute(SettingsPage()),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.only(left: 45, right: 16, top: 30),
                leading: Icon(Icons.help, color: Colors.black),
                title: Text(
                  AppLocalizations.of(context)!.help,
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    _createRoute(HelpPage()),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.only(left: 45, right: 16),
                leading: Icon(Icons.question_answer, color: Colors.black),
                title: Text(
                  AppLocalizations.of(context)!.faq,
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    _createRoute(FAQPage()),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.only(left: 45, right: 16),
                leading: Icon(Icons.bug_report, color: Colors.black),
                title: Text(
                  AppLocalizations.of(context)!.reportBug,
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    _createRoute(TestPage(onLocaleChange: (Locale ) {  },)),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.only(left: 45, right: 16),
                leading: Icon(Icons.logout, color: Colors.black),
                title: Text(
                  AppLocalizations.of(context)!.logout,
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: _logout,
              ),
            ],
          ),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.black, size: 28),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MainMenuPage(
                      onLocaleChange: (Locale p1) {},
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.arrow_back, color: Colors.black, size: 40),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                  SizedBox(width: 16),
                  Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(Icons.person, color: Colors.black, size: 40),
                  ),
                  SizedBox(width: 16),
                  userId == null
                      ? Text(
                          'User not logged in.\nPlease sign in to view details.',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Text(
                                'Error: ${snapshot.error}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }
                            if (!snapshot.hasData ||
                                snapshot.data?.data() == null) {
                              return Text(
                                'User data not found.\nAdd user data to Firestore:\nCollection: users\nDocument ID: $userId\nFields: firstName, lastName, email, phone',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }
                            var data =
                                snapshot.data!.data() as Map<String, dynamic>;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      data['firstName'] ?? 'N/A',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      data['lastName'] ?? 'N/A',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  data['email'] ?? 'N/A',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  data['phone'] ?? 'N/A',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ],
              ),
              SizedBox(height: 50),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ChangePasswordPage()),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock, color: Colors.black, size: 25),
                        SizedBox(width: 8),
                        Text(
                          'Change Password',
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => SubscriptionsPage()),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.credit_card, color: Colors.black, size: 25),
                        SizedBox(width: 8),
                        Text(
                          'Subscriptions',
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => LegalInformationPage()),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.gavel, color: Colors.black, size: 25),
                        SizedBox(width: 8),
                        Text(
                          'Legal Information',
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChangePasswordPage extends StatefulWidget {
  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _auth = FirebaseAuth.instance;

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen Boş Alanları Doldurunuz')),
      );
      return;
    }

    if (_currentPasswordController.text == _newPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yeni şifre mevcut şifre ile aynı olamaz')),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yeni şifreler eşleşmiyor')),
      );
      return;
    }

    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: _auth.currentUser!.email!,
        password: _currentPasswordController.text,
      );
      await _auth.currentUser!.reauthenticateWithCredential(credential);
      await _auth.currentUser!.updatePassword(_newPasswordController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Şifre başarıyla değiştirildi')),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Mevcut şifre yanlış. Lütfen doğru şifreyi girin')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: ${e.toString()}')),
      );
    }
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        final tween = Tween(begin: begin, end: end);
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );

        return SlideTransition(
          position: tween.animate(curvedAnimation),
          child: child,
        );
      },
      transitionDuration:
          Duration(milliseconds: 750), // Animasyon süresini uzatın
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 25),
            Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    size: 24,
                    color: Colors.black,
                    weight: 700,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                Text(
                  'Change Password',
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _currentPasswordController,
              decoration: InputDecoration(
                labelText: 'Mevcut Şifre',
                labelStyle: GoogleFonts.poppins(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              obscureText: true,
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextField(
              controller: _newPasswordController,
              decoration: InputDecoration(
                labelText: 'Yeni Şifre',
                labelStyle: GoogleFonts.poppins(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              obscureText: true,
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Yeni Şifreyi Onayla',
                labelStyle: GoogleFonts.poppins(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              obscureText: true,
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _changePassword,
              child: Text(
                'Şifreyi Değiştir',
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubscriptionsPage extends StatelessWidget {
  const SubscriptionsPage({super.key});

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        final tween = Tween(begin: begin, end: end);
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );

        return SlideTransition(
          position: tween.animate(curvedAnimation),
          child: child,
        );
      },
      transitionDuration:
          Duration(milliseconds: 750), // Animasyon süresini uzatın
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Subscriptions'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Manage Your Subscriptions',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            ListTile(
              title: Text('Premium Plan'),
              subtitle: Text('Active until: 2025-12-31'),
              trailing: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Subscription management requested')),
                  );
                },
                child: Text('Manage'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LegalInformationPage extends StatelessWidget {
  const LegalInformationPage({super.key});

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        final tween = Tween(begin: begin, end: end);
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );

        return SlideTransition(
          position: tween.animate(curvedAnimation),
          child: child,
        );
      },
      transitionDuration:
          Duration(milliseconds: 750), // Animasyon süresini uzatın
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Legal Information'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Legal Information',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'Terms of Service',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Read our terms of service here...',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            SizedBox(height: 20),
            Text(
              'Privacy Policy',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Read our privacy policy here...',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 30.0, left: 16.0),
            child: Row(
              children: [
                IconButton(
                  icon:
                      Icon(Icons.arrow_back, color: Colors.black, weight: 900),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                Text(
                  'Settings',
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20, left: 30.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => NotificationsSettingsPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  elevation: 0,
                ),
                icon: Icon(Icons.notifications, color: Colors.black, size: 25),
                label: Text(
                  'Notifications',
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => LanguagePage(
                              onLocaleChange: (Locale) {},
                            )),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  elevation: 0,
                ),
                icon: Icon(Icons.language, color: Colors.black, size: 25),
                label: Text(
                  'Language',
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PermissionsPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  elevation: 0,
                ),
                icon: Icon(Icons.lock, color: Colors.black, size: 25),
                label: Text(
                  'Permissions',
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  _NotificationsSettingsPageState createState() =>
      _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    // Simulate checking notification status
    await Future.delayed(Duration(seconds: 1));
    setState(() {
      _notificationsEnabled = true; // Simulated status
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });

    if (value) {
      // Simulate requesting permission
      await Future.delayed(Duration(seconds: 1));
    } else {
      // Simulate disabling notifications
      await Future.delayed(Duration(seconds: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set background color to white
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
                height: 20), // Add space at the top to move the content down
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.black, size: 32),
                  onPressed: () {
                    Navigator.pop(context); // Navigate back to SettingsPage
                  },
                ),
                const SizedBox(width: 8), // Space between the icon and the text
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 24, // Increased font size
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20), // Add space between header and content
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Push Notifications',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
                Switch(
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                  activeColor: Colors.black, // Set the active color to black
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LanguagePage extends StatefulWidget {
  final Function(Locale) onLocaleChange;
  const LanguagePage({super.key, required this.onLocaleChange});

  @override
  _LanguagePageState createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  final Map<String, Map<String, dynamic>> _languages = {
    'en': {
      'name': 'English',
      'flag': 'assets/uk_flag.png',
      'locale': const Locale('en')
    },
    'tr': {
      'name': 'Türkçe',
      'flag': 'assets/tr_flag.png',
      'locale': const Locale('tr')
    },
    'de': {
      'name': 'Deutsch',
      'flag': 'assets/de_flag.png',
      'locale': const Locale('de')
    },
    'es': {
      'name': 'Español',
      'flag': 'assets/es_flag.png',
      'locale': const Locale('es')
    },
    'fr': {
      'name': 'Français',
      'flag': 'assets/fr_flag.png',
      'locale': const Locale('fr')
    },
    'it': {
      'name': 'Italiano',
      'flag': 'assets/it_flag.png',
      'locale': const Locale('it')
    },
    'ja': {
      'name': '日本語',
      'flag': 'assets/jp_flag.png',
      'locale': const Locale('ja')
    },
    'pt': {
      'name': 'Português',
      'flag': 'assets/pt_flag.png',
      'locale': const Locale('pt')
    },
    'ru': {
      'name': 'Русский',
      'flag': 'assets/ru_flag.png',
      'locale': const Locale('ru')
    },
    'zh': {
      'name': '中文',
      'flag': 'assets/zh_flag.png',
      'locale': const Locale('zh')
    },
  };

  String _selectedLanguage = 'en';

  Widget buildLanguageSelector() {
    return ListView.builder(
      itemCount: _languages.length,
      itemBuilder: (context, index) {
        String key = _languages.keys.elementAt(index);
        String flagPath = _languages[key]!['flag'];
        String languageName = _languages[key]!['name'];

        return ListTile(
          leading: Image.asset(flagPath, width: 32, height: 32),
          title: Text(languageName),
          trailing: _selectedLanguage == key ? const Icon(Icons.check) : null,
          onTap: () {
            setState(() {
              _selectedLanguage = key;
            });
            widget.onLocaleChange(_languages[key]!['locale']);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.selectLanguage),
      ),
      body: buildLanguageSelector(),
    );
  }
}

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  _PermissionsPageState createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  Map<Permission, PermissionStatus> _permissionStatus = {
    Permission.storage: PermissionStatus.denied,
    Permission.location: PermissionStatus.denied,
    Permission.microphone: PermissionStatus.denied,
  };

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Simulate checking permissions
    await Future.delayed(Duration(seconds: 1));
    setState(() {
      _permissionStatus = {
        Permission.storage: PermissionStatus.granted,
        Permission.location: PermissionStatus.granted,
        Permission.microphone: PermissionStatus.granted,
      };
    });
  }

  Future<void> _togglePermission(Permission permission) async {
    // Simulate toggling permission
    await Future.delayed(Duration(seconds: 1));
    setState(() {
      _permissionStatus[permission] =
          _permissionStatus[permission] == PermissionStatus.granted
              ? PermissionStatus.denied
              : PermissionStatus.granted;
    });
  }

  String _getStatusText(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.denied:
        return 'İzin verilmedi';
      case PermissionStatus.granted:
        return 'İzin verildi';
      case PermissionStatus.limited:
        return 'Sınırlı izin';
      case PermissionStatus.restricted:
        return 'Kısıtlanmış';
      case PermissionStatus.permanentlyDenied:
        return 'Kalıcı olarak reddedildi';
      default:
        return 'Bilinmeyen durum';
    }
  }

  Color _getStatusColor(PermissionStatus status) {
    if (status == PermissionStatus.granted) {
      return Colors.green;
    } else if (status == PermissionStatus.denied) {
      return Colors.red;
    } else {
      return Colors.orange;
    }
  }

  IconData _getPermissionIcon(Permission permission) {
    switch (permission) {
      case Permission.storage:
        return Icons.photo_library;
      case Permission.location:
        return Icons.location_on;
      case Permission.microphone:
        return Icons.mic;
      default:
        return Icons.help_outline; // Default icon for unknown permissions
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
                height: 20), // Add space at the top to move the content down
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.black, size: 32),
                  onPressed: () {
                    Navigator.pop(context); // Navigate back to SettingsPage
                  },
                ),
                const SizedBox(width: 8), // Space between the icon and the text
                const Text(
                  'İzinler',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 24, // Increased font size
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20), // Add space between header and content
            _buildPermissionToggle(
              'Galeri    ',
              Permission.storage,
              _permissionStatus[Permission.storage] ?? PermissionStatus.denied,
            ),
            const SizedBox(height: 24),
            _buildPermissionToggle(
              'Konum   ',
              Permission.location,
              _permissionStatus[Permission.location] ?? PermissionStatus.denied,
            ),
            const SizedBox(height: 24),
            _buildPermissionToggle(
              'Mikrofon',
              Permission.microphone,
              _permissionStatus[Permission.microphone] ??
                  PermissionStatus.denied,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionToggle(
    String title,
    Permission permission,
    PermissionStatus status,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        Icon(
          _getPermissionIcon(permission),
          color: Colors.black,
          size: 28,
        ),
        Switch(
          value: status == PermissionStatus.granted,
          onChanged: (value) => _togglePermission(permission),
          activeColor: Colors.green,
          inactiveThumbColor: Colors.red,
          inactiveTrackColor: Colors.grey,
        ),
        Text(
          _getStatusText(status),
          style: TextStyle(
            color: _getStatusColor(status),
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Help', style: GoogleFonts.poppins())),
      body: Center(child: Text('Help Center', style: GoogleFonts.poppins())),
    );
  }
}

class FAQPage extends StatefulWidget {
  const FAQPage({super.key});

  @override
  _FAQPageState createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  String? selectedButton;

  void _toggleContainer(String buttonName) {
    setState(() {
      selectedButton = selectedButton == buttonName ? null : buttonName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'FAQ',
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAccordionButton('What is Touristiy?', Icons.info,
                      'Touristiy is an AI-powered travel assistant that personalizes your trips based on your interests, budget, and travel style. It provides customized itineraries, local recommendations, and real-time insights to enhance your travel experience.'),
                  SizedBox(height: 13), // Added spacing
                  _buildAccordionButton('How does Touristiy work?', Icons.work,
                      'Touristiy uses advanced AI algorithms to analyze your preferences and travel data. It then generates personalized travel plans and recommendations tailored to your needs.'),
                  SizedBox(height: 13), // Added spacing
                  _buildAccordionButton(
                      'Is Touristiy available worldwide?',
                      Icons.public,
                      'Yes, Touristiy is designed to work globally, offering travel assistance and recommendations for destinations around the world.'),
                  SizedBox(height: 13), // Added spacing
                  _buildAccordionButton(
                      'How does Touristiy’s AI personalize my experience?',
                      Icons.psychology,
                      'Touristiy’s AI learns from your travel history, preferences, and real-time data to provide personalized recommendations and insights.'),
                  SizedBox(height: 13), // Added spacing
                  _buildAccordionButton(
                      'Will Touristiy suggest activities based on real-time events?',
                      Icons.event,
                      'Yes, Touristiy can suggest activities based on real-time events happening at your destination, ensuring you never miss out on exciting experiences.'),
                  SizedBox(height: 13), // Added spacing
                  _buildAccordionButton(
                      'Is my personal data safe with Touristiy?',
                      Icons.security,
                      'Yes, Touristiy prioritizes your privacy and uses advanced security measures to protect your personal data.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccordionButton(String text, IconData icon, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: () => _toggleContainer(text),
          icon: Icon(icon, color: Colors.black),
          label: Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            elevation: 2,
            alignment: Alignment.centerLeft,
          ),
        ),
        AnimatedCrossFade(
          firstChild: SizedBox.shrink(),
          secondChild: Container(
            padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            width: double.infinity,
            color: Colors.grey[200],
            child: Text(
              content,
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          crossFadeState: selectedButton == text
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: Duration(milliseconds: 350),
        ),
      ],
    );
  }
}

class ReportBugPage extends StatefulWidget {
  const ReportBugPage({super.key});

  @override
  _ReportBugPageState createState() => _ReportBugPageState();
}

class _ReportBugPageState extends State<ReportBugPage> {
  final TextEditingController _headerController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  String _errorMessage = '';

  void _submitReport() async {
    if (_headerController.text.isEmpty || _subjectController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen boş alanları doldurun';
      });
      return;
    }

    setState(() {
      _errorMessage = '';
    });

    try {
      await FirebaseFirestore.instance.collection('Reports').doc().set({
        'Header': _headerController.text,
        'Subject': _subjectController.text,
        'Timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rapor gönderildi')),
      );
      _headerController.clear();
      _subjectController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Report A Bug',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            Text(
              'Konu Başlığı',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _headerController,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              decoration: InputDecoration(
                hintText: 'Konu Başlığı Girin.',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey,
                ),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Hata Konusu',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _subjectController,
              maxLines: 10,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              decoration: InputDecoration(
                hintText: 'Hata Konusu Girin.',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey,
                ),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Gönder',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
