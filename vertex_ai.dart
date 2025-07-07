import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Initialize logger
final logger = Logger(
  printer: PrettyPrinter(),
);

Future<bool> checkNetworkConnectivity() async {
  try {
    final response = await http.get(Uri.parse('https://www.google.com/'));
    return response.statusCode == 200;
  } catch (e) {
    logger.e('Network connectivity check failed: $e');
    return false;
  }
}

Future<Map<String, dynamic>> getUserPreferences(String userId) async {
  int retryCount = 0;
  const maxRetries = 5;
  final FirebaseApp app = Firebase.app();

  logger.i('getUserPreferences called, userId: $userId');

  try {
    if (Firebase.apps.isEmpty) {
      throw Exception('Firebase is not initialized.');
    }
    logger.i('Firebase app: ${app.name}');
  } catch (e) {
    logger.e('Firebase initialization error: $e');
    rethrow;
  }

  if (!(await checkNetworkConnectivity())) {
    logger.w('No network connectivity.');
    throw Exception('No network connectivity.');
  }

  while (retryCount < maxRetries) {
    try {
      logger.i('Connecting to Firestore...');
      final doc = await FirebaseFirestore.instanceFor(app: app)
          .collection('users')
          .doc(userId)
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Firestore request timed out.');
        },
      );

      if (doc.exists && doc.data() != null) {
        logger.i('User preferences retrieved: ${doc.data()}');
        return doc.data() as Map<String, dynamic>;
      } else {
        logger.w('User data not found for userId: $userId');
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'allAnswers': 'Default preferences',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        logger.i('New user data created for userId: $userId');
        return {'allAnswers': 'Default preferences'};
      }
    } catch (e) {
      logger.e('Firestore error: $e');
      if (e.toString().contains('NOT_FOUND') ||
          e.toString().contains('database')) {
        logger.w('Firestore not active, returning empty data: $e');
        return {};
      }
      if (e.toString().contains('unavailable')) {
        logger.w('Firestore service temporarily unavailable: $e');
      }

      retryCount++;
      if (retryCount >= maxRetries) {
        logger.e('Firestore connection error, retry limit exceeded: $e');
        throw Exception('Unable to connect to Firestore: $e');
      }
      logger.w('Firestore error, retrying ($retryCount/$maxRetries)...: $e');
      await Future.delayed(Duration(seconds: (2 * retryCount).toInt()));
    }
  }

  throw Exception('Failed to retrieve user preferences.');
}

