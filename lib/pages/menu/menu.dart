import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'package:kazumi/pages/router.dart';
import 'package:provider/provider.dart';

class ScaffoldMenu extends StatefulWidget {
  const ScaffoldMenu({super.key});

  @override
  State<ScaffoldMenu> createState() => _ScaffoldMenu();
}

class NavigationBarState extends ChangeNotifier {
  int _selectedIndex = 0;
  bool _isHide = false;
  bool _isBottom = false;

  int get selectedIndex => _selectedIndex;
  bool get isHide => _isHide;
  bool get isBottom => _isBottom;

  void updateSelectedIndex(int pageIndex) {
    _selectedIndex = pageIndex;
    notifyListeners();
  }

  void hideNavigate() {
    _isHide = true;
    notifyListeners();
  }

  void showNavigate() {
    _isHide = false;
    notifyListeners();
  }
}

class _ScaffoldMenu extends State<ScaffoldMenu> {
  final PageController _page = PageController();

  // 定义两个焦点作用域节点，分别管理 菜单区 和 内容区
  final FocusScopeNode _menuScopeNode = FocusScopeNode();
  final FocusScopeNode _contentScopeNode = FocusScopeNode();

  @override
  void dispose() {
    _menuScopeNode.dispose();
    _contentScopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (context) => NavigationBarState(),
        child: Consumer<NavigationBarState>(builder: (context, state, _) {
          return OrientationBuilder(builder: (context, orientation) {
            state._isBottom = orientation == Orientation.portrait;
            return orientation != Orientation.portrait
                ? sideMenuWidget(context, state)
                : bottomMenuWidget(context, state);
          });
        }));
  }

  Widget bottomMenuWidget(BuildContext context, NavigationBarState state) {
    return Scaffold(
        body: Container(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: PageView.builder(
            physics: const NeverScrollableScrollPhysics(),
            controller: _page,
            itemCount: menu.size,
            itemBuilder: (_, __) => const RouterOutlet(),
          ),
        ),
        bottomNavigationBar: state.isHide
            ? const SizedBox(height: 0)
            : NavigationBar(
                destinations: const <Widget>[
                  NavigationDestination(
                    selectedIcon: Icon(Icons.home),
                    icon: Icon(Icons.home_outlined),
                    label: '推荐',
                  ),
                  NavigationDestination(
                    selectedIcon: Icon(Icons.timeline),
                    icon: Icon(Icons.timeline_outlined),
                    label: '时间表',
                  ),
                  NavigationDestination(
                    selectedIcon: Icon(Icons.favorite),
                    icon: Icon(Icons.favorite_outlined),
                    label: '追番',
                  ),
                  NavigationDestination(
                    selectedIcon: Icon(Icons.settings),
                    icon: Icon(Icons.settings),
                    label: '我的',
                  ),
                ],
                selectedIndex: state.selectedIndex,
                onDestinationSelected: (int index) {
                  state.updateSelectedIndex(index);
                  Modular.to.navigate("/tab${menu.getPath(index)}/");
                },
              ));
  }

  Widget sideMenuWidget(BuildContext context, NavigationBarState state) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: Row(
        children: [
          // ==================================================
          // 左侧菜单区域
          // ==================================================
          EmbeddedNativeControlArea(
            child: FocusScope(
              node: _menuScopeNode,
              // 【菜单右键逻辑】：强制寻找右侧第一个控件（重置焦点位置）
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  
                  final policy = FocusTraversalGroup.of(context);
                  
                  // 寻找内容区内的第一个可聚焦元素（通常是 Grid 左上角的卡片）
                  final firstFocusable = policy.findFirstFocus(_contentScopeNode);

                  if (firstFocusable != null) {
                    firstFocusable.requestFocus();
                  } else {
                    // 如果右侧内容为空，保底聚焦到 Scope 本身
                    _contentScopeNode.requestFocus();
                  }
                  
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Visibility(
                visible: !state.isHide,
                child: NavigationRail(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                  groupAlignment: 1.0,
                  leading: FloatingActionButton(
                    elevation: 0,
                    heroTag: null,
                    onPressed: () {
                      Modular.to.pushNamed('/search/');
                    },
                    child: const Icon(Icons.search),
                  ),
                  labelType: NavigationRailLabelType.selected,
                  destinations: const <NavigationRailDestination>[
                    NavigationRailDestination(
                      selectedIcon: Icon(Icons.home),
                      icon: Icon(Icons.home_outlined),
                      label: Text('推荐'),
                    ),
                    NavigationRailDestination(
                      selectedIcon: Icon(Icons.timeline),
                      icon: Icon(Icons.timeline_outlined),
                      label: Text('时间表'),
                    ),
                    NavigationRailDestination(
                      selectedIcon: Icon(Icons.favorite),
                      icon: Icon(Icons.favorite_border),
                      label: Text('追番'),
                    ),
                    NavigationRailDestination(
                      selectedIcon: Icon(Icons.settings),
                      icon: Icon(Icons.settings_outlined),
                      label: Text('我的'),
                    ),
                  ],
                  selectedIndex: state.selectedIndex,
                  onDestinationSelected: (int index) {
                    state.updateSelectedIndex(index);
                    Modular.to.navigate("/tab${menu.getPath(index)}/");
                  },
                ),
              ),
            ),
          ),
          
          // ==================================================
          // 右侧内容区域
          // ==================================================
          Expanded(
            child: FocusScope(
              node: _contentScopeNode,
              // 【内容左键逻辑】：智能判断
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  
                  // 1. 获取当前真正拥有焦点的“叶子节点”（例如 Grid 中的某张卡片）
                  final currentFocus = FocusManager.instance.primaryFocus;

                  // 2. 以这个叶子节点的视角，尝试向左寻找下一个焦点
                  // 这种方式可以穿透嵌套的 Scaffold/PageView 结构
                  bool didMove = false;
                  if (currentFocus != null) {
                    didMove = currentFocus.focusInDirection(TraversalDirection.left);
                  }

                  // 3. 结果判断
                  if (didMove) {
                    // 如果成功移动了（说明还在网格内部），则不做其他处理
                    return KeyEventResult.handled;
                  } else {
                    // 如果无法移动（说明到了网格的最左边缘），则跳回菜单
                    _menuScopeNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              // 保持 Group 以确保内部导航连贯
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(), 
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16.0),
                      bottomLeft: Radius.circular(16.0),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16.0),
                      bottomLeft: Radius.circular(16.0),
                    ),
                    child: PageView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: menu.size,
                      itemBuilder: (_, __) => const RouterOutlet(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
