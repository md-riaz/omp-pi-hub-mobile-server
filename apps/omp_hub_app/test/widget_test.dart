import 'package:flutter_test/flutter_test.dart';
import 'package:omp_pi_hub_mobile_server/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const OmpPiHubMobileServerApp());
    expect(find.text('OMP Pi Hub Mobile'), findsOneWidget);
  });
}
