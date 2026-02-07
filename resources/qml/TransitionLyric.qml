import QtQuick 2.15

Item {
    id: root
    
    // 公共属性，透传给 KaraokeLyric
    property var lyricLine
    property var nextLyricLine: null  // 交替模式下第二行显示的下一句歌词
    property double currentTime
    property color playedColor
    property color unplayedColor
    property color outlineColor
    property int fontSize
    property string fontFamily
    property bool isActive: true
    property string textAlign
    property bool marqueeEnabled: true
    property bool translationEnabled: false
    property int translationFontSize
    property bool backgroundEnabled: false
    property color backgroundColor
    property int backgroundRadius
    
    // 动画设置
    property string transitionMode: "slide" // "slide", "fade", "scale", "bounce", "flip", "none", "alternate"
    property real lineSpacing: 10
    
    // 缩放/翻转用的属性
    property real itemAScale: 1.0
    property real itemBScale: 1.0
    property real itemARotX: 0
    property real itemBRotX: 0
    property real itemARotZ: 0
    property real itemBRotZ: 0
    
    implicitHeight: transitionMode === "alternate" ? (itemA.implicitHeight + itemB.implicitHeight + lineSpacing) : Math.max(itemA.implicitHeight, itemB.implicitHeight)
    implicitWidth: parent.width
    
    property bool useA: true
    
    onLyricLineChanged: {
        // 检查是否为同句更新（避免重复触发动画）
        var currentItem = useA ? itemA : itemB
        var oldLine = currentItem.lyricLine
        var isSameLine = false
        
        if (lyricLine && oldLine) {
            // 优先比较 start 时间戳
            if (lyricLine.start !== undefined && oldLine.start !== undefined) {
                if (lyricLine.start === oldLine.start) isSameLine = true
            } 
            // 兜底比较文本
            else if (lyricLine.text === oldLine.text) {
                isSameLine = true
            }
        }
        
        if (isSameLine) {
            currentItem.lyricLine = lyricLine
            return
        }

        if (transitionMode === "none") {
            // 无动画，直接更新当前活动的 item
            if (useA) itemA.lyricLine = lyricLine
            else itemB.lyricLine = lyricLine
            return
        }

        if (transitionMode === "alternate") {
            root.itemAScale = 1.0
            root.itemBScale = 1.0
            root.itemARotX = 0
            root.itemBRotX = 0
            
            useA = !useA
            if (useA) {
                itemA.lyricLine = lyricLine
                itemA.visible = true
                // 新歌词从下方升起
                itemA.y = itemA.implicitHeight > 0 ? itemA.implicitHeight * 0.5 : 30
                itemA.opacity = 0
                animAlternateToA.start()
            } else {
                itemB.lyricLine = lyricLine
                itemB.visible = true
                // 新歌词从下方升起
                itemB.y = itemB.implicitHeight > 0 ? itemB.implicitHeight * 0.5 : 30
                itemB.opacity = 0
                animAlternateToB.start()
            }
            return
        }
    
        if (useA) {
            // 当前显示 A，切换到 B
            itemB.lyricLine = lyricLine
            prepareEnter(itemB)
            
            if (transitionMode === "scale") animScaleToB.start()
            else if (transitionMode === "bounce") animBounceToB.start()
            else if (transitionMode === "flip") animFlipToB.start()
            else animToB.start()
            
            useA = false
        } else {
            // 当前显示 B，切换到 A
            itemA.lyricLine = lyricLine
            prepareEnter(itemA)
            
            if (transitionMode === "scale") animScaleToA.start()
            else if (transitionMode === "bounce") animBounceToA.start()
            else if (transitionMode === "flip") animFlipToA.start()
            else animToA.start()
            
            useA = true
        }
    }
    
    function prepareEnter(item) {
        item.visible = true
        item.opacity = 0
        
        // 强制重置所有变换属性，防止之前的动画状态残留（如 scale 停留在 0.5）
        root.itemAScale = 1.0
        root.itemBScale = 1.0
        if (transitionMode !== "flip") {
            root.itemARotX = 0
            root.itemBRotX = 0
        }
        root.itemARotZ = 0
        root.itemBRotZ = 0

        if (transitionMode === "slide") {
            item.y = item.height
        } else if (transitionMode === "bounce") {
            item.y = item.height * 1.5
        } else {
            item.y = 0
        }
        
        if (transitionMode === "scale") {
            if (item === itemA) root.itemAScale = 0.5
            else root.itemBScale = 0.5
        }
        if (transitionMode === "flip") {
            if (item === itemA) root.itemARotX = -90
            else root.itemBRotX = -90
        }
    }
    
    // 退出时的属性准备
    function prepareExit(item) {
        if (transitionMode === "scale") {
            // 当前项缩放到 1，准备缩小退出
        }
        if (transitionMode === "flip") {
            // 当前项旋转为 0，准备翻转退出
        }
    }
    
    // === slide / fade 动画 ===
    ParallelAnimation {
        id: animToB
        NumberAnimation { target: itemA; property: "opacity"; to: 0; duration: 800; easing.type: Easing.OutQuad }
        NumberAnimation { 
            target: itemA; property: "y"; 
            to: root.transitionMode === "slide" ? -itemA.height : 0; 
            duration: 800; easing.type: Easing.OutQuad 
        }
        NumberAnimation { target: itemB; property: "opacity"; to: 1; duration: 800; easing.type: Easing.OutQuad }
        NumberAnimation { 
            target: itemB; property: "y"; to: 0; 
            duration: 800; easing.type: Easing.OutQuad 
        }
    }
    
    ParallelAnimation {
        id: animToA
        NumberAnimation { target: itemB; property: "opacity"; to: 0; duration: 800; easing.type: Easing.OutQuad }
        NumberAnimation { 
            target: itemB; property: "y"; 
            to: root.transitionMode === "slide" ? -itemB.height : 0; 
            duration: 800; easing.type: Easing.OutQuad 
        }
        NumberAnimation { target: itemA; property: "opacity"; to: 1; duration: 800; easing.type: Easing.OutQuad }
        NumberAnimation { 
            target: itemA; property: "y"; to: 0; 
            duration: 800; easing.type: Easing.OutQuad 
        }
    }

    // === scale 缩放动画 ===
    ParallelAnimation {
        id: animScaleToB
        NumberAnimation { target: itemA; property: "opacity"; to: 0; duration: 400; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "itemAScale"; to: 0.5; duration: 400; easing.type: Easing.InQuad }
        NumberAnimation { target: itemB; property: "opacity"; to: 1; duration: 500; easing.type: Easing.OutBack }
        NumberAnimation { target: root; property: "itemBScale"; to: 1.0; duration: 500; easing.type: Easing.OutBack }
    }
    
    ParallelAnimation {
        id: animScaleToA
        NumberAnimation { target: itemB; property: "opacity"; to: 0; duration: 400; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "itemBScale"; to: 0.5; duration: 400; easing.type: Easing.InQuad }
        NumberAnimation { target: itemA; property: "opacity"; to: 1; duration: 500; easing.type: Easing.OutBack }
        NumberAnimation { target: root; property: "itemAScale"; to: 1.0; duration: 500; easing.type: Easing.OutBack }
    }

    // === bounce 弹跳动画 ===
    ParallelAnimation {
        id: animBounceToB
        NumberAnimation { target: itemA; property: "opacity"; to: 0; duration: 400; easing.type: Easing.InQuad }
        NumberAnimation { target: itemA; property: "y"; to: -itemA.height; duration: 400; easing.type: Easing.InBack }
        NumberAnimation { target: itemB; property: "opacity"; to: 1; duration: 600; easing.type: Easing.OutQuad }
        NumberAnimation { target: itemB; property: "y"; to: 0; duration: 600; easing.type: Easing.OutBounce }
    }
    
    ParallelAnimation {
        id: animBounceToA
        NumberAnimation { target: itemB; property: "opacity"; to: 0; duration: 400; easing.type: Easing.InQuad }
        NumberAnimation { target: itemB; property: "y"; to: -itemB.height; duration: 400; easing.type: Easing.InBack }
        NumberAnimation { target: itemA; property: "opacity"; to: 1; duration: 600; easing.type: Easing.OutQuad }
        NumberAnimation { target: itemA; property: "y"; to: 0; duration: 600; easing.type: Easing.OutBounce }
    }

    // === flip 翻转动画 ===
    SequentialAnimation {
        id: animFlipToB
        ParallelAnimation {
            NumberAnimation { target: itemA; property: "opacity"; to: 0; duration: 350; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "itemARotX"; to: 90; duration: 350; easing.type: Easing.InQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: itemB; property: "opacity"; to: 1; duration: 350; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "itemBRotX"; to: 0; duration: 350; easing.type: Easing.OutQuad }
        }
    }
    
    SequentialAnimation {
        id: animFlipToA
        ParallelAnimation {
            NumberAnimation { target: itemB; property: "opacity"; to: 0; duration: 350; easing.type: Easing.InQuad }
            NumberAnimation { target: root; property: "itemBRotX"; to: 90; duration: 350; easing.type: Easing.InQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: itemA; property: "opacity"; to: 1; duration: 350; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "itemARotX"; to: 0; duration: 350; easing.type: Easing.OutQuad }
        }
    }
    
    // 交替模式：新歌词在上方淡入，旧歌词下落到第二行后翻转显示下一句
    SequentialAnimation {
        id: animAlternateToA
        // 旧歌词(B)下落到第二行
        NumberAnimation { target: itemB; property: "y"; to: itemA.height + root.lineSpacing; duration: 1200; easing.type: Easing.InOutQuad }
        // 翻转隐藏旧歌词
        NumberAnimation { target: root; property: "itemBRotX"; to: 90; duration: 400; easing.type: Easing.InQuad }
        // 替换为下一句歌词
        ScriptAction { script: { if (root.nextLyricLine) itemB.lyricLine = root.nextLyricLine } }
        // 翻转显示新歌词（暗色）
        ScriptAction { script: { itemB.opacity = 0.4 } }
        NumberAnimation { target: root; property: "itemBRotX"; to: 0; duration: 400; easing.type: Easing.OutQuad }
        // 同时新歌词(A)在上方淡入
        onStarted: animAlternateInA.start()
    }
    ParallelAnimation {
        id: animAlternateInA
        NumberAnimation { target: itemA; property: "opacity"; to: 1.0; duration: 600; easing.type: Easing.OutQuad }
        NumberAnimation { target: itemA; property: "y"; to: 0; duration: 900; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: animAlternateToB
        // 旧歌词(A)下落到第二行
        NumberAnimation { target: itemA; property: "y"; to: itemB.height + root.lineSpacing; duration: 1200; easing.type: Easing.InOutQuad }
        // 翻转隐藏旧歌词
        NumberAnimation { target: root; property: "itemARotX"; to: 90; duration: 400; easing.type: Easing.InQuad }
        // 替换为下一句歌词
        ScriptAction { script: { if (root.nextLyricLine) itemA.lyricLine = root.nextLyricLine } }
        // 翻转显示新歌词（暗色）
        ScriptAction { script: { itemA.opacity = 0.4 } }
        NumberAnimation { target: root; property: "itemARotX"; to: 0; duration: 400; easing.type: Easing.OutQuad }
        // 同时新歌词(B)在上方淡入
        onStarted: animAlternateInB.start()
    }
    ParallelAnimation {
        id: animAlternateInB
        NumberAnimation { target: itemB; property: "opacity"; to: 1.0; duration: 600; easing.type: Easing.OutQuad }
        NumberAnimation { target: itemB; property: "y"; to: 0; duration: 900; easing.type: Easing.OutCubic }
    }

    KaraokeLyric {
        id: itemA
        anchors.left: parent.left
        anchors.right: parent.right
        // 不要使用 anchors.fill 或 verticalCenter，因为我们需要手动控制 y
        
        // 初始状态
        visible: true
        opacity: 1
        y: 0
        scale: root.itemAScale
        transformOrigin: Item.Center
        
        transform: [
            Rotation {
                origin.x: itemA.width / 2
                origin.y: itemA.height / 2
                axis { x: 1; y: 0; z: 0 }
                angle: root.itemARotX
            },
            Rotation {
                origin.x: itemA.width / 2
                origin.y: itemA.height / 2
                axis { x: 0; y: 0; z: 1 }
                angle: root.itemARotZ
            }
        ]
        
        // 属性绑定
        // 注意：lyricLine 由逻辑手动设置，不绑定
        lyricLine: null
        currentTime: root.currentTime
        playedColor: root.playedColor
        unplayedColor: root.unplayedColor
        outlineColor: root.outlineColor
        fontSize: root.fontSize
        fontFamily: root.fontFamily
        // isActive 控制是否高亮/marquee，透传
        
        marqueeEnabled: root.marqueeEnabled
        translationEnabled: root.translationEnabled
        translationFontSize: root.translationFontSize
        textAlign: root.transitionMode === "alternate" ? "left" : root.textAlign
        backgroundEnabled: root.backgroundEnabled
        backgroundColor: root.backgroundColor
        backgroundRadius: root.backgroundRadius
    }
    
    KaraokeLyric {
        id: itemB
        anchors.left: parent.left
        anchors.right: parent.right
        
        visible: false
        opacity: 0
        y: 0
        scale: root.itemBScale
        transformOrigin: Item.Center
        
        transform: [
            Rotation {
                origin.x: itemB.width / 2
                origin.y: itemB.height / 2
                axis { x: 1; y: 0; z: 0 }
                angle: root.itemBRotX
            },
            Rotation {
                origin.x: itemB.width / 2
                origin.y: itemB.height / 2
                axis { x: 0; y: 0; z: 1 }
                angle: root.itemBRotZ
            }
        ]
        
        lyricLine: null
        currentTime: root.currentTime
        playedColor: root.playedColor
        unplayedColor: root.unplayedColor
        outlineColor: root.outlineColor
        fontSize: root.fontSize
        fontFamily: root.fontFamily
        
        marqueeEnabled: root.marqueeEnabled
        translationEnabled: root.translationEnabled
        translationFontSize: root.translationFontSize
        textAlign: root.transitionMode === "alternate" ? "right" : root.textAlign
        backgroundEnabled: root.backgroundEnabled
        backgroundColor: root.backgroundColor
        backgroundRadius: root.backgroundRadius
    }
    
    // TransitionLyric 本身控制整体的 opacity (isActive)，内部只负责切换动画 (0->1, 1->0)。
    opacity: root.isActive ? 1.0 : 0.6
    
    Component.onCompleted: {
        if (root.useA) itemA.lyricLine = root.lyricLine
        else itemB.lyricLine = root.lyricLine
    }
}
