import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'api_client.dart';
import 'models.dart';

void main() {
  runApp(const AttendanceDemoApp());
}

const appApiBaseUrl = 'https://class-attendance-demo-api.onrender.com';
const appExpectedWifiSsid = 'Wapi-Guest';
const appCanvasColor = Color(0xFFF4F1EA);
const appSurfaceColor = Color(0xFFFFFCF7);
const appMutedSurfaceColor = Color(0xFFF0EBE2);
const appBorderColor = Color(0xFFD9D2C6);
const appTextColor = Color(0xFF16191C);
const appMutedTextColor = Color(0xFF6B6A63);
const appAccentColor = Color(0xFF18382F);
const appAccentSoftColor = Color(0xFFE5ECE8);
const appBronzeColor = Color(0xFF8A6A43);
const appShadowColor = Color(0x120F1419);

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: appAccentColor,
      secondary: appBronzeColor,
      surface: appSurfaceColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: appTextColor,
      error: Color(0xFF9E3B2F),
      onError: Colors.white,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: appCanvasColor,
    splashColor: appAccentColor.withValues(alpha: 0.06),
    highlightColor: Colors.transparent,
    dividerColor: appBorderColor,
    textTheme: base.textTheme.apply(
      bodyColor: appTextColor,
      displayColor: appTextColor,
    ),
    cardTheme: CardThemeData(
      color: appSurfaceColor,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: appBorderColor),
      ),
      shadowColor: appShadowColor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: appTextColor,
      elevation: 0,
    ),
    iconTheme: const IconThemeData(color: appTextColor),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: appMutedSurfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: const TextStyle(color: appMutedTextColor),
      hintStyle: const TextStyle(color: appMutedTextColor),
      prefixIconColor: appMutedTextColor,
      suffixIconColor: appMutedTextColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: appBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: appAccentColor, width: 1.2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: appAccentColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: appTextColor,
        side: const BorderSide(color: appBorderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: appTextColor,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

class AttendanceDemoApp extends StatefulWidget {
  const AttendanceDemoApp({super.key});

  @override
  State<AttendanceDemoApp> createState() => _AttendanceDemoAppState();
}

class _AttendanceDemoAppState extends State<AttendanceDemoApp> {
  late final ApiClient _apiClient = ApiClient(baseUrl: appApiBaseUrl);
  AppUser? _user;

  Future<void> _login({
    required String email,
    required String password,
  }) async {
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
      theme: buildAppTheme(),
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
    required String email,
    required String password,
  })
  onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController(
    text: 'demo1234',
  );
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
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
      backgroundColor: appCanvasColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: appSurfaceColor,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: appBorderColor),
                      boxShadow: const [
                        BoxShadow(
                          color: appShadowColor,
                          blurRadius: 26,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: appAccentSoftColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.verified_user_rounded,
                                  color: appAccentColor,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'RollCall Campus',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Attendance and lecture notes',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: appMutedTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Sign in',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Use your seeded campus account.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: appMutedTextColor,
                            ),
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'lecturer@campus.local',
                              prefixIcon: Icon(Icons.alternate_email),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            onSubmitted: (_) => _busy ? null : _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: Text(_busy ? 'Signing in...' : 'Sign In'),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'Demo access',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: appMutedTextColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _fillDemo('lecturer'),
                                  icon: const Icon(Icons.school_outlined),
                                  label: const Text('Lecturer'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _fillDemo('student'),
                                  icon: const Icon(Icons.badge_outlined),
                                  label: const Text('Student'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
    super.dispose();
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
      await _loadDashboard(quiet: true);
      final recordingStarted = await _startAudioRecording(
        started,
        announce: false,
      );
      if (recordingStarted) {
        showMessage('Session started. Recording is live.');
      } else {
        showMessage('Session started. Start recording if needed.');
      }
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

  bool _isRecordingSession(SessionSummary session) =>
      _recordingSessionId == session.id;

  String? _recordedAudioNameFor(SessionSummary session) {
    final filePath = _recordedAudioPaths[session.id];
    if (filePath == null || filePath.isEmpty) {
      return null;
    }

    return File(filePath).uri.pathSegments.last;
  }

  Future<bool> _startAudioRecording(
    SessionSummary session, {
    bool announce = true,
  }) async {
    if (_recordingSessionId != null && _recordingSessionId != session.id) {
      if (announce) {
        showMessage(
          'Only one recording can run at a time. Stop the active recording first.',
        );
      }
      return false;
    }

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (announce) {
          showMessage(
            'Microphone permission is required to record lecture audio.',
          );
        }
        return false;
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
        return false;
      }

      setState(() {
        _recordingSessionId = session.id;
        _recordedAudioPaths.remove(session.id);
      });
      if (announce) {
        showMessage('Recording started.');
      }
      return true;
    } catch (error) {
      if (announce) {
        showMessage(error.toString());
      }
      return false;
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

      showMessage('Recording stopped. Uploading audio...');
      await _uploadAudioLecture(
        session,
        filePathOverride: filePath,
        quietMessage: true,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _recordingSessionId = null;
        });
      }
      showMessage(error.toString());
    }
  }

  Future<void> _uploadAudioLecture(
    SessionSummary session, {
    String? filePathOverride,
    bool quietMessage = false,
  }) async {
    final filePath = filePathOverride ?? _recordedAudioPaths[session.id];
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
        fileName: filePathOverride == null ? _recordedAudioNameFor(session) : null,
      );
      if (mounted) {
        setState(() {
          _recordedAudioPaths.remove(session.id);
        });
      }
      if (!quietMessage) {
        showMessage('Audio uploaded. Summary is running.');
      }
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
    final activeSessions = _sortSessionsNewestFirst(
      _sessions.where((session) => session.isActive),
    );
    final currentSession = activeSessions.isEmpty ? null : activeSessions.first;
    final historySessions = _sortSessionsNewestFirst(
      _sessions.where(
        (session) => currentSession == null || session.id != currentSession.id,
      ),
    );

    return DashboardScaffold(
      user: widget.user,
      title: 'Lecturer',
      subtitle: currentSession == null ? 'Ready to start the next class' : 'Session in progress',
      onRefresh: _loadDashboard,
      onLogout: widget.onLogout,
      onOpenHistory: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => LecturerHistoryPage(
              user: widget.user,
              sessions: historySessions,
              reports: _reports,
              lecturesBySession: _lecturesBySession,
            ),
          ),
        );
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            InfoCard(title: 'Backend issue', body: _error!)
          else ...[
            if (currentSession == null) ...[
              _CreateSessionCard(
                courses: _courses,
                selectedCourseId: _selectedCourseId,
                titleController: _titleController,
                onCourseChanged: (value) =>
                    setState(() => _selectedCourseId = value),
                onCreatePressed: _createAndStartSession,
              ),
              if (historySessions.isNotEmpty) ...[
                const SizedBox(height: 20),
                const SectionHeader(
                  title: 'Recent',
                  subtitle: 'Past sessions and generated notes',
                ),
                ...historySessions.take(3).map(
                  (session) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SessionHistoryTile(
                      session: session,
                      lecture: _lecturesBySession[session.id],
                      meta: _lecturerHistoryMeta(_reports[session.id]),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => LecturerSessionDetailsPage(
                              session: session,
                              report: _reports[session.id],
                              lecture: _lecturesBySession[session.id],
                              allowAttendanceOverrides: false,
                              onOverrideAttendance: (record, status) async {},
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ] else
              LecturerCurrentSessionCard(
                session: currentSession,
                report: _reports[currentSession.id],
                lecture: _lecturesBySession[currentSession.id],
                generatingLecture: _uploadingSessions.contains(currentSession.id),
                isRecording: _isRecordingSession(currentSession),
                recordedAudioName: _recordedAudioNameFor(currentSession),
                onStartRecording: () => _startAudioRecording(currentSession),
                onStopRecording: () => _stopAudioRecording(currentSession),
                onUploadAudio: () => _uploadAudioLecture(currentSession),
                onEndSession: () => _endSession(currentSession),
                onOpenDetails: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => LecturerSessionDetailsPage(
                        session: currentSession,
                        report: _reports[currentSession.id],
                        lecture: _lecturesBySession[currentSession.id],
                        onOverrideAttendance: _overrideAttendance,
                      ),
                    ),
                  );
                },
              ),
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
        ssid: appExpectedWifiSsid,
      );
      showMessage('Attendance submitted as $status.');
      await _loadDashboard();
    } catch (error) {
      showMessage(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSessions = _sortSessionsNewestFirst(
      _sessions.where((session) => session.isActive),
    );
    final currentSession = activeSessions.isEmpty ? null : activeSessions.first;
    final historySessions = _sortSessionsNewestFirst(
      _sessions.where(
        (session) => currentSession == null || session.id != currentSession.id,
      ),
    );

    return DashboardScaffold(
      user: widget.user,
      title: 'Student',
      subtitle: currentSession == null ? 'Waiting for a live class' : 'Ready to check in',
      onRefresh: _loadDashboard,
      onLogout: widget.onLogout,
      onOpenHistory: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => StudentHistoryPage(
              user: widget.user,
              sessions: historySessions,
              lecturesBySession: _lecturesBySession,
            ),
          ),
        );
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _NetworkBanner(ssid: appExpectedWifiSsid),
          const SizedBox(height: 18),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            InfoCard(title: 'Backend issue', body: _error!)
          else ...[
            const SectionHeader(title: 'Current Session'),
            if (currentSession == null)
              Column(
                children: [
                  const InfoCard(
                    icon: Icons.event_busy_outlined,
                    title: 'No live session',
                    body: 'Attendance opens here when your lecturer starts class.',
                  ),
                  if (historySessions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const SectionHeader(
                      title: 'Recent',
                      subtitle: 'Attendance records and lecture notes',
                    ),
                    ...historySessions.take(3).map(
                      (session) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SessionHistoryTile(
                          session: session,
                          lecture: _lecturesBySession[session.id],
                          meta: session.attendanceStatus ?? 'Absent',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) => StudentSessionDetailsPage(
                                  session: session,
                                  lecture: _lecturesBySession[session.id],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: StudentActiveSessionCard(
                  session: currentSession,
                  codeController: _codeControllerFor(currentSession.id),
                  ssid: appExpectedWifiSsid,
                  onCheckIn: () => _checkIn(currentSession),
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
    required this.onRefresh,
    required this.onLogout,
    required this.child,
    this.onOpenHistory,
    this.subtitle,
  });

  final AppUser user;
  final String title;
  final String? subtitle;
  final Future<void> Function({bool quiet}) onRefresh;
  final VoidCallback onLogout;
  final Widget child;
  final VoidCallback? onOpenHistory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                  ),
                            ),
                            if ((subtitle ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle!,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: appMutedTextColor),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _HeaderActionButton(
                        icon: Icons.refresh,
                        onTap: () => onRefresh(quiet: false),
                      ),
                      if (onOpenHistory != null) ...[
                        const SizedBox(width: 8),
                        _HeaderActionButton(
                          icon: Icons.history,
                          onTap: onOpenHistory!,
                        ),
                      ],
                      const SizedBox(width: 8),
                      _HeaderActionButton(
                        icon: Icons.logout,
                        onTap: onLogout,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: appSurfaceColor,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: appBorderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: user.isLecturer
                                ? appAccentSoftColor
                                : const Color(0xFFE8ECEF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            user.isLecturer
                                ? Icons.school_outlined
                                : Icons.badge_outlined,
                            color: user.isLecturer
                                ? appAccentColor
                                : const Color(0xFF375468),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: appMutedTextColor),
                              ),
                            ],
                          ),
                        ),
                        _RoleChip(
                          label: user.isLecturer ? 'Lecturer' : 'Student',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(child: child),
          ],
        ),
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
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: appAccentSoftColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.play_circle_outline,
                    color: appAccentColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start a live session',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose a course and open attendance.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: appMutedTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: selectedCourseId,
              menuMaxHeight: 320,
              items: courses
                  .map(
                    (course) => DropdownMenuItem<String>(
                      value: course.id,
                      child: Text(
                        '${course.code} - ${course.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              selectedItemBuilder: (context) => courses
                  .map(
                    (course) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${course.code} - ${course.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: courses.isEmpty ? null : onCourseChanged,
              decoration: const InputDecoration(labelText: 'Unit'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Session title'),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: courses.isEmpty ? null : onCreatePressed,
              icon: const Icon(Icons.play_circle_fill),
              label: const Text('Start Live Session'),
            ),
          ],
        ),
      ),
    );
  }
}

