import 'package:flutter/material.dart';

import 'widgets/notice_queue_view.dart';

void addBigNotice({
  String? title,
  required String message,
  Widget? leading,
  double? seconds,
  bool showProgress = true,
}) {
  NoticeManager().addNotice(
    type: NoticeType.big,
    title: title,
    message: message,
    duration: Duration(milliseconds: ((seconds ?? 3) * 1000).toInt()),
    leading: leading,
    showProgress: showProgress,
  );
}

void addNotice({
  required String message,
  double? seconds,
  bool? error = false,
  bool showProgress = true,
}) {
  NoticeManager().addNotice(
    type: NoticeType.small,
    title: '', // 에러는 타이틀 없음
    message: message,
    error: error,
    showProgress: showProgress,
    duration: Duration(milliseconds: ((seconds ?? 3) * 1000).toInt()),
  );
}
