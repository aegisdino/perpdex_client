import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:perpdex/common/notice.dart';

import 'styles.dart';
import 'theme.dart';
import 'string_ext.dart';
import 'context_manager.dart';
import 'loader.dart';

export 'loader.dart';
export 'theme.dart';
export 'time.dart';
export 'system.dart';
export 'string_ext.dart';
export 'util_canvas.dart';
export 'util_color.dart';
export 'context_manager.dart';

int parseInt(dynamic value) {
  return value != null
      ? (int.tryParse(value.toString().replaceAll(',', '')) ?? 0)
      : 0;
}

double parseDouble(dynamic value) {
  return value != null
      ? (double.tryParse(value.toString().replaceAll(',', '')) ?? 0.0)
      : 0.0;
}

String doubleToString(
  dynamic inputValue, {
  int precision = 2,
  bool comma = false,
}) {
  double value =
      (inputValue is String) ? parseDouble(inputValue) : inputValue.toDouble();
  final valueText = (value.toInt().toDouble() == value)
      ? '${value.toInt()}'
      : '${value.toStringAsFixed(precision)}';
  if (comma) return Util.commaStringNumber(valueText);
  return valueText;
}

class Util {
  static late Size screenSize;
  static late double pixelRatio;

  static void init(BuildContext context) {
    screenSize = MediaQuery.of(context).size;
    pixelRatio = MediaQuery.of(context).devicePixelRatio;
  }

  static RegExp variantTimeRegex = RegExp(r"\d+\.\d+");

  static DateTime? parseDate(dynamic dateStr,
      {bool checkVariantTime = false, bool isUtc = false}) {
    if (dateStr == null || dateStr == '') return null;
    if (dateStr is int) {
      if (dateStr.toString().length <= 10) dateStr *= 1000;
      return dateStr == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(dateStr, isUtc: isUtc);
    } else if (dateStr is String?) {
      if (dateStr.isNullEmptyOrWhitespace) return null;

      if (checkVariantTime) {
        // variant time check
        final varTime = double.tryParse(dateStr!);
        if (varTime != null) {
          return variantTimeToDateTime(varTime);
        }
      }

      if (dateStr!.contains('년')) {
        dateStr = dateStr
            .replaceAll('년 ', '-')
            .replaceAll('월 ', '-')
            .replaceAll('일', '');
      }
      try {
        DateTime date = DateTime.parse(dateStr);
        return date;
      } catch (e) {
        // 에러는 무시하고 아래에서 우리가 직접 파싱
      }

      try {
        var elms = dateStr.split(RegExp(r"[\ \-\:\.]"));
        elms.removeWhere((e) => e == '');

        if (elms.length >= 3) {
          // 공백 삭제
          int year = int.parse(elms[0]);
          int month = int.parse(elms[1]);
          int day = int.parse(elms[2]);
          int hour = elms.length > 3 ? int.parse(elms[3]) : 0;
          int minute = elms.length > 4 ? int.parse(elms[4]) : 0;
          int sec = elms.length > 5 ? int.parse(elms[5]) : 0;
          return isUtc
              ? DateTime.utc(year, month, day, hour, minute, sec)
              : DateTime(year, month, day, hour, minute, sec);
        }
      } on Exception {
        debugPrint('parseDate: exception occurred when parsing $dateStr');
      }
    }
    return null;
  }

  static bool isValidBirthDate(String? value) {
    if (value != null && value.length == 8) {
      final date = parse8DigitDate(value);
      if (date == null || date.year < 1900 || date.year > DateTime.now().year)
        return false;
      return true;
    }
    return false;
  }

  static DateTime? parse8DigitDate(String dateStr) {
    if (dateStr.length == 8 || dateStr.length == 12) {
      try {
        DateTime date = DateTime(
          int.parse(dateStr.substring(0, 4)),
          int.parse(dateStr.substring(4, 6)),
          int.parse(dateStr.substring(6, 8)),
          dateStr.length >= 10 ? int.parse(dateStr.substring(8, 10)) : 0,
          dateStr.length >= 12 ? int.parse(dateStr.substring(10, 12)) : 0,
        );
        return date;
      } on Exception catch (e) {
        debugPrint('parse8DigitDate: $dateStr, exception ${e.toString()}');
      }
    }
    return null;
  }

