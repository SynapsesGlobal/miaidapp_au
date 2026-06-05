import 'package:intl/intl.dart';

String formatDate(DateTime date) =>
    DateFormat('d MMM yyyy hh:mma').format(date);
