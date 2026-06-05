// TODO Temporarily Disable no-sound-null-safety

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/utils/configure_dependencies.dart';

import 'main.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies(dev.name);

  await initFirebase();
  await runAppFromEnvironment();

  setupFlutterLocalNotifications();

  setLoggingLevelAll();
}
