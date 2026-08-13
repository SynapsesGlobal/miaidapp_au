// TODO Temporarily Disable no-sound-null-safety

import 'package:injectable/injectable.dart';

import 'main.dart';

void main() async {
  // ignore: avoid_print
  print('[ENV-CHECK] entrypoint=main_dev env=${dev.name}');
  await bootstrap(dev.name);
}
