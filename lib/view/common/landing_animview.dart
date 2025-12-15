import 'dart:async';
import 'dart:core';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '/common/util.dart';

class UpDownAnimationView extends StatefulWidget {
  final Duration? delay;
  final double? maxHeight;
  const UpDownAnimationView({this.delay, this.maxHeight, super.key});

  @override
  State<UpDownAnimationView> createState() => UpDownAnimationViewState();
}

class UpDownAnimationViewState extends State<UpDownAnimationView> {
  Size? screenSize;

  final random = math.Random();
  Timer? timer;
  int finishCount = 0;
  bool startShaking = false;

  void onFinishAnimation() {
    finishCount++;
    if (finishCount == 2) {
      setState(() {
        startShaking = true;
      });
    }
  }

  List<double> arrowImageAspectRatios = [2, 2];

  double getArrowHeight(double width) =>
      math.min(arrowImageAspectRatios[0] * width, screenSize!.height * 0.3);

  bool _upScaleReverse = false;

  int animateIndex = -1;
  double endScale = 0.9;
  double beginScale = 0.6;

  final images = ['assets/image/ARROW-DOWN2.png', 'assets/image/ARROW-UP2.png'];

  @override
  void initState() {
    super.initState();

    loadImageSize();
  }

  @override
  void dispose() {
    timer?.cancel();

    super.dispose();
  }

  Future loadImageSize() async {
    final arrowImageSizes =
        await Future.wait(images.map((e) => getImageSize(e)).toList());

    arrowImageAspectRatios = [
      arrowImageSizes[0].height / arrowImageSizes[0].width,
      arrowImageSizes[1].height / arrowImageSizes[1].width
    ];

    if (mounted) setState(() {});
  }

  double getHeightScale(double width) {
    final RenderBox? renderBox =
        imageKey.currentContext?.findRenderObject() as RenderBox?;
    double totalHeight = renderBox?.size.height ?? getArrowHeight(width) * 2;
    if (widget.maxHeight != null && totalHeight > widget.maxHeight!) {
      return widget.maxHeight! / totalHeight;
    }
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        screenSize = MediaQuery.of(context).size;

        double width = math.min(400, math.max(screenSize!.width / 4, 200));
        double heightScale = getHeightScale(width);
        width *= heightScale;
        return _buildImage(width);
      },
    );
  }

  final imageKey = GlobalKey();

  Widget _buildImage(double width) {
    return Row(
      spacing: 20,
      key: imageKey,
      children: [
        _buildFullUp(width),
        _buildFullDown(width),
      ],
    );
  }

  Widget _buildFullDown(double width) {
    double arrowHeight = getArrowHeight(width);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: !_upScaleReverse ? 1.1 : 0.9,
        end: !_upScaleReverse ? 0.9 : 1.1,
      ),
      curve: Curves.linear,
      duration: Duration(seconds: 1),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: Offset(0, -10),
                  child: Image.asset(
                    'assets/image/down_text.png',
                    height: arrowHeight * 0.15,
                  ),
                ),
                Transform.rotate(
                  angle: -math.pi / 12.0,
                  child: Image.asset(
                    'assets/image/ARROW-DOWN2.png',
                    width: width,
                    height: arrowHeight,
                  ),
                ),
                Transform.scale(
                  scaleX: animateIndex == 1 ? 1 : -1,
                  child: Transform.translate(
                    offset: Offset(0, -arrowHeight * 0.2),
                    child: Image.asset(
                      'assets/image/BEAR.png',
                      height: arrowHeight * 0.4,
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFullUp(double width) {
    double arrowHeight = getArrowHeight(width);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _upScaleReverse ? 1.1 : 0.9,
        end: _upScaleReverse ? 0.9 : 1.1,
      ),
      duration: Duration(seconds: 1),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: Offset(0, arrowHeight * 0.6 / 2),
                  child: Transform.scale(
                    scaleX: animateIndex == 0 ? -1 : 1,
                    child: Image.asset(
                      'assets/image/BULL2.png',
                      height: arrowHeight * 0.6,
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: math.pi / 12,
                  child: Image.asset(
                    'assets/image/ARROW-UP2.png',
                    width: width,
                    height: getArrowHeight(width),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, 10),
                  child: Image.asset(
                    'assets/image/up_text.png',
                    height: arrowHeight * 0.15,
                  ),
                )
              ],
            ),
          ),
        );
      },
      onEnd: () {
        setState(() {
          _upScaleReverse = !_upScaleReverse;
        });
      },
    );
  }
}

class RotateAnimationWidget extends StatefulWidget {
  final Widget child;
  final Duration? repeatPeriod;

  const RotateAnimationWidget({
    required this.child,
    this.repeatPeriod,
    super.key,
  });

  @override
  State<RotateAnimationWidget> createState() => _RotateAnimationWidgetState();
}

class _RotateAnimationWidgetState extends State<RotateAnimationWidget>
    with SingleTickerProviderStateMixin {
  bool doAniamte = true;

  Timer? timer;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    if (widget.repeatPeriod != null) {
      timer = Timer.periodic(widget.repeatPeriod!, (_) {
        if (mounted) {
          _controller.reset(); // 애니메이션을 처음 상태로 되돌림
          _controller.forward(); // 애니메이션 시작
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateY(_controller.value * 2 * 3.141592), // Y축 회전 (동전 플립)
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class MarqueeWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double width;
  final double? endPadding;

  const MarqueeWidget({
    Key? key,
    required this.child,
    this.duration = const Duration(seconds: 10),
    required this.width,
    this.endPadding,
  }) : super(key: key);

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget>
    with SingleTickerProviderStateMixin {
  late ScrollController scrollController;
  late AnimationController animationController;
  late Animation<double> animation;
  bool reverse = false;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _setupAnimation();

    animationController.forward();
  }

  void _setupAnimation() {
    animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: widget.width)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: widget.width, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50.0,
      ),
    ]).animate(animationController);

    animation.addListener(() {
      scrollController.jumpTo(animation.value % widget.width);
    });

    animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        animationController.repeat();
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: scrollController,
      child: Row(
        spacing: 20,
        children: [
          SizedBox(width: widget.endPadding ?? 0),
          ...List.generate(6, (_) => widget.child),
        ],
      ),
    );
  }
}
