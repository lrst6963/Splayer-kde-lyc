# SPlayer KDE Desktop Lyric

基于 Qt Quick (C++) 的 SPlayer 桌面歌词显示程序，支持 KDE Plasma。

## 特性

- ✅ 连接 SPlayer WebSocket 接口 (`ws://localhost:25885`)
- ✅ 自动重连机制
- ✅ 解析逐字歌词 (yrcData)
- ✅ 实时歌词同步，支持逐字卡拉 OK 着色效果
- ✅ 透明窗口、无边框、始终置顶
- ✅ 可拖拽移动
- ✅ 多种显示模式：
  - 奇偶行模式 (Double Line)
  - 滚动模式 (Scrolling)
  - 单行模式 (Single Line)
- ✅ 丰富的自定义选项（通过控制面板）：
  - 字体选择、大小调整
  - 对齐方式（居左、居中、居右、分离）
  - 行间距调整
- ✅ 歌词翻译显示支持
- ✅ 系统托盘集成（显示/隐藏、锁定窗口、退出）

## 编译

```bash
mkdir -p build
cd build
cmake ..
make
```

## 运行

确保 SPlayer 正在运行（WebSocket 服务已启动），然后：

```bash
./appsplayer-kde-lyric
```

## 依赖

- Qt 6.2+
  - Qt6::Quick
  - Qt6::WebSockets
  - Qt6::Network
  - Qt6::Widgets (用于系统托盘)
  - Qt6::Labs::Platform (用于文件对话框等)
- CMake 3.16+
- C++17 编译器

## 使用

- **移动窗口**：直接拖拽歌词文本即可移动窗口（除非已锁定）。
- **系统托盘**：
  - **显示/隐藏歌词**：快速切换歌词可见性。
  - **锁定(鼠标穿透)**：锁定窗口位置并开启鼠标穿透，避免误触。
  - **控制面板**：打开设置界面，调整显示效果。
  - **退出**：退出程序。
- **控制面板**：
  - 在托盘菜单中选择“控制面板”打开。
  - 可实时调整字体、显示模式、对齐方式等。

## 开发中功能

- 更多自定义外观选项（阴影、描边等详细配置）
- 歌词样式预设
