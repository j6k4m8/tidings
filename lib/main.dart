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
    // flutter_widget_from_html 0.17.x triggers a flood of harmless assertions
    // about RenderBox.size being accessed during dry layout/baseline passes
    // inside table cells. Filter them all out.
    final msg = details.exception.toString();
    if (details.exception is AssertionError &&
        (msg.contains('computeDryLayout') ||
            msg.contains('computeDryBaseline') ||
            msg.contains('does not meet its constraints'))) {
      return;
    }
    upstream?.call(details);
  };

  runApp(const TidingsApp());
}
