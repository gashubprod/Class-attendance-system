class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  final String id;
  final String name;
  final String email;
  final String role;

  bool get isLecturer => role == 'lecturer';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
    );
  }
}

class Course {
  const Course({required this.id, required this.code, required this.title});

  final String id;
  final String code;
  final String title;

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      code: json['code'] as String,
      title: json['title'] as String,
    );
  }
}

class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.title,
    required this.status,
    required this.startedAt,
    required this.attendanceClosesAt,
    required this.endedAt,
    required this.code,
    required this.attendanceRecordId,
    required this.attendanceStatus,
    required this.checkedInAt,
    required this.latestLectureId,
    required this.latestLectureStatus,
    required this.latestLectureCreatedAt,
  });

  final String id;
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String title;
  final String status;
  final DateTime? startedAt;
  final DateTime? attendanceClosesAt;
  final DateTime? endedAt;
  final String? code;
  final String? attendanceRecordId;
  final String? attendanceStatus;
  final DateTime? checkedInAt;
  final String? latestLectureId;
  final String? latestLectureStatus;
  final DateTime? latestLectureCreatedAt;

  bool get isActive => status == 'active';
  bool get isEnded => status == 'ended';

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String key) {
      final value = json[key];
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return SessionSummary(
      id: json['id'] as String,
      courseId: json['courseId'] as String,
      courseCode: json['courseCode'] as String,
      courseTitle: json['courseTitle'] as String,
      title: json['title'] as String,
      status: json['status'] as String,
      startedAt: parseDate('startedAt'),
      attendanceClosesAt: parseDate('attendanceClosesAt'),
      endedAt: parseDate('endedAt'),
      code: json['code'] as String?,
      attendanceRecordId: json['attendanceRecordId'] as String?,
      attendanceStatus: json['attendanceStatus'] as String?,
      checkedInAt: parseDate('checkedInAt'),
      latestLectureId: json['latestLectureId'] as String?,
      latestLectureStatus: json['latestLectureStatus'] as String?,
      latestLectureCreatedAt: parseDate('latestLectureCreatedAt'),
    );
  }
}

class LectureSummaryData {
  const LectureSummaryData({
    required this.id,
    required this.summary,
    required this.keyPoints,
    required this.actionItems,
  });

  final String id;
  final String summary;
  final List<String> keyPoints;
  final List<String> actionItems;

  factory LectureSummaryData.fromJson(Map<String, dynamic> json) {
    return LectureSummaryData(
      id: json['id'] as String,
      summary: json['summary'] as String,
      keyPoints: ((json['keyPoints'] as List<dynamic>?) ?? const [])
          .map((entry) => entry as String)
          .toList(),
      actionItems: ((json['actionItems'] as List<dynamic>?) ?? const [])
          .map((entry) => entry as String)
          .toList(),
    );
  }
}

class LectureRecord {
  const LectureRecord({
    required this.id,
    required this.sessionId,
    required this.sessionTitle,
    required this.sessionStatus,
    required this.courseCode,
    required this.courseTitle,
    required this.fileName,
    required this.sourceType,
    required this.status,
    required this.transcriptText,
    required this.errorMessage,
    required this.createdAt,
    required this.processedAt,
    required this.summary,
  });

  final String id;
  final String sessionId;
  final String sessionTitle;
  final String sessionStatus;
  final String courseCode;
  final String courseTitle;
  final String fileName;
  final String sourceType;
  final String status;
  final String transcriptText;
  final String? errorMessage;
  final DateTime? createdAt;
  final DateTime? processedAt;
  final LectureSummaryData? summary;

  bool get isProcessing => status == 'pending' || status == 'processing';

  factory LectureRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String key) {
      final value = json[key];
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return LectureRecord(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      sessionTitle: json['sessionTitle'] as String,
      sessionStatus: json['sessionStatus'] as String,
      courseCode: json['courseCode'] as String,
      courseTitle: json['courseTitle'] as String,
      fileName: json['fileName'] as String,
      sourceType: json['sourceType'] as String,
      status: json['status'] as String,
      transcriptText: json['transcriptText'] as String? ?? '',
      errorMessage: json['errorMessage'] as String?,
      createdAt: parseDate('createdAt'),
      processedAt: parseDate('processedAt'),
      summary: json['summary'] == null
          ? null
          : LectureSummaryData.fromJson(
              json['summary'] as Map<String, dynamic>,
            ),
    );
  }
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.status,
    required this.checkedInAt,
    required this.overrideReason,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String status;
  final DateTime? checkedInAt;
  final String? overrideReason;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final checkedInAtValue = json['checkedInAt'];
    return AttendanceRecord(
      id: json['id'] as String,
      studentId: json['studentId'] as String,
      studentName: json['studentName'] as String,
      studentEmail: json['studentEmail'] as String,
      status: json['status'] as String,
      checkedInAt: checkedInAtValue is String
          ? DateTime.tryParse(checkedInAtValue)
          : null,
      overrideReason: json['overrideReason'] as String?,
    );
  }
}

class SessionReport {
  const SessionReport({
    required this.session,
    required this.counts,
    required this.records,
  });

  final SessionSummary session;
  final Map<String, int> counts;
  final List<AttendanceRecord> records;

  factory SessionReport.fromJson(Map<String, dynamic> json) {
    final countsJson = json['counts'] as Map<String, dynamic>;
    return SessionReport(
      session: SessionSummary.fromJson(json['session'] as Map<String, dynamic>),
      counts: countsJson.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      records: ((json['records'] as List<dynamic>?) ?? const [])
          .map(
            (entry) => AttendanceRecord.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class LoginResult {
  const LoginResult({required this.token, required this.user});

  final String token;
  final AppUser user;
}
