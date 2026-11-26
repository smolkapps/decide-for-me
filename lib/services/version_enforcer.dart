import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VersionPolicy {
  final String appId;
  final String minSupportedVersion;
  final String latestVersion;
  final List<String> blockedVersions;
  final bool maintenanceMode;
  final String? maintenanceTitle;
  final String? maintenanceMessage;
  final String storeUrlIos;
  final String storeUrlAndroid;
  final String storeUrlFallback;
  final String? hardUpdateTitle;
  final String? hardUpdateMessage;
  final String? softUpdateTitle;
  final String? softUpdateMessage;

  const VersionPolicy({
    this.appId = '',
    required this.minSupportedVersion,
    required this.latestVersion,
    this.blockedVersions = const [],
    this.maintenanceMode = false,
    this.maintenanceTitle,
    this.maintenanceMessage,
    this.storeUrlIos = '',
    this.storeUrlAndroid = '',
    this.storeUrlFallback = '',
    this.hardUpdateTitle,
    this.hardUpdateMessage,
    this.softUpdateTitle,
    this.softUpdateMessage,
  });

  factory VersionPolicy.fromJson(Map<String, dynamic> json) {
    final minSupported = json['min_supported_version'];
    final latest = json['latest_version'];
    if (minSupported is! String || latest is! String) {
      throw const FormatException('Missing required version policy fields');
    }
    return VersionPolicy(
      appId: json['app_id'] as String? ?? '',
      minSupportedVersion: minSupported,
      latestVersion: latest,
      blockedVersions: (json['blocked_versions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
      maintenanceTitle: json['maintenance_title'] as String?,
      maintenanceMessage: json['maintenance_message'] as String?,
      storeUrlIos: json['store_url_ios'] as String? ?? '',
      storeUrlAndroid: json['store_url_android'] as String? ?? '',
      storeUrlFallback: json['store_url_fallback'] as String? ?? '',
      hardUpdateTitle: json['hard_update_title'] as String?,
      hardUpdateMessage: json['hard_update_message'] as String?,
      softUpdateTitle: json['soft_update_title'] as String?,
      softUpdateMessage: json['soft_update_message'] as String?,
    );
  }
}

enum VersionEnforcementMode {
  none,
  softUpdate,
  hardUpdate,
  maintenance,
}

@immutable
class VersionEnforcementState {
  final VersionEnforcementMode mode;
  final String title;
  final String message;
  final String? latestVersion;
  final String? storeUrl;
  final String? fallbackUrl;
  final bool showUpdateButton;

  const VersionEnforcementState({
    required this.mode,
    this.title = '',
    this.message = '',
    this.latestVersion,
    this.storeUrl,
    this.fallbackUrl,
    this.showUpdateButton = false,
  });

  const VersionEnforcementState.none() : this(mode: VersionEnforcementMode.none);

  bool get isRequiredBlock =>
      mode == VersionEnforcementMode.hardUpdate ||
      mode == VersionEnforcementMode.maintenance;

  bool get isVisible => mode != VersionEnforcementMode.none;
}

class VersionEnforcer with WidgetsBindingObserver {
  static const MethodChannel _channel =
      MethodChannel('org.smolkin.version_enforcer');
  static const Duration requestTimeout = Duration(seconds: 3);

  final Uri policyUri;
  final String appName;
  final String defaultAppVersion;
  final String defaultStoreUrl;
  final Future<Map<String, dynamic>?> Function(Uri uri)? _customPolicyLoader;
  final Future<String?> Function()? _appVersionLoader;
  final Future<bool> Function(Uri uri)? _urlLauncher;
  final DateTime Function() _clock;
  final Duration _resumeThrottle;
  final bool? _isIosOverride;

  final ValueNotifier<VersionEnforcementState> state =
      ValueNotifier(const VersionEnforcementState.none());

  DateTime? _lastChecked;
  bool _observing = false;
  bool _checkInFlight = false;
  bool _disposed = false;
  String? _dismissedSoftVersion;

  VersionEnforcer({
    required this.policyUri,
    required this.appName,
    required this.defaultAppVersion,
    required this.defaultStoreUrl,
    Future<Map<String, dynamic>?> Function(Uri uri)? policyLoader,
    Future<String?> Function()? appVersionLoader,
    Future<bool> Function(Uri uri)? urlLauncher,
    DateTime Function()? clock,
    Duration resumeThrottle = const Duration(minutes: 15),
    bool? isIosOverride,
  })  : _customPolicyLoader = policyLoader,
        _appVersionLoader = appVersionLoader,
        _urlLauncher = urlLauncher,
        _clock = clock ?? DateTime.now,
        _resumeThrottle = resumeThrottle,
        _isIosOverride = isIosOverride;

  void start() {
    if (_disposed) return;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    unawaited(check(force: true));
  }

  void dispose() {
    _disposed = true;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    state.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = _clock();
      if (_lastChecked == null ||
          now.difference(_lastChecked!) > _resumeThrottle) {
        unawaited(check());
      }
    }
  }

  bool get _isTestEnvironment {
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    return bindingName.contains('TestWidgetsFlutterBinding') ||
        Platform.environment.containsKey('FLUTTER_TEST');
  }

  Future<String> _resolveAppVersion() async {
    try {
      final loader = _appVersionLoader;
      if (loader == null && _isTestEnvironment) {
        return defaultAppVersion;
      }
      final loaded = loader != null
          ? await loader().timeout(requestTimeout)
          : await _channel
              .invokeMethod<String>('getAppVersion')
              .timeout(requestTimeout);
      if (loaded != null && loaded.trim().isNotEmpty) {
        return loaded.trim();
      }
    } catch (_) {
      // Fall back to the bundled version constant when native metadata is unavailable.
    }
    return defaultAppVersion;
  }

  Future<Map<String, dynamic>?> _fetchPolicyJson() async {
    final customLoader = _customPolicyLoader;
    if (customLoader != null) {
      return customLoader(policyUri).timeout(requestTimeout);
    }
    final client = HttpClient();
    client.connectionTimeout = requestTimeout;
    try {
      final request = await client.getUrl(policyUri).timeout(requestTimeout);
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(requestTimeout);
      if (response.statusCode != HttpStatus.ok) return null;
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(requestTimeout);
      if (body.length > 65536) return null;
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> check({bool force = false}) async {
    if (_disposed || _checkInFlight) return;
    if (_customPolicyLoader == null && _isTestEnvironment) return;
    if (!force &&
        _lastChecked != null &&
        _clock().difference(_lastChecked!) < _resumeThrottle) {
      return;
    }
    _checkInFlight = true;
    _lastChecked = _clock();
    try {
      final current = await _resolveAppVersion();
      if (_disposed) return;
      final raw = await _fetchPolicyJson();
      if (_disposed || raw == null) return;
      final policy = VersionPolicy.fromJson(raw);
      final next = evaluate(policy, current);
      if (!_disposed) {
        state.value = next;
      }
    } catch (_) {
      // Fail-open when offline, timed out, or receiving invalid remote policy.
    } finally {
      _checkInFlight = false;
    }
  }

  VersionEnforcementState evaluate(VersionPolicy policy, String current) {
    if (policy.maintenanceMode) {
      return VersionEnforcementState(
        mode: VersionEnforcementMode.maintenance,
        title: policy.maintenanceTitle ?? 'Scheduled Maintenance',
        message: policy.maintenanceMessage ??
            '$appName is undergoing scheduled maintenance. Please check back shortly.',
        showUpdateButton: false,
      );
    }

    final isIos =
        _isIosOverride ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);
    final storeUrl = isIos ? policy.storeUrlIos : policy.storeUrlAndroid;
    final fallbackUrl = policy.storeUrlFallback.isNotEmpty
        ? policy.storeUrlFallback
        : defaultStoreUrl;
    final hasStore = storeUrl.isNotEmpty || fallbackUrl.isNotEmpty;

    final isBlocked = policy.blockedVersions.contains(current);
    final isOutdated =
        compareSemVer(current, policy.minSupportedVersion) < 0;

    if (isBlocked || isOutdated) {
      return VersionEnforcementState(
        mode: VersionEnforcementMode.hardUpdate,
        title: policy.hardUpdateTitle ?? 'Update Required',
        message: policy.hardUpdateMessage ??
            'Your installed version of $appName ($current) is no longer supported. Please update to continue.',
        storeUrl: storeUrl,
        fallbackUrl: fallbackUrl,
        showUpdateButton: hasStore,
      );
    }

    if (compareSemVer(current, policy.latestVersion) < 0 &&
        _dismissedSoftVersion != policy.latestVersion) {
      return VersionEnforcementState(
        mode: VersionEnforcementMode.softUpdate,
        title: policy.softUpdateTitle ?? 'New Version Available',
        message: policy.softUpdateMessage ??
            'A newer version of $appName (${policy.latestVersion}) is available. Would you like to update?',
        latestVersion: policy.latestVersion,
        storeUrl: storeUrl,
        fallbackUrl: fallbackUrl,
        showUpdateButton: hasStore,
      );
    }

    return const VersionEnforcementState.none();
  }

  void dismissSoftUpdate(String? version) {
    if (version != null && version.isNotEmpty) {
      _dismissedSoftVersion = version;
    }
    if (!_disposed && state.value.mode == VersionEnforcementMode.softUpdate) {
      state.value = const VersionEnforcementState.none();
    }
  }

  Future<bool> openStore(VersionEnforcementState enforcement) async {
    for (final raw in [
      enforcement.storeUrl,
      enforcement.fallbackUrl,
      defaultStoreUrl,
    ]) {
      if (raw == null || raw.trim().isEmpty) continue;
      final uri = Uri.tryParse(raw.trim());
      if (uri == null) continue;
      try {
        final launcher = _urlLauncher;
        if (launcher != null) {
          if (await launcher(uri)) return true;
        } else {
          final opened = await _channel
              .invokeMethod<bool>('openUrl', {'url': uri.toString()});
          if (opened == true) return true;
        }
      } catch (_) {
        // Try fallback URL next.
      }
    }
    return false;
  }

  static int compareSemVer(String v1, String v2) {
    List<int> parse(String raw) {
      final clean = raw
          .trim()
          .replaceFirst(RegExp(r'^[vV]'), '')
          .split(RegExp(r'[+-]'))
          .first;
      return clean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    }

    final p1 = parse(v1);
    final p2 = parse(v2);
    final maxLen = p1.length > p2.length ? p1.length : p2.length;
    for (var i = 0; i < maxLen; i++) {
      final a = i < p1.length ? p1[i] : 0;
      final b = i < p2.length ? p2[i] : 0;
      if (a < b) return -1;
      if (a > b) return 1;
    }
    return 0;
  }
}

class VersionEnforcerGate extends StatefulWidget {
  final Uri policyUri;
  final String appName;
  final String defaultAppVersion;
  final String defaultStoreUrl;
  final VersionEnforcer? enforcer;
  final Widget child;

  const VersionEnforcerGate({
    super.key,
    required this.policyUri,
    required this.appName,
    required this.defaultAppVersion,
    required this.defaultStoreUrl,
    this.enforcer,
    required this.child,
  });

  @override
  State<VersionEnforcerGate> createState() => _VersionEnforcerGateState();
}

class _VersionEnforcerGateState extends State<VersionEnforcerGate> {
  VersionEnforcer? _ownedEnforcer;
  bool _openingStore = false;
  String? _launchError;

  VersionEnforcer get _effectiveEnforcer => widget.enforcer ?? _ownedEnforcer!;

  @override
  void initState() {
    super.initState();
    if (widget.enforcer == null) {
      _ownedEnforcer = VersionEnforcer(
        policyUri: widget.policyUri,
        appName: widget.appName,
        defaultAppVersion: widget.defaultAppVersion,
        defaultStoreUrl: widget.defaultStoreUrl,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _effectiveEnforcer.start();
    });
  }

  @override
  void didUpdateWidget(VersionEnforcerGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enforcer != widget.enforcer) {
      _ownedEnforcer?.dispose();
      _ownedEnforcer = null;
      if (widget.enforcer == null) {
        _ownedEnforcer = VersionEnforcer(
          policyUri: widget.policyUri,
          appName: widget.appName,
          defaultAppVersion: widget.defaultAppVersion,
          defaultStoreUrl: widget.defaultStoreUrl,
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _effectiveEnforcer.start();
      });
    }
  }

  @override
  void dispose() {
    _ownedEnforcer?.dispose();
    super.dispose();
  }

  Future<void> _handleOpenStore(VersionEnforcementState enforcement) async {
    if (_openingStore) return;
    setState(() {
      _openingStore = true;
      _launchError = null;
    });
    final ok = await _effectiveEnforcer.openStore(enforcement);
    if (mounted) {
      setState(() {
        _openingStore = false;
        if (!ok) {
          _launchError = 'Could not open the store page. Please try again.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VersionEnforcementState>(
      valueListenable: _effectiveEnforcer.state,
      builder: (context, enforcement, _) {
        final blocked = enforcement.isRequiredBlock;
        final visible = enforcement.isVisible;
        final isMaintenance =
            enforcement.mode == VersionEnforcementMode.maintenance;

        return Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              excluding: visible,
              child: ExcludeFocus(
                excluding: visible,
                child: AbsorbPointer(
                  absorbing: visible,
                  child: widget.child,
                ),
              ),
            ),
            if (blocked)
              Positioned.fill(
                child: PopScope(
                  canPop: false,
                  child: Material(
                    color: const Color(0xFF121212),
                    child: SafeArea(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isMaintenance
                                    ? Icons.build_circle_rounded
                                    : Icons.system_update_rounded,
                                size: 72,
                                color: isMaintenance
                                    ? Colors.amber
                                    : Colors.blueAccent,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                enforcement.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                enforcement.message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.white70,
                                  height: 1.4,
                                ),
                              ),
                              if (_launchError != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _launchError!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                              if (enforcement.showUpdateButton) ...[
                                const SizedBox(height: 28),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _openingStore
                                        ? null
                                        : () => _handleOpenStore(enforcement),
                                    child: const Text('Update Now'),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () =>
                                    unawaited(_effectiveEnforcer.check(force: true)),
                                child: const Text('Check Again'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else if (enforcement.mode == VersionEnforcementMode.softUpdate) ...[
              const ModalBarrier(dismissible: false, color: Colors.black54),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AlertDialog(
                      title: Text(enforcement.title),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(enforcement.message),
                          if (_launchError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _launchError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            setState(() => _launchError = null);
                            _effectiveEnforcer
                                .dismissSoftUpdate(enforcement.latestVersion);
                          },
                          child: const Text('Not Now'),
                        ),
                        if (enforcement.showUpdateButton)
                          FilledButton(
                            onPressed: _openingStore
                                ? null
                                : () => _handleOpenStore(enforcement),
                            child: const Text('Update'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
