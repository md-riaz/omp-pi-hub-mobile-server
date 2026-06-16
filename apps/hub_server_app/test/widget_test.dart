import 'package:flutter_test/flutter_test.dart';
import 'package:omp_pi_hub_mobile_companion/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const OmpPiHubMobileCompanionApp());
    expect(find.text('Hub Server App'), findsOneWidget);
  });
}
