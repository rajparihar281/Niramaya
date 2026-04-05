import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:niramaya_app/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: NiramayaApp(hardwareSosTrigger: false)));

    // Verify that the splash screen text appears.
    expect(find.text('NIRAMAYA'), findsOneWidget);
  });
}
