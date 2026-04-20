import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'api_client.dart';
import 'demo_content.dart';
import 'models.dart';

void main() {
  runApp(const AttendanceDemoApp());
}

String defaultBaseUrl() {
  try {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
  } catch (_) {
    // The app is scoped for mobile, but fallback to localhost for desktop tooling.
  }

  return 'http://127.0.0.1:8080';
}

class AttendanceDemoApp extends StatefulWidget {
  const AttendanceDemoApp({super.key});

  @override
  State<AttendanceDemoApp> createState() => _AttendanceDemoAppState();
}

class _AttendanceDemoAppState extends State<AttendanceDemoApp> {
  late final ApiClient _apiClient = ApiClient(baseUrl: defaultBaseUrl());
  AppUser? _user;

  Future<void> _login({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    _apiClient.baseUrl = baseUrl.trim();
    final result = await _apiClient.login(email: email, password: password);
    setState(() {
      _user = result.user;
    });
  }

  void _logout() {
    setState(() {
      _user = null;
      _apiClient.token = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RollCall Campus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9E4D1A),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3EDE3),
        cardTheme: CardThemeData(
          color: Colors.white.withValues(alpha: 0.88),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: _user == null
          ? LoginScreen(onLogin: _login)
          : _user!.isLecturer
          ? LecturerHomePage(
              apiClient: _apiClient,
              user: _user!,
              onLogout: _logout,
            )
          : StudentHomePage(
              apiClient: _apiClient,
              user: _user!,
              onLogout: _logout,
            ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin});

  final Future<void> Function({
    required String baseUrl,
    required String email,
    required String password,
  })
  onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _baseUrlController = TextEditingController(
    text: defaultBaseUrl(),
  );
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController(
    text: 'demo1234',
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.onLogin(
        baseUrl: _baseUrlController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _fillDemo(String role) {
    setState(() {
      _emailController.text = role == 'lecturer'
          ? 'lecturer@campus.local'
          : 'student1@campus.local';
      _passwordController.text = 'demo1234';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RollCall Campus',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Mobile-first attendance with short-lived session codes, campus Wi-Fi proof, and lecturer override controls.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF5A564D),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _baseUrlController,
                        decoration: const InputDecoration(
                          labelText: 'API base URL',
                          hintText: 'http://127.0.0.1:8080',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.tonal(
                            onPressed: () => _fillDemo('lecturer'),
                            child: const Text('Use Lecturer Demo'),
                          ),
                          FilledButton.tonal(
                            onPressed: () => _fillDemo('student'),
                            child: const Text('Use Student Demo'),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: Text(_busy ? 'Signing in...' : 'Sign in'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Android emulator should use 10.0.2.2. A physical phone should use your computer LAN IP instead of localhost.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6F6A62),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

abstract class DashboardPage<T extends StatefulWidget> extends State<T> {
  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class LecturerHomePage extends StatefulWidget {
  const LecturerHomePage({
    super.key,
    required this.apiClient,
    required this.user,
    required this.onLogout,
  });

  final ApiClient apiClient;
  final AppUser user;
  final VoidCallback onLogout;

  @override
  State<LecturerHomePage> createState() => _LecturerHomePageState();
}

class _LecturerHomePageState extends DashboardPage<LecturerHomePage> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final TextEditingController _titleController = TextEditingController(
    text: 'Today\'s lecture',
  );
  final Map<String, String> _recordedAudioPaths = {};
  final Map<String, TextEditingController> _transcriptControllers = {};
  final Set<String> _uploadingSessions = {};
  String? _recordingSessionId;
  Timer? _refreshTimer;
  bool _busy = true;
  String? _error;
  String? _selectedCourseId;
  List<Course> _courses = const [];
  List<SessionSummary> _sessions = const [];
  Map<String, SessionReport> _reports = const {};
  Map<String, LectureRecord> _lecturesBySession = const {};

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _loadDashboard(quiet: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _audioRecorder.dispose();
    _titleController.dispose();
    for (final controller in _transcriptControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _transcriptControllerFor(SessionSummary session) {
    return _transcriptControllers.putIfAbsent(
      session.id,
      () => TextEditingController(),
    );
  }

  Future<void> _loadDashboard({bool quiet = false}) async {
    if (!quiet && mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }

    try {
      final courses = await widget.apiClient.getCourses();
      final sessions = await widget.apiClient.getSessions();
      final reports = await Future.wait(
        sessions.map((session) async {
          final report = await widget.apiClient.getReport(session.id);
          return MapEntry(session.id, report);
        }),
      );
      final lectures = await Future.wait(
        sessions.where((session) => session.latestLectureId != null).map((
          session,
        ) async {
          final lecture = await widget.apiClient.getLecture(
            session.latestLectureId!,
          );
          return MapEntry(session.id, lecture);
        }),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _courses = courses;
        _selectedCourseId ??= courses.isNotEmpty ? courses.first.id : null;
        _sessions = sessions;
        _reports = Map<String, SessionReport>.fromEntries(reports);
        _lecturesBySession = Map<String, LectureRecord>.fromEntries(lectures);
        _busy = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
        _busy = false;
      });
    }
  }

  Future<void> _createAndStartSession() async {
    if (_selectedCourseId == null) {
      showMessage('Create a course seed first or choose a course.');
      return;
    }

    try {
      final created = await widget.apiClient.createSession(
        courseId: _selectedCourseId!,
        title: _titleController.text.trim(),
      );
      final started = await widget.apiClient.startSession(created.id);
      showMessage('Session started. Current code: ${started.code ?? '--'}');
      _transcriptControllerFor(started).text = demoTranscriptForSession(
        started.courseCode,
        started.title,
      );
      await _loadDashboard();
    } catch (error) {
      showMessage(error.toString());
    }
  }

  Future<void> _endSession(SessionSummary session) async {
    try {
      await widget.apiClient.endSession(session.id);
      showMessage('Session ended.');
      await _loadDashboard();
    } catch (error) {
      showMessage(error.toString());
    }
  }

  Future<void> _overrideAttendance(
    AttendanceRecord record,
    String status,
  ) async {
    try {
      await widget.apiClient.overrideAttendance(
        attendanceId: record.id,
        status: status,
        reason: 'Lecturer override from mobile',
      );
      showMessage('${record.studentName} marked $status.');
      await _loadDashboard(quiet: true);
    } catch (error) {
      showMessage(error.toString());
    }
  }

  void _fillDemoTranscript(SessionSummary session) {
    _transcriptControllerFor(session).text = demoTranscriptForSession(
      session.courseCode,
      session.title,
    );
  }

  bool _isRecordingSession(SessionSummary session) =>
      _recordingSessionId == session.id;

  String? _recordedAudioNameFor(SessionSummary session) {
    final filePath = _recordedAudioPaths[session.id];
    if (filePath == null || filePath.isEmpty) {
      return null;
    }

    return File(filePath).uri.pathSegments.last;
  }

  Future<void> _startAudioRecording(SessionSummary session) async {
    if (_recordingSessionId != null && _recordingSessionId != session.id) {
      showMessage(
        'Only one recording can run at a time. Stop the active recording first.',
      );
      return;
    }

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        showMessage(
          'Microphone permission is required to record lecture audio.',
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final courseSlug = session.courseCode
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      final recordingPath =
          '${directory.path}${Platform.pathSeparator}${courseSlug.isEmpty ? 'lecture' : courseSlug}-${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          numChannels: 1,
          sampleRate: 44100,
        ),
        path: recordingPath,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _recordingSessionId = session.id;
        _recordedAudioPaths.remove(session.id);
      });
      showMessage('Recording started.');
    } catch (error) {
      showMessage(error.toString());
    }
  }

  Future<void> _stopAudioRecording(SessionSummary session) async {
    if (_recordingSessionId != session.id) {
      return;
    }

    try {
      final filePath = await _audioRecorder.stop();
      if (!mounted) {
        return;
      }

      setState(() {
        _recordingSessionId = null;
        if (filePath != null && filePath.isNotEmpty) {
          _recordedAudioPaths[session.id] = filePath;
        }
      });

      if (filePath == null || filePath.isEmpty) {
        showMessage('No audio file was captured.');
        return;
      }

      showMessage('Recording saved. Upload it to start transcription.');
    } catch (error) {
      if (mounted) {
        setState(() {
          _recordingSessionId = null;
        });
      }
      showMessage(error.toString());
    }
  }

  Future<void> _generateLectureSummary(SessionSummary session) async {
    final transcript = _transcriptControllerFor(session).text.trim();
    if (transcript.isEmpty) {
      showMessage('Add transcript text or load the demo transcript first.');
      return;
    }

    setState(() {
      _uploadingSessions.add(session.id);
    });

    try {
      await widget.apiClient.createLecture(
        sessionId: session.id,
        transcriptText: transcript,
        fileName: '${session.courseCode}-${session.title}.txt',
      );
      showMessage('Lecture processing started.');
      await _loadDashboard(quiet: true);
    } catch (error) {
      showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _uploadingSessions.remove(session.id);
        });
      }
    }
  }

  Future<void> _uploadAudioLecture(SessionSummary session) async {
    final filePath = _recordedAudioPaths[session.id];
    if (filePath == null || filePath.isEmpty) {
      showMessage('Record lecture audio first.');
      return;
    }

    setState(() {
      _uploadingSessions.add(session.id);
    });

    try {
      await widget.apiClient.uploadLectureAudio(
        sessionId: session.id,
        filePath: filePath,
        fileName: _recordedAudioNameFor(session),
      );
      showMessage('Audio uploaded. Transcription and summary are running.');
      await _loadDashboard(quiet: true);
    } catch (error) {
      showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _uploadingSessions.remove(session.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSessions = _sessions
        .where((session) => session.isActive)
        .toList();
    final historySessions = _sessions
        .where((session) => session.isEnded)
        .toList();

    return DashboardScaffold(
      user: widget.user,
      title: 'Lecturer Console',
      subtitle:
          'Create sessions, manage attendance, and generate lecture summaries for the demo.',
      onRefresh: _loadDashboard,
      onLogout: widget.onLogout,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _CreateSessionCard(
            courses: _courses,
            selectedCourseId: _selectedCourseId,
            titleController: _titleController,
            onCourseChanged: (value) =>
                setState(() => _selectedCourseId = value),
            onCreatePressed: _createAndStartSession,
          ),
          const SizedBox(height: 20),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            InfoCard(title: 'Backend issue', body: _error!)
          else ...[
            const SectionHeader(
              title: 'Active Sessions',
              subtitle:
                  'Live codes, attendance reports, and audio or text lecture capture.',
            ),
            if (activeSessions.isEmpty)
              const InfoCard(
                title: 'No active sessions',
                body:
                    'Create and start a session to expose the live code and collect attendance.',
              )
            else
              ...activeSessions.map((session) {
                final report = _reports[session.id];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: LecturerSessionCard(
                    session: session,
                    report: report,
                    lecture: _lecturesBySession[session.id],
                    transcriptController: _transcriptControllerFor(session),
                    generatingLecture: _uploadingSessions.contains(session.id),
                    isRecording: _isRecordingSession(session),
                    recordedAudioName: _recordedAudioNameFor(session),
                    onFillDemoTranscript: () => _fillDemoTranscript(session),
                    onStartRecording: () => _startAudioRecording(session),
                    onStopRecording: () => _stopAudioRecording(session),
                    onUploadAudio: () => _uploadAudioLecture(session),
                    onGenerateLecture: () => _generateLectureSummary(session),
                    onEndSession: () => _endSession(session),
                    onOverrideAttendance: _overrideAttendance,
                  ),
                );
              }),
            const SizedBox(height: 8),
            const SectionHeader(
              title: 'Session History',
              subtitle: 'Ended sessions with reports and completed summaries.',
            ),
            if (historySessions.isEmpty)
              const InfoCard(
                title: 'No session history',
                body:
                    'Ended sessions will appear here together with lecture summaries.',
              )
            else
              ...historySessions.map((session) {
                final report = _reports[session.id];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: LecturerSessionCard(
                    session: session,
                    report: report,
                    lecture: _lecturesBySession[session.id],
                    transcriptController: _transcriptControllerFor(session),
                    generatingLecture: _uploadingSessions.contains(session.id),
                    isRecording: _isRecordingSession(session),
                    recordedAudioName: _recordedAudioNameFor(session),
                    onFillDemoTranscript: () => _fillDemoTranscript(session),
                    onStartRecording: () => _startAudioRecording(session),
                    onStopRecording: () => _stopAudioRecording(session),
                    onUploadAudio: () => _uploadAudioLecture(session),
                    onGenerateLecture: () => _generateLectureSummary(session),
                    onOverrideAttendance: _overrideAttendance,
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }
}

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({
    super.key,
    required this.apiClient,
    required this.user,
    required this.onLogout,
  });

  final ApiClient apiClient;
  final AppUser user;
  final VoidCallback onLogout;

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends DashboardPage<StudentHomePage> {
  final TextEditingController _ssidController = TextEditingController(
    text: 'CampusNet',
  );
  final Map<String, TextEditingController> _codeControllers = {};
  Timer? _refreshTimer;
  bool _busy = true;
  String? _error;
  List<SessionSummary> _sessions = const [];
  Map<String, LectureRecord> _lecturesBySession = const {};

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _loadDashboard(quiet: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ssidController.dispose();
    for (final controller in _codeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _codeControllerFor(String sessionId) {
    return _codeControllers.putIfAbsent(sessionId, TextEditingController.new);
  }

  Future<void> _loadDashboard({bool quiet = false}) async {
    if (!quiet && mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }

    try {
      final sessions = await widget.apiClient.getSessions();
      final lectures = await Future.wait(
        sessions.where((session) => session.latestLectureId != null).map((
          session,
        ) async {
          final lecture = await widget.apiClient.getLecture(
            session.latestLectureId!,
          );
          return MapEntry(session.id, lecture);
        }),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _sessions = sessions;
        _lecturesBySession = Map<String, LectureRecord>.fromEntries(lectures);
        _busy = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
        _busy = false;
      });
    }
  }

  Future<void> _checkIn(SessionSummary session) async {
    try {
      final status = await widget.apiClient.checkIn(
        sessionId: session.id,
        code: _codeControllerFor(session.id).text.trim(),
        ssid: _ssidController.text.trim(),
      );
      showMessage('Attendance submitted as $status.');
      await _loadDashboard();
    } catch (error) {
      showMessage(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSessions = _sessions
        .where((session) => session.isActive)
        .toList();
    final recentSessions = _sessions
        .where((session) => session.isEnded)
        .toList();

    return DashboardScaffold(
      user: widget.user,
      title: 'Student Check-in',
      subtitle:
          'Join live classes with the lecturer code, then review the lecture summary afterward.',
      onRefresh: _loadDashboard,
      onLogout: widget.onLogout,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campus Wi-Fi proof',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ssidController,
                    decoration: const InputDecoration(
                      labelText: 'Detected or expected SSID',
                      hintText: 'CampusNet',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            InfoCard(title: 'Backend issue', body: _error!)
          else ...[
            const SectionHeader(
              title: 'Ready Now',
              subtitle: 'Active sessions waiting for attendance check-in.',
            ),
            if (activeSessions.isEmpty)
              const InfoCard(
                title: 'No active sessions',
                body:
                    'Ask the lecturer to start a class session, then enter the live code here.',
              )
            else
              ...activeSessions.map(
                (session) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: StudentActiveSessionCard(
                    session: session,
                    codeController: _codeControllerFor(session.id),
                    ssid: _ssidController.text.trim(),
                    onCheckIn: () => _checkIn(session),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            const SectionHeader(
              title: 'Recent Sessions',
              subtitle: 'Attendance result plus the latest lecture summary.',
            ),
            if (recentSessions.isEmpty)
              const InfoCard(
                title: 'No recent sessions',
                body:
                    'Completed lecture summaries will appear here once a session ends.',
              )
            else
              ...recentSessions.map(
                (session) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: StudentHistorySessionCard(
                    session: session,
                    lecture: _lecturesBySession[session.id],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class DashboardScaffold extends StatelessWidget {
  const DashboardScaffold({
    super.key,
    required this.user,
    required this.title,
    required this.subtitle,
    required this.onRefresh,
    required this.onLogout,
    required this.child,
  });

  final AppUser user;
  final String title;
  final String subtitle;
  final Future<void> Function({bool quiet}) onRefresh;
  final VoidCallback onLogout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => onRefresh(quiet: false),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(onPressed: onLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Signed in as ${user.name}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5D594E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _CreateSessionCard extends StatelessWidget {
  const _CreateSessionCard({
    required this.courses,
    required this.selectedCourseId,
    required this.titleController,
    required this.onCourseChanged,
    required this.onCreatePressed,
  });

  final List<Course> courses;
  final String? selectedCourseId;
  final TextEditingController titleController;
  final ValueChanged<String?> onCourseChanged;
  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a session',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: selectedCourseId,
              items: courses
                  .map(
                    (course) => DropdownMenuItem<String>(
                      value: course.id,
                      child: Text('${course.code} - ${course.title}'),
                    ),
                  )
                  .toList(),
              onChanged: courses.isEmpty ? null : onCourseChanged,
              decoration: const InputDecoration(labelText: 'Course'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Session title'),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: courses.isEmpty ? null : onCreatePressed,
              icon: const Icon(Icons.play_circle_fill),
              label: const Text('Create & Start'),
            ),
          ],
        ),
      ),
    );
  }
}

class LecturerSessionCard extends StatelessWidget {
  const LecturerSessionCard({
    super.key,
    required this.session,
    required this.report,
    required this.lecture,
    required this.transcriptController,
    required this.generatingLecture,
    required this.isRecording,
    required this.recordedAudioName,
    required this.onFillDemoTranscript,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onUploadAudio,
    required this.onGenerateLecture,
    required this.onOverrideAttendance,
    this.onEndSession,
  });

  final SessionSummary session;
  final SessionReport? report;
  final LectureRecord? lecture;
  final TextEditingController transcriptController;
  final bool generatingLecture;
  final bool isRecording;
  final String? recordedAudioName;
  final VoidCallback onFillDemoTranscript;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onUploadAudio;
  final VoidCallback onGenerateLecture;
  final VoidCallback? onEndSession;
  final Future<void> Function(AttendanceRecord record, String status)
  onOverrideAttendance;

  @override
  Widget build(BuildContext context) {
    final countdown = session.attendanceClosesAt == null
        ? 'Attendance closed'
        : _timeRemainingLabel(session.attendanceClosesAt!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${session.courseCode} - ${session.title}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                StatusPill(label: session.status, status: session.status),
                if (session.isActive)
                  StatusPill(
                    label: 'Live code ${session.code ?? '--'}',
                    status: 'present',
                  ),
                if (session.isActive)
                  StatusPill(label: countdown, status: 'late'),
                if (lecture != null)
                  StatusPill(
                    label: 'Lecture ${lecture!.status}',
                    status: lecture!.status,
                  ),
                if (session.endedAt != null)
                  StatusPill(
                    label: 'Ended ${_formatDateTime(session.endedAt!)}',
                    status: 'completed',
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (report != null) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: report!.counts.entries
                    .map(
                      (entry) => StatusPill(
                        label: '${entry.key}: ${entry.value}',
                        status: entry.key,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              ...report!.records.map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    tileColor: const Color(0xFFF9F5EF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    title: Text(record.studentName),
                    subtitle: Text(
                      '${record.studentEmail}${record.checkedInAt == null ? '' : ' • ${_formatDateTime(record.checkedInAt!)}'}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (status) =>
                          onOverrideAttendance(record, status),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'present',
                          child: Text('Mark present'),
                        ),
                        PopupMenuItem(value: 'late', child: Text('Mark late')),
                        PopupMenuItem(
                          value: 'absent',
                          child: Text('Mark absent'),
                        ),
                        PopupMenuItem(
                          value: 'excused',
                          child: Text('Mark excused'),
                        ),
                        PopupMenuItem(
                          value: 'invalid',
                          child: Text('Mark invalid'),
                        ),
                      ],
                      child: StatusPill(
                        label: record.status,
                        status: record.status,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Lecture Capture',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Record on the phone and upload the audio for Groq transcription, or paste notes as a fallback.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5D594E)),
            ),
            const SizedBox(height: 12),
            if (recordedAudioName != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F5EF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  isRecording
                      ? 'Recording in progress...'
                      : 'Ready audio: $recordedAudioName',
                ),
              ),
            if (recordedAudioName != null) const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.tonalIcon(
                  onPressed: generatingLecture
                      ? null
                      : isRecording
                      ? onStopRecording
                      : onStartRecording,
                  icon: Icon(isRecording ? Icons.stop_circle : Icons.mic),
                  label: Text(isRecording ? 'Stop Recording' : 'Record Audio'),
                ),
                FilledButton.icon(
                  onPressed:
                      generatingLecture ||
                          isRecording ||
                          recordedAudioName == null
                      ? null
                      : onUploadAudio,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    generatingLecture ? 'Uploading...' : 'Upload Audio',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: transcriptController,
              minLines: 5,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Paste transcript or lecture notes',
                hintText:
                    'For the demo, paste lecture notes here and generate the summary.',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.tonal(
                  onPressed: onFillDemoTranscript,
                  child: const Text('Load Demo Transcript'),
                ),
                FilledButton.icon(
                  onPressed: generatingLecture || isRecording
                      ? null
                      : onGenerateLecture,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    generatingLecture ? 'Generating...' : 'Generate Summary',
                  ),
                ),
                if (onEndSession != null)
                  FilledButton.tonalIcon(
                    onPressed: onEndSession,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('End Session'),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            LectureSummaryPanel(
              lecture: lecture,
              emptyTitle: 'No lecture summary yet',
              emptyBody:
                  'Generate a lecture summary to give students a recap and action items.',
            ),
          ],
        ),
      ),
    );
  }
}

class StudentActiveSessionCard extends StatelessWidget {
  const StudentActiveSessionCard({
    super.key,
    required this.session,
    required this.codeController,
    required this.ssid,
    required this.onCheckIn,
  });

  final SessionSummary session;
  final TextEditingController codeController;
  final String ssid;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${session.courseCode} - ${session.courseTitle}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(session.title),
            const SizedBox(height: 12),
            StatusPill(
              label: 'Status ${session.attendanceStatus ?? 'absent'}',
              status: session.attendanceStatus ?? 'absent',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Lecturer code',
                hintText: 'Enter the 6-digit live code',
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: session.attendanceStatus == 'absent'
                  ? onCheckIn
                  : null,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(
                session.attendanceStatus == 'absent'
                    ? 'Check in via $ssid'
                    : 'Attendance already submitted',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentHistorySessionCard extends StatelessWidget {
  const StudentHistorySessionCard({
    super.key,
    required this.session,
    required this.lecture,
  });

  final SessionSummary session;
  final LectureRecord? lecture;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${session.courseCode} - ${session.title}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                StatusPill(
                  label: session.attendanceStatus ?? 'absent',
                  status: session.attendanceStatus ?? 'absent',
                ),
                if (session.endedAt != null)
                  StatusPill(
                    label: _formatDateTime(session.endedAt!),
                    status: 'completed',
                  ),
                if (lecture != null)
                  StatusPill(
                    label: 'Lecture ${lecture!.status}',
                    status: lecture!.status,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            LectureSummaryPanel(
              lecture: lecture,
              emptyTitle: 'Summary pending',
              emptyBody:
                  'The lecturer has not generated a lecture summary for this session yet.',
            ),
          ],
        ),
      ),
    );
  }
}

class LectureSummaryPanel extends StatelessWidget {
  const LectureSummaryPanel({
    super.key,
    required this.lecture,
    required this.emptyTitle,
    required this.emptyBody,
  });

  final LectureRecord? lecture;
  final String emptyTitle;
  final String emptyBody;

  @override
  Widget build(BuildContext context) {
    if (lecture == null) {
      return InfoCard(title: emptyTitle, body: emptyBody);
    }

    if (lecture!.isProcessing) {
      return const InfoCard(
        title: 'Lecture processing',
        body:
            'The summary job is running. Refresh in a few seconds to see the completed recap.',
      );
    }

    if (lecture!.summary == null) {
      return InfoCard(
        title: 'Lecture summary unavailable',
        body: lecture!.errorMessage ?? 'No summary could be generated.',
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Lecture Summary',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (lecture!.sourceType == 'audio_upload') ...[
            const SizedBox(height: 6),
            Text(
              'Generated from recorded audio upload.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5D594E)),
            ),
          ],
          const SizedBox(height: 10),
          Text(lecture!.summary!.summary),
          const SizedBox(height: 14),
          Text(
            'Key Points',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...lecture!.summary!.keyPoints.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.fiber_manual_record, size: 10),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(point)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Action Items',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...lecture!.summary!.actionItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.arrow_right_alt, size: 18),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5F594F)),
          ),
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(body),
          ],
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'present' => const Color(0xFF1F7A4C),
      'late' => const Color(0xFFB26A00),
      'absent' => const Color(0xFFA33A2F),
      'excused' => const Color(0xFF4461A6),
      'invalid' => const Color(0xFF5C4C7D),
      'active' => const Color(0xFF1F7A4C),
      'ended' => const Color(0xFF6B6258),
      'processing' => const Color(0xFF4461A6),
      'pending' => const Color(0xFF835D1B),
      'completed' => const Color(0xFF1F7A4C),
      _ => const Color(0xFF6B6258),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

String _timeRemainingLabel(DateTime value) {
  final difference = value.toLocal().difference(DateTime.now());
  if (difference.isNegative) {
    return 'Attendance closed';
  }

  if (difference.inMinutes >= 1) {
    return '${difference.inMinutes} min left';
  }

  return '${difference.inSeconds} sec left';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
      ? local.hour - 12
      : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute $suffix';
}
