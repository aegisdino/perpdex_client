import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '/common/string_ext.dart';
import '../styles.dart';
import '../theme.dart';

import '/data/providers.dart';

enum NoticeType {
  big, // 큰 알림 (좌하단)
  small, // 작은 알림 (우상단)
}

enum NoticePosition { lefttop, leftbottom, righttop, rightbottom }

class NoticeManager {
  factory NoticeManager() {
    if (_singleton == null) {
      _singleton = NoticeManager._internal();
    }
    return _singleton!;
  }

  static NoticeManager? _singleton;
  NoticeManager._internal();

  // 일반 알림 큐 (좌하단)
  List<NoticeMessageData> noticeBigQ = [];
  // 에러 알림 큐 (우상단)
  List<NoticeMessageData> noticeSmallQ = [];

  void addNotice({
    required NoticeType type,
    required String? title,
    required String message,
    Widget? leading,
    bool? error,
    Duration? duration,
    bool? showProgress,
  }) {
    final noticeData = NoticeMessageData(
      type: type,
      title: title ?? '',
      message: message,
      leading: leading,
      error: error,
      showProgress: showProgress,
      duration: duration ?? Duration(seconds: 3),
    );

    if (type == NoticeType.small) {
      noticeSmallQ.insert(0, noticeData);
    } else {
      noticeBigQ.insert(0, noticeData);
    }
    setUpdated();
  }

  void remove(NoticeMessageData data) {
    data.cancel();
    if (data.type == NoticeType.small) {
      noticeSmallQ.remove(data);
    } else {
      noticeBigQ.remove(data);
    }
    setUpdated();
  }

  void setUpdated() =>
      uncontrolledContainer.read(queueUpdatedProvider.notifier).state =
          DateTime.now();
}

class NoticeMessageData {
  final NoticeType type;
  final String title;
  final String message;
  final Duration duration;
  final Widget? leading;
  final bool? error;
  final bool? showProgress;

  late DateTime startTime;
  late DateTime endTime;
  bool isExpired = false;

  NoticeMessageData({
    required this.type,
    required this.title,
    required this.message,
    required this.duration,
    this.leading,
    this.error,
    this.showProgress,
  }) {
    startTime = DateTime.now();
    endTime = startTime.add(duration);
  }

  // Check if this bet is expired based on current time
  bool checkExpired() {
    if (isExpired) return true;

    if (DateTime.now().isBefore(endTime)) isExpired = true;
    return isExpired;
  }

  void cancel() {
    isExpired = true;
  }
}

class NoticeQueueView extends ConsumerStatefulWidget {
  final NoticeType type;
  final NoticePosition position;

  const NoticeQueueView({
    super.key,
    this.type = NoticeType.small,
    this.position = NoticePosition.leftbottom,
  });

  @override
  ConsumerState<NoticeQueueView> createState() => _NoticeQueueViewState();
}

class _NoticeQueueViewState extends ConsumerState<NoticeQueueView> {
  Timer? _timer;

  final _manager = NoticeManager();

  List<NoticeMessageData> get _queue {
    return widget.type == NoticeType.small
        ? _manager.noticeSmallQ
        : _manager.noticeBigQ;
  }

  bool get isSmallMode => widget.type == NoticeType.small;

  bool get isLeft =>
      widget.position == NoticePosition.leftbottom ||
      widget.position == NoticePosition.lefttop;

  bool get isTop =>
      widget.position == NoticePosition.lefttop ||
      widget.position == NoticePosition.righttop;

  double get minWidth => math.min(
      isSmallMode ? 150 : 300, MediaQuery.of(context).size.width * 0.9);
  double get maxWidth => math.min(
      isSmallMode ? 300 : 500, MediaQuery.of(context).size.width * 0.9);

