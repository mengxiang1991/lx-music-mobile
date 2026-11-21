# 曲间拾声 · HarmonyOS 音乐播放器

曲间拾声是一个原生鸿蒙音乐播放器。可以搜索歌曲、浏览不同平台的排行榜、收藏常听的歌，也可以导入本地音频和已有的洛雪歌单。退出 App 后，歌曲、队列和播放进度会保存在本机，下次打开可以接着听。

**[主要功能](#主要功能) · [快速上手](#快速上手) · [播放音源](#播放音源) · [安装与构建](#安装与构建) · [HiCar 调试](#hicar-调试) · [许可与致谢](#许可与致谢)**

## 主要功能

| 功能 | 可以做什么 |
| --- | --- |
| 搜索 | 在酷我曲库里按歌名或歌手搜索。结果可以播放、收藏或加入歌单。 |
| 排行榜 | 在酷我、网易云、QQ 音乐和汽水之间切换。酷我保留 DJ 嗨歌榜和经典老歌榜，汽水的「经典老歌」取自公开的「90后回忆歌单」。 |
| 歌单与收藏 | 新建、重命名和编辑歌单，批量移除歌曲或调整顺序。支持导入洛雪 `.lxmc` 和 JSON 歌单。 |
| 本地音乐 | 在「歌单」导入设备上的音频文件，供本机播放。 |
| 播放控制 | 支持上一首、下一首、进度跳转、顺序播放、列表循环、单曲循环和随机播放。歌曲行的「＋」可以将歌曲设为下一首。支持后台、锁屏和系统媒体控件。 |
| 播放历史 | 在「播放 → 播放历史」查看最近 100 首成功开播的歌曲。同一首只保留最近一条，点歌曲可重播，也可以清空记录。 |
| 备份与同步 | 导出收藏和在线歌单，或通过 WebDAV 在设备间手动上传、下载和应用备份。 |

## 快速上手

1. 打开「搜索」，搜索歌名，或直接从下方排行榜选歌。
2. 点歌曲行的心形图标可收藏。在「歌单」可以建歌单，也可以导入洛雪备份或本地音频。
3. 到「播放」管理队列、切换播放模式或打开播放历史。
4. 想单独检查网络音频是否能播，可以在「音源 → 播放音频链接」点击「播放测试音频」。

### 备份和 WebDAV

从「歌单 → 备份与同步」导出 JSON，再通过「导入歌单」合并回来。两台设备如需共享歌单，填入相同的 HTTPS WebDAV JSON 文件地址，可手动上传、下载合并或应用远端列表。创建文件需要已有目录，覆盖远端文件需要服务端支持强 ETag 和条件 PUT。备份包含在线收藏和在线歌单，本地音频和播放历史存放在各自设备。

## 播放音源

- **内置脚本** · 音源页内置 22 个候选，播放时会自动尝试。上次成功的脚本会优先进入候选队列。
- **GitHub 寻源（本地开发版）** · 在「音源 → GitHub 寻源」点「寻源」，App 会扫描配置好的公开仓库并在弹窗中列出候选。点候选旁的「添加」可以查看仓库、文件、版本和识别出的站点域名，确认后才加入自动换源。关闭弹窗后，可在音源页管理已添加的版本。
- **自定义接口** · 支持保存多套 HTTPS 地址。模板中的 `{source}` 代表歌曲平台，`{id}` 代表歌曲 ID。App 发送 GET 请求，接口可以返回纯文本地址或 `{"url":"https://example.com/audio.mp3"}`。可在音源页切换当前接口和脚本优先级。

例如 `https://music.example.com/resolve?source={source}&id={id}`。

脚本音源需要 API 23 或更高版本。寻源目前扫描 `pdone/lx-music-source`、`shellsec/lx-music-source` 和 `luanmuc/backend-api`。添加时固定 Git 提交及文件校验值，播放时在隔离 Worker 中执行。新添加的脚本只能访问确认对话框里列出的域名，返回的初始音频地址也需属于这些域名。候选能否添加和播放，取决于脚本兼容性、接口域名及第三方服务的可用性。

汽水榜单歌曲优先尝试已配置的地址接口，随后按歌名和歌手在网易云、酷我匹配，再交给播放音源解析。

## 安装与构建

项目使用 **ArkTS、ArkUI、AVPlayer 和 AVSession**。手机系统需为 HarmonyOS 6.0.0（API 20）或更高版本。工程目标 SDK 为 26.0.0，日常版包名为 `com.yueliu.lxmusic`。

1. 用 DevEco Studio 打开 `lx-music-harmony` 目录。
2. 参考 `build-profile.example.json5` 配置工程，并在 DevEco Studio 配置自己的调试签名。
3. 在 Windows 终端进入项目目录运行以下命令。DevEco Studio 安装在其他位置时，用 `-Studio` 指定安装路径。

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

HAP 生成在 `entry/build/default/outputs/default/`。配置好签名后，可通过 DevEco Studio 连接手机安装调试。

## HiCar 调试

本地开发版会在识别到 HiCar 屏幕时切换到车机播放页，提供播放、暂停、上下曲和队列选曲。队列为空时可以从收藏开始播放。手机和车机界面共用同一播放器和进度，媒体卡片通过 AVSession 获取播放信息。实车入口和播控仍待联调。

华为的 [HiCar 原生应用开发准备](https://developer.huawei.com/consumer/cn/doc/HiCar-Guides/development-preparation-0000002038694137/) 说明了「应用尝鲜区」的调试白名单流程。准备独立测试包名，邮件发给华为 HiCar 团队开通白名单。华为配置后，用该测试包名加 `.hicar.test` 后缀进行签名和打包。当前日常包仍使用 `com.yueliu.lxmusic`。

在支持 HiCar 的车机上验证尝鲜区入口、车载音频、媒体卡片和上下曲，并在播放过程中切回手机确认队列和进度接续。

## 许可与致谢

项目代码使用 [Apache License 2.0](LICENSE)。

- 搜索、播放交互与歌单备份格式参考了 [洛雪音乐手机版](https://github.com/lyswhut/lx-music-mobile) 和 [洛雪音乐桌面版](https://github.com/lyswhut/lx-music-desktop)。
- 内置脚本来源包括 [pdone/lx-music-source](https://github.com/pdone/lx-music-source)、[Hei Music](https://github.com/shellsec/lx-music-source) 和 [豆包定制](https://github.com/luanmuc/backend-api)。