class LecturerCurrentSessionCard extends StatelessWidget {
  const LecturerCurrentSessionCard({
    super.key,
    required this.session,
    required this.report,
    required this.lecture,
    required this.generatingLecture,
    required this.isRecording,
    required this.recordedAudioName,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onUploadAudio,
    required this.onEndSession,
    required this.onOpenDetails,
  });

  final SessionSummary session;
  final SessionReport? report;
  final LectureRecord? lecture;
  final bool generatingLecture;
  final bool isRecording;
  final String? recordedAudioName;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onUploadAudio;
  final VoidCallback onEndSession;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final countdown = session.attendanceClosesAt == null
        ? 'Attendance closed'
        : _timeRemainingLabel(session.attendanceClosesAt!);
    final audioAlreadySubmitted =
        lecture != null && lecture!.sourceType == 'audio_upload';
    final canRetryUpload =
        recordedAudioName != null && !isRecording && !audioAlreadySubmitted;
    final audioActionLabel = generatingLecture
        ? 'Uploading...'
        : isRecording
        ? 'Stop & Upload'
        : canRetryUpload
        ? 'Retry Upload'
        : audioAlreadySubmitted
        ? 'Audio Submitted'
        : 'Start Recording';
    final counts = report?.counts ?? const <String, int>{};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.courseCode,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: appMutedTextColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        session.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                StatusPill(label: 'Live', status: session.status),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: appTextColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live code',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    session.code ?? '--',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        countdown,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.84),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: MetricTile(
                    label: 'Present',
                    value: '${counts['present'] ?? 0}',
                    tone: 'present',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricTile(
                    label: 'Late',
                    value: '${counts['late'] ?? 0}',
                    tone: 'late',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricTile(
                    label: 'Absent',
                    value: '${counts['absent'] ?? 0}',
                    tone: 'absent',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (lecture != null)
                  StatusPill(
                    label: 'Notes ${lecture!.status}',
                    status: lecture!.status,
                  ),
                if (isRecording) const StatusPill(label: 'Recording', status: 'processing'),
                if (recordedAudioName != null && !isRecording)
                  const StatusPill(label: 'Audio ready', status: 'pending'),
              ],
            ),
            if (recordedAudioName != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: appMutedSurfaceColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isRecording
                      ? 'Recording in progress...'
                      : 'Pending upload: $recordedAudioName',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: appMutedTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed:
                      generatingLecture || audioAlreadySubmitted
                      ? null
                      : isRecording
                      ? onStopRecording
                      : canRetryUpload
                      ? onUploadAudio
                      : onStartRecording,
                  icon: Icon(
                    isRecording
                        ? Icons.stop_circle
                        : canRetryUpload
                        ? Icons.cloud_upload_outlined
                        : audioAlreadySubmitted
                        ? Icons.check_circle_outline
                        : Icons.mic,
                  ),
                  label: Text(audioActionLabel),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenDetails,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Details'),
                ),
                OutlinedButton.icon(
                  onPressed: onEndSession,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('End Session'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LecturerSessionDetailsPage extends StatelessWidget {
  const LecturerSessionDetailsPage({
    super.key,
    required this.session,
    required this.report,
    required this.lecture,
    required this.onOverrideAttendance,
    this.allowAttendanceOverrides = true,
  });

  final SessionSummary session;
  final SessionReport? report;
  final LectureRecord? lecture;
  final Future<void> Function(AttendanceRecord record, String status)
  onOverrideAttendance;
  final bool allowAttendanceOverrides;

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      title: session.courseCode,
      subtitle: 'Attendance report and lecture notes',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          LecturerSessionCard(
            session: session,
            report: report,
            lecture: lecture,
            generatingLecture: false,
            isRecording: false,
            recordedAudioName: null,
            showLectureControls: false,
            allowAttendanceOverrides: allowAttendanceOverrides,
            onStartRecording: () {},
            onStopRecording: () {},
            onUploadAudio: () {},
            onOverrideAttendance: onOverrideAttendance,
          ),
        ],
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
    required this.generatingLecture,
    required this.isRecording,
    required this.recordedAudioName,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onUploadAudio,
    required this.onOverrideAttendance,
    this.onEndSession,
    this.showLectureControls = true,
    this.allowAttendanceOverrides = true,
  });