  @override
  void initState() {
    super.initState();

    _startTimerIfNeeded();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimerIfNeeded() {
    if (_timer?.isActive == true || _queue.isEmpty) return;

    final now = DateTime.now();

    // 종료 시간 기준으로 오름차순 정렬 (가장 빨리 만료되는 항목이 먼저 오도록)
    final sortedNotices = [..._queue];

    sortedNotices..sort((a, b) => a.endTime.compareTo(b.endTime));
    final DateTime nextExpiryTime = sortedNotices.first.endTime;
    final remainDuration = nextExpiryTime.difference(now);

    if (remainDuration.inMilliseconds <= 0) {
      // 만료 시간이 이미 지났다면 즉시 처리한 후에 다시 시작
      _processExpiredItems();
    } else {
      _timer = Timer(remainDuration, () {
        _timer = null;
        _processExpiredItems();
      });
    }
  }

  void _processExpiredItems() {
    final DateTime now = DateTime.now();

    final expiredItems =
        _queue.where((item) => !item.endTime.isAfter(now)).toList();

    // Handle expired items
    for (var item in expiredItems) {
      item.isExpired = true;
      _manager.remove(item); // state provider로 알림
    }

    _startTimerIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(queueUpdatedProvider);
    _startTimerIfNeeded();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
        minWidth: minWidth,
        maxWidth: maxWidth,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: (isTop ? _queue.reversed : _queue)
              .map(
                (e) => Padding(
                  padding: EdgeInsets.only(
                    bottom: 5.0,
                  ),
                  child: isSmallMode ? _buildSmallItem(e) : _buildBigItem(e),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildSmallItem(NoticeMessageData data) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: data.error == true
            ? Color.fromARGB(255, 60, 30, 30)
            : Color.fromARGB(255, 11, 87, 31),
        border: Border.all(
            color: data.error == true
                ? Color.fromARGB(255, 120, 40, 40)
                : Color.fromARGB(255, 18, 111, 42)),
        borderRadius: BorderRadius.circular(0),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            child: Row(
              spacing: 4,
              children: [
                if (data.leading != null)
                  SizedBox(width: 70, child: Center(child: data.leading)),
                Expanded(
                  child: MyStyledText(
                    data.message,
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (data.showProgress == true)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CountdownProgressIndicator(
                        duration: data.duration, type: 'circular'),
                  ),
                _buildCloseIcon(data),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBigItem(NoticeMessageData data) {
    double height = 40;

    if (data.title.isNotNullEmptyOrWhitespace) height += 20;
    if (data.showProgress == true) height += 20;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border.all(color: Color.fromARGB(255, 70, 75, 85)),
        borderRadius: BorderRadius.circular(0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Row(children: [
                if (data.leading != null)
                  SizedBox(width: 70, child: Center(child: data.leading)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (data.title.isNotNullEmptyOrWhitespace)
                        MyStyledText(data.title,
                            style: AppTheme.bodyLargeBold
                                .copyWith(color: AppTheme.primary)),
                      MyStyledText(data.message,
                          style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.primary.withAlpha(200))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildCloseIcon(data),
                )
              ]),
            ),
            SizedBox(height: 10),
            if (data.showProgress == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  height: 5,
                  child: CountdownProgressIndicator(
                    duration: data.duration,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloseIcon(NoticeMessageData data) {
    return InkWell(
      onTap: () {
        NoticeManager().remove(data);
        setState(() {});
      },
      child: Icon(
        Icons.close,
        size: data.type == NoticeType.small ? 18 : 24,
        color: data.type == NoticeType.small ? Colors.white70 : null,
      ),
    );
  }
}

class CountdownProgressIndicator extends StatefulWidget {
  final Duration duration;
  final String type;

  const CountdownProgressIndicator({
    required this.duration,
    this.type = 'linear',
    Key? key,
  }) : super(key: key);

  @override
  State<CountdownProgressIndicator> createState() =>
      _CountdownProgressIndicatorState();
}

class _CountdownProgressIndicatorState extends State<CountdownProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // 애니메이션 컨트롤러 초기화
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // 1에서 0으로 감소하는 애니메이션 생성
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(_controller);

    // 애니메이션 시작
    _controller.forward();
  }

  @override
  void dispose() {
    // 컨트롤러 해제
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          child: widget.type == 'circular'
              ? CircularProgressIndicator(
                  value: _animation.value,
                  strokeWidth: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primary.withValues(alpha: 200)),
                )
              : LinearProgressIndicator(
                  value: _animation.value,
                  backgroundColor: Colors.black,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Color.fromARGB(0xff, 0x4B, 0x4E, 0x59)),
                ),
        );
      },
    );
  }
}
