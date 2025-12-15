import 'package:flutter/material.dart';

class NotificationEx extends Notification {
  String cmd;
  int? value;

  NotificationEx(this.cmd, {this.value});

  static notify(
    String cmd,
    BuildContext context, {
    int? value,
  }) {
    NotificationEx(
      cmd,
      value: value,
    ).dispatch(context);
  }
}
