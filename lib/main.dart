import 'package:flutter/material.dart';

import 'app/tidings_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // flutter_widget_from_html has an upstream bug where images inside table
  // cells trigger a "RenderBox.size accessed before layout" assertion in
  // RenderAspectRatio.computeDryLayout. The assertion is harmless — layout
  // and rendering are correct — but it floods the debug console. Filter it
  // out globally until the upstream fix lands.
  final upstream = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final isAspectRatioDryLayout =
        details.exception is AssertionError &&
        details.stack.toString().contains('computeDryLayout');
    if (!isAspectRatioDryLayout) {
      upstream?.call(details);
    }
  };

  runApp(const TidingsApp());
}
