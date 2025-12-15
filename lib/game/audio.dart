import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../platform/platform.dart';

class AudioChannel {
  int playTime = 0;
  AudioPlayer? player;
  String? currentSound;

  AudioChannel() {
    player = new AudioPlayer();
    player!.setReleaseMode(ReleaseMode.stop);
  }

  bool get isPlaying => player!.state == PlayerState.playing;

  Future<void> stop({bool release = false}) async {
    await player!.stop();
    if (release) await player!.release();
    playTime = 0;
    currentSound = null;
  }

  Future<bool> play(String soundName, {AudioCache? cache}) async {
    if (cache != null) {
      final url = await cache.load('${soundName}.ogg');
      await player!.setSourceUrl(url.path);
    } else {
      final source = AssetSource('sounds/${soundName}.ogg');

      await player!.setSource(source);
    }

    await player!.eventStream
        .where((event) => event.eventType == AudioEventType.prepared)
        .map((event) => event.isPrepared!);
    await player!.resume();

    if (isPlaying) {
      currentSound = soundName;
      playTime = DateTime.now().millisecondsSinceEpoch;
      return true;
    }
    return false;
  }
}

class AudioManager {
  factory AudioManager() {
    return _singleton;
  }

  AudioManager._internal();

  static final AudioManager _singleton = AudioManager._internal();

  // BGM 전용 플레이어
  final AudioPlayer _bgmPlayer = AudioPlayer();
  String? _currentBGM;

  // 효과음용 채널
  final List<AudioChannel> _sfxChannels =
      List.generate(5, (_) => AudioChannel());

  final AudioCache _audioCache = AudioCache(prefix: 'assets/sounds/');
  Map<String, Function?> onCompleteHandlers = {};

  List<String> audios = [
    'start',
    'win',
    'win_applause',
    'lose',
    'insert_coin',
    'btn_click',
    'betplaced',
    'beep',
    'up',
    'down',
    'timetickle',
    'timeout',
    'slot_lever',
  ];

  List<String> bgms = [
    'tension',
    'anticipation',
    'bet_loop',
  ];

  void toggleSound() {
    isSoundOn = !isSoundOn;
    if (!isSoundOn) stopAll();
  }

  AssetSource _loadSound(String soundName) =>
      AssetSource('sounds/${soundName}.ogg');

  int getPlayingSfxChannel() {
    for (int i = 0; i < _sfxChannels.length; i++) {
      if (_sfxChannels[i].currentSound != null &&
          _sfxChannels[i].player?.state == PlayerState.playing) {
        return i;
      }
    }
    return -1;
  }

  AudioChannel getAvailableChannel() {
    int oldestChannel = -1;
    for (int i = 0; i < _sfxChannels.length; i++) {
      if (_sfxChannels[i].currentSound == null ||
          _sfxChannels[i].player?.state != PlayerState.playing) {
        return _sfxChannels[i];
      }
      if (oldestChannel == -1 ||
          _sfxChannels[oldestChannel].playTime > _sfxChannels[i].playTime)
        oldestChannel = i;
    }

    return _sfxChannels[oldestChannel];
  }

  Future<void> initAudio() async {
    await _loadSetting();

    // 효과음 채널 초기화
    for (int i = 0; i < _sfxChannels.length; i++) {
      final channel = _sfxChannels[i];

      channel.player!.onLog.listen((log) {
        debugPrint('channel $i: $log');
      });

      channel.player!.onPlayerStateChanged.listen((PlayerState state) {
        if (channel.currentSound != null &&
            (state == PlayerState.stopped || state == PlayerState.completed)) {
          onCompleteHandlers[channel.currentSound]?.call();
          channel.currentSound = null;
        }
      });
    }

    // BGM 플레이어 설정
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    _bgmPlayer.onPlayerStateChanged.listen((PlayerState state) {
      debugPrint('bgmStateChanged: current $_currentBGM, state $state');
    });

    try {
      // AudioCache 초기화 및 경로 설정
      await _audioCache.loadAll([...audios].map((e) => '${e}.ogg').toList());
    } catch (e) {
      debugPrint('오디오 로드 실패: $e');
    }
  }

  bool get isBGMPlaying => _bgmPlayer.state == PlayerState.playing;

