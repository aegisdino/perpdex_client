import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
export 'package:confetti/confetti.dart';

import '../view/common/commonview.dart';
import '/common/util.dart';

class CircleUserView extends StatefulWidget {
  final String? nickName;
  final double? betAmount;
  final String? profileImage;
  final Color? nameColor;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final bool? locked;
  final String? currency;
  final bool? scaleDownOverflow;

  const CircleUserView({
    this.nickName,
    this.betAmount,
    this.profileImage,
    this.nameColor,
    this.color,
    this.backgroundColor,
    required this.size,
    this.locked,
    this.currency,
    this.scaleDownOverflow = true,
    super.key,
  });

  @override
  State<CircleUserView> createState() => _CircleUserViewState();
}

class _CircleUserViewState extends State<CircleUserView> {
  Color get color => widget.color ?? Colors.green;

  @override
  Widget build(BuildContext context) {
    return _doAnimation(true, _buildCircleAvatar());
  }

  Widget _buildCircleAvatar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.backgroundColor,
            border: Border.all(
              color: color,
            ),
          ),
          child: ClipOval(
            child: _buildContent(),
          ),
        ),
        if (widget.nickName.isNotNullEmptyOrWhitespace &&
            widget.profileImage.isNotNullEmptyOrWhitespace)
          SizedBox(
            width: widget.size,
            child: Center(
              child: widget.scaleDownOverflow == true
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        children: [
                          Text(
                            widget.nickName!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: widget.nameColor ?? Colors.white),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      widget.nickName!,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: widget.nameColor ?? Colors.white),
                    ),
            ),
          ),
        if (widget.betAmount != null)
          CoinNumberView(
            '${widget.betAmount}',
            ticker: widget.currency,
            style: TextStyle(
                fontSize: math.min(18, math.max(12, widget.size * 0.3)),
                color: color),
            iconSize: 10,
          ),
      ],
    );
  }

  Widget _doAnimation(bool isNew, Widget child) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 1000),
      curve: Curves.easeOutBack,
      tween: Tween(begin: isNew ? 0.0 : 1.0, end: 1.0),
      builder: (context, value, child) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateY(isNew ? value * 2 * 3.141592 : 0), // Y축 회전 (동전 플립)
          //..scale(isNew ? 0.2 + (0.8 * value) : 1.0), // 크기 변화
          child: child,
        );
      },
      child: child,
    );
  }

  Widget _buildContent() {
    if (widget.profileImage.isNotNullEmptyOrWhitespace) {
      return Image.asset('assets/avatars/${widget.profileImage!}');
    } else {
      return Padding(
        padding: const EdgeInsets.all(1.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue[200],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              widget.nickName ?? '',
            ),
          ),
        ),
      );
    }
  }
}

class CoinNumberView extends StatefulWidget {
  final String amount;
  final TextStyle? style;
  final double? iconSize;
  final String? ticker;
  final bool? center;

  const CoinNumberView(
    this.amount, {
    this.style,
    this.iconSize,
    this.ticker,
    this.center,
    super.key,
  });

  @override
  State<CoinNumberView> createState() => _CoinNumberViewState();
}

class _CoinNumberViewState extends State<CoinNumberView> {
  static Map<String, String> tickerMap = {
    'USDT': 'usdt',
    'SOL': 'sol2',
    'gold': 'gold'
  };

  String get icon => tickerMap[widget.ticker] ?? 'usdt';

  late String amount;

  @override
  void initState() {
    super.initState();

    _updateAmount();
  }

  @override
  void didUpdateWidget(CoinNumberView oldWidget) {
    if (widget.amount != oldWidget.amount ||
        widget.ticker != oldWidget.ticker) {
      _updateAmount();
    }
    super.didUpdateWidget(oldWidget);
  }

  void _updateAmount() {
    final amountDouble = double.parse(widget.amount);
    bool showAsInt = amountDouble == double.parse(widget.amount.split('.')[0]);
    if (showAsInt) {
      amount = showAsInt ? amountDouble.toStringAsFixed(0) : widget.amount;
    } else {
      amount = widget.amount.replaceAll(RegExp(r'\.?0*$'), '');
    }
  }

