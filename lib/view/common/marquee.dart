import 'package:flutter/cupertino.dart';

class Marquee extends StatefulWidget {
  final Widget child;
  final Duration moveDuration;
  final double speed;
  final double moveDistance;
  final double maxWidth;

  const Marquee({
    Key? key,
    required this.child,
    this.speed = 1.0,
    this.moveDuration = const Duration(milliseconds: 1000),
    this.moveDistance = 10.0,
    required this.maxWidth,
  }) : super(key: key);

  @override
  MarqueeState createState() => MarqueeState();
}

class MarqueeState extends State<Marquee> with WidgetsBindingObserver {
  late ScrollController _scrollController;
  double _position = 0.0;

  int _lastItemCount = 1;
  int itemCount = 1;
  bool _appPaused = false;

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      startScroll();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void startScroll() {
    if (_position > 0) {
      _position %= widget.maxWidth;
      _scrollController.jumpTo(_position);
    }

    Future.doWhile(_scroll);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 앱이 백그라운드로 간 후 포그라운드로 올 때 배경이미지가 스크롤이 한번에 몰려서 되는 문제 수정을 위해서
    // 앱의 백그라운드 상태를 기록하고 활용한다
    if (state == AppLifecycleState.resumed) {
      _appPaused = false;
      startScroll();
    } else if (state == AppLifecycleState.paused) {
      _appPaused = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      addAutomaticKeepAlives: false,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Center(
          child: widget.child,
        );
      },
      scrollDirection: Axis.horizontal,
      controller: _scrollController,
      physics:
          const NeverScrollableScrollPhysics(), // not allow the user to scroll.
    );
  }

  Future<bool> _scroll() async {
    if (mounted && !_appPaused) {
      double moveDistance = widget.moveDistance * widget.speed;
      if (moveDistance > 0) {
        _position += moveDistance;
        _scrollController.animateTo(_position,
            duration: widget.moveDuration, curve: Curves.linear);
      }

      await Future.delayed(widget.moveDuration);

      if (mounted) {
        if (_position >= widget.maxWidth * 5) {
          _position = 0;
          _scrollController.jumpTo(0);
        }

        itemCount = (_position / widget.maxWidth).ceil() + 1;
        if (_lastItemCount != itemCount) {
          _lastItemCount = itemCount;
          setState(() {});
        }
      }
      return true;
    }
    return false;
  }
}
