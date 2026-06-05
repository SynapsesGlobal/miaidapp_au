import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'configure_dependencies.config.dart';
import 'dart:developer' as developer;
const sandbox = Environment('sandbox');

final getIt = GetIt.I;

@InjectableInit()
Future<GetIt> configureDependencies(
  String environment,
) async {
  //developer.log('Configuring dependencies for environment: $environment');
  return await $initGetIt(
    getIt,
    environment: environment,
  );
}
