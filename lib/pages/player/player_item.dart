import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

class PlayerItemPanel extends StatefulWidget {
  const PlayerItemPanel({
    super.key,
    required this.onBackPressed,
    required this.setPlaybackSpeed,
    required this.changeEpisode,
    required this.handleFullscreen,
    required this.handlePreNextEpisode,
    // 移除：required this.handleSuperResolutionChange,
    required this.animationController,
    required this.keyboardFocus,
    required this.sendDanmaku,
    required this.startHideTimer,
    required this.cancelHideTimer,
    required this.handleDanmaku,
    required this.skipOP,
    required this.playButtonFocusNode,
    // 新增：一起看回调
    required this.showSyncPlayRoomCreateDialog,
    required this.showSyncPlayEndPointSwitchDialog,
    this.disableAnimations = false,
  });

  final void Function(BuildContext) onBackPressed;
  final Future<void> Function(double) setPlaybackSpeed;
  final Future<void> Function(int, {int currentRoad, int offset}) changeEpisode;
  final void Function() handleFullscreen;
  // 移除：final Future<void> Function(int shaderIndex) handleSuperResolutionChange;
  final AnimationController animationController;
  final FocusNode keyboardFocus;
  final void Function() startHideTimer;
  final void Function() cancelHideTimer;
  final void Function() handleDanmaku;
  final void Function(String direction) handlePreNextEpisode;
  final void Function() skipOP;
  final void Function(String) sendDanmaku;
  final FocusNode playButtonFocusNode;
  // 新增：一起看回调
  final void Function() showSyncPlayRoomCreateDialog;
  final void Function() showSyncPlayEndPointSwitchDialog;
  final bool disableAnimations;

  @override
  State<PlayerItemPanel> createState() => _PlayerItemPanelState();
}

class _PlayerItemPanelState extends State<PlayerItemPanel> {
  Box setting = GStorage.setting;
  late Animation<Offset> topOffsetAnimation;
  late Animation<Offset> bottomOffsetAnimation;
  final VideoPageController videoPageController =
      Modular.get<VideoPageController>();
  final PlayerController playerController = Modular.get<PlayerController>();

  // SVG Caches
  String? cachedSvgString;
  Widget? cachedDanmakuOnIcon;
  Widget? cachedDanmakuOffIcon;
  Widget? cachedDanmakuSettingIcon;

  static const double _danmakuIconSize = 24.0;
  static const double _loadingIndicatorStrokeWidth = 2.0;

