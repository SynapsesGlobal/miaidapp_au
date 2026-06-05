
import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

part 'otp_store.g.dart';

@injectable
class OtpStore = _OtpStore with _$OtpStore;

abstract class _OtpStore with Store {}