  static final dateDelimRegexp = RegExp(r"[T\ \-\:]");

  static String dateStringToDigits(String dateStr) {
    return dateStr.replaceAll(dateDelimRegexp, '');
  }

  static DateTime? parseDotDate(String dateStr) {
    try {
      var elms = dateStr.split('.');
      if (elms.length >= 3) {
        int year = int.parse(elms[0].trim());
        int month = int.parse(elms[1].trim());
        int day = int.parse(elms[2].trim());
        int hour = elms.length > 3 ? int.parse(elms[3]) : 0;
        int minute = elms.length > 4 ? int.parse(elms[4]) : 0;
        int sec = elms.length > 5 ? int.parse(elms[5]) : 0;
        return DateTime(year, month, day, hour, minute, sec);
      }
    } on Exception {}
    return null;
  }

  // 시간 부분은 없애고 날짜만 비교해서 몇일전인지 알려줌
  static String getDayElapsed(dynamic dateInput) {
    if (dateInput == null) return '';

    DateTime? date = (dateInput is String) ? parseDate(dateInput) : dateInput;
    if (date == null) return '';

    var checkdate = DateTime(date.year, date.month, date.day);
    var now = DateTime.now();
    var today = DateTime(now.year, now.month, now.day);
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'time.today'.tr();
    } else {
      int days = now.difference(checkdate).inDays;
      int months = days ~/ 30;
      if (months > 0) {
        return 'time.month_ago'.tr(args: ['$months']);
      } else {
        return 'time.day_ago'.tr(args: ['$days']);
      }
    }
  }

  static String getElapsedText(DateTime date, {DateTime? refDate}) {
    refDate ??= DateTime.now();
    final diffDate = date.difference(refDate);
    int days = diffDate.inDays;
    int hours = diffDate.inHours;
    int minutes = diffDate.inMinutes;
    int months = days ~/ 30;
    if (months > 0) {
      return 'time.month_ago'.tr(args: ['$months']);
    } else if (days > 0) {
      return 'time.day_ago'.tr(args: ['$days']);
    } else if (hours > 0) {
      return 'time.hours_ago'.tr(args: ['$hours']);
    } else if (minutes > 0) {
      return 'time.minute_ago'.tr(args: ['$minutes']);
    } else {
      return 'time.sec_ago'.tr(args: ['${diffDate.inSeconds}']);
    }
  }

  static String getDurationText(DateTime date, {DateTime? refDate}) {
    refDate ??= DateTime.now();
    final diffDate = date.difference(refDate);
    int days = diffDate.inDays;
    int hours = diffDate.inHours % 24;
    int minutes = diffDate.inMinutes % 60;
    int secs = diffDate.inSeconds % 60;

    if (days > 0) {
      return '${days}days ${zeroPadTimeNum(hours)}:${zeroPadTimeNum(minutes)}:${zeroPadTimeNum(secs)}';
    } else if (hours > 0) {
      return '${zeroPadTimeNum(hours)}:${zeroPadTimeNum(minutes)}:${zeroPadTimeNum(secs)}';
    } else if (minutes > 0) {
      return '00:${zeroPadTimeNum(minutes)}:${zeroPadTimeNum(secs)}';
    } else {
      return '00:00:${zeroPadTimeNum(secs)}';
    }
  }

  static String getDurationTextFromSeconds(int seconds) {
    int days = seconds ~/ (24 * 3600);
    int hours = (seconds - days * (24 * 3600)) ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;

    if (days > 0) {
      return '${days}d ${zeroPadTimeNum(hours)}:${zeroPadTimeNum(minutes)}:${zeroPadTimeNum(secs)}';
    } else if (hours > 0) {
      return '${zeroPadTimeNum(hours)}:${zeroPadTimeNum(minutes)}:${zeroPadTimeNum(secs)}';
    } else if (minutes > 0) {
      return '00:${zeroPadTimeNum(minutes)}:${zeroPadTimeNum(secs)}';
    } else {
      return '00:00:${zeroPadTimeNum(secs)}';
    }
  }

  static DateTime get today {
    var now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String getRemainTime(DateTime date, DateTime endDate,
      {bool? addText = true}) {
    bool remained = true;
    int minutes = endDate.difference(date).inMinutes;
    if (minutes < 0) {
      remained = false;
      minutes = -minutes;
    }
    int hours = minutes ~/ 60;
    minutes -= hours * 60;
    if (minutes > 30) hours++;
    int days = hours ~/ 24;
    hours %= 24;

    List<String> texts = [];
    if (days > 0) texts.add('$days일');
    if (days < 30 && hours > 0) texts.add('$hours시간');
    String text = texts.join(' ');
    if (addText == true) text += (remained ? ' 남음' : ' 지남');
    return text;
  }

  static int parseDateToEpochSec(var dateStr) {
    if (dateStr.runtimeType == String) {
      int? num = int.tryParse(dateStr);
      if (num == null) {
        var date = DateTime.parse(dateStr);
        return date.millisecondsSinceEpoch ~/ 1000;
      } else {
        return num;
      }
    } else if (dateStr.runtimeType == DateTime) {
      return dateStr.millisecondsSinceEpoch ~/ 1000;
    } else {
      return dateStr;
    }
  }

  static int getElapsedInMillis(DateTime old, {DateTime? base}) {
    if (base == null)
      return DateTime.now().difference(old).inMilliseconds;
    else
      return base.difference(old).inMilliseconds;
  }

  static ScaffoldState? getScaffoldState(
      {GlobalKey<ScaffoldState>? scaffoldkey, BuildContext? context}) {
    var scaffoldState = scaffoldkey?.currentState;
    if (scaffoldState == null && context != null) {
      scaffoldState = Scaffold.of(context);
    }
    if (scaffoldState == null && ContextManager.scaffoldStack.isNotEmpty) {
      scaffoldState = ContextManager.scaffoldStack.last.currentState;
    }
    return scaffoldState;
  }

  static Future copyClipboard(
    String text, {
    String? message,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == text) {
      print('복사 성공: ${data?.text}');
      if (message != null) toastNotice(message);
    } else {
      print('복사 실패');
      toastError('Clipboard copy failed');
    }
  }

  static void toastError(
    String message, {
    GlobalKey<ScaffoldState>? scaffoldkey,
    BuildContext? context,
    bool center = true,
    bool useSnackBar = false,
  }) {
    if (useSnackBar == false) {
      addNotice(message: message, error: true, seconds: 3.0);
      // Fluttertoast.showToast(
      //   msg: message,
      //   gravity: center ? ToastGravity.CENTER : ToastGravity.BOTTOM_RIGHT,
      //   toastLength: Toast.LENGTH_LONG,
      //   fontSize: 16.0,
      //   backgroundColor: Colors.red,
      //   textColor: Colors.white,
      // );
    } else {
      showSnackBar(message,
          bgcolor: Colors.red, scaffoldkey: scaffoldkey, context: context);
    }
  }

  static void showCenterToast(
    String message, {
    BuildContext? context,
    int? delay,
    bool? error = false,
  }) {
    final overlay = Overlay.of(context ?? ContextManager.buildContext!);
    OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height / 2 - 50,
        width: MediaQuery.of(context).size.width,
        child: Material(
          color: Colors.transparent,
          child: Container(
            alignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                message,
                style: TextStyle(
                  color: error == true ? Colors.red : Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(Duration(seconds: delay ?? 1), () {
      overlayEntry.remove();
    });
  }

  static void toastNotice(
    String message, {
    GlobalKey<ScaffoldState>? scaffoldkey,
    BuildContext? context,
    bool useSnackBar = false,
    bool center = true,
    bool error = false,
    double? fontSize,
  }) {
    if (useSnackBar == false) {
      center
          ? showCenterToast(message, context: context, error: error)
          : addNotice(message: message, error: false, seconds: 3.0);

            // Fluttertoast.showToast(
            //   msg: message,
            //   toastLength: Toast.LENGTH_LONG,
            //   fontSize: fontSize ?? 15.0,
            //   backgroundColor: context != null
            //       ? Theme.of(context).snackBarTheme.backgroundColor
            //       : null,
            //   textColor: context != null
            //       ? Theme.of(context).snackBarTheme.contentTextStyle?.color
            //       : null,
            //   gravity:
            //       center ? ToastGravity.CENTER : ToastGravity.BOTTOM_RIGHT);
    } else {
      showSnackBar(message,
          bgcolor: Colors.blue, scaffoldkey: scaffoldkey, context: context);
    }
  }

  static void showSnackBar(
    String message, {
    Color? bgcolor,
    Color? color,
    int? seconds,
    GlobalKey<ScaffoldState>? scaffoldkey,
    BuildContext? context,
  }) {
    var scaffold = getScaffoldState(scaffoldkey: scaffoldkey, context: context);
    if (scaffold != null) {
      try {
        ScaffoldMessenger.of(scaffold.context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: InkWell(
              onTap: () {
                try {
                  ScaffoldMessenger.of(scaffold.context).hideCurrentSnackBar();
                } on Exception catch (e) {
                  debugPrint(
                      'showSnackBar: hideCurrentSnackBar exception ${e.toString()}');
                }
              },
              child: Text(message,
                  style: TextStyle(
                      color: color ?? AppTheme.colorScheme.onSurface)),
            ),
            duration: Duration(seconds: seconds ?? 3),
            backgroundColor: bgcolor ?? AppTheme.colorScheme.surface,
          ));
      } on Exception catch (e) {
        debugPrint('showSnackBar: exception ${e.toString()}');
      }
    } else {
      debugPrint('showSnackBar: no scaffold, $message');
    }
  }

  static List<BuildContext> alertDialogs = [];

  static bool isAlertVisible() {
    return alertDialogs.isNotEmpty;
  }

  static bool disposeAlert() {
    if (alertDialogs.isNotEmpty) {
      final ctx = alertDialogs.removeLast();
      Navigator.of(ctx).pop();
      return true;
    } else {
      return false;
    }
  }

  static Future<String?> showAlert(
    String message, {
    Widget? msgwidget,
    Function? onOK,
    BuildContext? context,
    String? title,
    EdgeInsets? insetPadding,
  }) async {
    var ctx = context ?? ContextManager.buildContext;
    if (ctx != null) {
      if (isloaderVisible()) hideLoading();

      alertDialogs.add(ctx);

      final result = await showDialog<String?>(
        context: ctx,
        barrierDismissible: false, // user must tap button!
        builder: (BuildContext context) {
          return AlertDialog(
            insetPadding: insetPadding ??
                const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
            backgroundColor: AppTheme.colorScheme.surface,
            title: Text(title ?? 'common.notice'.tr()),
            scrollable: true,
            content: ListBody(
              children: <Widget>[
                message.isNotNullEmptyOrWhitespace
                    ? SelectionArea(
                        child: MyStyledText(
                          message,
                          fontSize: 14,
                          height: 1.4,
                          color: AppTheme.colorScheme.onSurface,
                        ),
                      )
                    : (msgwidget ?? Container())
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: Text('common.ok'.tr()),
                onPressed: () {
                  Navigator.of(context).pop('ok');
                  if (onOK != null) onOK();
                },
              ),
            ],
          );
        },
      );

      alertDialogs.removeLast();
      return result;
    } else {
      debugPrint('showAlert: $message');
      return Future.value(null);
    }
  }

  static BuildContext? promptAlertContext;

  static Future<String?> promptAlert(
    String message, {
    BuildContext? context,
    String? title,
    Widget? msgwidget,
    String? cancelText,
    String? confirmText,
    void Function(BuildContext)? onOK,
    void Function(BuildContext)? onCancel,
    double? borderRadius,
  }) async {
    context ??= ContextManager.buildContext;
    if (isloaderVisible()) hideLoading();

    promptAlertContext = context;
    String? result = await showDialog<String?>(
      context: context!,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          title: Text(title ?? 'common.notice'.tr()),
          scrollable: true,
          backgroundColor: AppTheme.colorScheme.surface,
          content: Container(
            constraints: BoxConstraints(
                minHeight: 60,
                minWidth: MediaQuery.of(context).size.width * 0.4,
                maxWidth: MediaQuery.of(context).size.width * 0.8),
            child: ListBody(
              children: <Widget>[
                msgwidget ??
                    MyStyledText(
                      message,
                      fontSize: 14,
                      height: 1.4,
                      color: AppTheme.colorScheme.onSurface,
                    )
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(cancelText ?? 'common.cancel'.tr()),
              onPressed: () {
                if (onCancel != null) onCancel(context);
                Navigator.pop(context, "cancel");
              },
            ),
            TextButton(
              child: Text(confirmText ?? 'common.ok'.tr()),
              onPressed: () {
                if (onOK != null) onOK(context);
                Navigator.pop(context, "ok");
              },
            ),
          ],
        );
      },
    );
    promptAlertContext = null;
    return result;
  }

  static void closePromptPopup({String? action}) {
    if (promptAlertContext != null) {
      Navigator.pop(promptAlertContext!, action ?? 'cancel');
    }
  }

  static Future<String?> promptAlert3(
    String message,
    List<String> btnTexts, {
    List<Function?>? onButtonClicks,
    BuildContext? context,
  }) async {
    context ??= ContextManager.buildContext;
    List<TextButton> flatButtons = [];
    for (var i = 0; i < btnTexts.length; i++) {
      var btn = TextButton(
        child: Text(btnTexts[i]),
        onPressed: () {
          Navigator.pop(context!, "button$i");
          if (onButtonClicks != null &&
              onButtonClicks.length > i &&
              onButtonClicks[i] != null) onButtonClicks[i]!();
        },
      );
      flatButtons.add(btn);
    }
    String? result = await showDialog<String?>(
      context: context!,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('common.notice'.tr()),
          scrollable: true,
          content: ListBody(
            children: <Widget>[Text(message)],
          ),
          actions: flatButtons,
        );
      },
    );
    return result;
  }

  static void killFocus(BuildContext context) {
    FocusScope.of(context).requestFocus(FocusNode());
  }

  static int zero = "0".codeUnits[0];
  static int nine = "9".codeUnits[0];
  static int dash = "-".codeUnits[0];

  static bool isNumber(int code) {
    return code >= zero && code <= nine;
  }

  static String readNumber(String text, int fromPos, {bool backward = false}) {
    bool dotFound = false;
    if (backward) {
      while (text[fromPos] == ' ') {
        fromPos--;
      }
      int endPos = 0;
      for (var i = fromPos; i >= 0; i--) {
        if (!dotFound && text[i] == '.') {
          dotFound = true;
        } else if (!(text.codeUnits[i] >= zero && text.codeUnits[i] <= nine)) {
          endPos = i + 1;
          break;
        }
      }
      return text.substring(endPos, fromPos + 1);
    } else {
      // 첫번째 숫자를 만날때까지 스킵
      while (!(text.codeUnits[fromPos] >= zero &&
          text.codeUnits[fromPos] <= nine)) {
        fromPos++;
      }
      int endPos = text.length;
      for (var i = fromPos; i < text.length; i++) {
        if (!dotFound && text[i] == '.') {
          dotFound = true;
        } else if (!(text.codeUnits[i] >= zero && text.codeUnits[i] <= nine)) {
          endPos = i;
          break;
        }
      }
      return text.substring(fromPos, endPos);
    }
  }

  static String commaStringNumber(dynamic money, {int stride = 3}) {
    if (money == null) return '';
    money = '${money}';
    List<String> numsplits = [];
    final numbers = money.split('.');
    final value = numbers[0];
    int chunks = (value.length + stride - 1) ~/ stride;

    for (var i = 0; i < chunks; i++) {
      int endindex = value.length - i * stride;
      int startindex = endindex - stride;
      numsplits.insert(
          0, value.substring(startindex < 0 ? 0 : startindex, endindex));
    }
    if (numbers.length == 1) {
      return numsplits.join(",");
    } else {
      return [numsplits.join(","), numbers[1]].join('.');
    }
  }

  static String dateYMD(DateTime? date,
      {bool showHMS = false,
      bool showSec = false,
      bool showDoW = false,
      String delim = '-'}) {
    if (date == null) return '';
    final dow = (showDoW == true) ? ' (EEE)' : '';
    final hms = (showHMS == true) ? (showSec ? ' HH:mm:ss' : ' HH:mm') : '';
    final String value =
        DateFormat('yyyy${delim}MM${delim}dd$hms$dow').format(date);
    return value;
  }

  static String dateYMDKor(DateTime? date) {
    if (date == null) return '';
    return "${date.year}년 ${date.month}월 ${date.day}일";
  }

  static String readKorMoney(int money) {
    if (money == 0) return '0';

    String text = money.toString().split('').reversed.join('');
    final _10kCount = (text.length / 4).ceil();

    List<String> _10kUnitNames = ['천', '백', '', ''];
    List<String> _4UnitNames = ['', '만', '억', '조', '경'];
    List<String> _readTexts = [];

    for (int i = 0; i < _10kCount; i++) {
      String temp = text
          .substring(i * 4, min(text.length, (i + 1) * 4))
          .split('')
          .reversed
          .join('');
      String nums = '0000'.substring(0, 4 - temp.length) + temp;
      String readText = '';

      for (var j = 0; j < 4; j++) {
        if (nums[j] == '0') continue;
        // 한글 단위가 있으면 해당 숫자 + 단위
        // 없으면 앞의 0들을 제외한 전체 숫자
        if (_10kUnitNames[j] != '') {
          readText += nums[j] + _10kUnitNames[j];
        } else {
          readText += nums.substring(j);
        }
        break;
      }

      readText = readText + _4UnitNames[i];

      if (readText == '1만') readText = '만';
      _readTexts.add(readText);
    }
    return _readTexts.reversed.join('');
  }

  static String dateYMDHMS(DateTime date) {
    return dateYMD(date, showHMS: true, showSec: true);
  }

  static String dateAboutPeriod(DateTime date) {
    int minutes = DateTime.now().difference(date).inMinutes;
    int hour = minutes ~/ 60;
    int day = minutes ~/ (24 * 60);

    if (minutes == 0) {
      return '방금';
    } else if (minutes < 60) {
      return '$minutes분전';
    } else if (day > 0) {
      return '$day일전';
    } else {
      return '$hour시간전';
    }
  }

  static String intToString(int val, {int pad = 0}) {
    return val.toString().padLeft(pad, '0');
  }

  static Size computeTextSize(
    String text, {
    TextStyle? style,
    double? maxWidth,
  }) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: maxWidth ?? double.infinity);
    return textPainter.size;
  }

  static String dateMonthEndPeriod(String fromdate, int months) {
    var elms = fromdate.split('-');
    int endmonth = int.parse(elms[1]) + months;
    int year = int.parse(elms[0]) + (endmonth - 1) ~/ 12;
    int day = int.parse(elms[2]);
    int month = (endmonth > 12) ? endmonth % 12 : endmonth;
    String enddate = Util.dateYMD(DateTime.parse(
            "$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}")
        .add(-const Duration(days: 1)));
    return enddate;
  }

  static void scrollToBottom(ScrollController scrollCtrl,
      {int durationMillis = 100}) {
    if (durationMillis == 0) {
      scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent);
    } else {
      Future.delayed(Duration(milliseconds: durationMillis), () {
        scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent);
      });
    }
  }

  static List<String> split(String source, {String delim = ' '}) {
    List<String> elms = [];
    source.split(delim).forEach((val) {
      if (val != '') elms.add(val);
    });
    return elms;
  }

  static void debugPrint(String message) {
    List<String> pieces = [];

    int linelen = 1024;
    for (int i = 0; i < message.length; i += linelen) {
      int offset = i + linelen;
      pieces.add(message.substring(
          i, offset >= message.length ? message.length : offset));
    }

    for (var line in pieces) {
      debugPrint(line);
    }
  }

  static bool checkPhoneNumber(String value) {
    if (value.startsWith('010') ||
        value.startsWith('011') ||
        value.startsWith('016') ||
        value.startsWith('017') ||
        value.startsWith('018') ||
        value.startsWith('019')) return true;
    return false;
  }

  static DateTime l900start = DateTime(1899, 12, 31);
  static const double l900startTick = 599265216000000000;

  // C# double time to DateTime
  static DateTime? cSharpTimeToDateTime(double ticks) {
    var dayAft1900 = (ticks - l900startTick) / (864000000000);
    var days = dayAft1900.toInt();
    var remain = (dayAft1900 - days);
    var hour = (remain * 24).toInt();
    var minute = (remain * 1440).toInt() % 60;
    var seconds = (remain * 86400).toInt() % 60;

    DateTime newdate = l900start.add(
        Duration(days: days, hours: hour, minutes: minute, seconds: seconds));
    return newdate;
  }

  // C# double time to millisecondsSinceEpoch (1970-01-01 00:00:00)
  static int? cSharpTimeToEpochMilli(double ticks) {
    var date = cSharpTimeToDateTime(ticks);
    return date?.millisecondsSinceEpoch;
  }

  static double toCSharpTime(DateTime dat) {
    Duration diff = dat.difference(l900start);
    double ticks = (diff.inDays +
                (diff.inHours % 24) / 24 +
                (diff.inMinutes % 60) / 1440 +
                (diff.inSeconds % 60) / 86400) *
            864000000000 +
        l900startTick;
    return ticks;
  }

  // The "variant time" is a double where the integer part is the number of days after 30dec1899.
  // As such, 0 is 30dec1899 while 01jan1900 is actually 2 (unlike Excel which copies Lotus and
  // defines it as day 1) and there is no 29feb1900. The fractional part of the decimal string
  // representation is treated as an unsigned partial day offset from 00:00:00 on that day.
  // The significance of the wording here is that while numerically -1.75 is
  // the same as -1 + -0.75, a variant time treats -1.75 as -1 + +0.75 (i.e. 3/4 of a day after midnight 29dec1899).
  // Thus, when converting negative values to YYYY/MM/DD HH:MM:SS or calculating date
  // differences involving negative values, the date and time parts must be treated separately.
  //
  // https://stackoverflow.com/questions/22476192/how-is-variant-time-date-double-8-byte-handled

  static DateTime variantStart = DateTime(1899, 12, 30);

  // C# double time to DateTime
  static DateTime? variantTimeToDateTime(double ticks) {
    var days = ticks.toInt();
    var remain = (ticks - days);

    // 반올림으로 전체 초 계산 후
    // 시, 분, 초를 계산해줘야 함
    var totalsecs = (remain * 86400).round();
    var hour = totalsecs ~/ 3600;
    totalsecs -= hour * 3600;
    var minute = totalsecs ~/ 60;
    totalsecs -= minute * 60;
    var seconds = totalsecs;

    DateTime newdate = variantStart.add(
        Duration(days: days, hours: hour, minutes: minute, seconds: seconds));

    //debugPrint('$ticks, $days, $hour, $minute, $seconds, ${newdate.toString()}');
    return newdate;
  }

  static double toOADate(DateTime dat) {
    Duration difference = dat.difference(l900start);
    var dateVal = difference.inDays;
    var remain = difference - Duration(days: dateVal);
    return dateVal.toDouble() +
        (remain.inHours / 24) +
        (remain.inMinutes % 60) / 1440 +
        (remain.inSeconds % 60) / 86400;
  }

  static const _chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  static Random? _rnd;

  static String getRandomString(int length) {
    return String.fromCharCodes(Iterable.generate(length,
        (_) => _chars.codeUnitAt(_random(null).nextInt(_chars.length))));
  }

  static Random _random(int? seed) {
    if (seed != null) {
      return Random(seed);
    } else {
      _rnd ??= Random();
      return _rnd!;
    }
  }

  static String shuffleText(String input, {int? seed}) {
    final random = _random(seed);
    var items = utf8.encode(input);
    for (var i = items.length - 1; i > 0; i--) {
      var n = random.nextInt(i + 1);

      var temp = items[i];
      items[i] = items[n];
      items[n] = temp;
    }

    return utf8.decode(items);
  }

  static String unshuffleText(String input, {int? seed}) {
    final random = _random(seed);
    var items = utf8.encode(input);

    List<int> seeds = [];
    for (var i = input.length - 1; i > 0; i--) {
      seeds.add(random.nextInt(i + 1));
    }
    final seedsReversed = seeds.reversed.toList();

    // Go through all elements.
    for (var i = 1; i < items.length; i++) {
      var n = seedsReversed[i - 1];
      var temp = items[i];
      items[i] = items[n];
      items[n] = temp;
    }

    return utf8.decode(items);
  }

  static Future<String> getStringFromAsset(String path) async {
    return await rootBundle.loadString(path);
  }

  static Future<String> getFileFromAssets(String path) async {
    /*
    final byteData = await rootBundle.load(path);

    final filePath =
        '${(await getTemporaryDirectory()).path}/${path.replaceAll('/', '_')}';
    final file = File(filePath);
    await file.writeAsBytes(byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    return filePath;
    */
    throw Error();
  }

  static Map<String, String> parseUrl(String url) {
    final Map<String, String> queryParams = {};

    final paramPos = url.indexOf('?');
    final params = url.substring(paramPos + 1);
    params.split('&').forEach((param) {
      final elms = param.split('=');
      queryParams[elms[0]] = elms[1];
    });

    return queryParams;
  }
}

