import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../../common/widgets/notice_queue_view.dart';
import '/common/util.dart';
import '/common/styles.dart';

class EmptyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EmptyAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  @override
  Size get preferredSize => const Size(0.0, 0.0);
}

typedef GobackCallback = Future<void> Function();

enum MenuPosition { none, left, right }

// ignore: must_be_immutable
class MenuAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showbackbutton;
  final bool showclosebutton;
  final bool showlogo;
  final MenuPosition menupos;
  final GlobalKey<ScaffoldState>? scaffoldkey;
  final String title;
  final TextStyle? titleFontStyle;
  final GobackCallback? onGoBack;
  final Widget? titleWidget;
  final double height;
  final Color? color;
  final Color? backgroudColor;
  final Widget? trailing;

  @override
  Size get preferredSize => Size(60.0, height);

  MenuAppBar({
    this.scaffoldkey,
    this.showbackbutton = true,
    this.showclosebutton = false,
    this.menupos = MenuPosition.none,
    this.showlogo = false,
    this.onGoBack,
    this.height = 50,
    this.title = "",
    this.titleFontStyle,
    this.titleWidget,
    this.trailing,
    this.color,
    this.backgroudColor,
    Key? key,
  }) : super(key: key);

  Color? _textColor;

  Color barColor(BuildContext context) {
    return backgroudColor ?? Theme.of(context).colorScheme.background;
  }

  Color textColor(BuildContext context) {
    _textColor ??= AppTheme.getMatchingTextColor(barColor(context));
    return _textColor!;
  }

  void goBack(BuildContext context) {
    if (onGoBack != null) {
      onGoBack?.call();
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _buildLeadingWidget(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        showbackbutton
            ? InkWell(
                child: Padding(
                  padding: const EdgeInsets.all(0),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      Icon(
                        Icons.arrow_back,
                        color: color ?? textColor(context),
                      ),
                    ],
                  ),
                ),
                onTap: () {
                  goBack(context);
                },
              )
            : Container(),
        if (menupos == MenuPosition.left) _buildMenuButton(context),
      ],
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    return InkWell(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          Icons.menu,
          color: color ?? textColor(context),
          size: 30,
        ),
      ),
      onTap: () {
        final state = (scaffoldkey ?? ContextManager.scaffold)?.currentState;
        if (menupos == MenuPosition.right)
          state?.openEndDrawer();
        else
          state?.openDrawer();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.only(right: 10),
      color: barColor(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildLeadingWidget(context),
              showlogo ? _buildLogoImage() : Container(),
            ],
          ),
          Expanded(
            child: titleWidget != null
                ? titleWidget!
                : Row(
                    //mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 10),
                      MyStyledText(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color ?? textColor(context),
                        ),
                      ),
                      if (menupos == MenuPosition.left &&
                          !(showbackbutton || showlogo))
                        Container(
                          width: 30,
                        ),
                    ],
                  ),
          ),
          if (menupos == MenuPosition.right) _buildMenuButton(context),
          trailing ?? _buildTrailing(context),
        ],
      ),
    );
  }

  Widget _buildTrailing(BuildContext context) {
    if (showclosebutton) {
      return InkWell(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.close,
            color: color ?? textColor(context),
            size: 30,
          ),
        ),
        onTap: () {
          goBack(context);
        },
      );
    } else {
      return Container();
    }
  }

  Widget _buildLogoImage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 8, 0, 8),
      child: Row(
        children: [
          Image.asset('assets/logo/square_logo.png',
              height: 30, color: AppTheme.colorScheme.onBackground),
          const SizedBox(width: 10),
          const Text('', style: TextStyle(fontSize: 16))
        ],
      ),
    );
  }
}

class CircleProgress extends StatelessWidget {
  final double? size;
  final Color? color;
  final double? stroke;

