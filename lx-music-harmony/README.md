# 曲间拾声 HarmonyOS

基于 ArkTS、ArkUI 和 HarmonyOS AVPlayer 的独立原生手机应用。参考上游手机版的搜索和播放交互，以及手机版、桌面版的歌单备份格式。

## 构建

1. 在 DevEco Studio 打开本目录。工程的兼容版本为 HarmonyOS 6.0.0（API 20），目标 SDK 为 26.0.0。
2. Windows 下可运行 `powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1`。DevEco Studio 安装在其他位置时，用 `-Studio` 指定路径。
3. 未签名 HAP 生成在 `entry/build/default/outputs/default/entry-default-unsigned.hap`。在 DevEco Studio 配置本项目的调试签名后，连接真机并运行。应用包名为 `com.yueliu.lxmusic`。

## 使用

- **搜索** · 输入歌手或歌名查询酷我曲库，可收藏搜索结果。搜索框下直接展示酷我热歌榜、新歌榜、飙升榜、DJ 嗨歌榜和经典老歌榜。播放搜索或榜单歌曲需要配置播放地址接口。
- **歌单和收藏** · 使用歌曲行的心形按钮收藏线上或本地歌曲，使用加号添加到已有歌单或新建歌单。歌单页的「编辑」支持批量移除和上下排序，自建及导入歌单还可更名和删除。支持导入洛雪 `.lxmc` 和 JSON 歌单。
- **备份和同步** · 从「歌单 → 备份与同步」导出 JSON。通过「导入歌单」可将其合并回来。两台设备使用相同的 HTTPS WebDAV JSON 文件地址，可手动上传、下载合并，或应用远端的名称、顺序和移除。创建远端文件需要已有目录，覆盖时服务端需支持强 ETag 和条件 PUT。备份和同步传输在线条目。导入的本机音频保留在原设备。
- **播放** · 支持播放、暂停、进度跳转、上一首、下一首、顺序播放、列表循环、单曲循环和随机播放。歌曲行的「＋」可设为下一首，队列内也可移除待播歌曲。切到后台或锁屏可继续播放，系统媒体控件可暂停、继续和切歌。重新打开 App 后，点「播放」继续上次的队列和进度。音频源无法跳转时，会提示并尝试从头播放。
- **音源** · 可保存多套 HTTPS 播放音源，并手动选择当前接口。页面底部的「播放音频链接」可用于粘贴直链或试听内置的 SoundHelix MP3。比如 `https://music.example.com/resolve?source={source}&id={id}`。客户端发送 GET 请求，接受纯文本音频 URL 或 `{"url":"https://example.com/audio.mp3"}`。收藏不会改变对应歌曲的来源和 ID。

音源页内置 22 个候选，来自 pdone/lx-music-source、Hei Music 和豆包定制，含原始地址和镜像。脚本按固定版本下载、校验后在隔离的 Worker 中执行。脚本源需要 API 23 或更高的系统。格式兼容和第三方服务可用性可能因音源和歌曲而异。保存的 HTTPS 地址模板和脚本源之间可自动尝试下一项，也可以设置优先尝试脚本源。

排行榜可在酷我音乐、网易云音乐、QQ 音乐和汽水音乐之间切换。汽水的「经典老歌」来自公开歌单「90后回忆歌单」。汽水歌曲播放时优先使用已配置的地址接口，随后按歌名和歌手在网易云、酷我匹配，再交由现有播放音源解析。

当前未接入任意导入洛雪 JavaScript 脚本、歌词及原版洛雪同步协议。

## 上游

- [lx-music-mobile](https://github.com/lyswhut/lx-music-mobile)
- [lx-music-desktop](https://github.com/lyswhut/lx-music-desktop)
