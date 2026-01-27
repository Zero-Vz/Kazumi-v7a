import 'package:flutter/material.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/utils/webdav.dart';

class WebDavEditorPage extends StatefulWidget {
  const WebDavEditorPage({
    super.key,
  });

  @override
  State<WebDavEditorPage> createState() => _WebDavEditorPageState();
}

class _WebDavEditorPageState extends State<WebDavEditorPage> {
  final TextEditingController webDavURLController = TextEditingController();
  final TextEditingController webDavUsernameController = TextEditingController();
  final TextEditingController webDavPasswordController = TextEditingController();
  
  Box setting = GStorage.setting;
  bool passwordVisible = false;

  // 1. 定义 FocusNodes (焦点节点)
  // 这些节点像“锚点”一样，帮助我们手动控制焦点位置
  final FocusNode _urlFocus = FocusNode();
  final FocusNode _userFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();
  final FocusNode _saveBtnFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    webDavURLController.text =
        setting.get(SettingBoxKey.webDavURL, defaultValue: '');
    webDavUsernameController.text =
        setting.get(SettingBoxKey.webDavUsername, defaultValue: '');
    webDavPasswordController.text =
        setting.get(SettingBoxKey.webDavPassword, defaultValue: '');
  }

  // 2. 记得销毁 FocusNodes 以防止内存泄漏
  @override
  void dispose() {
    _urlFocus.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _saveBtnFocus.dispose();
    webDavURLController.dispose();
    webDavUsernameController.dispose();
    webDavPasswordController.dispose();
    super.dispose();
  }

  // 辅助方法：处理保存逻辑
  Future<void> _handleSave() async {
    setting.put(SettingBoxKey.webDavURL, webDavURLController.text);
    setting.put(SettingBoxKey.webDavUsername, webDavUsernameController.text);
    setting.put(SettingBoxKey.webDavPassword, webDavPasswordController.text);
    var webDav = WebDav();
    try {
      await webDav.init();
    } catch (e) {
      KazumiDialog.showToast(message: '配置失败 ${e.toString()}');
      await setting.put(SettingBoxKey.webDavEnable, false);
      return;
    }
    KazumiDialog.showToast(message: '配置成功, 开始测试');
    try {
      await webDav.ping();
      KazumiDialog.showToast(message: '测试成功');
    } catch (e) {
      KazumiDialog.showToast(message: '测试失败 ${e.toString()}');
      await setting.put(SettingBoxKey.webDavEnable, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SysAppBar(
        title: Text('WEBDAV编辑'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SizedBox(
            width: (MediaQuery.of(context).size.width > 1000) ? 1000 : null,
            child: Column(
              children: [
                TextField(
                  focusNode: _urlFocus, // 绑定焦点
                  controller: webDavURLController,
                  // 3. 设置键盘动作为 "Next" (下一项)
                  textInputAction: TextInputAction.next,
                  // 4. 当用户按下遥控器确定键或软键盘的Next时，跳转到下一个焦点
                  onSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_userFocus);
                  },
                  decoration: const InputDecoration(
                      labelText: 'URL', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                TextField(
                  focusNode: _userFocus, // 绑定焦点
                  controller: webDavUsernameController,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_passFocus);
                  },
                  decoration: const InputDecoration(
                      labelText: 'Username', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                TextField(
                  focusNode: _passFocus, // 绑定焦点
                  controller: webDavPasswordController,
                  obscureText: !passwordVisible,
                  textInputAction: TextInputAction.done, // 最后一个输入框设为 Done
                  onSubmitted: (_) {
                    // 输入完密码后，跳转到保存按钮
                    FocusScope.of(context).requestFocus(_saveBtnFocus);
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          passwordVisible = !passwordVisible;
                        });
                      },
                      icon: Icon(passwordVisible
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        focusNode: _saveBtnFocus, // 给按钮也绑定焦点
        child: const Icon(Icons.save),
        onPressed: _handleSave,
      ),
    );
  }
}
