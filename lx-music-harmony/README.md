# 洛雪音乐 HarmonyOS

基于 ArkTS、ArkUI 和 HarmonyOS AVPlayer 的独立原生手机应用。参考上游手机版的搜索和播放交互，以及手机版、桌面版的歌单备份格式。

## 构建

1. 在 DevEco Studio 打开本目录。工程的兼容版本为 HarmonyOS 6.0.0（API 20），目标 SDK 为 26.0.0。
2. Windows 下可运行 `powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1`。DevEco Studio 安装在其他位置时，用 `-Studio` 指定路径。
3. 未签名 HAP 生成在 `entry/build/default/outputs/default/entry-default-unsigned.hap`。在 DevEco Studio 配置本项目的调试签名后，连接真机并运行。应用包名为 `com.yueliu.lxmusic`。

## 使用

- **搜索** · 输入歌手或歌名查询酷我曲库，可收藏搜索结果。播放搜索结果需要配置播放地址接口。
- **歌单** · 通过系统选择器添加本地音频，或导入手机版、桌面版导出的 `.lxmc` 和 JSON 歌单。导入会新建歌单。原备份中的本地文件路径不能跨设备复用，音频可重新通过系统选择器添加。
- **播放** · 支持播放、暂停、进度跳转、上一首、下一首、顺序播放和单曲循环。
- **音源** · 点「播放测试音频」可直接试听内置的 SoundHelix MP3 链接。也可粘贴其他音频直链，或填写自己的 HTTPS 播放地址接口。比如 `https://music.example.com/resolve?source={source}&id={id}`。客户端发送 GET 请求，接受纯文本音频 URL 或 `{"url":"https://example.com/audio.mp3"}`。收藏不会改变对应歌曲的来源和 ID。

首版未接入旧版洛雪 JavaScript 自定义音源、锁屏和后台播放、歌词、排行榜及多端同步。

## 上游

- [lx-music-mobile](https://github.com/lyswhut/lx-music-mobile)
- [lx-music-desktop](https://github.com/lyswhut/lx-music-desktop)