extension Precision on double {
  String debugPrint(int fractionDigits) {
    return toStringAsFixed(fractionDigits);
  }

  double toPrecision(int fractionDigits) {
    var mod = pow(10, fractionDigits.toDouble()).toDouble();

    try {
      return (mod != 0.0) ? ((this * mod).round().toDouble() / mod) : this;
    } catch (e) {
      return this;
    }
  }
}

String zeroPadTimeNum(int num) {
  return '${num < 10 ? '0' : ''}${num.toString()}';
}

String zeroPadTime(int sec) {
  int hours = (sec ~/ 3600);
  int minutes = (sec ~/ 60) % 60;
  int seconds = sec % 60;

  return "${hours > 0 ? '$hours:' : ''}${zeroPadTimeNum(minutes)}:${zeroPadTimeNum(seconds)}";
}

String getAssetPath(String path) {
  final assetPath = (path.startsWith('asset://'))
      ? 'assets/contents/${path.substring(8)}'
      : path;
  return assetPath;
}

Future<Size> getImageSize(String assetPath) async {
  final ImageProvider provider = AssetImage(assetPath);
  final ImageStream stream = provider.resolve(ImageConfiguration());
  final Completer<Size> completer = Completer<Size>();

  final listener = ImageStreamListener(
    (ImageInfo info, bool synchronousCall) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      completer.complete(size);
    },
  );

  stream.addListener(listener);
  return completer.future;
}