  @override
  void initState() {
    super.initState();
    topOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: widget.animationController,
      curve: Curves.easeInOut,
    ));
    bottomOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: widget.animationController,
      curve: Curves.easeInOut,
    ));
    cacheSvgIcons();
  }

  void cacheSvgIcons() {
    cachedDanmakuOffIcon = RepaintBoundary(
      child: SvgPicture.asset(
        'assets/images/danmaku_off.svg',
        height: _danmakuIconSize,
      ),
    );

    cachedDanmakuSettingIcon = RepaintBoundary(
      child: SvgPicture.asset(
        'assets/images/danmaku_setting.svg',
        height: _danmakuIconSize,
      ),
    );
  }

  Widget danmakuOnIcon(BuildContext context) {
    final colorHex = Theme.of(context)
        .colorScheme
        .primary
        .toARGB32()
        .toRadixString(16)
        .substring(2);

    if (cachedSvgString != colorHex) {
      cachedSvgString = colorHex;
      final svgString = danmakuOnSvg.replaceFirst('00AEEC', colorHex);
      cachedDanmakuOnIcon = RepaintBoundary(
        child: SvgPicture.string(
          svgString,
          height: _danmakuIconSize,
        ),
      );
    }

    return cachedDanmakuOnIcon!;
  }

  Widget _buildDanmakuToggleButton(BuildContext context) {
    return TVIconButton(
      color: Colors.white,
      icon: playerController.danmakuLoading
          ? SizedBox(
              width: _danmakuIconSize,
              height: _danmakuIconSize,
              child: CircularProgressIndicator(
                strokeWidth: _loadingIndicatorStrokeWidth,
              ),
            )
          : (playerController.danmakuOn
              ? danmakuOnIcon(context)
              : cachedDanmakuOffIcon!),
      onPressed: playerController.danmakuLoading
          ? () {}
          : () {
              widget.handleDanmaku();
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) {
      return Stack(
        alignment: Alignment.center,
        children: [
          // 顶部渐变区域
          AnimatedPositioned(
            duration: const Duration(seconds: 1),
            top: 0,
            left: 0,
            right: 0,
            child: Visibility(
              visible: !playerController.lockPanel &&
                  (widget.disableAnimations
                      ? playerController.showVideoController
                      : true),
              child: widget.disableAnimations
                  ? Container(
                      height: 50,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black45,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    )
                  : SlideTransition(
                      position: topOffsetAnimation,
                      child: Container(
                        height: 50,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black45,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),

          // 底部渐变区域
          AnimatedPositioned(
            duration: const Duration(seconds: 1),
            bottom: 0,
            left: 0,
            right: 0,
            child: Visibility(
              visible: !playerController.lockPanel &&
                  (widget.disableAnimations
                      ? playerController.showVideoController
                      : true),
              child: widget.disableAnimations
                  ? Container(
                      height: 100,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black45,
                          ],
                        ),
                      ),
                    )
                  : SlideTransition(
                      position: bottomOffsetAnimation,
                      child: Container(
                        height: 100,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black45,
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),

          // 自定义顶部组件
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Visibility(
              visible: !playerController.lockPanel &&
                  (widget.disableAnimations
                      ? playerController.showVideoController
                      : true),
              child: widget.disableAnimations
                  ? topControlWidget
                  : SlideTransition(
                      position: topOffsetAnimation, child: topControlWidget),
            ),
          ),

          // 自定义播放器底部组件
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Visibility(
              visible: !playerController.lockPanel &&
                  (widget.disableAnimations
                      ? playerController.showVideoController
                      : true),
              child: widget.disableAnimations
                  ? bottomControlWidget
                  : SlideTransition(
                      position: bottomOffsetAnimation,
                      child: bottomControlWidget),
            ),
          ),
        ],
      );
    });
  }

  Widget get bottomControlWidget {
    return Observer(builder: (context) {
      return SafeArea(
        top: false,
        bottom: videoPageController.isFullscreen,
        left: videoPageController.isFullscreen,
        right: videoPageController.isFullscreen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ProgressBar(
                thumbRadius: 8,
                thumbGlowRadius: 18,
                timeLabelLocation: TimeLabelLocation.sides,
                timeLabelTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.0,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                progress: playerController.currentPosition,
                buffered: playerController.buffer,
                total: playerController.duration,
                onSeek: null, // 禁止拖拽/点击
                onDragStart: null,
                onDragUpdate: null,
                onDragEnd: null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: FocusTraversalGroup(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start, // 居左排列，无 Spacer
                  children: [
                    
                    // 1. 播放/暂停
                    TVIconButton(
                      focusNode: widget.playButtonFocusNode,
                      autofocus: true,
                      color: Colors.white,
                      icon: Icon(playerController.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                      onPressed: () {
                        playerController.playOrPause();
                      },
                    ),

                    // 2. 下一集
                    TVIconButton(
                      color: Colors.white,
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: () => widget.handlePreNextEpisode('next'),
                    ),
                    
                     // 3. 跳过 OP (原 forward_80.png 图标)
                    TVIconButton(
                      icon: Image.asset(
                        'assets/images/forward_80.png',
                        color: Colors.white,
                        height: 24,
                      ),
                      onPressed: widget.skipOP,
                    ),

                    // 4. 弹幕开关
                    _buildDanmakuToggleButton(context),

                    // 5. 一起看 (SyncPlay) - 替代原超分辨率位置
                    MenuAnchor(
                      consumeOutsideTap: true,
                      onOpen: () {
                        widget.cancelHideTimer();
                        playerController.canHidePlayerPanel = false;
                      },
                      onClose: () {
                        widget.cancelHideTimer();
                        widget.startHideTimer();
                        playerController.canHidePlayerPanel = true;
                      },
                      builder: (BuildContext context, MenuController controller,
                          Widget? child) {
                        return TVIconButton(
                          onPressed: () {
                            if (controller.isOpen) {
                              controller.close();
                            } else {
                              controller.open();
                            }
                          },
                          // 使用群组图标代表一起看
                          icon: const Icon(Icons.group_rounded,
                              color: Colors.white),
                        );
                      },
                      menuChildren: [
                        MenuItemButton(
                          child: Container(
                            height: 48,
                            constraints: const BoxConstraints(minWidth: 112),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  "当前房间: ${playerController.syncplayRoom == '' ? '未加入' : playerController.syncplayRoom}"),
                            ),
                          ),
                        ),
                        MenuItemButton(
                          child: Container(
                            height: 48,
                            constraints: const BoxConstraints(minWidth: 112),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  "网络延时: ${playerController.syncplayClientRtt}ms"),
                            ),
                          ),
                        ),
                        MenuItemButton(
                          onPressed: () {
                            widget.showSyncPlayRoomCreateDialog();
                          },
                          child: Container(
                            height: 48,
                            constraints: const BoxConstraints(minWidth: 112),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: const Text("加入房间"),
                            ),
                          ),
                        ),
                        MenuItemButton(
                          onPressed: () {
                            widget.showSyncPlayEndPointSwitchDialog();
                          },
                          child: Container(
                            height: 48,
                            constraints: const BoxConstraints(minWidth: 112),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: const Text("切换服务器"),
                            ),
                          ),
                        ),
                        MenuItemButton(
                          onPressed: () async {
                            await playerController.exitSyncPlayRoom();
                          },
                          child: Container(
                            height: 48,
                            constraints: const BoxConstraints(minWidth: 112),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: const Text("断开连接"),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 6. 倍速播放
                    MenuAnchor(
                      consumeOutsideTap: true,
                      onOpen: () {
                        widget.cancelHideTimer();
                        playerController.canHidePlayerPanel = false;
                      },
                      onClose: () {
                        widget.cancelHideTimer();
                        widget.startHideTimer();
                        playerController.canHidePlayerPanel = true;
                      },
                      builder: (BuildContext context, MenuController controller,
                          Widget? child) {
                        return TVIconButton(
                          onPressed: () {
                            if (controller.isOpen) {
                              controller.close();
                            } else {
                              controller.open();
                            }
                          },
                          icon: Text(
                            playerController.playerSpeed == 1.0
                                ? '倍速'
                                : '${playerController.playerSpeed}x',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      },
                      menuChildren: [
                        for (final double i
                            in defaultPlaySpeedList) ...<MenuItemButton>[
                          MenuItemButton(
                            onPressed: () async {
                              await widget.setPlaybackSpeed(i);
                            },
                            child: Container(
                              height: 48,
                              constraints: const BoxConstraints(minWidth: 112),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${i}x',
                                  style: TextStyle(
                                    color: i == playerController.playerSpeed
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // 7. 视频比例
                    MenuAnchor(
                      consumeOutsideTap: true,
                      onOpen: () {
                        widget.cancelHideTimer();
                        playerController.canHidePlayerPanel = false;
                      },
                      onClose: () {
                        widget.cancelHideTimer();
                        widget.startHideTimer();
                        playerController.canHidePlayerPanel = true;
                      },
                      builder: (BuildContext context, MenuController controller,
                          Widget? child) {
                        return TVIconButton(
                          onPressed: () {
                            if (controller.isOpen) {
                              controller.close();
                            } else {
                              controller.open();
                            }
                          },
                          icon: const Icon(Icons.aspect_ratio_rounded,
                              color: Colors.white),
                        );
                      },
                      menuChildren: [
                        for (final entry in aspectRatioTypeMap.entries)
                          MenuItemButton(
                            onPressed: () =>
                                playerController.aspectRatioType = entry.key,
                            child: Container(
                              height: 48,
                              constraints: const BoxConstraints(minWidth: 112),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  entry.value,
                                  style: TextStyle(
                                    color: entry.key ==
                                            playerController.aspectRatioType
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      );
    });
  }

  Widget get topControlWidget {
    return Observer(builder: (context) {
      return SafeArea(
        top: false,
        bottom: false,
        left: videoPageController.isFullscreen,
        right: videoPageController.isFullscreen,
        child: Row(
          children: [
            // 返回按钮
            TVIconButton(
              color: Colors.white,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                widget.onBackPressed(context);
              },
            ),
            // 标题文字
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  ' ${videoPageController.title} [${videoPageController.roadList[videoPageController.currentRoad].identifier[videoPageController.currentEpisode - 1]}]'
                   '${playerController.playerWidth > 0 ? " (${playerController.playerWidth}x${playerController.playerHeight})" : ""}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Theme.of(context).textTheme.titleMedium!.fontSize,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            // 移除：CollectButton（收藏按钮）
          ],
        ),
      );
    });
  }
}

// ----------------------------------------------------
// TV 专用图标按钮，获得焦点时显示边框
// ----------------------------------------------------
class TVIconButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback onPressed;
  final bool autofocus;
  final Color? color;
  final FocusNode? focusNode;

  const TVIconButton({
    Key? key,
    required this.icon,
    required this.onPressed,
    this.autofocus = false,
    this.color,
    this.focusNode,
  }) : super(key: key);

  @override
  _TVIconButtonState createState() => _TVIconButtonState();
}

class _TVIconButtonState extends State<TVIconButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (hasFocus) {
        if (mounted) {
          setState(() {
            _isFocused = hasFocus;
          });
        }
      },
      // 监听遥控器确认键，手动触发点击
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        decoration: _isFocused
            ? BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(50),
                color: Colors.black45, // 加上背景色，让高亮更明显
              )
            : null,
        // 排除内部按钮的焦点，防止“双重高亮”和“焦点残留”
        child: ExcludeFocus(
          child: IconButton(
            icon: widget.icon,
            onPressed: widget.onPressed,
            color: widget.color,
            // 选中时稍微放大一点图标
            iconSize: _isFocused ? 28 : 24,
          ),
        ),
      ),
    );
  }
}
