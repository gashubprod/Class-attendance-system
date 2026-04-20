String demoTranscriptForSession(String courseCode, String title) {
  return '''
Today we are walking through $courseCode and the session "$title".
We reviewed how a lecturer starts a class session, how the app rotates the attendance code, and how students prove presence using the code together with campus Wi-Fi validation.
The backend records whether a student is present, late, absent, excused, or invalid, and the lecturer can still override a record when there is a valid reason.
For the demo, the important path is simple: start a session, let a student check in, end the session, and then generate a lecture summary from notes or transcript text.
Before the next class, students should review the summary, verify the key points, and prepare one question or improvement for the workflow.
''';
}
