import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/widgets.dart';

import '../api/netclient.dart';
import 'providers.dart';
import '/common/all.dart';

export 'settings.dart';

class DataManager {
  DataManager._();

  static final DataManager _db = DataManager._();
  factory DataManager() => _db;

  void clearCache() {}

  Map<String, dynamic> options = {};

  Map<String, dynamic> walletData = {};

  bool get isValidWallet =>
      (walletData['address'] as String?).isNotNullEmptyOrWhitespace;
  String? get savedWalletAddress => walletData['address'];

  bool get soundEffect => getOption('soundeffect') ?? true;
  bool get bgm => getOption('bgm') ?? true;

  double get textScale => getOption('textscale') ?? 1.0;

  // dataLoadingStateProvider는 providers.dart로 이동됨

  final StreamController<DateTime?> dataChangeNotifyStream =
      StreamController<DateTime?>.broadcast();

  set dataLoadingState(String state) {
    uncontrolledContainer.read(dataLoadingStateProvider.notifier).state = state;
  }

  void setDataUpdated() {
    dataChangeNotifyStream.add(DateTime.now());
  }

  bool get isInitDataLoading {
    return uncontrolledContainer
            .read(dataLoadingStateProvider.notifier)
            .state ==
        'initdataloading';
  }

  List<Map<String, dynamic>> agencyLists = [];

  List<String> selectedIndicators = [];

  Future init(BuildContext? context) async {
    SharedPreferences? prefs = await SharedPreferences.getInstance();
    final indicatorText = prefs.getString('indicator_list');
    if (indicatorText.isNotNullEmptyOrWhitespace) {
      selectedIndicators = indicatorText!.split(',');
    }

    /*
    await loadSetting(context);

    // 모바일 버전만 총판 목록을 가져오기 필요함
    final result = await ServerAPI().loadAgencyList();
    if (result != null) {
      if (result['rows'] != null)
        agencyLists = List<Map<String, dynamic>>.from(result['rows']);
    }
    */
    // } catch (e) {}
  }


  Future saveIndicators() async {
    SharedPreferences? prefs = await SharedPreferences.getInstance();
    prefs.setString('indicator_list', selectedIndicators.join(','));
  }

  Future<Map<String, dynamic>> loadWallet(
    String? currency, {
    required String gameMode,
  }) async {
    final pref = await SharedPreferences.getInstance();

    final wallet = pref.getString('$gameMode.$currency.wallet');
    if (wallet != null) {
      walletData = jsonDecode(wallet);
    } else {
      walletData = {};
    }

    return walletData;
  }

  Future saveWallet(
    Map<String, dynamic>? data,
    String? currency, {
    required String gameMode,
  }) async {
    final pref = await SharedPreferences.getInstance();

    walletData = data ?? {};
    await pref.setString('$gameMode.$currency.wallet', jsonEncode(data));
  }

  Future loadSetting(BuildContext? context) async {
    final pref = await SharedPreferences.getInstance();

    options = pref.getString('options') != null
        ? jsonDecode(pref.getString('options')!)
        : {};
  }

  dynamic getOption(String key) {
    return options[key];
  }

  Future setOption(String key, dynamic value, {BuildContext? context}) async {
    options[key] = value;

    final pref = await SharedPreferences.getInstance();
    pref.setString('options', jsonEncode(options));
  }

  Future loadDataFromServer() async {

  }

  void clear() {}
}
