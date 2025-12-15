import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';

import '/data/providers.dart';

export 'settings.dart';

class Localization {
  static String language = 'en';

  static Future init(BuildContext? context) async {
    await loadLanguage(context);
  }

  // languageStateProvider는 providers.dart로 이동됨

  static List<String> supportedLangs = ['ko', 'ja', 'en', 'zh-CN', 'zh-TW'];

  static Future loadLanguage(BuildContext? context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lang = prefs.getString('language');
    if (lang == null) {
      String langCode = PlatformDispatcher.instance.locale.languageCode;
      if (supportedLangs.indexOf(langCode) == -1) {
        language = 'en';
      } else {
        language = langCode;
      }
    } else {
      language = lang;
    }

    updateLocale(context);
  }

  static void changeLanguage(
    String lang, {
    BuildContext? context,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (supportedLangs.indexOf(lang) == -1) {
      lang = 'en';
    }

    language = lang;

    prefs.setString('language', lang);

    updateLocale(context);
  }

  static void updateLocale(BuildContext? context) {
    final vals = language.split('-');
    context?.setLocale(
        (vals.length == 2) ? Locale(vals[0], vals[1]) : Locale(language));

    uncontrolledContainer.read(languageStateProvider.notifier).state = language;
  }

  static Widget drawCurrentLangFlag() {
    return Image.asset('assets/image/${Localization.language}.png', width: 30);
  }
}

class LanguageListView extends StatefulWidget {
  final bool useWrap;
  final Function? onSelected;
  final double? iconSize;
  const LanguageListView(
      {this.useWrap = false, this.onSelected, this.iconSize, super.key});

  @override
  State<LanguageListView> createState() => _LanguageListViewState();
}

class _LanguageListViewState extends State<LanguageListView> {
  double get iconSize => widget.iconSize ?? 30;

  @override
  Widget build(BuildContext context) {
    return widget.useWrap
        ? Wrap(children: _buildLangButtons())
        : Row(children: _buildLangButtons());
  }

  void _selectLanaguage(String code) {
    Localization.changeLanguage(code, context: context);
    setState(() {});
  }

  Widget _drawFlag(String code) {
    return Localization.language == code
        ? Image.asset('assets/image/${code}.png', width: iconSize)
        : _buildColoredAssetImage('assets/image/${code}.png', width: iconSize);
  }

  List<Widget> _buildLangButtons() {
    return Localization.supportedLangs
        .map((e) => InkWell(
            onTap: () {
              _selectLanaguage(e);
              widget.onSelected?.call();
            },
            child: SizedBox(
              width: iconSize * 1.3,
              height: iconSize * 1.3,
              child: Center(
                child: _drawFlag(e),
              ),
            )))
        .toList();
  }

  Widget _buildColoredAssetImage(
    String imagePath, {
    double? width,
    double? height,
    Color? color,
  }) {
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
