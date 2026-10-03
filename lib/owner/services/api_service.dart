import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Pass --dart-define=API_BASE_URL=http://<pc-lan-ip>:5000/api when testing
  // on a real phone, or your Render https URL once deployed.
  // ════════════════════════════════════════════════════════════════
  //  >>> SET YOUR BACKEND URL HERE before building the release APK <<<
  //  Must END WITH /api, e.g.  https://lexnland-backend.onrender.com/api
  //  Leave localhost for your own emulator/web testing.
  //  You can also override without editing:
  //    flutter build apk --release --dart-define=API_BASE_URL=https://.../api
  // ════════════════════════════════════════════════════════════════
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://owner-panel-backend.onrender.com/api',
  );
  
  /// Backend origin without the trailing "/api". Used to turn relative media
  /// paths from the server (e.g. "/uploads/photos/x.jpg") into full URLs.
  static String get mediaBase {
    var b = baseUrl;
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    if (b.endsWith('/api')) b = b.substring(0, b.length - 4);
    return b;
  }

  static Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('auth_token');
  }

  static Future<void> saveToken(String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('auth_token', token);
  }

  static Future<void> saveOwner(Map<String, dynamic> owner) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('owner_data', jsonEncode(owner));
  }

  static Future<Map<String, dynamic>?> getSavedOwner() async {
    final p = await SharedPreferences.getInstance();
    final d = p.getString('owner_data');
    if (d == null) return null;
    return jsonDecode(d);
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('auth_token');
    await p.remove('owner_data');
  }

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = {'Content-Type': 'application/json'};
    if (auth) {
      final t = await getToken();
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  static Map<String, dynamic> _handle(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body['message'] ?? 'Request failed (${res.statusCode})');
  }

  // ── AUTH ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String state = '',
    String city = '',
  }) async {
    final res = await http.post(Uri.parse('$baseUrl/auth/register'),
        headers: await _headers(auth: false),
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'state': state,
          'city': city
        }));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(Uri.parse('$baseUrl/auth/login'),
        headers: await _headers(auth: false),
        body: jsonEncode({'email': email, 'password': password}));
    final data = _handle(res);
    if (data['token'] != null) {
      await saveToken(data['token']);
      if (data['owner'] != null) await saveOwner(data['owner']);
    }
    return data;
  }

  static Future<Map<String, dynamic>> googleAuth(String idToken) async {
    final res = await http.post(Uri.parse('$baseUrl/auth/google'),
        headers: await _headers(auth: false),
        body: jsonEncode({'idToken': idToken}));
    final data = _handle(res);
    if (data['token'] != null) {
      await saveToken(data['token']);
      if (data['owner'] != null) await saveOwner(data['owner']);
    }
    return data;
  }

  /// Reports which profiles already exist for this Google account, without
  /// creating either. Returns {hasOwner, hasCustomer}.
  static Future<Map<String, dynamic>> profileStatus(String idToken) async {
    final res = await http.post(Uri.parse('$baseUrl/auth/profile-status'),
        headers: await _headers(auth: false),
        body: jsonEncode({'idToken': idToken}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> verifyEmailOTP({
    required String email,
    required String otp,
  }) async {
    final res = await http.post(Uri.parse('$baseUrl/auth/verify-email-otp'),
        headers: await _headers(auth: false),
        body: jsonEncode({'email': email, 'otp': otp}));
    final data = _handle(res);
    if (data['token'] != null) {
      await saveToken(data['token']);
      if (data['owner'] != null) await saveOwner(data['owner']);
    }
    return data;
  }

  static Future<Map<String, dynamic>> resendOTP({
    required String email,
    String type = 'verify',
  }) async {
    final res = await http.post(Uri.parse('$baseUrl/auth/resend-otp'),
        headers: await _headers(auth: false),
        body: jsonEncode({'email': email, 'type': type}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final res = await http.post(Uri.parse('$baseUrl/auth/forgot-password'),
        headers: await _headers(auth: false),
        body: jsonEncode({'email': email}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> verifyResetOTP({
    required String email,
    required String otp,
  }) async {
    final res = await http.post(Uri.parse('$baseUrl/auth/verify-reset-otp'),
        headers: await _headers(auth: false),
        body: jsonEncode({'email': email, 'otp': otp}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    final res = await http.post(Uri.parse('$baseUrl/auth/reset-password'),
        headers: await _headers(auth: false),
        body: jsonEncode({
          'email': email,
          'resetToken': resetToken,
          'newPassword': newPassword
        }));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(Uri.parse('$baseUrl/auth/me'),
        headers: await _headers());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$baseUrl/auth/profile'),
        headers: await _headers(), body: jsonEncode(data));
    final out = _handle(res);
    // Keep the cached owner in sync so the onboarding gate doesn't re-trigger
    // on the next launch (e.g. when getMe times out on a cold backend).
    if (out['owner'] != null) {
      await saveOwner(out['owner'] as Map<String, dynamic>);
    }
    return out;
  }

  static Future<List<String>> searchCities(String state, String query) async {
    if (state.isEmpty) return [];
    final uri = Uri.parse('$baseUrl/locations/cities')
        .replace(queryParameters: {'state': state, 'search': query});
    try {
      final res = await http.get(uri, headers: await _headers(auth: false));
      final data = _handle(res);
      return (data['cities'] as List? ?? []).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  // ── PROPERTIES ───────────────────────────────────────────
  static Future<Map<String, dynamic>> createProperty({
    required String propertyType,
    required String propertyName,
    required String location,
    String localLandmark = '',
    String mapLink = '',
    double? latitude,
    double? longitude,
    required Map<String, dynamic> details,
  }) async {
    final body = {
      'propertyType': propertyType,
      'propertyName': propertyName,
      'location': location,
      'localLandmark': localLandmark,
      'mapLink': mapLink,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      ...details,
    };
    final res = await http.post(Uri.parse('$baseUrl/properties'),
        headers: await _headers(), body: jsonEncode(body));
    return _handle(res);
  }

  /// Resolve a pasted Google Maps link into { latitude, longitude }.
  /// Throws with a friendly message if the link can't be read.
  static Future<Map<String, dynamic>> resolveLocation(String mapLink) async {
    final res = await http.post(
        Uri.parse('$baseUrl/properties/resolve-location'),
        headers: await _headers(),
        body: jsonEncode({'mapLink': mapLink}));
    return _handle(res);
  }

  // ✅ Update property (for edit screen)
  static Future<Map<String, dynamic>> updateProperty(
      String id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$baseUrl/properties/$id'),
        headers: await _headers(), body: jsonEncode(data));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> uploadPropertyPhotos({
    required String propertyId,
    required List<Uint8List> imageBytes,
    required List<String> fileNames,
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest(
        'POST', Uri.parse('$baseUrl/properties/$propertyId/photos'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    for (int i = 0; i < imageBytes.length; i++) {
      final name = fileNames.isNotEmpty ? fileNames[i] : 'photo_$i.jpg';
      final ext = name.split('.').last.toLowerCase();
      final mime = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
      request.files.add(http.MultipartFile.fromBytes('photos', imageBytes[i],
          filename: name, contentType: MediaType.parse(mime)));
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getMyProperties(
      {String? status, String? type}) async {
    var url = '$baseUrl/properties';
    final params = <String>[];
    if (status != null) params.add('status=$status');
    if (type != null) params.add('type=$type');
    if (params.isNotEmpty) url += '?${params.join('&')}';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getDashboardStats() async {
    final res = await http.get(Uri.parse('$baseUrl/properties/dashboard'),
        headers: await _headers());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> updatePropertyStatus(
      String id, String status) async {
    final res = await http.patch(Uri.parse('$baseUrl/properties/$id/status'),
        headers: await _headers(), body: jsonEncode({'status': status}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> deleteProperty(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/properties/$id'),
        headers: await _headers());
    return _handle(res);
  }

  // ── VISITS ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> getVisits(
      {String? category, String? status}) async {
    var url = '$baseUrl/visits';
    final params = <String>[];
    if (category != null) params.add('category=$category');
    if (status != null) params.add('status=$status');
    if (params.isNotEmpty) url += '?${params.join('&')}';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> confirmVisit(String id) async {
    final res = await http.patch(Uri.parse('$baseUrl/visits/$id/confirm'),
        headers: await _headers());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> rescheduleVisit(String id,
      {required String newDate,
      required String newTime,
      String reason = ''}) async {
    final res = await http.patch(Uri.parse('$baseUrl/visits/$id/reschedule'),
        headers: await _headers(),
        body: jsonEncode(
            {'newDate': newDate, 'newTime': newTime, 'reason': reason}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> cancelVisit(
      String id, String reason) async {
    final res = await http.patch(Uri.parse('$baseUrl/visits/$id/cancel'),
        headers: await _headers(), body: jsonEncode({'reason': reason}));
    return _handle(res);
  }

  // ── NOTIFICATIONS ────────────────────────────────────────
  static Future<Map<String, dynamic>> getNotifications() async {
    final res = await http.get(Uri.parse('$baseUrl/notifications'),
        headers: await _headers());
    return _handle(res);
  }

  static Future<void> markAllRead() async {
    await http.patch(Uri.parse('$baseUrl/notifications/read-all'),
        headers: await _headers());
  }

  static Future<void> clearNotifications() async {
    await http.delete(Uri.parse('$baseUrl/notifications/clear'),
        headers: await _headers());
  }

  // ── MESSAGES ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> getChats() async {
    final res = await http.get(Uri.parse('$baseUrl/messages'),
        headers: await _headers());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getChatMessages(String chatId) async {
    final res = await http.get(Uri.parse('$baseUrl/messages/$chatId'),
        headers: await _headers());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> sendReply(
      String chatId, String text) async {
    final res = await http.post(Uri.parse('$baseUrl/messages/$chatId/reply'),
        headers: await _headers(), body: jsonEncode({'text': text}));
    return _handle(res);
  }

  // ── DOCUMENT UPLOAD ──────────────────────────────────────
  /// Upload registry and/or NOC documents for a property.
  static Future<Map<String, dynamic>> uploadDocuments({
    required String propertyId,
    Uint8List? registryBytes,
    String? registryFileName,
    Uint8List? nocBytes,
    String? nocFileName,
    String? idType,
    Uint8List? idFrontBytes,
    String? idFrontFileName,
    Uint8List? idBackBytes,
    String? idBackFileName,
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/properties/$propertyId/documents'),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    if (registryBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'registry',
        registryBytes,
        filename: registryFileName ?? 'registry.pdf',
        contentType:
            MediaType.parse(_mimeFor(registryFileName ?? 'registry.pdf')),
      ));
    }
    if (nocBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'noc',
        nocBytes,
        filename: nocFileName ?? 'noc.pdf',
        contentType: MediaType.parse(_mimeFor(nocFileName ?? 'noc.pdf')),
      ));
    }
    if (idType != null && idType.isNotEmpty) {
      request.fields['idType'] = idType;
    }
    if (idFrontBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'idFront',
        idFrontBytes,
        filename: idFrontFileName ?? 'id_front.jpg',
        contentType:
            MediaType.parse(_mimeFor(idFrontFileName ?? 'id_front.jpg')),
      ));
    }
    if (idBackBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'idBack',
        idBackBytes,
        filename: idBackFileName ?? 'id_back.jpg',
        contentType: MediaType.parse(_mimeFor(idBackFileName ?? 'id_back.jpg')),
      ));
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  static String _mimeFor(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  // ── OWNER CHAT ────────────────────────────────────────────
  static Future<Map<String, dynamic>> getOwnerChats() async {
    final res = await http.get(Uri.parse('$baseUrl/customers/owner-chats'),
        headers: await _headers());
    return _handle(res);
  }

  static Future<int> getUnreadChatCount() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/customers/owner-chats/unread-count'),
        headers: await _headers(),
      );
      final out = _handle(res);
      return (out['count'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<Map<String, dynamic>> getOwnerChatMessages(
      String chatId) async {
    final res = await http.get(
        Uri.parse('$baseUrl/customers/owner-chats/$chatId/messages'),
        headers: await _headers());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> submitProblem(String message) async {
    final res = await http.post(Uri.parse('$baseUrl/customers/owner-support'),
        headers: await _headers(), body: jsonEncode({'message': message}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> saveOwnerDetails(
      Map<String, String> details) async {
    final res = await http.patch(Uri.parse('$baseUrl/auth/owner-details'),
        headers: await _headers(), body: jsonEncode(details));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> createPaymentLink() async {
    final res = await http.post(Uri.parse('$baseUrl/auth/payment/create-link'),
        headers: await _headers());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> paymentStatus() async {
    final res = await http.get(Uri.parse('$baseUrl/auth/payment/status'),
        headers: await _headers());
    return _handle(res);
  }

  // ── RAZORPAY STANDARD CHECKOUT (order + verify) ───────────
  /// Creates a Razorpay order for the one-time owner registration fee.
  /// Returns { orderId, amount, currency, keyId } or { alreadyPaid: true }.
  static Future<Map<String, dynamic>> createPaymentOrder() async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/payment/create-order'),
      headers: await _headers(),
    );
    return _handle(res);
  }

  /// Verifies the payment signature server-side. On success the backend
  /// marks the owner as paid. Returns { isPaid: true } when verified.
  static Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/payment/verify'),
      headers: await _headers(),
      body: jsonEncode({
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      }),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> ownerSendMessage({
    required String chatId,
    required String text,
    String? imageUrl,
    String? linkUrl,
  }) async {
    final res = await http.post(
        Uri.parse('$baseUrl/customers/owner-chats/$chatId/messages'),
        headers: await _headers(),
        body: jsonEncode({
          'text': text,
          if (imageUrl != null) 'imageUrl': imageUrl,
          if (linkUrl != null) 'linkUrl': linkUrl
        }));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> ownerPollMessages(
      String chatId, String since) async {
    final uri = Uri.parse('$baseUrl/customers/owner-chats/$chatId/poll')
        .replace(queryParameters: {'since': since});
    final res = await http.get(uri, headers: await _headers());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> confirmVisitOwner(String id,
      {String note = ''}) async {
    final res = await http.patch(Uri.parse('$baseUrl/visits/$id/confirm'),
        headers: await _headers(), body: jsonEncode({'ownerNote': note}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> cancelVisitOwner(
      String id, String reason) async {
    final res = await http.patch(Uri.parse('$baseUrl/visits/$id/cancel'),
        headers: await _headers(), body: jsonEncode({'reason': reason}));
    return _handle(res);
  }

  static Future<Map<String, dynamic>> completeVisitOwner(String id) async {
    final res = await http.patch(Uri.parse('$baseUrl/visits/$id/complete'),
        headers: await _headers());
    return _handle(res);
  }

  // ── OWNER MESSAGE ACTIONS ─────────────────────────────────
  static Future<Map<String, dynamic>> ownerUploadChatAudio({
    required String chatId,
    required List<int> bytes,
    required String fileName,
    int duration = 0,
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest(
        'POST', Uri.parse('$baseUrl/customers/owner-chats/$chatId/audio'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields['duration'] = duration.toString();
    request.files.add(http.MultipartFile.fromBytes('audio', bytes,
        filename: fileName,
        contentType: fileName.toLowerCase().endsWith('.webm')
            ? MediaType('audio', 'webm')
            : MediaType('audio', 'mp4')));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body['message'] ?? 'Voice upload failed');
  }

  static Future<Map<String, dynamic>> ownerUploadChatPhoto({
    required String chatId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest(
        'POST', Uri.parse('$baseUrl/customers/owner-chats/$chatId/upload'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    final ext =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final mime = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/jpeg';
    request.files.add(http.MultipartFile.fromBytes('photo', bytes,
        filename: fileName, contentType: MediaType.parse(mime)));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body['message'] ?? 'Upload failed');
  }

  static Future<Map<String, dynamic>> ownerEditMessage({
    required String chatId,
    required String msgId,
    required String newText,
  }) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/customers/owner-chats/$chatId/messages/$msgId'),
      headers: await _headers(),
      body: jsonEncode({'text': newText}),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> ownerDeleteMessage({
    required String chatId,
    required String msgId,
    required String scope,
  }) async {
    final req = http.Request('DELETE',
        Uri.parse('$baseUrl/customers/owner-chats/$chatId/messages/$msgId'));
    req.headers.addAll(await _headers());
    req.body = jsonEncode({'scope': scope});
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getVisitById(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/visits/$id'),
        headers: await _headers());
    return _handle(res);
  }

  static Future<Map<String, dynamic>> rescheduleVisitOwner(
    String id, {
    required String newDate,
    required String newTime,
    String reason = '',
  }) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/visits/$id/reschedule'),
      headers: await _headers(),
      body: jsonEncode(
          {'newDate': newDate, 'newTime': newTime, 'reason': reason}),
    );
    return _handle(res);
  }

  // ── Upload Aadhaar front + back (owner self-verification) ──────
  static Future<Map<String, dynamic>> uploadAadhaar({
    required Uint8List frontBytes,
    required String frontName,
    required Uint8List backBytes,
    required String backName,
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest(
        'POST', Uri.parse('$baseUrl/auth/upload-aadhaar'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    String _mime(String name) {
      final ext = name.split('.').last.toLowerCase();
      return ext == 'pdf'
          ? 'application/pdf'
          : ext == 'png'
              ? 'image/png'
              : 'image/jpeg';
    }

    request.files.add(http.MultipartFile.fromBytes(
      'aadhaarFront',
      frontBytes,
      filename: frontName,
      contentType: MediaType.parse(_mime(frontName)),
    ));
    request.files.add(http.MultipartFile.fromBytes(
      'aadhaarBack',
      backBytes,
      filename: backName,
      contentType: MediaType.parse(_mime(backName)),
    ));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _handle(res);
  }
}
