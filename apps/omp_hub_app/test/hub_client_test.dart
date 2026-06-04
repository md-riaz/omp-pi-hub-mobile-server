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
  test('BrowseResult parses enriched directory entries', () {
    final result = BrowseResult.fromJson({
      'path': '/work',
      'parent': '/',
      'root': '/',
      'home': '/home/alice',
      'platform': 'linux',
      'separator': '/',
      'roots': [
        {'name': '/', 'path': '/'},
      ],
      'showHidden': false,
      'truncated': true,
      'total': 2,
      'limit': 1,
      'items': [
        {
          'name': 'src',
          'path': '/work/src',
          'type': 'directory',
          'isDirectory': true,
          'isFile': false,
          'isSymlink': false,
          'targetType': null,
          'extension': '',
          'size': null,
          'modifiedAt': 1234,
          'createdAt': 1000,
          'permissions': {'readable': true, 'writable': false},
        },
        {
          'name': 'README.md',
          'path': '/work/README.md',
          'type': 'file',
          'isDirectory': false,
          'isFile': true,
          'isSymlink': false,
          'targetType': null,
          'extension': '.md',
          'size': 99,
          'modifiedAt': 5678,
          'createdAt': 5000,
          'permissions': {'readable': true, 'writable': true},
        },
      ],
    });

    expect(result.home, '/home/alice');
    expect(result.platform, 'linux');
    expect(result.roots, ['/']);
    expect(result.truncated, isTrue);
    expect(result.items.first.isDirectory, isTrue);
    expect(result.items.first.readable, isTrue);
    expect(result.items.first.writable, isFalse);
    expect(result.items.first.type, 'directory');
    expect(result.items.last.isFile, isTrue);
    expect(result.items.last.extension, '.md');
    expect(result.items.last.size, 99);
    expect(result.items.last.modifiedAt, 5678);
    expect(result.items.last.createdAt, 5000);
  });
}