  Widget build(BuildContext context) {
    double iconSize = widget.iconSize ?? 12;
    return Row(
      mainAxisAlignment: widget.center == true
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Image.asset('assets/image/${icon}.png', width: iconSize),
        SizedBox(width: 4),
        Text(amount, style: widget.style)
      ],
    );
  }
}

class CelebrationWidget extends StatefulWidget {
  final Function(ConfettiController)? onInit;
  CelebrationWidget({this.onInit, super.key});

  @override
  CelebrationWidgetState createState() => CelebrationWidgetState();
}

Path createParticlePath(Size size) {
  // 하트 모양 파티클
  final path = Path();
  path.moveTo(size.width / 2, size.height / 5);
  path.cubicTo(
    size.width / 2,
    size.height / 3,
    size.width / 4,
    size.height / 3,
    size.width / 4,
    size.height / 2,
  );
  path.cubicTo(
    size.width / 4,
    size.height * 2 / 3,
    size.width / 2,
    size.height * 2 / 3,
    size.width / 2,
    size.height * 4 / 5,
  );
  path.cubicTo(
    size.width / 2,
    size.height * 2 / 3,
    size.width * 3 / 4,
    size.height * 2 / 3,
    size.width * 3 / 4,
    size.height / 2,
  );
  path.cubicTo(
    size.width * 3 / 4,
    size.height / 3,
    size.width / 2,
    size.height / 3,
    size.width / 2,
    size.height / 5,
  );
  return path;
}

class CelebrationWidgetState extends State<CelebrationWidget> {
  late ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(seconds: 2));
    widget.onInit?.call(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 기존 UI
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _controller,
            blastDirection: math.pi / 2, // 아래 방향 (pi/2 라디안 = 90도)
            maxBlastForce: 5, // 입자가 튀어나가는 최대 힘
            minBlastForce: 2, // 입자가 튀어나가는 최소 힘
            emissionFrequency: 0.05, // 입자 방출 빈도
            numberOfParticles: 50, // 입자 수
            gravity: 0.1, // 중력 (낮을수록 천천히 떨어짐)
            shouldLoop: false, // 반복 여부
            colors: const [
              // 입자 색상
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple
            ],
            // 추가 커스터마이징
            createParticlePath: createParticlePath,
          ),
        ),
      ],
    );
  }

  // 승리했을 때 호출
  void celebrate() {
    _controller.play();
  }

  void stop() {
    _controller.stop();
  }
}

class LimitedFittedText extends StatelessWidget {
  final String text;
  final double maxTextSize;
  final TextStyle? style;
  final TextAlign? textAlign;

  const LimitedFittedText({
    Key? key,
    required this.text,
    required this.maxTextSize,
    this.style,
    this.textAlign,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth,
            maxHeight: constraints.maxHeight,
          ),
          child: Text(
            text,
            textAlign: textAlign,
            style: (style ?? const TextStyle()).copyWith(
              fontSize: maxTextSize,
            ),
          ),
        ),
      );
    });
  }
}

class ColoredAssetImage extends StatelessWidget {
  final String imagePath;
  final double? width;
  final double? height;
  final Color? color;

  const ColoredAssetImage(this.imagePath,
      {this.width, this.height, this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0,
        0,
        0,
        1,
        0
      ]),
      child: Image.asset(
        imagePath,
        width: width,
        height: height,
        color: color ?? Colors.grey,
        colorBlendMode: BlendMode.modulate,
      ),
    );
  }
}

class UpDownIcon extends StatelessWidget {
  final double? basePrice;
  final double? endPrice;
  final int? udIndex;
  final double? size;
  final Color? color;
  final Color? iconColor;

  const UpDownIcon({
    this.basePrice,
    this.endPrice,
    this.udIndex,
    this.size,
    this.color,
    this.iconColor,
    super.key,
  });

  static List<Color> colors = [
    Colors.grey,
    AppTheme.upColor,
    AppTheme.downColor
  ];

  static List<Color> iconColors = [Colors.black, Colors.black, Colors.white];
  static List<String> icons = [
    'assets/image/minus.png',
    'assets/image/uparrow.png',
    'assets/image/downarrow.png',
  ];

  int get upDownIndex =>
      udIndex ??
      ((basePrice ?? 0) < (endPrice ?? 0)
          ? 1
          : (basePrice ?? 0) > (endPrice ?? 0)
              ? 2
              : 0);