  Future<bool> playBGM(String name, {double? volume, int? delayMillis}) async {
    if (!isSoundOn || !isBgmOn || isAppHidden()) {
      debugPrint('playBGM: $name, sound disabled');
      return false;
    }

    // 이미 같은 BGM이 재생 중이면 아무 것도 하지 않음
    if (name == _currentBGM && isBGMPlaying) {
      debugPrint('playBGM: sound $name is already playing');
      return true;
    }

    // 다른 BGM이 재생 중이었다면 중지
    if (_currentBGM != null && _currentBGM != name) {
      debugPrint('playBGM: stop old $_currentBGM and play $name');
      await _bgmPlayer.stop();
      await _bgmPlayer.release();

      // 원래 지정된 딜레이와 100중 맥스
      if (delayMillis != null) delayMillis = math.max(delayMillis, 100);
    }

    // delay가 지정됨
    if (delayMillis != null) {
      await Future.delayed(Duration(milliseconds: delayMillis));
    }

    try {
      _currentBGM = name;

      // 볼륨 설정
      await _bgmPlayer.setVolume(volume ?? 0.5);

      await _bgmPlayer.setSource(_loadSound(name));
      await _bgmPlayer.eventStream
          .where((event) => event.eventType == AudioEventType.prepared)
          .map((event) => event.isPrepared!);
      await _bgmPlayer.resume();

      debugPrint('playBGM: bgm $name play done');

      return true;
    } catch (e) {
      debugPrint('AudioManager.playBGM - $name, ${e.toString()}');
      return false;
    }
  }

  bool pauseBGM() {
    if (_currentBGM != null && isBGMPlaying) {
      _bgmPlayer.pause();
      return true;
    }
    return false;
  }

  bool resumeBGM() {
    if (isBgmOn &&
        isSoundOn &&
        _currentBGM != null &&
        _bgmPlayer.state == PlayerState.paused) {
      _bgmPlayer.resume();
      return true;
    }
    return false;
  }

  Future<void> stopBGM({bool? release}) async {
    if (_currentBGM != null) {
      await _bgmPlayer.stop();
      if (release == true) {
        await _bgmPlayer.release();
      }

      debugPrint('stopBGM: $_currentBGM stopped');

      _currentBGM = null;
    } else {
      debugPrint('stopBGM: no current BGM');
    }
  }

  Future<bool> playSound(
    String soundName, {
    bool pauseBGMDuringPlayback = true,
    double? volume,
    Function? onComplete,
  }) async {
    if (!isSoundOn || !isSfxOn || isAppHidden()) {
      debugPrint('playSound: $soundName. sound disabled');
      return false;
    }

    try {
      // 사용 가능한 채널 가져오기
      final channel = getAvailableChannel();
      // 채널이 이미 다른 소리를 재생 중이라면 중지
      if (channel.isPlaying) {
        await channel.stop();
      }

      // 완료 핸들러 등록
      onCompleteHandlers[soundName] = onComplete;

      // 볼륨 설정
      await channel.player!.setVolume(volume ?? 0.5);

      // 오디오 파일 재생
      final result = await channel.play(soundName, cache: _audioCache);

      debugPrint('playSound: $soundName played. state ${result}');

      return result;
    } catch (e) {
      debugPrint('AudioManager.playSound - $soundName, ${e.toString()}');
      onComplete?.call();
      return false;
    }
  }

  void setBGMVolume(double val) {
    _bgmPlayer.setVolume(val);
  }

  Future<void> stopAllSfx() async {
    for (var channel in _sfxChannels) {
      channel.stop();
    }
  }

  Future<void> stopAll() async {
    await stopBGM();
    await stopAllSfx();
  }

  bool _audioContextActivated = false;

  Future<void> activateAudio() async {
    if (kIsWeb) {
      if (!_audioContextActivated) {
        await playSound('btn_click',
            volume: 0.01, pauseBGMDuringPlayback: false);
        _audioContextActivated = true;
        debugPrint('AudioManager.activateAudio: play silent sound');
      }
    }
  }

  void playIntro() {
    playBGM('anticipation', volume: 0.5);
  }

  void stopIntro() {
    if (_currentBGM == 'anticipation') {
      stopBGM();
    }
  }

  bool isSoundOn = true;
  bool get isSfxOn => getOption('sfx') ?? true;
  bool get isBgmOn => getOption('bgm') ?? true;

  Map<String, dynamic> soundSettings = {};

  Future _loadSetting() async {
    final pref = await SharedPreferences.getInstance();

    soundSettings = pref.getString('sound_settings') != null
        ? jsonDecode(pref.getString('sound_settings')!)
        : {};
  }

  dynamic getOption(String key) {
    return soundSettings[key];
  }

  Future<void> setOption(String key, dynamic value) async {
    soundSettings[key] = value;

    final pref = await SharedPreferences.getInstance();
    pref.setString('sound_settings', jsonEncode(soundSettings));
  }

  Future<void> setSfx(bool v) async {
    await setOption('sfx', v);
  }

  Future<void> setBgm(bool v) async {
    await setOption('bgm', v);
    if (!isBgmOn) stopBGM();
  }
}
