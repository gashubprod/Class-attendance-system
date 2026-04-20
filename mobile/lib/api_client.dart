import 'dart:convert';
import 'dart:io';

import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.baseUrl, this.token});

  String baseUrl;
  String? token;

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final json = await _request(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    );

    final result = LoginResult(
      token: json['token'] as String,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
    token = result.token;
    return result;
  }

  Future<AppUser> me() async {
    final json = await _request('GET', '/me');
    return AppUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<List<Course>> getCourses() async {
    final json = await _request('GET', '/courses');
    return ((json['courses'] as List<dynamic>?) ?? const [])
        .map((entry) => Course.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<SessionSummary> createSession({
    required String courseId,
    required String title,
  }) async {
    final json = await _request(
      'POST',
      '/sessions',
      body: {'courseId': courseId, 'title': title},
    );
    return SessionSummary.fromJson(json['session'] as Map<String, dynamic>);
  }

  Future<SessionSummary> startSession(String sessionId) async {
    final json = await _request('POST', '/sessions/$sessionId/start');
    return SessionSummary.fromJson(json['session'] as Map<String, dynamic>);
  }

  Future<SessionSummary> endSession(String sessionId) async {
    final json = await _request('POST', '/sessions/$sessionId/end');
    return SessionSummary.fromJson(json['session'] as Map<String, dynamic>);
  }

  Future<List<SessionSummary>> getActiveSessions() async {
    final json = await _request('GET', '/sessions/active');
    return ((json['sessions'] as List<dynamic>?) ?? const [])
        .map((entry) => SessionSummary.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<List<SessionSummary>> getSessions() async {
    final json = await _request('GET', '/sessions');
    return ((json['sessions'] as List<dynamic>?) ?? const [])
        .map((entry) => SessionSummary.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<SessionSummary> getSessionCode(String sessionId) async {
    final json = await _request('GET', '/sessions/$sessionId/code');
    return SessionSummary.fromJson(json['session'] as Map<String, dynamic>);
  }

  Future<String> checkIn({
    required String sessionId,
    required String code,
    required String ssid,
  }) async {
    final json = await _request(
      'POST',
      '/attendance/check-in',
      body: {
        'sessionId': sessionId,
        'code': code,
        'network': {'ssid': ssid},
      },
    );
    final attendance = json['attendance'] as Map<String, dynamic>;
    return attendance['status'] as String;
  }

  Future<SessionReport> getReport(String sessionId) async {
    final json = await _request('GET', '/reports/sessions/$sessionId');
    return SessionReport.fromJson(json);
  }

  Future<LectureRecord> createLecture({
    required String sessionId,
    required String transcriptText,
    String? fileName,
  }) async {
    final json = await _request(
      'POST',
      '/lectures',
      body: {
        'sessionId': sessionId,
        'transcriptText': transcriptText,
        'fileName': fileName ?? 'lecture-notes.txt',
      },
    );
    return LectureRecord.fromJson(json['lecture'] as Map<String, dynamic>);
  }

  Future<LectureRecord> uploadLectureAudio({
    required String sessionId,
    required String filePath,
    String? fileName,
  }) async {
    final client = HttpClient();
    try {
      final file = File(filePath);
      final pathSegments = file.uri.pathSegments;
      final resolvedName =
          fileName ??
          (pathSegments.isNotEmpty ? pathSegments.last : 'lecture-audio.m4a');
      final uri = Uri.parse(
        '$baseUrl/lectures/upload',
      ).replace(queryParameters: {'sessionId': sessionId});
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        _audioMimeTypeForPath(resolvedName),
      );
      request.headers.set('X-File-Name', resolvedName);
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      request.contentLength = await file.length();
      await request.addStream(file.openRead());

      final response = await request.close();
      final decoded = await _decodeJsonResponse(response);
      if (response.statusCode >= 400) {
        final error = decoded['error'] as String? ?? 'Audio upload failed';
        final details = decoded['details'];
        throw ApiException(details == null ? error : '$error ($details)');
      }

      return LectureRecord.fromJson(decoded['lecture'] as Map<String, dynamic>);
    } on SocketException {
      throw const ApiException(
        'Could not reach the backend. Check that the API server is running and the base URL is correct.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<LectureRecord> getLecture(String lectureId) async {
    final json = await _request('GET', '/lectures/$lectureId');
    return LectureRecord.fromJson(json['lecture'] as Map<String, dynamic>);
  }

  Future<void> overrideAttendance({
    required String attendanceId,
    required String status,
    String? reason,
  }) async {
    await _request(
      'PATCH',
      '/attendance/$attendanceId',
      body: {'status': status, 'reason': reason ?? ''},
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final decoded = await _decodeJsonResponse(response);

      if (response.statusCode >= 400) {
        final error = decoded['error'] as String? ?? 'Request failed';
        final details = decoded['details'];
        throw ApiException(details == null ? error : '$error ($details)');
      }

      return decoded;
    } on SocketException {
      throw const ApiException(
        'Could not reach the backend. Check that the API server is running and the base URL is correct.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _decodeJsonResponse(
    HttpClientResponse response,
  ) async {
    final payload = await response.transform(utf8.decoder).join();
    if (payload.isEmpty) {
      return <String, dynamic>{};
    }

    return jsonDecode(payload) as Map<String, dynamic>;
  }

  String _audioMimeTypeForPath(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.wav')) {
      return 'audio/wav';
    }
    if (lower.endsWith('.webm')) {
      return 'audio/webm';
    }
    if (lower.endsWith('.ogg')) {
      return 'audio/ogg';
    }
    if (lower.endsWith('.mp3')) {
      return 'audio/mpeg';
    }
    if (lower.endsWith('.aac')) {
      return 'audio/aac';
    }
    return 'audio/mp4';
  }
}