  const CircleProgress({this.size, this.color, this.stroke, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (size != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Center(
            child: Container(
              height: size,
              width: size,
              margin: const EdgeInsets.all(5),
              child: buildProgress(context),
            ),
          ),
        ],
      );
    } else {
      return buildProgress(context);
    }
  }

  double get strokeWidth {
    return stroke != null
        ? stroke!
        : (size == null
            ? 4
            : size! < 30
                ? 2
                : 4);
  }

  Widget buildProgress(BuildContext context) {
    return CircularProgressIndicator(
      strokeWidth: strokeWidth,
      color: color,
    );
  }
}

class DotProgressSteps extends StatelessWidget {
  final int count;
  final int step;
  final bool progressMode;
  final Function(int)? onTap;

  const DotProgressSteps(this.count, this.step, this.progressMode,
      {this.onTap, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Widget> circles = [];
    for (int i = 0; i < count; i++) {
      circles.add(Padding(
        padding: const EdgeInsets.all(5.0),
        child: InkWell(
          onTap: progressMode
              ? null
              : () {
                  if (onTap != null) onTap!(i);
                },
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color:
                  (progressMode && i < step) || (!progressMode && i == step - 1)
                      ? Colors.blueAccent
                      : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ));
    }
    return Center(
      child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: circles),
    );
  }
}

class TextStroked extends StatelessWidget {
  final String text;
  final double? fontsize;
  final double? strokewidth;
  final Color? color;
  final Color? strokecolor;

  const TextStroked(this.text,
      {this.fontsize, this.color, this.strokecolor, this.strokewidth, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        // Stroked text as border.
        Text(
          text,
          style: TextStyle(
            fontSize: fontsize,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokewidth != null
                  ? strokewidth!
                  : (fontsize != null ? fontsize! * 0.1 : 2)
              ..color = strokecolor ?? Colors.white,
          ),
        ),
        // Solid text as fill.
        Text(
          text,
          style: TextStyle(
            fontSize: fontsize,
            color: color ?? AppTheme.colorScheme.onBackground,
          ),
        ),
      ],
    );
  }
}

class MyProgressView extends StatelessWidget {
  final double percent;
  final String? text;
  final String? infoText;
  final Widget? addWidget;
  final double? width;
  final double? lineHeight;
  final Color? backgroundColor;
  final Color? progressColor;

  const MyProgressView({
    required this.percent,
    this.text,
    this.infoText,
    this.width,
    this.lineHeight,
    this.addWidget,
    this.backgroundColor,
    this.progressColor,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return width != null
        ? SizedBox(
            width: width,
            child: _build(context),
          )
        : _build(context);
  }

  Widget _build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LinearPercentIndicator(
          lineHeight: lineHeight ?? 18,
          percent: percent,
          center: text.isNotNullEmptyOrWhitespace
              ? Text(text!,
                  style: TextStyle(
                      fontSize: 12,
                      color: percent >= 0.6 ? AppTheme.onPrimary : null))
              : null,
          backgroundColor: backgroundColor ?? AppTheme.background,
          progressColor: backgroundColor ?? AppTheme.primary,
          barRadius: const Radius.circular(10),
        ),
        if (infoText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 3, 0, 0),
            child: Center(
              child: Text(
                infoText!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                overflow: TextOverflow.fade,
                maxLines: 2,
              ),
            ),
          ),
        if (addWidget != null) addWidget!,
      ],
    );
  }
}

class MyProgressTimerView extends StatefulWidget {
  final Timer? timer;
  final DateTime? startTime;
  final int durationInMillis;
  final bool showText;
  final bool reverse;
  final double? height;

  const MyProgressTimerView({
    this.timer,
    required this.startTime,
    required this.durationInMillis,
    this.showText = true,
    this.reverse = false,
    this.height,
    Key? key,
  }) : super(key: key);

  @override
  State<MyProgressTimerView> createState() => MyProgressTimerViewState();
}

class MyProgressTimerViewState extends State<MyProgressTimerView> {
  Timer? timer;
  late DateTime startTime;

  @override
  void initState() {
    super.initState();

    createTimer();
  }

