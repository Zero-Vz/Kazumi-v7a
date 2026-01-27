import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/bean/card/bangumi_card.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/utils/logger.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.inputTag = ''});

  final String inputTag;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final SearchController searchController = SearchController();
  final FocusNode _searchBarFocusNode = FocusNode();

  final SearchPageController searchPageController = SearchPageController();
  final ScrollController scrollController = ScrollController();

  // 控制当前显示的是“建议/历史”还是“搜索结果”
  bool _showSuggestions = true;

  final List<Tab> tabs = [
    Tab(text: "排序方式"),
    Tab(text: "过滤器"),
  ];

  @override
  void initState() {
    super.initState();
    scrollController.addListener(scrollListener);
    searchPageController.loadSearchHistories();

    // 监听焦点变化，当搜索框重新获得焦点时，显示建议列表
    _searchBarFocusNode.addListener(() {
      if (_searchBarFocusNode.hasFocus) {
        setState(() {
          _showSuggestions = true;
        });
      }
    });
  }

  @override
  void dispose() {
    searchPageController.bangumiList.clear();
    scrollController.removeListener(scrollListener);
    _searchBarFocusNode.dispose();
    super.dispose();
  }

  void scrollListener() {
    if (scrollController.hasClients &&
        scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200 &&
        !searchPageController.isLoading &&
        searchController.text != '' &&
        searchPageController.bangumiList.length >= 20) {
      KazumiLogger().i('SearchController: search results is loading more');
      searchPageController.searchBangumi(searchController.text, type: 'add');
    }
  }

  // 执行搜索的统一入口
  void _performSearch(String keyword) {
    if (keyword.isEmpty) return;
    
    // 收起键盘（如果是软键盘）
    _searchBarFocusNode.unfocus();
    
    setState(() {
      _showSuggestions = false; // 隐藏建议，显示结果
      searchController.text = keyword; // 确保输入框文字同步
    });
    
    searchPageController.searchBangumi(keyword, type: 'init');
  }

  Widget showFilterSwitcher() {
    return Wrap(
      children: [
        Observer(
          builder: (context) => InkWell(
            onTap: () {
              searchPageController.setNotShowWatchedBangumis(
                  !searchPageController.notShowWatchedBangumis);
            },
            child: ListTile(
              title: const Text('不显示已看过的番剧'),
              trailing: Switch(
                value: searchPageController.notShowWatchedBangumis,
                onChanged: (value) {
                  searchPageController.setNotShowWatchedBangumis(value);
                },
              ),
            ),
          ),
        ),
        Observer(
          builder: (context) => InkWell(
            onTap: () {
              searchPageController.setNotShowAbandonedBangumis(
                  !searchPageController.notShowAbandonedBangumis);
            },
            child: ListTile(
              title: const Text('不显示已抛弃的番剧'),
              trailing: Switch(
                value: searchPageController.notShowAbandonedBangumis,
                onChanged: (value) {
                  searchPageController.setNotShowAbandonedBangumis(value);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget showSortSwitcher() {
    return Wrap(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('按热度排序'),
              onTap: () {
                Navigator.pop(context);
                final newText = searchPageController.attachSortParams(
                    searchController.text, 'heat');
                _performSearch(newText);
              },
            ),
            ListTile(
              title: const Text('按评分排序'),
              onTap: () {
                Navigator.pop(context);
                final newText = searchPageController.attachSortParams(
                    searchController.text, 'rank');
                _performSearch(newText);
              },
            ),
            ListTile(
              title: const Text('按匹配程度排序'),
              onTap: () {
                Navigator.pop(context);
                final newText = searchPageController.attachSortParams(
                    searchController.text, 'match');
                _performSearch(newText);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget showSearchOptionTabBar({required List<Widget> options}) {
    return DefaultTabController(
        length: tabs.length,
        child: Scaffold(
            body: Column(
          children: [
            PreferredSize(
              preferredSize: Size.fromHeight(kToolbarHeight),
              child: Material(
                child: TabBar(
                  tabs: tabs,
                ),
              ),
            ),
            Expanded(
                child: TabBarView(
              children: options,
            ))
          ],
        )));
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.inputTag != '') {
        final String tagString = 'tag:${Uri.decodeComponent(widget.inputTag)}';
        if (searchController.text != tagString) {
           _performSearch(tagString);
        }
      }
    });

    return Scaffold(
      appBar: SysAppBar(
        backgroundColor: Colors.transparent,
        title: const Text("搜索"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          showModalBottomSheet(
            isScrollControlled: true,
            constraints: BoxConstraints(
              maxHeight: (MediaQuery.sizeOf(context).height >=
                      LayoutBreakpoint.compact['height']!)
                  ? MediaQuery.of(context).size.height * 1 / 4
                  : MediaQuery.of(context).size.height,
              maxWidth: (MediaQuery.sizeOf(context).width >=
                      LayoutBreakpoint.medium['width']!)
                  ? MediaQuery.of(context).size.width * 9 / 16
                  : MediaQuery.of(context).size.width,
            ),
            clipBehavior: Clip.antiAlias,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            context: context,
            builder: (context) {
              return showSearchOptionTabBar(
                  options: [showSortSwitcher(), showFilterSwitcher()]);
            },
          );
        },
        icon: const Icon(Icons.sort),
        label: const Text("搜索设置"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  FocusScope.of(context).nextFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: SearchBar(
                controller: searchController,
                focusNode: _searchBarFocusNode,
                
                // 修改点 1: 还原搜索图标
                leading: const Icon(Icons.search),
                
                // 修改点 2: 恢复背景色逻辑 (选中时高亮，平时默认)
                backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                  (states) {
                    if (states.contains(WidgetState.focused)) {
                       // 选中时的颜色
                      return Theme.of(context).highlightColor.withOpacity(0.2) == Colors.transparent 
                          ? Colors.white24 
                          : Theme.of(context).highlightColor;
                    }
                    // 默认颜色 (返回 null 让组件使用默认主题色，通常是 Surface 颜色)
                    return null;
                  },
                ),
                elevation: WidgetStateProperty.all(0), // 保持扁平化
                
                trailing: [
                  if (searchController.text.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        searchController.clear();
                        setState(() {
                          _showSuggestions = true;
                        });
                        _searchBarFocusNode.requestFocus();
                      },
                      icon: const Icon(Icons.clear),
                    ),
                ],
                hintText: '搜索番剧...',
                onChanged: (value) {
                  if (!_showSuggestions) {
                    setState(() {
                      _showSuggestions = true;
                    });
                  }
                },
                onSubmitted: (value) {
                  _performSearch(value);
                },
              ),
            ),
          ),
          
          Expanded(
            child: _showSuggestions ? _buildSuggestionsList() : _buildSearchResultsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Observer(
      builder: (context) {
        if (searchPageController.searchHistories.isEmpty) {
          return Center(
            child: Text(
              "暂无搜索历史",
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (var history in searchPageController.searchHistories.take(10))
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(history.keyword),
                onTap: () {
                  _performSearch(history.keyword);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    searchPageController.deleteSearchHistory(history);
                  },
                ),
              ),
            if (searchPageController.searchHistories.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  searchPageController.clearSearchHistory();
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text("清空搜索历史"),
              )
          ],
        );
      },
    );
  }

  Widget _buildSearchResultsGrid() {
    return Observer(builder: (context) {
      if (searchPageController.isTimeOut) {
        return Center(
          child: SizedBox(
            height: 400,
            child: GeneralErrorWidget(
              errMsg: '什么都没有找到 (´;ω;`)',
              actions: [
                GeneralErrorButton(
                  onPressed: () {
                    searchPageController.searchBangumi(
                        searchController.text,
                        type: 'init');
                  },
                  text: '点击重试',
                ),
              ],
            ),
          ),
        );
      }

      if (searchPageController.isLoading &&
          searchPageController.bangumiList.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      int crossCount = 3;
      if (MediaQuery.sizeOf(context).width >
          LayoutBreakpoint.compact['width']!) {
        crossCount = 5;
      }
      if (MediaQuery.sizeOf(context).width >
          LayoutBreakpoint.medium['width']!) {
        crossCount = 6;
      }
      List<BangumiItem> filteredList =
          searchPageController.bangumiList.toList();

      if (searchPageController.notShowWatchedBangumis) {
        final watchedBangumiIds =
            searchPageController.loadWatchedBangumiIds();
        filteredList = filteredList
            .where((item) => !watchedBangumiIds.contains(item.id))
            .toList();
      }

      if (searchPageController.notShowAbandonedBangumis) {
        final abandonedBangumiIds =
            searchPageController.loadAbandonedBangumiIds();
        filteredList = filteredList
            .where((item) => !abandonedBangumiIds.contains(item.id))
            .toList();
      }

      return GridView.builder(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          mainAxisSpacing: StyleString.cardSpace - 2,
          crossAxisSpacing: StyleString.cardSpace,
          crossAxisCount: crossCount,
          mainAxisExtent:
              MediaQuery.of(context).size.width / crossCount / 0.65 +
                  MediaQuery.textScalerOf(context).scale(32.0),
        ),
        itemCount: filteredList.isNotEmpty ? filteredList.length : 0,
        itemBuilder: (context, index) {
          return filteredList.isNotEmpty
              ? BangumiCardV(
                  enableHero: false,
                  bangumiItem: filteredList[index],
                )
              : Container();
        },
      );
    });
  }
}
