import QtQuick 2.15
import QtQuick.Controls 2.15 as Controls
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import Qt.labs.platform 1.1 as Platform

Window {
    id: controlPanel
    
    property var settings
    property var targetWindow
    
    width: 700
    height: 700
    visibility: Window.Hidden
    title: "控制面板"
    flags: Qt.Window | Qt.WindowStaysOnTopHint
    modality: Qt.NonModal
    transientParent: targetWindow
    color: "#1E1E1E"

    onVisibleChanged: {
        if (visible) {
            x = (Screen.width - width) / 2
            y = (Screen.height - height) / 2
        }
    }

    onClosing: function(close) {
        close.accepted = true
        controlPanel.visibility = Window.Hidden
    }

    ListModel {
        id: displayModeModel
        ListElement { label: "交替模式(Alternate)"; value: "alternate" }
        ListElement { label: "奇偶模式(Double)"; value: "double" }
        ListElement { label: "滚动模式(Scrolling)"; value: "scroll" }
        ListElement { label: "单行模式(Single)"; value: "single" }
    }

    ListModel {
        id: alignModeModel
        ListElement { label: "分离(上左下右)"; value: "split" }
        ListElement { label: "全部居左"; value: "left" }
        ListElement { label: "全部居右"; value: "right" }
        ListElement { label: "全部居中"; value: "center" }
    }

    // 根据模式动态更新对齐选项
    function updateAlignModel() {
        var currentAlign = settings.lyricAlignMode
        alignModeModel.clear()
        
        // 只有双行模式（double）支持分离对齐
        if (settings.lyricDisplayMode === "double") {
             alignModeModel.append({ label: "分离(上左下右)", value: "split" })
        }
        
        alignModeModel.append({ label: "全部居左", value: "left" })
        alignModeModel.append({ label: "全部居右", value: "right" })
        alignModeModel.append({ label: "全部居中", value: "center" })

        // 如果当前是对齐是 split 但新模式不支持，则重置为 center
        if (currentAlign === "split" && settings.lyricDisplayMode !== "double") {
             settings.lyricAlignMode = "center"
        }
        
        // 恢复选中项
        alignCombo.currentIndex = alignIndex(settings.lyricAlignMode)
    }

    Connections {
        target: settings
        function onLyricDisplayModeChanged() {
            updateAlignModel()
        }
    }
    
    Component.onCompleted: updateAlignModel()

    function displayModeIndex(value) {
        for (var i = 0; i < displayModeModel.count; i++) {
            if (displayModeModel.get(i).value === value) return i
        }
        return 0
    }

    function alignIndex(value) {
        for (var i = 0; i < alignModeModel.count; i++) {
            if (alignModeModel.get(i).value === value) return i
        }
        return 0
    }

    function effectiveAlign(isEvenLine) {
        if (settings.lyricAlignMode === "split") return isEvenLine ? "left" : "right"
        return settings.lyricAlignMode
    }

    function textAlignToHAlign(alignValue) {
        if (alignValue === "right") return Text.AlignRight
        if (alignValue === "center") return Text.AlignHCenter
        return Text.AlignLeft
    }

    Controls.Pane {
        anchors.fill: parent
        padding: 16

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            Controls.ScrollView {
                id: controlScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: controlScroll.availableWidth
                    spacing: 12

                    Controls.Label { text: "窗口宽度"; Layout.fillWidth: true }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Controls.Slider {
                            from: 400
                            to: 3840 // 支持 4K
                            stepSize: 10
                            value: settings.lyricWindowWidth
                            onMoved: settings.lyricWindowWidth = Math.round(value)
                            Layout.fillWidth: true
                        }
                        Controls.SpinBox {
                            from: 400
                            to: 3840
                            value: settings.lyricWindowWidth
                            stepSize: 10
                            editable: true
                            onValueModified: settings.lyricWindowWidth = value
                            Layout.preferredWidth: 96
                        }
                    }

                    Controls.Label { text: "字体大小"; Layout.fillWidth: true }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Controls.Slider {
                            id: fontSizeSlider
                            from: 16
                            to: 72
                            stepSize: 1
                            value: settings.lyricFontSize
                            onMoved: settings.lyricFontSize = Math.round(value)
                            Layout.fillWidth: true
                        }
                        Controls.SpinBox {
                            id: fontSizeSpin
                            from: 16
                            to: 72
                            value: settings.lyricFontSize
                            onValueModified: settings.lyricFontSize = value
                            Layout.preferredWidth: 96
                        }
                    }

                    Controls.Label { text: "字体"; Layout.fillWidth: true }
                    Controls.ComboBox {
                        id: fontFamilyCombo
                        editable: true
                        model: targetWindow.fontFamilyOptions
                        Layout.fillWidth: true
                        onModelChanged: currentIndex = Math.max(0, targetWindow.fontFamilyOptions.indexOf(settings.lyricFontFamily))
                        Component.onCompleted: currentIndex = Math.max(0, targetWindow.fontFamilyOptions.indexOf(settings.lyricFontFamily))
                        onAccepted: settings.lyricFontFamily = editText
                        onActivated: settings.lyricFontFamily = currentText
                    }

                    Controls.Label { text: "显示模式"; Layout.fillWidth: true }
                    Controls.ComboBox {
                        id: displayModeCombo
                        model: displayModeModel
                        textRole: "label"
                        Layout.fillWidth: true
                        currentIndex: displayModeIndex(settings.lyricDisplayMode)
                        onActivated: settings.lyricDisplayMode = displayModeModel.get(currentIndex).value
                    }

                    Controls.Label { 
                        text: "切换动画"
                        visible: settings.lyricDisplayMode !== "alternate" && settings.lyricDisplayMode !== "scroll"
                        Layout.fillWidth: true 
                    }
                    Controls.ComboBox {
                        id: transitionCombo
                        visible: settings.lyricDisplayMode !== "alternate" && settings.lyricDisplayMode !== "scroll"
                        model: ListModel {
                            ListElement { label: "滑动(Slide)"; value: "slide" }
                            ListElement { label: "淡入淡出(Fade)"; value: "fade" }
                            ListElement { label: "无(None)"; value: "none" }
                        }
                        textRole: "label"
                        Layout.fillWidth: true
                        
                        Component.onCompleted: {
                            for(var i=0; i<model.count; i++) {
                                if(model.get(i).value === settings.lyricTransition) {
                                    currentIndex = i
                                    return
                                }
                            }
                            currentIndex = 0
                        }
                        
                        onActivated: settings.lyricTransition = model.get(currentIndex).value
                    }

                    Controls.Label { 
                        text: "对齐" 
                        visible: settings.lyricDisplayMode !== "alternate"
                        Layout.fillWidth: true 
                    }
                    Controls.ComboBox {
                        id: alignCombo
                        visible: settings.lyricDisplayMode !== "alternate"
                        model: alignModeModel
                        textRole: "label"
                        Layout.fillWidth: true
                        currentIndex: alignIndex(settings.lyricAlignMode)
                        onActivated: settings.lyricAlignMode = alignModeModel.get(currentIndex).value
                    }

                    Controls.Label { text: "滚动行数"; visible: settings.lyricDisplayMode === "scroll"; Layout.fillWidth: true }
                    RowLayout {
                        visible: settings.lyricDisplayMode === "scroll"
                        Layout.fillWidth: true
                        spacing: 10
                        Controls.Slider {
                            from: 2
                            to: 10
                            stepSize: 1
                            value: settings.scrollLineCount
                            onMoved: settings.scrollLineCount = Math.round(value)
                            Layout.fillWidth: true
                        }
                        Controls.SpinBox {
                            from: 2
                            to: 10
                            value: settings.scrollLineCount
                            onValueModified: settings.scrollLineCount = value
                            Layout.preferredWidth: 96
                        }
                    }

                    Controls.Label { text: "行间距"; Layout.fillWidth: true }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Controls.Slider {
                            id: lineSpacingSlider
                            from: 0
                            to: 40
                            stepSize: 1
                            value: settings.lyricDisplayMode === "scroll" ? settings.scrollLineSpacing : settings.lyricLineSpacing
                            onMoved: {
                                var v = Math.round(value)
                                if (settings.lyricDisplayMode === "scroll") {
                                    settings.scrollLineSpacing = v
                                } else {
                                    settings.lyricLineSpacing = v
                                }
                            }
                            Layout.fillWidth: true
                        }
                        Controls.SpinBox {
                            from: 0
                            to: 40
                            value: settings.lyricDisplayMode === "scroll" ? settings.scrollLineSpacing : settings.lyricLineSpacing
                            onValueModified: {
                                if (settings.lyricDisplayMode === "scroll") {
                                    settings.scrollLineSpacing = value
                                } else {
                                    settings.lyricLineSpacing = value
                                }
                            }
                            Layout.preferredWidth: 96
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Controls.Label { text: "翻译"; Layout.fillWidth: true }
                        Controls.Switch {
                            checked: settings.translationEnabled
                            onToggled: settings.translationEnabled = checked
                        }
                    }

                    Controls.Label { text: "翻译大小"; Layout.fillWidth: true }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Controls.Slider {
                            from: 10
                            to: 48
                            stepSize: 1
                            value: settings.translationFontSize
                            enabled: settings.translationEnabled
                            onMoved: settings.translationFontSize = Math.round(value)
                            Layout.fillWidth: true
                        }
                        Controls.SpinBox {
                            from: 10
                            to: 48
                            value: settings.translationFontSize
                            enabled: settings.translationEnabled
                            onValueModified: settings.translationFontSize = value
                            Layout.preferredWidth: 96
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Controls.Label { text: "状态指示灯"; Layout.fillWidth: true }
                        Controls.Switch {
                            checked: settings.showStatusIndicator
                            onToggled: settings.showStatusIndicator = checked
                        }
                    }

                    Controls.Label { text: "颜色"; Layout.fillWidth: true }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 10

                        Controls.Button { text: "高亮"; onClicked: playedColorDialog.open() }
                        Rectangle {
                            width: 28
                            height: 18
                            radius: 3
                            color: settings.playedColor
                            border.width: 1
                            border.color: "#444"
                        }

                        Controls.Button { text: "未唱"; onClicked: unplayedColorDialog.open() }
                        Rectangle {
                            width: 28
                            height: 18
                            radius: 3
                            color: settings.unplayedColor
                            border.width: 1
                            border.color: "#444"
                        }

                        Controls.Button { text: "描边"; onClicked: outlineColorDialog.open() }
                        Rectangle {
                            width: 28
                            height: 18
                            radius: 3
                            color: settings.outlineColor
                            border.width: 1
                            border.color: "#444"
                        }
                    }

                    Controls.Label { text: "背景"; Layout.fillWidth: true }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Controls.Switch {
                            checked: settings.backgroundEnabled
                            onToggled: settings.backgroundEnabled = checked
                        }
                        
                        Controls.Button { text: "颜色"; enabled: settings.backgroundEnabled; onClicked: backgroundColorDialog.open() }
                        Rectangle {
                            width: 28
                            height: 18
                            radius: 3
                            color: settings.backgroundColor
                            border.width: 1
                            border.color: "#444"
                        }
                        
                        Controls.Label { text: "透明度"; enabled: settings.backgroundEnabled }
                        Controls.Slider {
                            from: 0
                            to: 255
                            stepSize: 1
                            value: Math.round(settings.backgroundColor.a * 255)
                            enabled: settings.backgroundEnabled
                            onMoved: {
                                var c = settings.backgroundColor
                                settings.backgroundColor = Qt.rgba(c.r, c.g, c.b, value / 255)
                            }
                            Layout.fillWidth: true
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: settings.backgroundEnabled
                        Controls.Label { text: "圆角" }
                        Controls.Slider {
                            from: 0
                            to: 30
                            stepSize: 1
                            value: settings.backgroundRadius
                            onMoved: settings.backgroundRadius = Math.round(value)
                            Layout.fillWidth: true
                        }
                        Controls.SpinBox {
                            from: 0
                            to: 30
                            value: settings.backgroundRadius
                            onValueModified: settings.backgroundRadius = value
                            Layout.preferredWidth: 80
                        }
                    }

                    Controls.Label { text: "窗口"; Layout.fillWidth: true }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        
                        Controls.Label { text: "锁定" }
                        Controls.Switch {
                            checked: settings.isLocked
                            onToggled: settings.isLocked = checked
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Controls.Button {
                            text: "重置位置"
                            onClicked: {
                                targetWindow.x = (Screen.width - targetWindow.width) / 2
                                targetWindow.y = Screen.height - targetWindow.height - targetWindow.bottomMargin
                                // 同时保存到设置
                                settings.windowX = targetWindow.x
                                settings.windowY = targetWindow.y
                            }
                        }
                    }

                    Controls.Label { text: "预览"; Layout.fillWidth: true }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: settings.translationEnabled ? 96 : 70
                        radius: 8
                        color: "#00000000"
                        border.width: 1
                        border.color: "#333"

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            Controls.Label {
                                width: parent.width
                                text: "示例歌词 Preview"
                                font.pixelSize: settings.lyricFontSize
                                font.family: settings.lyricFontFamily
                                color: settings.playedColor
                                horizontalAlignment: textAlignToHAlign(effectiveAlign(true))
                                verticalAlignment: Text.AlignVCenter
                            }

                            Controls.Label {
                                width: parent.width
                                visible: settings.translationEnabled
                                text: "示例翻译 Translation"
                                font.pixelSize: settings.translationFontSize
                                font.family: settings.lyricFontFamily
                                color: settings.unplayedColor
                                opacity: 0.85
                                horizontalAlignment: textAlignToHAlign(effectiveAlign(true))
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Controls.Button {
                    text: "重置样式"
                    onClicked: {
                        settings.lyricFontSize = 42
                        settings.lyricFontFamily = "Noto Sans CJK SC"
                        settings.playedColor = "#00D9FF"
                        settings.unplayedColor = "#FFFFFF"
                        settings.outlineColor = "black"
                        settings.lyricAlignMode = "split"
                        settings.lyricLineSpacing = 10
                        settings.scrollLineSpacing = 5
                        settings.translationEnabled = false
                        settings.translationFontSize = 18
                        settings.backgroundEnabled = false
                        settings.backgroundColor = "#80000000"
                        settings.backgroundRadius = 8
                    }
                }
                Item { Layout.fillWidth: true }
                Controls.Button {
                    text: "关闭"
                    onClicked: controlPanel.close()
                }
            }
        }
    }

    Platform.ColorDialog {
        id: playedColorDialog
        currentColor: settings.playedColor
        onAccepted: settings.playedColor = currentColor
    }

    Platform.ColorDialog {
        id: unplayedColorDialog
        currentColor: settings.unplayedColor
        onAccepted: settings.unplayedColor = currentColor
    }

    Platform.ColorDialog {
        id: outlineColorDialog
        currentColor: settings.outlineColor
        onAccepted: settings.outlineColor = currentColor
    }

    Platform.ColorDialog {
        id: backgroundColorDialog
        currentColor: settings.backgroundColor
        options: Platform.ColorDialog.ShowAlphaChannel
        onAccepted: settings.backgroundColor = currentColor
    }
}
