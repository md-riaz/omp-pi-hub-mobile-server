import 'package:flutter_test/flutter_test.dart';
import 'package:omp_pi_hub_mobile_companion/src/hub_client.dart';

void main() {
  test('AgentCreateRequest serializes cli only when selected', () {
    expect(
      AgentCreateRequest(
        cwd: ' /work/repo ',
        model: ' gpt-5-codex ',
        initialPrompt: ' start ',
        cli: ' pi ',
      ).toJson(),
      {
        'cwd': '/work/repo',
        'model': 'gpt-5-codex',
        'cli': 'pi',
        'initialPrompt': 'start',
      },
    );

    expect(AgentCreateRequest(cwd: '/work/repo', cli: ' ').toJson(), {
      'cwd': '/work/repo',
    });
  });
}
