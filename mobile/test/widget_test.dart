import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('renders login screen shell', (tester) async {
    await tester.pumpWidget(const AttendanceDemoApp());

    expect(find.text('RollCall Campus'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
