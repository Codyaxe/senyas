import 'package:flutter/material.dart';
import '../../core/timing.dart';
import '../inference/model_paths.dart';
import '../inference/pipeline.dart';

/// Bottom sheet showing measured metrics only. "n/a" = not measured.
void showMetricsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const SafeArea(child: _MetricsView()),
  );
}

class _MetricsView extends StatelessWidget {
  const _MetricsView();

  static const _order = [
    'gemma_load', 'sign_e2e', 'gemma_sign_ttft', 'gemma_sign_total',
    'audio_recorded', 'whisper_load', 'whisper_transcribe', 'whisper_unload',
    'gemma_simplify_ttft', 'gemma_simplify_total', 'speech_e2e',
  ];

  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 13);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pipeline diagnostics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ValueListenableBuilder(
              valueListenable: pipeline.state,
              builder: (_, s, __) => Text(
                  'Router: ${s.name} · Gemma ${pipeline.gemmaReady.value ? 'resident' : 'not loaded'}'
                  ' · Whisper usable: ${pipeline.whisperUsable ?? 'untested'}',
                  style: mono),
            ),
            ValueListenableBuilder(
              valueListenable: pipeline.lastError,
              builder: (_, e, __) => e == null
                  ? const SizedBox.shrink()
                  : Text('Last error: ${e.code.name} — ${e.message}',
                      style: mono.copyWith(color: Colors.red)),
            ),
            FutureBuilder(
              future: ModelPaths.readiness(),
              builder: (_, snap) => Text(
                  snap.hasData ? 'Models: ${snap.data}' : 'Models: checking…',
                  style: mono),
            ),
            const Divider(),
            ValueListenableBuilder<Map<String, Metric>>(
              valueListenable: Metrics.latest,
              builder: (_, m, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final k in _order)
                    Text(m[k]?.toString() ?? '$k: n/a', style: mono),
                ],
              ),
            ),
            const Divider(),
            ValueListenableBuilder<Map<String, double?>>(
              valueListenable: Metrics.memoryMb,
              builder: (_, m, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Process RSS (total, not Dart heap):', style: mono),
                  if (m.isEmpty) const Text('  n/a', style: mono),
                  for (final e in m.entries)
                    Text('  ${e.key}: ${e.value?.toStringAsFixed(0) ?? 'n/a'} MB',
                        style: mono),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
