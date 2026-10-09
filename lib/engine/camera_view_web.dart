import 'package:flutter/material.dart';

/// Web: the camera preview is an HtmlElementView whose DOM is built by
/// SenyasBridge.mountCamera (video + landmark overlay canvas).
Widget buildCameraView(String? viewType, {required bool detecting}) {
  return HtmlElementView(viewType: viewType ?? 'senyas-cam');
}
