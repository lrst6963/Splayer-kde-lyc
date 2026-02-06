import QtQuick 2.15
import QtQuick.Controls 2.15 as Controls
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import Qt.labs.platform 1.1 as Platform
import Qt.labs.settings 1.1 as LabsSettings

Window {
    id: root

    LabsSettings.Settings {
        id: settings
        property int lyricFontSize: 42
        property string lyricFontFamily: "Noto Sans CJK SC"
        property color playedColor: "#00D9FF"
        property color unplayedColor: "#FFFFFF"
        property color outlineColor: "black"
        property string lyricAlignMode: "split"
        property int lyricLineSpacing: 10
        property int scrollLineSpacing: 5
        property bool translationEnabled: false
        property int translationFontSize: 18
        property bool showStatusIndicator: false
        property string lyricDisplayMode: "double"
        property int scrollLineCount: 2
        property bool backgroundEnabled: false
        property color backgroundColor: "#80000000"
        property int backgroundRadius: 8
        property int windowX: -1
        property int windowY: -1
        property bool showLyrics: true
        property alias isLocked: root.isLocked
    }

    width: 1024
    property int bottomMargin: 60
    property int contentPadding: 44
    property real scrollLineHeightScale: 1.2
    
    function scrollFixedItemHeight() {
        var h = root.lyricFontSize * root.scrollLineHeightScale
        if (root.translationEnabled && splayer.hasTranslation) {
            h += 4 + root.translationFontSize * 1.5
        }
        return Math.max(1, Math.ceil(h))
    }

    function scrollViewportHeight() {
        if (root.lyricDisplayMode === "single") {
             return scrollFixedItemHeight()
        }
        return Math.ceil(scrollFixedItemHeight() * root.scrollLineCount
                         + root.scrollLineSpacing * Math.max(0, root.scrollLineCount - 1))
    }

    function calculateWindowHeight() {
        if (root.lyricDisplayMode === "scroll" || root.lyricDisplayMode === "single") {
             return scrollViewportHeight()
        }

        return Math.max(180, (splayer.lyricLineEven && splayer.lyricLineEven.text !== undefined && splayer.lyricLineEven.text !== "")
                               || (splayer.lyricLineOdd && splayer.lyricLineOdd.text !== undefined && splayer.lyricLineOdd.text !== "")
                               ? (evenLyric.implicitHeight + oddLyric.implicitHeight + root.lyricLineSpacing + contentPadding)
                               : 180)
    }

    height: calculateWindowHeight()
    visible: settings.showLyrics && hasLyrics
    title: "SPlayer Lyric"

    readonly property bool hasLyrics: (lyricDisplayMode === "double" && 
                    ((splayer.lyricLineEven && splayer.lyricLineEven.text !== undefined && splayer.lyricLineEven.text !== "")
                    || (splayer.lyricLineOdd && splayer.lyricLineOdd.text !== undefined && splayer.lyricLineOdd.text !== "")))
                    || ((lyricDisplayMode === "scroll" || lyricDisplayMode === "single") && splayer.lyrics && splayer.lyrics.length > 0)

    property bool isLocked: false
    property int lyricFontSize: settings.lyricFontSize
    property string lyricFontFamily: settings.lyricFontFamily
    property color playedColor: settings.playedColor
    property color unplayedColor: settings.unplayedColor
    property color outlineColor: settings.outlineColor
    property string lyricAlignMode: settings.lyricAlignMode
    property int lyricLineSpacing: settings.lyricLineSpacing
    property int scrollLineSpacing: Math.max(0, settings.scrollLineSpacing)
    property bool translationEnabled: settings.translationEnabled
    property int translationFontSize: settings.translationFontSize
    property bool showStatusIndicator: settings.showStatusIndicator
    property string lyricDisplayMode: settings.lyricDisplayMode
    property int scrollLineCount: Math.max(2, settings.scrollLineCount)
    property bool backgroundEnabled: settings.backgroundEnabled
    property color backgroundColor: settings.backgroundColor
    property int backgroundRadius: settings.backgroundRadius
    property var fontFamilyOptions: []

    ListModel {
        id: displayModeModel
        ListElement { label: "双行模式(Odd/Even)"; value: "double" }
        ListElement { label: "滚动模式(Scrolling)"; value: "scroll" }
        ListElement { label: "单行模式(Single)"; value: "single" }
    }

    function displayModeIndex(value) {
        for (var i = 0; i < displayModeModel.count; i++) {
            if (displayModeModel.get(i).value === value) return i
        }
        return 0
    }

    ListModel {
        id: alignModeModel
        ListElement { label: "分离(上左下右)"; value: "split" }
        ListElement { label: "全部居左"; value: "left" }
        ListElement { label: "全部居右"; value: "right" }
        ListElement { label: "全部居中"; value: "center" }
    }

    function alignIndex(value) {
        for (var i = 0; i < alignModeModel.count; i++) {
            if (alignModeModel.get(i).value === value) return i
        }
        return 0
    }

    function effectiveAlign(isEvenLine) {
        if (root.lyricAlignMode === "split") return isEvenLine ? "left" : "right"
        return root.lyricAlignMode
    }

    function textAlignToHAlign(alignValue) {
        if (alignValue === "right") return Text.AlignRight
        if (alignValue === "center") return Text.AlignHCenter
        return Text.AlignLeft
    }

    // 字体逻辑移至下方的 main Component.onCompleted 块

    function openControlPanel() {
        Qt.callLater(function() {
            controlPanel.visibility = Window.Windowed
            controlPanel.raise()
            controlPanel.requestActivate()
        })
    }

    flags: Qt.FramelessWindowHint
           | Qt.Tool
           | Qt.WindowStaysOnTopHint
           | Qt.X11BypassWindowManagerHint
           | (isLocked ? Qt.WindowTransparentForInput : 0)

    color: "transparent"

    Component.onCompleted: {
        splayer.setupTrayIcon()
        
        if (Qt.fontFamilies) {
            fontFamilyOptions = Qt.fontFamilies().sort()
        } else {
            fontFamilyOptions = ["Noto Sans CJK SC", "Sans Serif"]
        }

        // 恢复窗口位置
        if (settings.windowX !== -1 && settings.windowY !== -1) {
            root.x = settings.windowX
            root.y = settings.windowY
        } else {
            // 默认位置（底部居中）
            root.x = (Screen.width - root.width) / 2
            root.y = Screen.height - root.height - root.bottomMargin
        }
    }

    onIsLockedChanged: {
        if (!isLocked) { 
            root.raise()
            root.requestActivate() 
        }

        if (settings.windowX !== -1 && settings.windowY !== -1) {

            restoreTimer.restart()
        }
    }

    Timer {
        id: restoreTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (settings.windowX !== -1 && settings.windowY !== -1) {
                root.x = settings.windowX
                root.y = settings.windowY
            }
        }
    }

    MouseArea {
        id: dragArea

        property point clickPos: Qt.point(0, 0)

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.isLocked ? Qt.ArrowCursor : Qt.SizeAllCursor
        onPressed: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                contextMenu.popup()
                return
            }
            if (root.isLocked) {
                return
            }
            clickPos = Qt.point(mouse.x, mouse.y);
        }
        onPositionChanged: function(mouse) {
            if (root.isLocked || !(mouse.buttons & Qt.LeftButton)) {
                return
            }
            var deltaX = mouse.x - clickPos.x;
            var deltaY = mouse.y - clickPos.y;
            root.x += deltaX;
            root.y += deltaY;
        }
        
        onReleased: {
            // 拖动结束时保存位置
            if (!root.isLocked) {
                settings.windowX = root.x
                settings.windowY = root.y
            }
        }
    }

    Item {
        anchors.fill: parent
        // 双行歌词
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.lyricLineSpacing
            visible: root.lyricDisplayMode === "double" && ((splayer.lyricLineEven && splayer.lyricLineEven.text !== undefined && splayer.lyricLineEven.text !== "")
                  || (splayer.lyricLineOdd && splayer.lyricLineOdd.text !== undefined && splayer.lyricLineOdd.text !== ""))

            // 上行
            KaraokeLyric {
                id: evenLyric
                height: Math.max(60, implicitHeight)
                lyricLine: splayer.lyricLineEven
                currentTime: splayer.currentTime
                playedColor: root.playedColor
                unplayedColor: root.unplayedColor
                outlineColor: root.outlineColor
                fontSize: root.lyricFontSize
                fontFamily: root.lyricFontFamily
                property bool isActive: (splayer.currentLineIndex < 0 || splayer.currentLineIndex % 2 === 0)
                opacity: isActive ? 1.0 : 0.6
                marqueeEnabled: isActive
                translationEnabled: root.translationEnabled
                translationFontSize: root.translationFontSize
                property string alignValue: root.effectiveAlign(true)
                textAlign: alignValue

                backgroundEnabled: root.backgroundEnabled
                backgroundColor: root.backgroundColor
                backgroundRadius: root.backgroundRadius

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
                anchors.rightMargin: 20
            }

            // 下行
            KaraokeLyric {
                id: oddLyric
                height: Math.max(60, implicitHeight)
                lyricLine: splayer.lyricLineOdd
                currentTime: splayer.currentTime
                playedColor: root.playedColor
                unplayedColor: root.unplayedColor
                outlineColor: root.outlineColor
                fontSize: root.lyricFontSize
                fontFamily: root.lyricFontFamily
                property bool isActive: (splayer.currentLineIndex % 2 !== 0)
                opacity: isActive ? 1.0 : 0.6
                marqueeEnabled: isActive
                translationEnabled: root.translationEnabled
                translationFontSize: root.translationFontSize
                property string alignValue: root.effectiveAlign(false)
                textAlign: alignValue

                backgroundEnabled: root.backgroundEnabled
                backgroundColor: root.backgroundColor
                backgroundRadius: root.backgroundRadius

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
                anchors.rightMargin: 20
            }
        }

        // 滚动歌词
        ListView {
            id: lyricListView
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: root.scrollViewportHeight()
            visible: root.lyricDisplayMode === "scroll" || root.lyricDisplayMode === "single"
            model: splayer.lyrics
            clip: true
            spacing: root.lyricDisplayMode === "single" ? 0 : root.scrollLineSpacing
            interactive: false
            preferredHighlightBegin: 0
            preferredHighlightEnd: root.scrollFixedItemHeight()
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightMoveDuration: 400

            delegate: Item {
                width: ListView.view.width
                height: root.scrollFixedItemHeight()

                KaraokeLyric {
                    id: lyricItem
                    lyricLine: modelData
                    currentTime: splayer.currentTime
                    playedColor: root.playedColor
                    unplayedColor: root.unplayedColor
                    outlineColor: root.outlineColor
                    fontSize: root.lyricFontSize
                    fontFamily: root.lyricFontFamily
                    lineHeightScale: root.scrollLineHeightScale
                    
                    property bool isActive: (index === splayer.currentLineIndex)
                    opacity: isActive ? 1.0 : 0.6
                    
                    marqueeEnabled: isActive
                    translationEnabled: root.translationEnabled
                    translationFontSize: root.translationFontSize
                    
                    // 对于滚动模式，居中对齐通常最好，或使用全局对齐
                    property string alignValue: root.lyricAlignMode === "split" ? "center" : root.lyricAlignMode
                    textAlign: alignValue
                    
                    backgroundEnabled: root.backgroundEnabled
                    backgroundColor: root.backgroundColor
                    backgroundRadius: root.backgroundRadius

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                }
            }

            Connections {
                target: splayer
                function onCurrentLineIndexChanged() {
                    if ((root.lyricDisplayMode === "scroll" || root.lyricDisplayMode === "single") && splayer.currentLineIndex >= 0) {
                        lyricListView.currentIndex = splayer.currentLineIndex
                    }
                }
            }
        }

        // 无歌词提示
        Text {
            anchors.centerIn: parent
            text: "Waiting for SPlayer..."
            color: "white"
            font.pixelSize: root.lyricFontSize
            font.family: root.lyricFontFamily
            font.weight: Font.DemiBold
            style: Text.Outline
            styleColor: "black"
            visible: !root.hasLyrics
        }

        // 播放状态指示
        Rectangle {
            width: 8
            height: 8
            radius: 4
            color: splayer.isPlaying ? "#00FF00" : "#AAAAAA"
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            opacity: 0.5
            visible: root.showStatusIndicator
        }

    }

    // C++ 托盘集成
    Connections {
        target: splayer
        
        function onTrayShowLyricsChanged() {
            settings.showLyrics = splayer.trayShowLyrics
        }
        
        function onTrayLockedChanged() {
            root.isLocked = splayer.trayLocked
        }
        
        function onRequestShowControlPanel() {
            Qt.callLater(root.openControlPanel)
        }
        
        function onRequestQuit() {
            Qt.quit()
        }

        function onRequestActivate() {
            root.show()
            root.raise()
            root.requestActivate()
        }
    }
    
    // 将设置同步到 C++ 托盘
    Binding {
        target: splayer
        property: "trayShowLyrics"
        value: settings.showLyrics
    }
    
    Binding {
        target: splayer
        property: "trayLocked"
        value: root.isLocked
    }

    Controls.Menu {
        id: contextMenu
        Controls.MenuItem {
            text: "隐藏歌词"
            onTriggered: settings.showLyrics = false
        }
        Controls.MenuItem {
            text: root.isLocked ? "解锁" : "锁定(鼠标穿透)"
            onTriggered: root.isLocked = !root.isLocked
        }
        Controls.MenuSeparator { }
        Controls.MenuItem {
            text: "控制面板"
            onTriggered: Qt.callLater(root.openControlPanel)
        }
        Controls.MenuItem {
            text: "退出"
            onTriggered: Qt.quit()
        }
    }

    ControlPanel {
        id: controlPanel
        settings: settings
        targetWindow: root
    }

}