  @override
  Widget build(BuildContext context) {
    final colorIndex = upDownIndex;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 1, 1, 1),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? colors[colorIndex],
        ),
        width: size ?? 20,
        height: size ?? 20,
        child: Center(
          child: Image.asset(
            icons[colorIndex],
            color: iconColor ?? iconColors[colorIndex],
            width: (size ?? 20) * 0.7,
          ),
        ),
      ),
    );
  }
}

class CircularBoxContainer extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? borderColor;
  final double? thickness;
  final double? width;
  final double? height;
  final double? borderRadius;

  const CircularBoxContainer({
    required this.child,
    this.color,
    this.thickness,
    this.width,
    this.height,
    this.borderColor,
    this.borderRadius,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius ?? 16),
        color: color,
        border: Border.all(
          width: thickness ?? 1,
          color: borderColor ?? color ?? Colors.transparent,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

class HoverClickTooltip extends StatefulWidget {
  final Widget child;
  final Widget tooltipWidget;
  final bool showOnHover;
  final bool showOnClick;
  final double? width;
  final Offset? offset;

  HoverClickTooltip({
    required this.child,
    required this.tooltipWidget,
    this.width,
    this.offset,
    this.showOnHover = true,
    this.showOnClick = true,
  });

  @override
  _HoverClickTooltipState createState() => _HoverClickTooltipState();
}

class _HoverClickTooltipState extends State<HoverClickTooltip> {
  bool isTooltipVisible = false;
  OverlayEntry? overlayEntry;
  final LayerLink layerLink = LayerLink();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: layerLink,
      child: MouseRegion(
        onEnter: widget.showOnHover ? (_) => showTooltip() : null,
        onExit: widget.showOnHover ? (_) => hideTooltip() : null,
        child: GestureDetector(
          onTapDown: widget.showOnClick ? (_) => showTooltip() : null,
          onTapUp: widget.showOnClick ? (_) => hideTooltip() : null,
          onTapCancel: widget.showOnClick ? () => hideTooltip() : null,
          child: widget.child,
        ),
      ),
    );
  }

  void showTooltip() {
    if (overlayEntry != null) return;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: widget.width ?? 100,
        child: CompositedTransformFollower(
          link: layerLink,
          offset: widget.offset ?? Offset(0, 0), // 툴팁 위치 조정
          followerAnchor: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: widget.tooltipWidget,
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry!);
  }

  void hideTooltip() {
    overlayEntry?.remove();
    overlayEntry = null;
  }

  @override
  void dispose() {
    hideTooltip();
    super.dispose();
  }
}

class ConnectWalletButton extends StatelessWidget {
  final double? width;
  ConnectWalletButton({this.width, super.key});

  @override
  Widget build(BuildContext context) {
    // final needConnectWallet = (_game.myInfo!.isGuest ||
    //     _game.passwordLocked ||
    //     _game.walletService.connectedAddress == null);

    // if (needConnectWallet)
    //   return _buildButton(
    //       _game.isCoinGame
    //           ? 'bitgame.connectwallet'.tr()
    //           : 'bitgame.signin'.tr(), () async {
    //     await _game.connectWallet();
    //   });
    // else if (_game.isIdPassAccount && !_game.passwordLocked)
    //   return _buildButton('bitgame.charge'.tr(), () async {
    //     openCryptoChargeDialog(context);
    //   });
    return Container();
  }

  Widget _buildButton(String text, Function()? onPressed) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: width ?? 135,
            height: 40,
            child: MyButton(
              text: text,
              buttonColor: const ui.Color.fromARGB(255, 183, 105, 16),
              borderRadius: 10,
              onPressed: onPressed,
            ),
          ),
        ],
      ),
    );
  }
}

class WinStreakWidget extends StatefulWidget {
  final int winStreak;

  WinStreakWidget({required this.winStreak});

  @override
  _WinStreakWidgetState createState() => _WinStreakWidgetState();
}

