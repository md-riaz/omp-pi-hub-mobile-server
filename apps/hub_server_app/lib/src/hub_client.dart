import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'hub_models.dart';

class AgentCreateRequest {
  AgentCreateRequest({
    required this.cwd,
    this.name = '',
    this.model = '',
    this.initialPrompt = '',
    this.cli = '',
  });

  final String cwd;
  final String name;
  final String model;
  final String initialPrompt;
  final String cli;

  Map<String, String> toJson() {
    return {
      'cwd': cwd.trim(),
      if (name.trim().isNotEmpty) 'name': name.trim(),
      if (model.trim().isNotEmpty) 'model': model.trim(),
      if (cli.trim().isNotEmpty) 'cli': cli.trim(),
      if (initialPrompt.trim().isNotEmpty)
        'initialPrompt': initialPrompt.trim(),
    };
  }
}

class AgentCreateResult {
  AgentCreateResult({
    required this.status,
    required this.complete,
    this.id,
    this.pid,
    this.error,
  });

  final String status;
  final bool complete;
  final String? id;
  final int? pid;
  final String? error;

  String get summary {
    final idPart = id == null ? '' : ' - $id';
    final pidPart = pid == null ? '' : ' - pid $pid';
    final errorPart = error == null ? '' : ' - $error';
    return '$status$idPart$pidPart$errorPart';
  }

  factory AgentCreateResult.fromJson(Map<String, dynamic> json) {
    final creation = json['creation'] is Map
        ? _stringKeyMap(json['creation'] as Map)
        : json;
    return AgentCreateResult(
      status: creation['status']?.toString() ?? 'submitted',
      complete: json['complete'] == true,
      id: creation['id']?.toString(),
      pid: _intValue(creation['pid']),
      error: creation['error']?.toString(),
    );
  }
}

class CollaborationSendResult {
  CollaborationSendResult({
    required this.id,
    required this.targetCount,
    required this.commandIds,
  });

  final String id;
  final int targetCount;
  final List<String> commandIds;

  factory CollaborationSendResult.fromJson(Map<String, dynamic> json) {
    final message = json['collaborationMessage'] is Map
        ? _stringKeyMap(json['collaborationMessage'] as Map)
        : <String, dynamic>{};
    final commands = json['commands'] is List
        ? json['commands'] as List
        : const [];
    return CollaborationSendResult(
      id: message['id']?.toString() ?? '',
      targetCount: commands.length,
      commandIds: [
        for (final command in commands)
          if (command is Map && command['id'] != null) command['id'].toString(),
      ],
    );
  }
}

class HubClient {
  String baseUrl = '';
  String token = '';
  HttpClient? _streamClient;

  void configure({required String baseUrl, required String token}) {
    this.baseUrl = normalizeBaseUrl(baseUrl);
    this.token = token.trim();
  }

