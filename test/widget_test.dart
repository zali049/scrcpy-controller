import 'package:flutter_test/flutter_test.dart';
import 'package:scrcpy_gui_controller/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ScrcpyGUIApp());
    expect(find.text('Scrcpy Controller'), findsWidgets);
  });
}
