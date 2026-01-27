import 'dart:async';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:kazumi/pages/player/player_item_panel.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/logger.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/pages/player/player_item_surface.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:kazumi/pages/my/my_controller.dart';

class PlayerItem extends StatefulWidget {
  const PlayerItem({
    super.key,
    required this.openMenu,
    required this.locateEpisode,
    required this.changeEpisode,
    required this.onBackPressed,
    required this.keyboardFocus,
    required this.sendDanmaku,
    this.disableAnimations = false,
  });

  final VoidCallback openMenu;
  final VoidCallback locateEpisode;
  final Future<void> Function(int episode, {int currentRoad, int offset})
      changeEpisode;
  final void Function(BuildContext) onBackPressed;
  final void Function(String) sendDanmaku;
  final FocusNode keyboardFocus;
  final bool disableAnimations;

  @override
  State<PlayerItem> createState() => _PlayerItemState();
}

class _PlayerItemState extends State<PlayerItem>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  Box setting = GStorage.setting;
  final PlayerController playerController = Modular.get<PlayerController>();
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final HistoryController historyController = Modular.get<HistoryController>();
  final CollectController collectController = Modular.get<CollectController>();
  final MyController myController = Modular.get<MyController>();

  late Map<String, List<String>> keyboardShortcuts;
  late List<String> keyboardActionsNeedLongPress;
  late Map<String, void Function()> keyboardActions;

  // 播放按钮专用焦点控制器
  final FocusNode playButtonFocusNode = FocusNode();

  // HUD (Heads-Up Display) 状态变量
  bool _hudVisible = false;
  IconData? _hudIcon;
  String? _hudText;
  String? _hudSubText;
  Timer? _hudTimer;

  // Seek 累积逻辑变量
  int _seekAccumulator = 0;
  Timer? _seekResetTimer;

  late int collectType;

  // 弹幕相关变量
  final _danmuKey = GlobalKey();
  late bool _border;
  late double _opacity;
  late double _fontSize;
  late double _danmakuArea;
  late bool _hideTop;
  late bool _hideBottom;
  late bool _hideScroll;
  late bool _massiveMode;
  late bool _danmakuColor;
  late bool _danmakuBiliBiliSource;
  late bool _danmakuGamerSource;
  late bool _danmakuDanDanSource;
  late double _danmakuDuration;
  late double _danmakuLineHeight;
  late int _danmakuFontWeight;
  late bool _danmakuUseSystemFont;

  late bool haEnable;
  late bool autoPlayNext;

  Timer? hideTimer;
  Timer? playerTimer;

  AnimationController? animationController;
  double lastPlayerSpeed = 1.0;
  int episodeNum = 0;

  late mobx.ReactionDisposer _fullscreenListener;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    try {
      if (playerController.playerPlaying) {
        playerController.danmakuController.resume();
      }
    } catch (_) {}
  }

  void _loadShortcuts() {
    keyboardShortcuts = {};
    defaultShortcuts.forEach((key, defaultValue) {
      keyboardShortcuts[key] = setting
          .get('shortcut_$key', defaultValue: defaultValue)
          .cast<String>();
    });
  }

  void _initKeyboardActions() {
    keyboardActionsNeedLongPress = ["forward"];
    keyboardActions = {
      'playorpause': () => _togglePlayWithHud(),
      'forward': () async => handleShortcutForwardDown(),
      'rewind': () async => handleShortcutRewind(),
      'next': () async => handlePreNextEpisode('next'),
      'prev': () async => handlePreNextEpisode('prev'),
      'fullscreen': () => handleShortcutFullscreen(),
      'skip': () async => skipOP(),
      'toggledanmaku': () => handleDanmaku(),
      'speed1': () async => setPlaybackSpeed(1.0),
      'speed2': () async => setPlaybackSpeed(2.0),
      'speed3': () async => setPlaybackSpeed(3.0),
      'speedup': () async => handleSpeedChange('up'),
      'speeddown': () async => handleSpeedChange('down'),
      'forwardRepeat': () async => handleShortcutForwardRepeat(),
      'forwardUp': () async => handleShortcutForwardUp(),
    };
  }

  void _initPlayerMenu() {
    Utils.initPlayerMenu(keyboardActions);
  }

  void _disposePlayerMenu() {
    Utils.disposePlayerMenu();
  }

  // 格式化时间 HH:MM:SS 或 MM:SS
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  // 触发 HUD 显示
  void _triggerHud({IconData? icon, String? text, String? subText}) {
    _hudTimer?.cancel(); // 先取消旧的计时器
    
    setState(() {
      _hudVisible = true;
      if (icon != null) _hudIcon = icon;
      _hudText = text;
      _hudSubText = subText;
    });

    if (icon == Icons.play_arrow_rounded) {
      return; 
    }

    _hudTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _hudVisible = false;
        });
      }
    });
  }

  // 带 HUD 的播放/暂停切换
  void _togglePlayWithHud() {
    bool wasPlaying = playerController.playing;
    playerController.playOrPause();

    // 暂停时需要确保显示菜单
    if (wasPlaying) {
      // 变为暂停状态，如果菜单是隐藏的，建议显示出来（可选，根据用户习惯）
      // displayVideoController(); 
      // 按照需求：暂停时不自动隐藏，如果用户在暂停时手动唤出菜单，菜单将不会消失。
    } else {
      // 变为播放状态，重新开始隐藏计时
      startHideTimer();
    }

    String? timeText;
    if (wasPlaying) {
      timeText = _formatDuration(playerController.currentPosition);
    }

    _triggerHud(
      icon: wasPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
      text: timeText,
      subText: null,
    );
  }

  bool handleShortcutDown(String keyLabel) {
    for (final entry in keyboardShortcuts.entries) {
      final func = entry.key;
      final keys = entry.value;
      if (keys.contains(keyLabel)) {
        final action = keyboardActions[func];
        if (action != null) {
          action();
          return true;
        }
      }
    }
    return false;
  }

  bool handleShortcutLongPress(String keyLabel, String mode) {
    for (final func in keyboardActionsNeedLongPress) {
      final keys = keyboardShortcuts[func];
      if (keys?.contains(keyLabel) == true) {
        final action = keyboardActions[func + mode];
        if (action != null) {
          action();
          return true;
        }
      }
    }
    return false;
  }

  Future<void> handlePreNextEpisode(String direction) async {
    if (videoPageController.loading) return;
    final currentRoad = videoPageController.currentRoad;
    final episodes = videoPageController.roadList[currentRoad].data;
    int targetEpisode;
    if (direction == 'next') {
      targetEpisode = videoPageController.currentEpisode + 1;
    } else if (direction == 'prev') {
      targetEpisode = videoPageController.currentEpisode - 1;
    } else {
      return;
    }

    if (targetEpisode > episodes.length) {
      KazumiDialog.showToast(message: '已经是最新一集');
      return;
    }
    if (targetEpisode <= 0) {
      KazumiDialog.showToast(message: '已经是第一集');
      return;
    }

    final identifier = videoPageController
        .roadList[currentRoad].identifier[targetEpisode - 1];
    KazumiDialog.showToast(message: '正在加载$identifier');
    widget.changeEpisode(targetEpisode, currentRoad: currentRoad);
  }

  // Seek 处理逻辑
  Future<void> _handleSeekLogic(int deltaSeconds, IconData icon) async {
    _seekResetTimer?.cancel();

    int current = playerController.currentPosition.inSeconds;
    int total = playerController.duration.inSeconds;

    // 1. 累积时间
    _seekAccumulator += deltaSeconds;

    // 2. 计算目标位置
    int targetPosition = current + _seekAccumulator;

    // 3. 边界限制
    if (targetPosition > total) targetPosition = total;
    if (targetPosition < 0) targetPosition = 0;

    // 4. 反向修正累积值 (显示真实增量)
    int actualDelta = targetPosition - current;

    // 5. 格式化 Subtext: （+ 10 S）
    String sign = actualDelta > 0 ? "+" : "-";
    String absValue = actualDelta.abs().toString();
    String subTextStr = "（$sign $absValue S）";

    if (actualDelta == 0) subTextStr = "（0S）";

    // 6. 立即更新 HUD
    _triggerHud(
      icon: icon,
      text: _formatDuration(Duration(seconds: targetPosition)),
      subText: subTextStr,
    );

    // 7. 延迟执行实际跳转
    _seekResetTimer = Timer(const Duration(milliseconds: 800), () async {
      try {
        playerTimer?.cancel();
        await playerController.seek(Duration(seconds: targetPosition));
        playerTimer = getPlayerTimer();

        if (mounted) {
          setState(() {
            _seekAccumulator = 0;
            if (playerController.playing) {
              _hudVisible = false;
            } else {
              _triggerHud(
                icon: Icons.play_arrow_rounded,
                text: _formatDuration(Duration(seconds: targetPosition)),
                subText: null
              );
            }
          });
        }
      } catch (e) {
        KazumiLogger().e('PlayerController: seek failed', error: e);
      }
    });
  }

  // 快退
  Future<void> handleShortcutRewind() async {
    await _handleSeekLogic(-10, Icons.fast_rewind_rounded);
  }

  // 快进
  Future<void> handleShortcutForwardUp() async {
    if (playerController.showPlaySpeed) {
      playerController.showPlaySpeed = false;
      setPlaybackSpeed(lastPlayerSpeed);
      return;
    }
    await _handleSeekLogic(10, Icons.fast_forward_rounded);
  }

  Future<void> handleShortcutForwardDown() async {
    lastPlayerSpeed = playerController.playerSpeed;
  }

  Future<void> handleShortcutForwardRepeat() async {
    if (playerController.playerSpeed < 2.0) {
      playerController.showPlaySpeed = true;
      setPlaybackSpeed(2.0);
    }
  }

  void handleShortcutFullscreen() {
    if (!videoPageController.isPip) handleFullscreen();
  }

  // 跳过 OP，固定 80s
  Future<void> skipOP() async {
    await playerController
        .seek(playerController.currentPosition + const Duration(seconds: 75));
    _triggerHud(
      icon: Icons.forward_rounded,
      text: "跳过 OP",
      subText: "（+ 80S）",
    );
  }

  void handleDanmaku() {
    playerController.danmakuController.clear();
    if (playerController.danmakuOn) {
      setState(() {
        playerController.danmakuOn = false;
      });
      setting.put(SettingBoxKey.danmakuEnabledByDefault, false);
      _triggerHud(icon: Icons.visibility_off_rounded, text: "弹幕关", subText: null);
      return;
    }
    if (playerController.danDanmakus.isEmpty) {
      KazumiDialog.showToast(message: "暂无弹幕源");
      return;
    }
    setState(() {
      playerController.danmakuOn = true;
    });
    setting.put(SettingBoxKey.danmakuEnabledByDefault, true);
    _triggerHud(icon: Icons.visibility_rounded, text: "弹幕开", subText: null);
  }

  void _handleFullscreenChange(BuildContext context) async {
    playerController.lockPanel = false;
    playerController.danmakuController.clear();
  }

  // --- 一起看服务器切换弹窗 ---
  void showSyncPlayEndPointSwitchDialog() {
    if (playerController.syncplayController != null) {
      KazumiDialog.showToast(message: 'SyncPlay: 请先退出当前房间再切换服务器');
      return;
    }

    final String defaultCustomSyncPlayEndPoint = '自定义服务器';
    String customSyncPlayEndPoint = defaultCustomSyncPlayEndPoint;
    String selectedSyncPlayEndPoint = setting.get(
        SettingBoxKey.syncPlayEndPoint,
        defaultValue: defaultSyncPlayEndPoint);

    KazumiDialog.show(
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          List<String> syncPlayEndPoints = [];
          syncPlayEndPoints.addAll(defaultSyncPlayEndPoints);
          syncPlayEndPoints.add(customSyncPlayEndPoint);
          if (!syncPlayEndPoints.contains(selectedSyncPlayEndPoint)) {
            syncPlayEndPoints.add(selectedSyncPlayEndPoint);
          }
          return AlertDialog(
            title: const Text('选择服务器'),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    value: selectedSyncPlayEndPoint,
                    items: syncPlayEndPoints.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        if (newValue == defaultCustomSyncPlayEndPoint) {
                          final serverTextController = TextEditingController();
                          KazumiDialog.show(
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('自定义服务器'),
                                content: TextField(
                                  controller: serverTextController,
                                  decoration: const InputDecoration(
                                    hintText: '请输入服务器地址',
                                  ),
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    child: const Text('取消'),
                                    onPressed: () {
                                      KazumiDialog.dismiss();
                                    },
                                  ),
                                  TextButton(
                                    child: const Text('确认'),
                                    onPressed: () {
                                      if (serverTextController
                                              .text.isNotEmpty &&
                                          !syncPlayEndPoints.contains(
                                              serverTextController.text)) {
                                        KazumiDialog.dismiss();
                                        setDialogState(() {
                                          customSyncPlayEndPoint =
                                              serverTextController.text;
                                          selectedSyncPlayEndPoint =
                                              serverTextController.text;
                                        });
                                      } else {
                                        KazumiDialog.showToast(
                                            message: '服务器地址不能重复或为空');
                                      }
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        } else {
                          setDialogState(() {
                            selectedSyncPlayEndPoint = newValue;
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('取消'),
                onPressed: () {
                  KazumiDialog.dismiss();
                },
              ),
              TextButton(
                child: const Text('确认'),
                onPressed: () {
                  setting.put(
                    SettingBoxKey.syncPlayEndPoint,
                    selectedSyncPlayEndPoint,
                  );
                  KazumiDialog.dismiss();
                },
              ),
            ],
          );
        });
      },
    );
  }

  // --- 一起看房间创建弹窗 ---
  void showSyncPlayRoomCreateDialog() {
    final formKey = GlobalKey<FormState>();
    final TextEditingController roomController = TextEditingController();
    final TextEditingController usernameController = TextEditingController();
    KazumiDialog.show(builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('加入房间'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: roomController,
                keyboardType: TextInputType.number,
                // 修改：添加 TextInputAction.next，方便跳转
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '房间号',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入房间号';
                  }
                  final regex = RegExp(r'^[0-9]{6,10}$');
                  if (!regex.hasMatch(value)) {
                    return '房间号需要6到10位数字';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: usernameController,
                // 修改：添加 TextInputAction.done
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '用户名',
                ),
                // 修改：监听提交，支持回车键
                onFieldSubmitted: (_) {
                  if (formKey.currentState!.validate()) {
                    KazumiDialog.dismiss();
                    playerController.createSyncPlayRoom(roomController.text,
                        usernameController.text, widget.changeEpisode);
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入用户名';
                  }
                  final regex = RegExp(r'^[a-zA-Z]{4,12}$');
                  if (!regex.hasMatch(value)) {
                    return '用户名必须为4到12位英文字符';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              KazumiDialog.dismiss();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                KazumiDialog.dismiss();
                playerController.createSyncPlayRoom(roomController.text,
                    usernameController.text, widget.changeEpisode);
              }
            },
            child: const Text('确定'),
          ),
        ],
      );
    });
  }

  void handleFullscreen() {
    _handleFullscreenChange(context);
    if (videoPageController.isFullscreen) {
      Utils.exitFullScreen();
      if (!Utils.isDesktop()) {
        widget.locateEpisode();
        videoPageController.showTabBody = true;
      }
    } else {
      Utils.enterFullScreen();
      videoPageController.showTabBody = false;
    }
    videoPageController.isFullscreen = !videoPageController.isFullscreen;
  }

  void displayVideoController() {
    animationController?.forward();
    hideTimer?.cancel();
    startHideTimer();
    playerController.showVideoController = true;
  }

  void hideVideoController() {
    animationController?.reverse();
    hideTimer?.cancel();
    playerController.showVideoController = false;
    widget.keyboardFocus.requestFocus();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await playerController.setPlaybackSpeed(speed);
  }

  Future<void> handleSpeedChange(String type) async {
    try {
      final currentSpeed = playerController.playerSpeed;
      int index = defaultPlaySpeedList.indexOf(currentSpeed);
      if (type == "up") {
        if (index < defaultPlaySpeedList.length - 1) {
          index++;
          setPlaybackSpeed(defaultPlaySpeedList[index]);
        } else {
          KazumiDialog.showToast(message: '已达倍速上限');
        }
      } else if (type == "down") {
        if (index > 0) {
          index--;
          setPlaybackSpeed(defaultPlaySpeedList[index]);
        } else {
          KazumiDialog.showToast(message: '已达倍速下限');
        }
      }
    } catch (e) {
      KazumiLogger().e('PlayerController: speed change failed', error: e);
    }
  }

  void startHideTimer() {
    hideTimer = Timer(const Duration(seconds: 8), () {
      // 修改：增加 && playerController.playing 判断
      // 只有在播放状态下才自动隐藏，暂停时保持显示
      if (mounted && playerController.canHidePlayerPanel && playerController.playing) {
        playerController.showVideoController = false;
        animationController?.reverse();
        widget.keyboardFocus.requestFocus();
      }
      hideTimer = null;
    });
  }

  void cancelHideTimer() {
    hideTimer?.cancel();
  }

  Timer getPlayerTimer() {
    return Timer.periodic(const Duration(seconds: 1), (timer) {
      playerController.playing = playerController.playerPlaying;
      playerController.isBuffering = playerController.playerBuffering;
      playerController.currentPosition = playerController.playerPosition;
      playerController.buffer = playerController.playerBuffer;
      playerController.duration = playerController.playerDuration;
      playerController.completed = playerController.playerCompleted;
      if (playerController.currentPosition.inMicroseconds != 0 &&
          playerController.playerPlaying == true &&
          playerController.danmakuOn == true) {
        playerController.danDanmakus[playerController.currentPosition.inSeconds]
            ?.asMap()
            .forEach((idx, danmaku) async {
          if (!_danmakuColor) {
            danmaku.color = Colors.white;
          }
          if (!_danmakuBiliBiliSource && danmaku.source.contains('BiliBili')) {
            return;
          }
          if (!_danmakuGamerSource && danmaku.source.contains('Gamer')) {
            return;
          }
          if (!_danmakuDanDanSource &&
              !(danmaku.source.contains('BiliBili') ||
                  danmaku.source.contains('Gamer'))) {
            return;
          }
          await Future.delayed(
              Duration(
                  milliseconds: idx *
                      1000 ~/
                      playerController
                          .danDanmakus[
                              playerController.currentPosition.inSeconds]!
                          .length),
              () => mounted &&
                      playerController.playerPlaying &&
                      !playerController.playerBuffering &&
                      playerController.danmakuOn &&
                      !myController.isDanmakuBlocked(danmaku.message)
                  ? playerController.danmakuController.addDanmaku(
                      DanmakuContentItem(danmaku.message,
                          color: danmaku.color,
                          type: danmaku.type == 4
                              ? DanmakuItemType.bottom
                              : (danmaku.type == 5
                                  ? DanmakuItemType.top
                                  : DanmakuItemType.scroll)))
                  : null);
        });
      }

      if (playerController.playerPlaying && !videoPageController.loading) {
        historyController.updateHistory(
            videoPageController.currentEpisode,
            videoPageController.currentRoad,
            videoPageController.currentPlugin.name,
            videoPageController.bangumiItem,
            playerController.playerPosition,
            videoPageController.src,
            videoPageController.roadList[videoPageController.currentRoad]
                .identifier[videoPageController.currentEpisode - 1]);
      }
      if (playerController.completed &&
          videoPageController.currentEpisode <
              videoPageController
                  .roadList[videoPageController.currentRoad].data.length &&
          !videoPageController.loading &&
          autoPlayNext) {
        KazumiDialog.showToast(
            message:
                '正在加载${videoPageController.roadList[videoPageController.currentRoad].identifier[videoPageController.currentEpisode]}');
        try {
          playerTimer!.cancel();
        } catch (_) {}
        widget.changeEpisode(videoPageController.currentEpisode + 1,
            currentRoad: videoPageController.currentRoad);
      }
      playerController.setSyncPlayCurrentPosition();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadShortcuts();
    _initKeyboardActions();
    _initPlayerMenu();
    _fullscreenListener = mobx.reaction<bool>(
      (_) => videoPageController.isFullscreen,
      (_) {
        _handleFullscreenChange(context);
      },
    );
    WidgetsBinding.instance.addObserver(this);
    animationController ??= AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    playerController.danmakuOn =
        setting.get(SettingBoxKey.danmakuEnabledByDefault, defaultValue: false);
    _border = setting.get(SettingBoxKey.danmakuBorder, defaultValue: true);
    _opacity = setting.get(SettingBoxKey.danmakuOpacity, defaultValue: 1.0);
    _fontSize = setting.get(SettingBoxKey.danmakuFontSize, defaultValue: 25.0);
    _danmakuArea = setting.get(SettingBoxKey.danmakuArea, defaultValue: 1.0);
    _hideTop = !setting.get(SettingBoxKey.danmakuTop, defaultValue: true);
    _hideBottom =
        !setting.get(SettingBoxKey.danmakuBottom, defaultValue: false);
    _hideScroll = !setting.get(SettingBoxKey.danmakuScroll, defaultValue: true);
    _massiveMode =
        setting.get(SettingBoxKey.danmakuMassive, defaultValue: false);
    _danmakuColor = setting.get(SettingBoxKey.danmakuColor, defaultValue: true);
    _danmakuDuration =
        setting.get(SettingBoxKey.danmakuDuration, defaultValue: 8.0);
    _danmakuLineHeight =
        setting.get(SettingBoxKey.danmakuLineHeight, defaultValue: 1.6);
    _danmakuBiliBiliSource =
        setting.get(SettingBoxKey.danmakuBiliBiliSource, defaultValue: true);
    _danmakuGamerSource =
        setting.get(SettingBoxKey.danmakuGamerSource, defaultValue: true);
    _danmakuDanDanSource =
        setting.get(SettingBoxKey.danmakuDanDanSource, defaultValue: true);
    _danmakuFontWeight =
        setting.get(SettingBoxKey.danmakuFontWeight, defaultValue: 4);
    _danmakuUseSystemFont =
        setting.get(SettingBoxKey.useSystemFont, defaultValue: false);
    haEnable = setting.get(SettingBoxKey.hAenable, defaultValue: true);
    autoPlayNext = setting.get(SettingBoxKey.autoPlayNext, defaultValue: true);
    playerTimer = getPlayerTimer();
    displayVideoController();
  }

  @override
  void dispose() {
    _fullscreenListener();
    WidgetsBinding.instance.removeObserver(this);
    playerTimer?.cancel();
    hideTimer?.cancel();
    animationController?.dispose();
    animationController = null;
    _disposePlayerMenu();
    playButtonFocusNode.dispose();
    _hudTimer?.cancel();
    _seekResetTimer?.cancel();
    playerController.lockPanel = false;
    playerController.showVideoController = true;
    playerController.showSeekTime = false;
    playerController.showBrightness = false;
    playerController.showVolume = false;
    playerController.showPlaySpeed = false;
    playerController.brightnessSeeking = false;
    playerController.volumeSeeking = false;
    playerController.canHidePlayerPanel = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    collectType =
        collectController.getCollectType(videoPageController.bangumiItem);
    return Observer(
      builder: (context) {
        return ClipRect(
          child: Container(
            color: Colors.black,
            child: SizedBox(
              height: videoPageController.isFullscreen
                  ? (MediaQuery.of(context).size.height)
                  : (MediaQuery.of(context).size.width * 9.0 / (16.0)),
              width: MediaQuery.of(context).size.width,
              child: Stack(alignment: Alignment.center, children: [
                Center(
                    child: Focus(
                        focusNode: widget.keyboardFocus,
                        autofocus: true,
                        // 修正：onKeyEvent，允许 KeyRepeatEvent 通过以支持长按，过滤 KeyUp
                        onKeyEvent: (focusNode, KeyEvent event) {
                          if (event is KeyUpEvent) {
                            return KeyEventResult.ignored;
                          }

                          final key = event.logicalKey;

                          // 1. 确认键 / 播放键
                          if (key == LogicalKeyboardKey.select ||
                              key == LogicalKeyboardKey.enter ||
                              key == LogicalKeyboardKey.gameButtonA ||
                              key == LogicalKeyboardKey.mediaPlay ||
                              key == LogicalKeyboardKey.mediaPause ||
                              key == LogicalKeyboardKey.mediaPlayPause) {
                            if (!playerController.showVideoController) {
                              // 只在 KeyDown 时触发播放暂停，避免长按重复触发
                              if (event is KeyDownEvent) {
                                _togglePlayWithHud();
                              }
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          }

                          // 2. 菜单键 / 上键：呼出菜单并聚焦
                          if (key == LogicalKeyboardKey.contextMenu ||
                              key == LogicalKeyboardKey.arrowUp) {
                            if (!playerController.showVideoController) {
                              if (event is KeyDownEvent) {
                                displayVideoController();
                                playButtonFocusNode.requestFocus();
                              }
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          }

                          // 3. 下键：隐藏菜单
                          if (key == LogicalKeyboardKey.arrowDown) {
                            if (playerController.showVideoController) {
                              if (event is KeyDownEvent) {
                                hideVideoController();
                              }
                              return KeyEventResult.handled;
                            }
                          }

                          // 4. 左右键逻辑 (直接 Seek + HUD)
                          if (!playerController.showVideoController) {
                            if (key == LogicalKeyboardKey.arrowLeft) {
                              handleShortcutRewind();
                              return KeyEventResult.handled;
                            }
                            if (key == LogicalKeyboardKey.arrowRight) {
                              handleShortcutForwardUp();
                              return KeyEventResult.handled;
                            }
                          } else {
                            return KeyEventResult.ignored;
                          }

                          // 处理其他快捷键
                          bool handled = false;
                          final keyLabel = event.logicalKey.keyLabel.isNotEmpty
                              ? event.logicalKey.keyLabel
                              : event.logicalKey.debugName ?? '';
                          if (event is KeyDownEvent) {
                            handled = handleShortcutDown(keyLabel);
                          }
                          return handled
                              ? KeyEventResult.handled
                              : KeyEventResult.ignored;
                        },
                        child: const PlayerItemSurface())),

                // Loading
                (playerController.isBuffering || videoPageController.loading)
                    ? const Positioned.fill(
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Container(),

                // 弹幕
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: videoPageController.isFullscreen
                      ? MediaQuery.sizeOf(context).height
                      : (MediaQuery.sizeOf(context).width * 9 / 16),
                  child: DanmakuScreen(
                    key: _danmuKey,
                    createdController: (DanmakuController e) {
                      playerController.danmakuController = e;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        playerController.updateDanmakuSpeed();
                      });
                    },
                    option: DanmakuOption(
                      hideTop: _hideTop,
                      hideScroll: _hideScroll,
                      hideBottom: _hideBottom,
                      area: _danmakuArea,
                      opacity: _opacity,
                      fontSize: _fontSize,
                      duration: _danmakuDuration / playerController.playerSpeed,
                      lineHeight: _danmakuLineHeight,
                      strokeWidth: _border ? 1.5 : 0.0,
                      fontWeight: _danmakuFontWeight,
                      massiveMode: _massiveMode,
                      fontFamily:
                          _danmakuUseSystemFont ? null : customAppFontFamily,
                    ),
                  ),
                ),

                // HUD (优化：缩小尺寸 200x150, 4:3)
                if (_hudVisible)
                  Positioned.fill(
                    child: Center(
                      child: SizedBox(
                        width: 200, // 缩小尺寸
                        height: 150, // 缩小尺寸 (4:3)
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          // 内容居中
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_hudIcon != null)
                                Icon(_hudIcon, color: Colors.white, size: 48), // 图标对应缩小
                              if (_hudText != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _hudText!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24, // 字号对应缩小
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                              if (_hudSubText != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _hudSubText!,
                                  style: const TextStyle(
                                    color: Colors.white, // 强制白色
                                    fontSize: 16, // 字号对应缩小
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // 播放器控制面板
                PlayerItemPanel(
                  playButtonFocusNode: playButtonFocusNode,
                  onBackPressed: widget.onBackPressed,
                  setPlaybackSpeed: setPlaybackSpeed,
                  changeEpisode: widget.changeEpisode,
                  handleFullscreen: handleFullscreen,
                  // 移除：handleSuperResolutionChange: handleSuperResolutionChange,
                  handlePreNextEpisode: handlePreNextEpisode,
                  animationController: animationController!,
                  keyboardFocus: widget.keyboardFocus,
                  sendDanmaku: widget.sendDanmaku,
                  startHideTimer: startHideTimer,
                  cancelHideTimer: cancelHideTimer,
                  handleDanmaku: handleDanmaku,
                  skipOP: skipOP,
                  disableAnimations: widget.disableAnimations,
                  // 新增：一起看回调
                  showSyncPlayRoomCreateDialog: showSyncPlayRoomCreateDialog,
                  showSyncPlayEndPointSwitchDialog: showSyncPlayEndPointSwitchDialog,
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}
