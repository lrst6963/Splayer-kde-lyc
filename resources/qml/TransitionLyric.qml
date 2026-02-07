import QtQuick 2.15

Item {
    id: root
    
    // 公共属性，透传给 KaraokeLyric
    property var lyricLine
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
    property string transitionMode: "slide" // "slide", "fade", "none", "alternate"
    property real lineSpacing: 10
    
    implicitHeight: transitionMode === "alternate" ? (itemA.implicitHeight + itemB.implicitHeight + lineSpacing) : Math.max(itemA.implicitHeight, itemB.implicitHeight)
    implicitWidth: parent.width
    
    property bool useA: true
    
    onLyricLineChanged: {
        if (transitionMode === "none") {
            // 无动画，直接更新当前活动的 item
            if (useA) itemA.lyricLine = lyricLine
            else itemB.lyricLine = lyricLine
            return
        }

        if (transitionMode === "alternate") {
            useA = !useA
            if (useA) {
                itemA.lyricLine = lyricLine
                itemA.visible = true
                // 从下方开始
                itemA.y = itemB.height + lineSpacing
                animAlternateToA.start()
            } else {
                itemB.lyricLine = lyricLine
                itemB.visible = true
                // 从下方开始
                itemB.y = itemA.height + lineSpacing
                animAlternateToB.start()
            }
            return
        }
    
        if (useA) {
            // 当前显示 A，切换到 B
            itemB.lyricLine = lyricLine
            
            // 确保 B 在初始位置
            prepareEnter(itemB)
            
            // 运行动画
            animToB.start()
            
            useA = false
        } else {
            // 当前显示 B，切换到 A
            itemA.lyricLine = lyricLine
            
            prepareEnter(itemA)
            
            animToA.start()
            
            useA = true
        }
    }
    
    function prepareEnter(item) {
        item.visible = true
        item.opacity = 0
        if (transitionMode === "slide") {
            item.y = item.height // 从下方进入
        } else {
            item.y = 0
        }
    }
    
    ParallelAnimation {
        id: animToB
        // A 退出
        NumberAnimation { target: itemA; property: "opacity"; to: 0; duration: 800; easing.type: Easing.OutQuad }
        NumberAnimation { 
            target: itemA; 
            property: "y"; 
            to: root.transitionMode === "slide" ? -itemA.height : 0; 
            duration: 800; 
            easing.type: Easing.OutQuad 
        }
        
        // B 进入
        NumberAnimation { target: itemB; property: "opacity"; to: 1; duration: 800; easing.type: Easing.OutQuad }
        NumberAnimation { 
            target: itemB; 
            property: "y"; 
            to: 0; 
            duration: 800; 
            easing.type: Easing.OutQuad 
        }
    }
    
    ParallelAnimation {
        id: animToA
        // B 退出
        NumberAnimation { target: itemB; property: "opacity"; to: 0; duration: 800; easing.type: Easing.OutQuad }
        NumberAnimation { 
            target: itemB; 
            property: "y"; 
            to: root.transitionMode === "slide" ? -itemB.height : 0; 
            duration: 800; 
            easing.type: Easing.OutQuad 
        }
        
        // A 进入
        NumberAnimation { target: itemA; property: "opacity"; to: 1; duration: 800; easing.type: Easing.OutQuad }
        NumberAnimation { 
            target: itemA; 
            property: "y"; 
            to: 0; 
            duration: 800; 
            easing.type: Easing.OutQuad 
        }
    }

    ParallelAnimation {
        id: animAlternateToA
        NumberAnimation { target: itemA; property: "opacity"; to: 1.0; duration: 800; easing.type: Easing.OutQuad }
        NumberAnimation { target: itemA; property: "y"; to: 0; duration: 800; easing.type: Easing.OutQuad }
        
        NumberAnimation { target: itemB; property: "opacity"; to: 0.4; duration: 800; easing.type: Easing.OutQuad }
        NumberAnimation { target: itemB; property: "y"; to: itemA.height + root.lineSpacing; duration: 800; easing.type: Easing.OutQuad }
    }

    ParallelAnimation {
        id: animAlternateToB
        NumberAnimation { target: itemB; property: "opacity"; to: 1.0; duration: 800; easing.type: Easing.OutQuad }
        NumberAnimation { target: itemB; property: "y"; to: 0; duration: 800; easing.type: Easing.OutQuad }
        
        NumberAnimation { target: itemA; property: "opacity"; to: 0.4; duration: 800; easing.type: Easing.OutQuad }
        NumberAnimation { target: itemA; property: "y"; to: itemB.height + root.lineSpacing; duration: 800; easing.type: Easing.OutQuad }
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
