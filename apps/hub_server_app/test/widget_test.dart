import 'package:flutter_test/flutter_test.dart';
import 'package:hub_server_app/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const OmpPiHubMobileCompanionApp());
    expect(find.text('Hub Server App'), findsOneWidget);
  });
}
