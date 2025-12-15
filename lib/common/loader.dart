import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_loader/flutter_overlay_loader.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:synchronized/synchronized.dart';

import 'context_manager.dart';
import 'theme.dart';
import 'loading_view.dart';

bool _loaderVisible = false;
LoadingParam? _savedLoadingParam;
Lock _loaderLock = Lock();

class LoadingParam {
  final BuildContext context;
  final String? message;
  final Color? overlayColor;

  LoadingParam({required this.context, this.message, this.overlayColor});
}

List<LoadingParam> _pushedLoading = [];
int _lastLoadingIndex = 0;
Timer? loadingTimer;

bool isloaderVisible() {
  return _loaderVisible;
}

Widget buildLoadingAnimation(String? animName, {double? size}) {
  if (animName == 'nova') {
    return LoadingView(mode: 'one');
  } else if (animName == 'twistingDots') {
    return LoadingAnimationWidget.twistingDots(
      leftDotColor: const Color(0xFF1A1A3F),
      rightDotColor: const Color(0xFFEA3799),
      size: size ?? 36,
    );
  } else if (animName == 'waveDots') {
    return LoadingAnimationWidget.waveDots(
      color: AppTheme.onBackground,
      size: size ?? 36,
    );
  } else if (animName == 'progressiveDots') {
    return LoadingAnimationWidget.progressiveDots(
      color: AppTheme.onBackground,
      size: size ?? 36,
    );
  } else if (animName == 'flickr') {
    return LoadingAnimationWidget.flickr(
      leftDotColor: const Color(0xFF0063DC),
      rightDotColor: const Color(0xFFFF0084),
      size: size ?? 36,
    );
  } else if (animName == 'discreteCircle') {
    return LoadingAnimationWidget.discreteCircle(
      color: AppTheme.primary,
      secondRingColor: AppTheme.colorScheme.error,
      thirdRingColor: AppTheme.dexSecondary,
      size: size ?? 36,
    );
  } else {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Center(
          child: Container(
            height: 30,
            width: 30,
            margin: const EdgeInsets.all(5),
            child: const CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        ),
      ],
    );
  }
}

void showLoading({
  String? message,
  String? animName = 'flickr',
  Color? overlayColor,
  Duration? duration,
  bool hidePrevious = true,
  BuildContext? context,
}) async {
  await _loaderLock.synchronized(() async {
    if (_loaderVisible) {
      if (hidePrevious) {
        hideLoading();
      } else {
        debugPrint('showLoading: loader already visible');
        return;
      }
    }
    _loaderVisible = true;

    _savedLoadingParam = LoadingParam(
      context: context ?? ContextManager.buildContext!,
      message: message,
      overlayColor: overlayColor,
    );

    loadingTimer?.cancel();

    int loadingIndexCaptured = ++_lastLoadingIndex;
    loadingTimer = Timer(duration ?? const Duration(seconds: 15), () {
      if (_lastLoadingIndex == loadingIndexCaptured) {
        hideLoading();
        loadingTimer = null;
      }
    });

    if (animName == 'nova') {
      Loader.show(
        context ?? ContextManager.buildContext!,
        overlayColor: Colors.transparent,
        progressIndicator: buildLoadingAnimation(animName),
      );
    } else {
      Loader.show(
        context ?? ContextManager.buildContext!,
        overlayColor: Colors.transparent,
        progressIndicator: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildLoadingAnimation(animName),
            if (message != null)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
  });
}

void hideLoading() async {
  await _loaderLock.synchronized(() async {
    _hideLoading();
  });
}

void _hideLoading() {
  if (_loaderVisible) {
    _loaderVisible = false;
    _savedLoadingParam = null;
    loadingTimer?.cancel();
    loadingTimer = null;

    Loader.hide();
  } else {
    //debugPrint('hideLoading: loader not visible');
  }
}

void pauseLoading() {
  if (_loaderVisible) {
    _pushedLoading.add(_savedLoadingParam!);
    hideLoading();
  }
}

void resumeLoading({String? newMessage}) {
  if (_pushedLoading.isNotEmpty) {
    showLoading(
      context: _pushedLoading.last.context,
      message: newMessage ?? _pushedLoading.last.message,
      overlayColor: _pushedLoading.last.overlayColor,
    );
    _pushedLoading.removeLast();
  }
}
