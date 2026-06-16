import 'package:flutter/material.dart';
import '../hub_client.dart';
import '../hub_models.dart';
import 'connection_screen.dart';
import 'session_list_screen.dart';
import 'session_detail_screen.dart';

class MissionControlScreen extends StatefulWidget {
  final TextEditingController serverController;
  final TextEditingController tokenController;
  final bool connecting;
  final bool connected;
  final String? connectionError;
  final String connectionState;
  final HubSnapshot? snapshot;
  final String? selectedSessionId;
  final String? detailSessionId;
  final HubSession? detailSession;
  final bool detailLoading;
  final bool detailLoadingOlder;
  final String? detailError;
  final VoidCallback onConnect;
  final ValueChanged<String> onOpenDetail;
  final VoidCallback onCloseDetail;
  final VoidCallback onLoadOlderHistory;
  final VoidCallback onRetryDetail;
  final ValueChanged<String> onSend;
  final VoidCallback? onAbort;
  final VoidCallback? onCompact;
  final VoidCallback? onShutdown;
  final ValueChanged<String>? onModelChanged;
  final Map<String, List<String>> recentSessionModels;
  final VoidCallback? onNewSession;
  final VoidCallback? onBroadcast;
  final VoidCallback? onDisconnect;
  final VoidCallback? onLogout;
  final HubClient client;
  final List<Map<String, String>> recentConnections;
  final ValueChanged<Map<String, String>>? onRecentConnection;

  const MissionControlScreen({
    super.key,
    required this.serverController,
    required this.tokenController,
    required this.connecting,
    required this.connected,
    this.connectionError,
    required this.connectionState,
    this.snapshot,
    this.selectedSessionId,
    this.detailSessionId,
    this.detailSession,
    this.detailLoading = false,
    this.detailLoadingOlder = false,
    this.detailError,
    required this.onConnect,
    required this.onOpenDetail,
    required this.onCloseDetail,
    required this.onLoadOlderHistory,
    required this.onRetryDetail,
    required this.onSend,
    this.onAbort,
    this.onCompact,
    this.onShutdown,
    this.onModelChanged,
    this.recentSessionModels = const {},
    this.onNewSession,
    this.onBroadcast,
    this.onDisconnect,
    this.onLogout,
    required this.client,
    this.recentConnections = const [],
    this.onRecentConnection,
  });

  @override
  State<MissionControlScreen> createState() => _MissionControlScreenState();
}

class _MissionControlScreenState extends State<MissionControlScreen> {
  @override
  Widget build(BuildContext context) {
    // Not connected: show connection screen
    if (!widget.connected) {
      return ConnectionScreen(
        serverController: widget.serverController,
        tokenController: widget.tokenController,
        connecting: widget.connecting,
        error: widget.connectionError,
        onConnect: widget.onConnect,
        recentConnections: widget.recentConnections,
        onRecentConnection: widget.onRecentConnection,
      );
    }

    // Detail selected: show cached thread immediately, then hydrate like a messenger.
    if (widget.detailSessionId != null) {
      final session = widget.detailSession;
      if (session != null) {
        return SessionDetailScreen(
          client: widget.client,
          session: session,
          availableModels: session.availableModels,
          loadingInitial: widget.detailLoading && !session.detailLoaded,
          loadingOlder: widget.detailLoadingOlder,
          loadError: widget.detailError,
          onLoadOlder: widget.onLoadOlderHistory,
          onRetryLoad: widget.onRetryDetail,
          onSend: widget.onSend,
          onAbort: widget.onAbort,
          onCompact: widget.onCompact,
          onShutdown: widget.onShutdown,
          onModelChanged: widget.onModelChanged,
          recentModelIds: widget.recentSessionModels[session.id] ?? const [],
          onBack: widget.onCloseDetail,
          connectionState: widget.connectionState,
          connected: widget.connected,
          onReconnect: widget.onConnect,
        );
      }
      return _DetailLoadingShell(
        error: widget.detailError,
        onBack: widget.onCloseDetail,
        onRetry: widget.onRetryDetail,
      );
    }

    // Default: session list
    return SessionListScreen(
      sessions: widget.snapshot?.sessions ?? [],
      connectionUrl: widget.serverController.text,
      onOpenSession: widget.onOpenDetail,
      onNewSession: widget.onNewSession,
      onBroadcast: widget.onBroadcast,
      onDisconnect: widget.onDisconnect,
      onLogout: widget.onLogout,
      connectionState: widget.connectionState,
      connected: widget.connected,
      onReconnect: widget.onConnect,
    );
  }
}

class _DetailLoadingShell extends StatelessWidget {
  const _DetailLoadingShell({
    required this.error,
    required this.onBack,
    required this.onRetry,
  });

  final String? error;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: onBack,
        ),
        title: const Text('Loading thread'),
      ),
      body: Center(
        child: error == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
      ),
    );
  }
}
