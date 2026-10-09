import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// IO platforms: Android gets the native senyas/signcam PlatformView;
/// elsewhere shows the simulated-camera placeholder.
Widget buildCameraView(String? viewType, {required bool detecting}) {
  if (viewType != null && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidView(viewType: viewType);
  }
  return _SimCamPlaceholder(detecting: detecting);
}

class _SimCamPlaceholder extends StatelessWidget {
  final bool detecting;
  const _SimCamPlaceholder({required this.detecting});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: detecting ? 0.85 : 0.4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sign_language_rounded,
                size: 110,
                color: detecting ? AppColors.accent : Colors.white54),
            const SizedBox(height: 12),
            Text(
              detecting ? 'Simulated Camera' : 'Detection Paused',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