  static String normalizeBaseUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
    return withScheme.replaceAll(RegExp(r'/+$'), '');
  }

  Uri _uri(String path, [Map<String, String>? queryParameters]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);

  void _authorize(HttpClientRequest request) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  }

  HttpClient _newHttpClient() {
    return HttpClient()..connectionTimeout = const Duration(seconds: 8);
  }

  Future<HubSnapshot> fetchSnapshot() async {
    return _fetchSnapshotPath('/api/snapshot/summary');
  }

  Future<HubSnapshot> _fetchSnapshotPath(String path) async {
    final client = _newHttpClient();
    try {
      final request = await client.getUrl(_uri(path));
      _authorize(request);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 404) {
        throw Exception(
          'Hub server is not updated: $path returned 404. Update and restart the hub server.',
        );
      }
      if (response.statusCode != 200) {
        throw Exception('${response.statusCode}: $body');
      }
      return HubSnapshot.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      ).activeOnly();
    } finally {
      client.close(force: true);
    }
  }

  Future<HubSession> fetchSessionDetail(
    String sessionId, {
    int limit = 80,
  }) async {
    final client = _newHttpClient();
    try {
      final request = await client.getUrl(
        _uri('/api/sessions/${Uri.encodeComponent(sessionId)}', {
          'limit': '$limit',
        }),
      );
      _authorize(request);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception('${response.statusCode}: $body');
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      return HubSession.fromJson(_stringKeyMap(data['session'] as Map));
    } finally {
      client.close(force: true);
    }
  }

  Future<HubHistoryPage> fetchSessionHistory(
    String sessionId, {
    required int before,
    int limit = 80,
  }) async {
    final client = _newHttpClient();
    try {
      final request = await client.getUrl(
        _uri('/api/sessions/${Uri.encodeComponent(sessionId)}/history', {
          'before': '$before',
          'limit': '$limit',
        }),
      );
      _authorize(request);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception('${response.statusCode}: $body');
      }
      return HubHistoryPage.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } finally {
      client.close(force: true);
    }
  }

  Stream<HubSnapshot> streamSnapshots() async* {
    _streamClient?.close(force: true);
    _streamClient = _newHttpClient();
    final request = await _streamClient!.getUrl(
      _uri('/api/stream', {'summary': '1'}),
    );
    _authorize(request);
    final response = await request.close();
    if (response.statusCode != 200) {
      final body = await response.transform(utf8.decoder).join();
      throw Exception('${response.statusCode}: $body');
    }

    HubSnapshot? snapshot;
    int? lastSeq;
    final dataLines = <String>[];
    await for (final line
        in response.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (dataLines.isEmpty) continue;
        final rawData = dataLines.join('\n');
        dataLines.clear();
        final data = jsonDecode(rawData) as Map<String, dynamic>;
        final seq = _intValue(data['seq']);
        final missedEvents =
            seq != null && lastSeq != null && seq > lastSeq + 1;
        if (missedEvents) {
          snapshot = await fetchSnapshot();
          yield snapshot;
        }
        if (seq != null) lastSeq = seq;
        if (data['type'] == 'snapshot') {
          snapshot = HubSnapshot.fromJson(
            data['snapshot'] as Map<String, dynamic>,
          ).activeOnly();
        } else {
          final previousSnapshot = snapshot;
          if (data['session'] != null) {
            final session = HubSession.fromJson(
              data['session'] as Map<String, dynamic>,
            );
            if (session.isActive(
              staleThresholdMs: snapshot?.server?.staleThresholdMs,
            )) {
              snapshot = (snapshot ?? HubSnapshot.empty()).upsert(session);
            } else {
              snapshot = (snapshot ?? HubSnapshot.empty()).removeSession(
                session.id,
              );
            }
          }
          if (data['type'] == 'session_removed' && data['sessionId'] != null) {
            final removedId = data['sessionId'].toString();
            snapshot = (snapshot ?? HubSnapshot.empty()).removeSession(
              removedId,
            );
          }
          if (data['command'] != null) {
            snapshot = _upsertCommandInSnapshot(
              snapshot ?? HubSnapshot.empty(),
              _commandFromStreamData(data),
            );
          }
          if (data['event'] != null) {
            snapshot = _upsertEventInSnapshot(
              snapshot ?? HubSnapshot.empty(),
              previousSnapshot,
              _stringKeyMap(data['event'] as Map),
            );
          }
        }
        if (snapshot != null) yield snapshot;
        continue;
      }
      if (line.startsWith(':')) continue;
      if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> payload,
  ) async {
    final client = _newHttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl$path'));
      request.headers.contentType = ContentType.json;
      _authorize(request);
      request.write(jsonEncode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception('${response.statusCode}: $body');
      }
      final data = jsonDecode(body);
      return data is Map ? _stringKeyMap(data) : <String, dynamic>{};
    } finally {
      client.close(force: true);
    }
  }

  Future<AgentCreateResult> createAgent(AgentCreateRequest requestBody) async {
    final client = _newHttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('$baseUrl/api/agents/create'),
      );
      request.headers.contentType = ContentType.json;
      _authorize(request);
      request.write(jsonEncode(requestBody.toJson()));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception('${response.statusCode}: $body');
      }
      return AgentCreateResult.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> updateCommandText(String commandId, String text) async {
    await _postJson('/api/commands/${Uri.encodeComponent(commandId)}/update', {
      'text': text,
    });
  }

  Future<void> cancelCommand(String commandId) async {
    await _postJson(
      '/api/commands/${Uri.encodeComponent(commandId)}/cancel',
      {},
    );
  }

  Future<HubCommand?> sendMessage(
    String sessionId,
    String text, {
    String deliveryMode = 'steer',
    String? clientCommandId,
  }) async {
    final client = _newHttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl/api/send'));
      request.headers.contentType = ContentType.json;
      _authorize(request);
      request.write(
        jsonEncode({
          'sessionId': sessionId,
          'text': text,
          'deliveryMode': deliveryMode,
          'clientCommandId': clientCommandId ?? newClientCommandId(),
        }),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception('${response.statusCode}: $body');
      }
      final data = jsonDecode(body);
      if (data is Map && data['command'] is Map) {
        return HubCommand.fromJson(_stringKeyMap(data['command'] as Map));
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<CollaborationSendResult> sendCollaborationMessage({
    required List<String> sessionIds,
    required String text,
  }) async {
    final data = await _postJson('/api/collaboration/messages', {
      'sessionIds': sessionIds,
      'text': text,
    });
    return CollaborationSendResult.fromJson(data);
  }

  Future<void> sendControl(
    String sessionId,
    String action, {
    String? modelId,
  }) async {
    final client = _newHttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl/api/control'));
      request.headers.contentType = ContentType.json;
      _authorize(request);
      final payload = <String, String>{
        'sessionId': sessionId,
        'action': action,
      };
      if (modelId != null) payload['modelId'] = modelId;
      request.write(jsonEncode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw Exception('${response.statusCode}: $body');
      }
    } finally {
      client.close(force: true);
    }
  }

  void close() {
    _streamClient?.close(force: true);
  }

  /// Browse remote directory on the hub host.
  Future<BrowseResult> browseDirectory(String dirPath) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(_uri('/api/browse', {'path': dirPath}));
      _authorize(req);
      final res = await req.close().timeout(const Duration(seconds: 8));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw Exception('${res.statusCode}: $body');
      final json = jsonDecode(body) as Map<String, dynamic>;
      return BrowseResult.fromJson(json);
    } finally {
      client.close(force: true);
    }
  }

  /// Send text + optional file attachments to a session.
  ///
  /// The hub stores attachments on the host and sends OMP a text prompt with
  /// local file paths, mirroring OMP TUI image paste behavior.
  Future<HubCommand?> sendAttachment(
    String sessionId, {
    required String text,
    required List<AttachmentData> attachments,
    String? clientCommandId,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.postUrl(_uri('/api/send-attachment'));
      req.headers.contentType = ContentType.json;
      _authorize(req);
      req.write(
        jsonEncode({
          'sessionId': sessionId,
          'text': text,
          'attachments': attachments.map((a) => a.toJson()).toList(),
          'clientCommandId': clientCommandId ?? newClientCommandId(),
        }),
      );
      final res = await req.close().timeout(const Duration(seconds: 30));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw Exception('${res.statusCode}: $body');
      final data = jsonDecode(body);
      if (data is Map && data['command'] is Map) {
        return HubCommand.fromJson(_stringKeyMap(data['command'] as Map));
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

String newClientCommandId() {
  final random = Random.secure();
  final bytes = List<int>.generate(12, (_) => random.nextInt(256));
  final suffix = base64UrlEncode(bytes).replaceAll('=', '');
  return 'app-${DateTime.now().microsecondsSinceEpoch}-$suffix';
}

class BrowseResult {
  final String path;
  final String parent;
  final String root;
  final String home;
  final String platform;
  final String separator;
  final List<String> roots;
  final bool showHidden;
  final List<BrowseEntry> items;
  final bool truncated;
  final int total;
  final int limit;

  BrowseResult({
    required this.path,
    required this.parent,
    required this.root,
    required this.home,
    required this.platform,
    required this.separator,
    required this.roots,
    required this.showHidden,
    required this.items,
    required this.truncated,
    required this.total,
    required this.limit,
  });

  factory BrowseResult.fromJson(Map<String, dynamic> json) {
    return BrowseResult(
      path: json['path']?.toString() ?? '/',
      parent: json['parent']?.toString() ?? '/',
      root: json['root']?.toString() ?? '/',
      home: json['home']?.toString() ?? '/',
      platform: json['platform']?.toString() ?? '',
      separator: json['separator']?.toString() ?? '/',
      roots: _browseRootPaths(json['roots']),
      showHidden: json['showHidden'] == true,
      items: (json['items'] as List? ?? [])
          .map((e) => BrowseEntry.fromJson(e))
          .toList(),
      truncated: json['truncated'] == true,
      total: _intValue(json['total']) ?? 0,
      limit: _intValue(json['limit']) ?? 0,
    );
  }
}

class BrowseEntry {
  final String name;
  final String path;
  final String type;
  final bool isDirectory;
  final bool isFile;
  final bool isSymlink;
  final String? targetType;
  final String extension;
  final int? size;
  final int? modifiedAt;
  final int? createdAt;
  final bool? readable;
  final bool? writable;

  BrowseEntry({
    required this.name,
    required this.path,
    required this.type,
    required this.isDirectory,
    required this.isFile,
    required this.isSymlink,
    required this.extension,
    this.targetType,
    this.size,
    this.modifiedAt,
    this.createdAt,
    this.readable,
    this.writable,
  });

  factory BrowseEntry.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? '';
    final permissions = json['permissions'] is Map
        ? _stringKeyMap(json['permissions'] as Map)
        : const <String, dynamic>{};
    return BrowseEntry(
      name: json['name']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      type: type,
      isDirectory: json['isDirectory'] == true || type == 'directory',
      isFile: json['isFile'] == true || type == 'file',
      isSymlink: json['isSymlink'] == true || type == 'symlink',
      targetType: json['targetType']?.toString(),
      extension: json['extension']?.toString() ?? '',
      size: _intValue(json['size']),
      modifiedAt: _intValue(json['modifiedAt']),
      createdAt: _intValue(json['createdAt']),
      readable: _boolValue(permissions['readable']),
      writable: _boolValue(permissions['writable']),
    );
  }
}

class AttachmentData {
  final String name;
  final String mimeType;
  final String data; // base64 encoded

  AttachmentData({
    required this.name,
    required this.mimeType,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'mimeType': mimeType,
    'data': data,
  };
}

HubSnapshot _upsertEventInSnapshot(
  HubSnapshot snapshot,
  HubSnapshot? previousSnapshot,
  Map<String, dynamic> event,
) {
  final sessionId = event['sessionId']?.toString();
  if (sessionId == null || sessionId.isEmpty) return snapshot;
  final index = snapshot.sessions.indexWhere(
    (session) => session.id == sessionId,
  );
  if (index < 0) return snapshot;
  final payload = event['payload'] is Map
      ? _stringKeyMap(event['payload'] as Map)
      : <String, dynamic>{};
  HubItem? item;
  final type = event['type']?.toString() ?? '';
  if (payload['item'] is Map) {
    item = HubItem.fromJson(_stringKeyMap(payload['item'] as Map));
  } else if (type == 'session.message_update' && payload['text'] != null) {
    item = HubItem(
      id:
          event['id']?.toString() ??
          'live-${event['seq'] ?? DateTime.now().millisecondsSinceEpoch}',
      kind: 'assistant',
      role: 'assistant',
      timestamp:
          _intValue(event['timestamp']) ??
          DateTime.now().millisecondsSinceEpoch,
      text: payload['text'].toString(),
      metadata: const {},
      streaming: true,
    );
  }
  if (item == null) return snapshot;
  final session = snapshot.sessions[index];
  final priorSession = previousSnapshot?.sessions
      .where((candidate) => candidate.id == sessionId)
      .firstOrNull;
  final priorHistory = priorSession?.history ?? const <HubItem>[];
  var history = session.history;
  var liveMessage = session.liveMessage;
  if (type == 'session.message_update') {
    liveMessage = HubItem(
      id: item.id,
      kind: item.kind,
      role: item.role,
      timestamp: item.timestamp,
      text: item.text,
      metadata: item.metadata,
      streaming: true,
    );
  } else if (type == 'session.message_end' || type == 'session.input') {
    history = _upsertHistoryItemList(history, item, priorHistory: priorHistory);
    liveMessage = null;
  }
  final nextSessions = [...snapshot.sessions];
  nextSessions[index] = _copySession(
    session,
    history: history,
    liveMessage: liveMessage,
  );
  return HubSnapshot(
    server: snapshot.server,
    sessions: nextSessions,
    commands: snapshot.commands,
  );
}

List<HubItem> _upsertHistoryItemList(
  List<HubItem> history,
  HubItem item, {
  List<HubItem> priorHistory = const [],
}) {
  final next = [...history];
  final commandId = item.metadata['commandId']?.toString();
  var index = commandId == null || commandId.isEmpty
      ? -1
      : next.indexWhere(
          (existing) => existing.metadata['commandId']?.toString() == commandId,
        );
  if (index < 0) index = next.indexWhere((existing) => existing.id == item.id);
  if (index < 0 && item.kind == 'user') {
    index = next.indexWhere(
      (existing) =>
          existing.kind == 'user' && existing.text.trim() == item.text.trim(),
    );
  }
  if (index >= 0) {
    next[index] = item;
  } else {
    next.add(item);
  }
  for (final prior in priorHistory) {
    if (next.any((existing) => existing.id == prior.id)) continue;
    next.insert(0, prior);
  }
  next.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return next;
}

HubSession _copySession(
  HubSession session, {
  List<HubItem>? history,
  HubItem? liveMessage,
}) {
  return session.copyWith(history: history, liveMessage: liveMessage);
}

HubSnapshot _upsertCommandInSnapshot(HubSnapshot snapshot, HubCommand command) {
  final commands = [...snapshot.commands];
  final index = commands.indexWhere((current) => current.id == command.id);
  if (index >= 0) {
    commands[index] = command;
  } else {
    commands.add(command);
  }
  commands.sort(_compareCommands);
  final sessions = [
    for (final session in snapshot.sessions)
      if (command.sessionId == session.id)
        session.withActivity(
          commands: _upsertSessionCommand(session.commands, command),
        )
      else
        session,
  ];
  return HubSnapshot(
    server: snapshot.server,
    sessions: sessions,
    commands: commands,
  );
}

HubCommand _commandFromStreamData(Map<String, dynamic> data) {
  final command = _stringKeyMap(data['command'] as Map);
  command['sessionId'] ??= data['sessionId'];
  command['createdAt'] ??= command['timestamp'];
  return HubCommand.fromJson(command);
}

List<HubCommand> _upsertSessionCommand(
  List<HubCommand> commands,
  HubCommand command,
) {
  final next = [...commands];
  final index = next.indexWhere((current) => current.id == command.id);
  if (index >= 0) {
    next[index] = command;
  } else {
    next.add(command);
  }
  next.sort(_compareCommands);
  return next;
}

class HubHistoryPage {
  HubHistoryPage({
    required this.items,
    required this.offset,
    required this.total,
    required this.hasMore,
  });

  final List<HubItem> items;
  final int offset;
  final int total;
  final bool hasMore;

  factory HubHistoryPage.fromJson(Map<String, dynamic> json) {
    return HubHistoryPage(
      items: (json['items'] as List? ?? [])
          .whereType<Map>()
          .map((item) => HubItem.fromJson(_stringKeyMap(item)))
          .toList(),
      offset: _intValue(json['offset']) ?? 0,
      total: _intValue(json['total']) ?? 0,
      hasMore: json['hasMore'] == true,
    );
  }
}

int _compareCommands(HubCommand a, HubCommand b) {
  return (b.updatedAt ?? 0).compareTo(a.updatedAt ?? 0);
}

Map<String, dynamic> _stringKeyMap(Map value) {
  return value.map((key, value) => MapEntry(key.toString(), value));
}

List<String> _browseRootPaths(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map && item['path'] != null)
        item['path'].toString()
      else if (item != null)
        item.toString(),
  ];
}

bool? _boolValue(Object? value) {
  if (value is bool) return value;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return null;
}

int? _intValue(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