  final SessionSummary session;
  final SessionReport? report;
  final LectureRecord? lecture;
  final bool generatingLecture;
  final bool isRecording;
  final String? recordedAudioName;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onUploadAudio;
  final VoidCallback? onEndSession;
  final Future<void> Function(AttendanceRecord record, String status)
  onOverrideAttendance;
  final bool showLectureControls;
  final bool allowAttendanceOverrides;

  @override
  Widget build(BuildContext context) {
    final countdown = session.attendanceClosesAt == null
        ? 'Attendance closed'
        : _timeRemainingLabel(session.attendanceClosesAt!);
    final theme = Theme.of(context);
    final audioAlreadySubmitted =
        lecture != null && lecture!.sourceType == 'audio_upload';
    final canRetryUpload =
        recordedAudioName != null && !isRecording && !audioAlreadySubmitted;
    final audioActionLabel = generatingLecture
        ? 'Uploading...'
        : isRecording
        ? 'Stop & Upload'
        : canRetryUpload
        ? 'Retry Upload'
        : audioAlreadySubmitted
        ? 'Audio Submitted'
        : 'Start Recording';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.courseCode,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: appMutedTextColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        session.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                StatusPill(label: session.status, status: session.status),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (session.isActive)
                  StatusPill(
                    label: 'Code ${session.code ?? '--'}',
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
            if (report != null) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'Present',
                      value: '${report!.counts['present'] ?? 0}',
                      tone: 'present',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricTile(
                      label: 'Late',
                      value: '${report!.counts['late'] ?? 0}',
                      tone: 'late',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricTile(
                      label: 'Absent',
                      value: '${report!.counts['absent'] ?? 0}',
                      tone: 'absent',
                    ),
                  ),
                ],
              ),
            ],
            if (report != null) ...[
              const SizedBox(height: 22),
              Text(
                'Attendance',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ...report!.records.map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AttendanceRecordTile(
                    record: record,
                    allowOverrides: allowAttendanceOverrides,
                    onOverrideAttendance: onOverrideAttendance,
                  ),
                ),
              ),
            ],
            if (showLectureControls) ...[
              const SizedBox(height: 10),
              Text(
                'Lecture Capture',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (recordedAudioName != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: appMutedSurfaceColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isRecording
                        ? 'Recording in progress...'
                        : 'Pending upload: $recordedAudioName',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: appMutedTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (recordedAudioName != null) const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed:
                        generatingLecture || audioAlreadySubmitted
                        ? null
                        : isRecording
                        ? onStopRecording
                        : canRetryUpload
                        ? onUploadAudio
                        : onStartRecording,
                    icon: Icon(
                      isRecording
                          ? Icons.stop_circle
                          : canRetryUpload
                          ? Icons.cloud_upload_outlined
                          : audioAlreadySubmitted
                        ? Icons.check_circle_outline
                        : Icons.mic,
                    ),
                    label: Text(audioActionLabel),
                  ),
                  if (onEndSession != null)
                    OutlinedButton.icon(
                      onPressed: onEndSession,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('End Session'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            LectureSummaryPanel(
              lecture: lecture,
              emptyTitle: 'No summary yet',
              emptyBody: 'Start a session and stop the recording to generate one.',
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
    final checkedIn = session.attendanceStatus != null &&
        session.attendanceStatus != 'absent';
    final countdown = session.attendanceClosesAt == null
        ? 'Attendance closed'
        : _timeRemainingLabel(session.attendanceClosesAt!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.courseCode,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: appMutedTextColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        session.courseTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: checkedIn
                      ? (session.attendanceStatus ?? 'Submitted')
                      : 'Live',
                  status: checkedIn
                      ? (session.attendanceStatus ?? 'present')
                      : 'active',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(session.title),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: appMutedSurfaceColor,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_tethering, color: appAccentColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ssid,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    countdown,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: appMutedTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (checkedIn)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: appAccentSoftColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: appAccentColor,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Checked in',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    if (session.checkedInAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formatDateTime(session.checkedInAt!),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: appMutedTextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else ...[
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Live code',
                  hintText: 'Enter the 6-digit code',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onCheckIn,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Check In'),
              ),
            ],
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
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.courseCode,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: appMutedTextColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        session.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: session.attendanceStatus ?? 'absent',
                  status: session.attendanceStatus ?? 'absent',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (session.endedAt != null)
                  StatusPill(
                    label: _formatDateTime(session.endedAt!),
                    status: 'completed',
                  ),
                if (lecture != null)
                  StatusPill(
                    label: 'Notes ${lecture!.status}',
                    status: lecture!.status,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: appMutedSurfaceColor,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    color: appAccentColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      session.attendanceStatus == null ||
                              session.attendanceStatus == 'absent'
                          ? 'No attendance submitted'
                          : 'Attendance recorded as ${session.attendanceStatus}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: appMutedTextColor,
                      ),
                    ),
                  ),
                ],
              ),
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

