// TODO Temporarily Disable no-sound-null-safety

import 'package:flutter/material.dart';
import 'package:miaid/utils/configure_dependencies.dart';

import 'main.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await configureDependencies(sandbox.name);

  await initFirebase();

  setupFlutterLocalNotifications();

  setLoggingLevelAll();

  runAppFromEnvironment();
}