  @override
  void didUpdateWidget(MyProgressTimerView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.startTime != widget.startTime) {
      createTimer();
    }
  }

  void createTimer() {
    timer = Timer(Duration(milliseconds: widget.durationInMillis), () {
      if (mounted) setState(() {});
    });
    startTime = widget.startTime ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    int elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
    double progress = elapsedMs / (widget.durationInMillis);
    if (widget.reverse) progress = 1 - progress;

    return MyProgressView(
      percent: min(1, max(0, progress)),
      lineHeight: widget.height,
      text: widget.showText
          ? "${elapsedMs.toStringAsFixed(1)}/${widget.durationInMillis.toInt()}초"
          : '',
    );
  }

  void update() {
    if (mounted) setState(() {});
  }
}

extension ColorExtension on Color {
  Color darken(double amount) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final darkenedHsl =
        hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return darkenedHsl.toColor();
  }
}

class MyButton extends StatelessWidget {
  final double? width;
  final double? height;
  final String text;
  final Widget? widget;
  final TextStyle? textStyle;
  final double? fontSize;
  final Color? textColor;
  final Function()? onPressed;
  final ButtonStyle? buttonStyle;
  final Color? buttonColor;
  final double? borderRadius;
  final String? themeColor; // primary, secondary
  final EdgeInsets? contentsPadding;
  final Widget? icon;
  final Color? outlineColor;
  final double outlineWidth;

  const MyButton({
    required this.text,
    this.widget,
    this.textStyle,
    this.buttonStyle,
    this.onPressed,
    this.buttonColor,
    this.borderRadius = 5,
    this.width,
    this.height,
    this.fontSize,
    this.textColor,
    this.themeColor,
    this.contentsPadding,
    this.icon,
    this.outlineColor,
    this.outlineWidth = 1.0,
    super.key,
  });

  Color _buttonColor(BuildContext context) {
    if (buttonColor != null) return buttonColor!;
    if (themeColor != null) {
      if (themeColor == 'primary') {
        return AppTheme.primary;
      } else if (themeColor == 'secondary') {
        return AppTheme.dexSecondary;
      }
    }
    return AppTheme.primary;
  }

  Color? _textColor(BuildContext context) {
    if (textColor != null) return textColor;
    if (themeColor != null) {
      if (themeColor == 'primary') {
        return AppTheme.onPrimary;
      } else if (themeColor == 'secondary') {
        return AppTheme.onSecondary;
      }
    }

    return AppTheme.getMatchingTextColor(_buttonColor(context));
  }

  double get _height => height ?? 50;

  @override
  Widget build(BuildContext context) {
    var tColor = _textColor(context);
    return Container(
      width: width, // ?? MediaQuery.of(context).size.width,
      height: _height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: buttonStyle ??
            ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(0),
              backgroundColor: _buttonColor(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(borderRadius ?? 0),
                ),
                side: outlineColor != null
                    ? BorderSide(
                        color: outlineColor!,
                        width: outlineWidth,
                      )
                    : BorderSide.none, // 추가된 부분
              ),
            ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: widget ??
              Padding(
                padding:
                    contentsPadding ?? const EdgeInsets.fromLTRB(4, 2, 4, 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: icon!,
                      ),
                    MyStyledText(
                      text,
                      style: textStyle ??
                          TextStyle(
                            fontSize: fontSize ?? 14,
                            color: tColor,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String text;
  final double? width;
  final List<Color> colors;
  final Function() onPressed;
  final BuildContext? context;
  final TextStyle? textStyle;

  const GradientButton({
    required this.text,
    this.width,
    required this.colors,
    required this.onPressed,
    this.textStyle,
    this.context,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 40, // overlay의 높이
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: colors,
                ),
              ),
            ),
          ),
          MyButton(
            width: width ?? min(MediaQuery.of(context).size.width * 0.3, 200),
            text: text,
            buttonColor: Colors.transparent,
            textStyle: textStyle ?? AppTheme.bodyLargeBold,
            borderRadius: 8,
            height: 40,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

class UnderlineText extends StatelessWidget {
  final String text;
  final TextAlign? textAlign;
  final TextStyle? style;
  final Color? underlineColor;
  final double? underlineThickness;

  const UnderlineText(
    this.text, {
    this.textAlign,
    this.style,
    this.underlineColor,
    this.underlineThickness,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: underlineColor ?? AppTheme.colorScheme.onSurface,
            width: underlineThickness ?? 0.5,
          ),
        ),
      ),
      child: Text(
        text,
        textAlign: textAlign,
        style: style,
        overflow: TextOverflow.fade,
      ),
    );
  }
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        // etc.
      };
}