class _WinStreakWidgetState extends State<WinStreakWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(covariant WinStreakWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.winStreak != oldWidget.winStreak) {
      if (widget.winStreak == 0) {
        _controller.reverse().then((_) {
          if (mounted) setState(() {});
        });
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextStyle get style => AppTheme.bodySmall.copyWith(color: Colors.white);
  TextStyle get styleSmall =>
      AppTheme.bodySmall.copyWith(color: Colors.white, fontSize: 10);

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: widget.winStreak > 0 || _controller.isAnimating,
      child: FadeTransition(
        opacity: _animation,
        child: HoverClickTooltip(
          offset: Offset(0, 100),
          width: 200,
          tooltipWidget: CircularBoxContainer(
            width: 200,
            color: const ui.Color.fromARGB(255, 25, 24, 24),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('5연승: 잭팟 금액의 50%\n10연승: 잭팟 금액의 100%', style: style),
                  SizedBox(height: 5),
                  Text('* 매일 자정 초기화\n* 여러 명 존재시 넣은 금액의 비율로 나눔',
                      style: styleSmall),
                ],
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/image/fire.png'),
                          fit: BoxFit.fitWidth,
                        ),
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: Duration(milliseconds: 500),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                            return ScaleTransition(
                                child: child, scale: animation);
                          },
                          key: ValueKey<int>(widget.winStreak),
                          child: Text(
                            '${widget.winStreak}',
                            style: AppTheme.bodyLargeBold
                                .copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '연승중',
                  style: AppTheme.smallText(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTooltip() {
    return CircularBoxContainer(
      width: 200,
      color: const ui.Color.fromARGB(255, 25, 24, 24),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('5연승: 잭팟 금액의 50%\n10연승: 잭팟 금액의 100%', style: style),
            SizedBox(height: 5),
            Text('* 매일 자정 초기화\n* 여러 명 존재시 넣은 금액의 비율로 나눔', style: styleSmall),
          ],
        ),
      ),
    );
  }
}

class HyperlinkText extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final Color? normalColor;
  final Color? hoverColor;
  final TextStyle? style;

  const HyperlinkText({
    required this.text,
    required this.onTap,
    this.normalColor,
    this.hoverColor,
    this.style,
    super.key,
  });

  @override
  State<HyperlinkText> createState() => _HyperlinkTextState();
}

class _HyperlinkTextState extends State<HyperlinkText> {
  bool isHovered = false;
  bool isTapped = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => isTapped = true),
        onTapUp: (_) => setState(() => isTapped = false),
        onTapCancel: () => setState(() => isTapped = false),
        onTap: widget.onTap,
        child: Text(
          widget.text,
          style: widget.style?.copyWith(
                  color: isTapped || isHovered
                      ? (widget.hoverColor ?? Colors.red)
                      : (widget.normalColor ?? Colors.blue),
                  decoration: isTapped || isHovered
                      ? TextDecoration.underline
                      : TextDecoration.none) ??
              TextStyle(
                color: isTapped || isHovered
                    ? (widget.hoverColor ?? Colors.red)
                    : (widget.normalColor ?? Colors.blue),
                decoration: isTapped || isHovered
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
        ),
      ),
    );
  }
}

class GlowingOutlineCard extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double glowWidth;
  final double borderRadius;
  final Color backgroundColor;
  final FocusNode? focusNode;

  const GlowingOutlineCard({
    Key? key,
    required this.child,
    this.glowColor = Colors.amber,
    this.glowWidth = 1.5,
    this.borderRadius = 8.0,
    this.backgroundColor = const Color(0xFF1A1A2E),
    this.focusNode,
  }) : super(key: key);

  @override
  State<GlowingOutlineCard> createState() => _GlowingOutlineCardState();
}

class _GlowingOutlineCardState extends State<GlowingOutlineCard> {
  final ValueNotifier<bool> _showGlow = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _showGlow.value = widget.focusNode?.hasFocus ?? false;
    widget.focusNode?.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_onFocusChange);
    _showGlow.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    _showGlow.value = widget.focusNode!.hasFocus;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _showGlow,
      builder: (context, showGlow, child) {
        return Container(
          decoration: showGlow
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: widget.glowColor.withOpacity(0.7),
                      blurRadius: 4,
                      spreadRadius: 0.5,
                    ),
                  ],
                )
              : null,
          child: Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              side: showGlow
                  ? BorderSide(color: widget.glowColor, width: widget.glowWidth)
                  : BorderSide.none,
            ),
            color: showGlow ? widget.backgroundColor : null,
            elevation: 0,
            child: widget.child,
          ),
        );
      },
    );
  }
}