Future<String> sendToVertexAI(
  List<Map<String, dynamic>> messages, {
  String? userId,
  Map<String, dynamic>? fileData,
}) async {
  const maxRetries = 3;
  int retryCount = 0;

  while (retryCount < maxRetries) {
    try {
      logger.i(
          'sendToVertexAI called, userId: $userId, attempt: ${retryCount + 1}');

      final jsonString = await rootBundle.loadString('assets/vertex-key.json');
      if (jsonString.isEmpty) {
        logger.e('Vertex AI credentials not found in assets.');
        throw Exception('Vertex AI credentials not found in assets.');
      }
      logger.i('Vertex AI credentials loaded from assets.');
      final accountCredentials =
          ServiceAccountCredentials.fromJson(jsonDecode(jsonString));
      final scopes = ['https://www.googleapis.com/auth/cloud-platform'];

      if (!(await checkNetworkConnectivity())) {
        logger.w('No network connectivity.');
        throw Exception('No network connectivity.');
      }

      late AutoRefreshingAuthClient client;
      try {
        final stopwatch = Stopwatch()..start();
        client =
            await clientViaServiceAccount(accountCredentials, scopes).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Client creation timed out.');
          },
        );
        stopwatch.stop();
        logger.i(
            'Client created: $client (Duration: ${stopwatch.elapsedMilliseconds} ms)');
      } catch (e) {
        logger.e('Client creation error: $e');
        rethrow;
      }

      final url = Uri.parse(
        'https://us-central1-aiplatform.googleapis.com/v1/projects/vast-fuze-457213-n2/locations/us-central1/publishers/google/models/gemini-2.0-flash-001:generateContent',
      );
      logger.i('URL: $url');

      Map<String, dynamic> userPreferences = {};
      if (userId != null) {
        logger.i('Retrieving user preferences...');
        userPreferences = await getUserPreferences(userId);
        logger.i('User preferences to be sent to Vertex AI: $userPreferences');
        userPreferences = Map<String, dynamic>.from(userPreferences);
        userPreferences.forEach((key, value) {
          if (value is Timestamp) {
            userPreferences[key] = value.toDate().toIso8601String();
          } else if (value is FieldValue) {
            userPreferences[key] = DateTime.now().toIso8601String();
          }
        });
      } else {
        logger.w('userId is null, preferences not retrieved.');
      }

      List<Map<String, Object>> contents = [];

      // Kullanıcı tercihlerini ekle, ama sadece bir kere ve uygun bir şekilde
      if (userPreferences.isNotEmpty &&
          userPreferences.containsKey('allAnswers') &&
          userPreferences['allAnswers'] is String) {
        logger.i('Adding preferences as context...');
        contents.add(<String, Object>{
          'role': 'user',
          'parts': <Map<String, Object>>[
            {
              'text': 'User preferences: ${userPreferences['allAnswers']}',
            },
          ],
        });
      } else {
        logger.w(
            'Preferences not added: userPreferences is empty or missing allAnswers.');
      }

      if (fileData != null) {
        logger.i('Dosya gönderiliyor: ${fileData['fileName']}');
        String fileType = fileData['fileType'] ?? 'application/octet-stream';
        String fileContent = fileData['fileContent'] ?? '';

        // Validate file content
        if (fileContent.isEmpty) {
          logger.e('File content is empty for ${fileData['fileName']}');
          throw Exception('File content is empty.');
        }

        // Estimate the size of the base64 data in bytes
        final base64Size = (fileContent.length * 3 / 4).round();
        logger.i('Base64 content size: $base64Size bytes');

        // Add a simple prompt with the image
        contents.add(<String, Object>{
          'role': 'user',
          'parts': <Map<String, Object>>[
            {
              'text': 'Describe this image.'
            },
            {
              'inlineData': {
                'mimeType': fileType,
                'data': fileContent,
              },
            },
          ],
        });
      }

      if (fileData == null) {
        contents.addAll(messages.map((message) {
          final cleanedMessage = Map<String, dynamic>.from(message);
          if (cleanedMessage.containsKey('timestamp') &&
              cleanedMessage['timestamp'] is FieldValue) {
            cleanedMessage['timestamp'] = DateTime.now().toIso8601String();
          }
          return <String, Object>{
            'role': cleanedMessage['isUser'] ? 'user' : 'model',
            'parts': <Map<String, Object>>[
              {'text': cleanedMessage['text']?.toString() ?? 'Test message'},
            ],
          };
        }).toList());
      }

      final body = jsonEncode({
        "contents": contents,
        "generationConfig": {
          "temperature": 0.7,
          "maxOutputTokens": 8192,
        },
      });

      logger.i('Vertex AI request body: $body');

      logger.i('Sending request to Vertex AI...');
      final response = await client
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Vertex AI request timed out.');
        },
      );
      logger.i('Vertex AI response status code: ${response.statusCode}');
      logger.i('Vertex AI response body: ${response.body}');

      final decoded = jsonDecode(response.body);
      logger.i('Vertex AI decoded response: $decoded');

      if (decoded['error'] != null) {
        logger.e('Vertex AI error: ${decoded['error']['message']}');
        throw Exception('Vertex AI error: ${decoded['error']['message']}');
      }

      if (decoded['candidates'] != null &&
          decoded['candidates'].isNotEmpty &&
          decoded['candidates'][0]['content'] != null &&
          decoded['candidates'][0]['content']['parts'] != null &&
          decoded['candidates'][0]['content']['parts'].isNotEmpty &&
          decoded['candidates'][0]['content']['parts'][0]['text'] != null) {
        String responseText =
            decoded['candidates'][0]['content']['parts'][0]['text'];
        logger.i('Vertex AI response text: $responseText');
        if (responseText.isEmpty) {
          logger.w('Vertex AI returned an empty response text.');
          return 'No meaningful response received from the model.';
        }
        return responseText;
      } else {
        logger.w(
            'Vertex AI response does not contain expected fields: $decoded');
        return 'No response received.';
      }
    } catch (e) {
      logger.e('Vertex AI error: $e');
      if (e.toString().contains('No network connectivity')) {
        retryCount++;
        if (retryCount >= maxRetries) {
          logger.e('Retry limit exceeded for Vertex AI request: $e');
          throw Exception(
              'Failed to connect to Vertex AI after $maxRetries attempts: $e');
        }
        logger.w('Retrying Vertex AI request ($retryCount/$maxRetries)...');
        await Future.delayed(Duration(seconds: (2 * retryCount).toInt()));
      } else {
        rethrow;
      }
    }
  }

  throw Exception('Failed to connect to Vertex AI after $maxRetries attempts.');
}