class LecturerHistoryPage extends StatelessWidget {
  const LecturerHistoryPage({
    super.key,
    required this.user,
    required this.sessions,
    required this.reports,
    required this.lecturesBySession,
  });

  final AppUser user;
  final List<SessionSummary> sessions;
  final Map<String, SessionReport> reports;
  final Map<String, LectureRecord> lecturesBySession;

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      title: 'History',
      subtitle: 'Past sessions, attendance, and generated notes',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (sessions.isEmpty)
            const InfoCard(
              icon: Icons.history_toggle_off,
              title: 'No history yet',
              body: 'Completed sessions will appear here.',
            )
          else
            ...sessions.map(
              (session) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SessionHistoryTile(
                  session: session,
                  lecture: lecturesBySession[session.id],
                  meta: _lecturerHistoryMeta(reports[session.id]),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => LecturerSessionDetailsPage(
                          session: session,
                          report: reports[session.id],
                          lecture: lecturesBySession[session.id],
                          allowAttendanceOverrides: false,
                          onOverrideAttendance: (record, status) async {},
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StudentHistoryPage extends StatelessWidget {
  const StudentHistoryPage({
    super.key,
    required this.user,
    required this.sessions,
    required this.lecturesBySession,
  });

  final AppUser user;
  final List<SessionSummary> sessions;
  final Map<String, LectureRecord> lecturesBySession;

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      title: 'History',
      subtitle: 'Attendance records and lecture notes',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (sessions.isEmpty)
            const InfoCard(
              icon: Icons.history_toggle_off,
              title: 'No history yet',
              body: 'Completed classes will appear here.',
            )
          else
            ...sessions.map(
              (session) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SessionHistoryTile(
                  session: session,
                  lecture: lecturesBySession[session.id],
                  meta: session.attendanceStatus ?? 'Absent',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => StudentSessionDetailsPage(
                          session: session,
                          lecture: lecturesBySession[session.id],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StudentSessionDetailsPage extends StatelessWidget {
  const StudentSessionDetailsPage({
    super.key,
    required this.session,
    required this.lecture,
  });

  final SessionSummary session;
  final LectureRecord? lecture;

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      title: session.courseCode,
      subtitle: 'Attendance status and lecture notes',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          StudentHistorySessionCard(session: session, lecture: lecture),
        ],
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
        title: 'Processing',
        body: 'Summary is still running.',
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appMutedSurfaceColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Notes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: 10),
              if (lecture!.sourceType == 'audio_upload')
                const StatusPill(label: 'Audio', status: 'processing'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            lecture!.summary!.summary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
          if (lecture!.summary!.keyPoints.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Key Points',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            ...lecture!.summary!.keyPoints.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: appSurfaceColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.fiber_manual_record,
                          size: 10,
                          color: appAccentColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(point)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (lecture!.summary!.actionItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            ...lecture!.summary!.actionItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: appSurfaceColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.arrow_outward_rounded,
                          size: 18,
                          color: appBronzeColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

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
          if ((subtitle ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: appMutedTextColor),
            ),
          ],
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.body,
    this.icon,
  });

  final String title;
  final String body;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: appAccentSoftColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: appAccentColor),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: appMutedTextColor,
                    height: 1.45,
                  ),
            ),
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
      'present' => const Color(0xFF1F6B45),
      'late' => const Color(0xFF9B680A),
      'absent' => const Color(0xFFA34832),
      'excused' => const Color(0xFF3E6177),
      'invalid' => const Color(0xFF5D5368),
      'active' => appAccentColor,
      'ended' => const Color(0xFF5A5953),
      'processing' => const Color(0xFF3E6177),
      'pending' => appBronzeColor,
      'completed' => const Color(0xFF1F6B45),
      _ => const Color(0xFF5A5953),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final Color accent = switch (tone) {
      'present' => const Color(0xFF1F6B45),
      'late' => const Color(0xFF9B680A),
      'absent' => const Color(0xFFA34832),
      _ => appAccentColor,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: appMutedSurfaceColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: appMutedTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class SessionHistoryTile extends StatelessWidget {
  const SessionHistoryTile({
    super.key,
    required this.session,
    required this.lecture,
    required this.meta,
    required this.onTap,
  });

  final SessionSummary session;
  final LectureRecord? lecture;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timestamp = _historyTimestamp(session);
    final notesLabel = lecture == null
        ? null
        : lecture!.isProcessing
        ? 'Notes running'
        : 'Notes ready';
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: appMutedSurfaceColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  color: appAccentColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.courseCode,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: appMutedTextColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timestamp,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: appMutedTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: appMutedTextColor,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (session.isActive)
                          StatusPill(
                            label: session.status,
                            status: session.status,
                          ),
                        if (lecture != null)
                          StatusPill(
                            label: notesLabel!,
                            status: lecture!.status,
                          ),
                        if (session.attendanceStatus != null)
                          StatusPill(
                            label: session.attendanceStatus!,
                            status: session.attendanceStatus!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: appMutedSurfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: appMutedTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubPageScaffold extends StatelessWidget {
  const _SubPageScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderActionButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: appMutedTextColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _AttendanceRecordTile extends StatelessWidget {
  const _AttendanceRecordTile({
    required this.record,
    required this.allowOverrides,
    required this.onOverrideAttendance,
  });

  final AttendanceRecord record;
  final bool allowOverrides;
  final Future<void> Function(AttendanceRecord record, String status)
  onOverrideAttendance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appMutedSurfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.studentName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.studentEmail,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: appMutedTextColor,
                  ),
                ),
                if (record.checkedInAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Checked in ${_formatDateTime(record.checkedInAt!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: appMutedTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if ((record.overrideReason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    record.overrideReason!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: appMutedTextColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (allowOverrides)
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              onSelected: (status) => onOverrideAttendance(record, status),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'present', child: Text('Mark present')),
                PopupMenuItem(value: 'late', child: Text('Mark late')),
                PopupMenuItem(value: 'absent', child: Text('Mark absent')),
                PopupMenuItem(value: 'excused', child: Text('Mark excused')),
                PopupMenuItem(value: 'invalid', child: Text('Mark invalid')),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusPill(label: record.status, status: record.status),
                  const SizedBox(width: 6),
                  const Icon(Icons.more_horiz, color: appMutedTextColor),
                ],
              ),
            )
          else
            StatusPill(label: record.status, status: record.status),
        ],
      ),
    );
  }
}

class _NetworkBanner extends StatelessWidget {
  const _NetworkBanner({required this.ssid});

  final String ssid;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: appAccentSoftColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.wifi_tethering,
                color: appAccentColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campus Wi-Fi',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ssid,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: appMutedTextColor,
                    ),
                  ),
                ],
              ),
            ),
            const _RoleChip(label: 'Verified'),
          ],
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: appSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: appBorderColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: appAccentSoftColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: appAccentColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _lecturerHistoryMeta(SessionReport? report) {
  if (report == null) {
    return 'Attendance unavailable';
  }

  return '${report.counts['present'] ?? 0} present · '
      '${report.counts['late'] ?? 0} late · '
      '${report.counts['absent'] ?? 0} absent';
}

String _historyTimestamp(SessionSummary session) {
  final time =
      session.endedAt ?? session.startedAt ?? session.latestLectureCreatedAt;
  if (time == null) {
    return 'No timestamp';
  }
  return _formatDateTime(time);
}

List<SessionSummary> _sortSessionsNewestFirst(Iterable<SessionSummary> sessions) {
  final list = sessions.toList();
  list.sort(
    (left, right) => _sessionSortTime(
      right,
    ).compareTo(_sessionSortTime(left)),
  );
  return list;
}

DateTime _sessionSortTime(SessionSummary session) {
  return session.startedAt ??
      session.endedAt ??
      session.latestLectureCreatedAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
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