class MyIconButton extends StatelessWidget {
  final IconData iconData;
  final Color? bgColor;
  final Color? color;
  final Function() onTap;

  const MyIconButton(
    this.iconData, {
    this.bgColor,
    this.color,
    required this.onTap,
    super.key,
  });

  @override
  build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 30,
        decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            color: (bgColor ?? Colors.brown).withAlpha(200)),
        child: Icon(
          iconData,
          color: color ?? Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

class DropDownMenu<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final double? width;
  final Function(T?)? onChanged;
  final EdgeInsets? padding;
  final EdgeInsets? itemPadding;
  final Color? textColor;
  final Color? selColor;
  final Color? borderColor;
  final double? fontSize;
  final bool? dense;

  const DropDownMenu({
    this.value,
    required this.items,
    this.width,
    this.padding,
    this.itemPadding,
    this.onChanged,
    this.textColor,
    this.selColor,
    this.borderColor,
    this.fontSize,
    this.dense,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: width ?? double.infinity,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor ?? Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          padding: padding,
          isExpanded: true,
          isDense: dense ?? false,
          selectedItemBuilder: (BuildContext context) {
            return items
                .map((e) => Container(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: itemPadding ?? const EdgeInsets.all(8.0),
                        child: Text(
                          e.toString(),
                          style: TextStyle(
                              color: textColor, fontSize: fontSize ?? 14),
                          textAlign: TextAlign.left,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ))
                .toList();
          },
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Container(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      e.toString(),
                      style: TextStyle(
                        color: e == value
                            ? (selColor ?? AppTheme.primary)
                            : (textColor),
                        fontSize: fontSize ?? 14,
                      ),
                      textAlign: TextAlign.left,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          iconSize: 24,
        ),
      ),
    );
  }
}

class MyScaffold extends StatefulWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  MyScaffold(
      {this.appBar,
      this.body,
      this.floatingActionButton,
      this.floatingActionButtonLocation,
      this.drawer,
      this.endDrawer,
      this.backgroundColor,
      this.bottomNavigationBar,
      this.scaffoldKey,
      Key? key})
      : super(key: key);

  @override
  State<MyScaffold> createState() => _MyScaffoldState();
}

class _MyScaffoldState extends State<MyScaffold> {
  late GlobalKey<ScaffoldState> scaffoldKey;

  @override
  void initState() {
    super.initState();

    scaffoldKey = widget.scaffoldKey ?? GlobalKey<ScaffoldState>();
    ContextManager.pushScaffold(scaffoldKey);
  }

  @override
  void dispose() {
    ContextManager.popScaffold(scaffoldKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        key: scaffoldKey,
        appBar: widget.appBar,
        body: Stack(
          children: [
            widget.body ?? Container(),
            Positioned(
              left: 10,
              bottom: 20,
              child: NoticeQueueView(type: NoticeType.big),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: NoticeQueueView(
                type: NoticeType.small,
                position: NoticePosition.righttop,
              ),
            ),
          ],
        ),
        floatingActionButton: widget.floatingActionButton,
        floatingActionButtonLocation: widget.floatingActionButtonLocation,
        drawer: widget.drawer,
        endDrawer: widget.endDrawer,
        backgroundColor: widget.backgroundColor,
        bottomNavigationBar: widget.bottomNavigationBar,
      ),
    );
  }
}

class MyCard extends StatelessWidget {
  final Widget? child;
  final Color? surfaceTintColor;
  final double? elevation;
  const MyCard({this.child, this.elevation, this.surfaceTintColor, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation ?? 0,
      surfaceTintColor: surfaceTintColor ?? AppTheme.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10), // 모서리 둥글게
        side: BorderSide(
          color: Colors.grey.withAlpha(50),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}
