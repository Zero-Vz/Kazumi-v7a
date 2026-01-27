# Kazumi
根据`Predidit/Kazumi`项目修改成适用于Android v7a的TV端版本
使用 Flutter 开发的基于自定义规则的番剧采集与在线观看程序。
使用最多五行基于 `Xpath` 语法的选择器构建自己的规则。支持规则导入与规则分享。支持基于 `Anime4K` 的实时超分辨率。绝赞开发中 (～￣▽￣)～

## 支持平台

Android v7a TV端

## 屏幕截图 

<table>
  <tr>
    <td><img alt="" src="static/screenshot/img_1.png"></td>
    <td><img alt="" src="static/screenshot/img_2.png"></td>
    <td><img alt="" src="static/screenshot/img_3.png"></td>
  <tr>
  <tr>
    <td><img alt="" src="static/screenshot/img_4.png"></td>
    <td><img alt="" src="static/screenshot/img_5.png"></td>
    <td><img alt="" src="static/screenshot/img_6.png"></td>
  <tr>
</table>

## 功能 / 开发计划

- [x] 规则编辑器
- [x] 番剧目录
- [x] 番剧搜索
- [x] 番剧时间表
- [x] 番剧字幕
- [x] 分集播放
- [x] 视频播放器
- [x] 多视频源支持
- [x] 规则分享
- [x] 硬件加速
- [x] 高刷适配
- [x] 追番列表
- [x] 番剧弹幕
- [x] 在线更新
- [x] 历史记录
- [x] 倍速播放
- [x] 配色方案 
- [x] 跨设备同步
- [x] 无线投屏 (DLNA)
- [x] 外部播放器播放
- [x] 超分辨率
- [x] 一起看
- [ ] 番剧下载
- [ ] 番剧更新提醒
- [ ] 还有更多 (/・ω・＼) 

## 下载

通过本页面 [Actions](https://github.com/Zero-Vz/Kazumi_TV-v7a/actions) 中的PR workflow选项卡下载：

<a href="https://github.com/Zero-Vz/Kazumi_TV-v7a/actions">
  <img src="static/svg/get_it_on_github.svg" alt="Get it on Github" width="200"/>
</a>




## Q&A

<details>
<summary>使用者 Q&A</summary>

#### Q: 为什么少数番剧中有广告？

A: 本项目未插入任何广告。广告来自视频源, 请不要相信广告中的任何内容, 并尽量选择没有广告的视频源观看。

#### Q: 为什么我启用超分辨率功能后播放卡顿？

A: 超分辨率功能对 GPU 性能要求较高, 如果没有在高性能独立显卡上运行 Kazumi, 尽量选择效率档而非质量档。对低分辨率视频源而非高分辨率视频源使用超分也可以降低性能消耗。

#### Q: 为什么播放视频时内存占用较高？

A: 本程序在视频播放时, 会尽可能多地缓存视频到内存, 以提供较好的观看体验。如果您的内存较为紧张, 可以在播放设置选项卡启用低内存模式, 这将限制缓存。

#### Q: 为什么少数番剧无法通过外部播放器观看？

A: 部分视频源的番剧使用了反盗链措施, 这可以被 Kazumi 解决, 但无法被外部播放器解决。

</details>

<details>
<summary>规则编写者 Q&A</summary>

#### Q: 为什么我的自定义规则无法实现检索？

A: 目前我们对 `Xpath` 语法的支持并不完整, 我们目前只支持以 `//` 开头的选择器。建议参照我们给出的示例规则构建自定义规则。

#### Q: 为什么我的自定义规则可以实现检索, 但不能实现观看？

A: 尝试关闭自定义规则的使用内置播放器选项, 这将尝试使用 `webview` 进行播放, 提高兼容性。但在内置播放器可用时, 建议启用内置播放器, 以获得更加流畅并带有弹幕的观看体验。

</details>

<details>
<summary>开发者 Q&A</summary>

#### Q: 我在尝试自行编译该项目, 但编译没有成功。

A: 本项目编译需要良好的网络环境, 除了由 Google 托管的 Flutter 相关依赖外, 本项目同样依赖托管在 MavenCentral/Github/SourceForge 上的资源。如果您位于中国大陆, 可能需要设置恰当的镜像地址。

</details>





