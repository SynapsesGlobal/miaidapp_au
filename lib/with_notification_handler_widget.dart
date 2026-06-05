import 'package:after_layout/after_layout.dart';
import 'package:flutter/widgets.dart';

import 'notifications/notifications_handler.dart';

class WithNotificationHandlerWidget extends StatefulWidget {
  const WithNotificationHandlerWidget({
    Key? key,
    required this.child,
    required this.handler,
  }) : super(key: key);

  final Widget child;
  final NotificationHandler handler;

  @override
  State<StatefulWidget> createState() {
    return _WithNotificationHandlerWidgetState();
  }
}

class _WithNotificationHandlerWidgetState
    extends State<WithNotificationHandlerWidget>
    with AfterLayoutMixin<WithNotificationHandlerWidget> {
  @override
  void afterFirstLayout(BuildContext context) {
    widget.handler.setup(context);
  }

  @override
  Widget build(BuildContext context) {
    widget.handler.setup(context);
    return widget.child;
  }
}
