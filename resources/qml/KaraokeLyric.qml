import QtQuick 2.15

Item {
    id: root

    property var lyricLine: null
    required property double currentTime
    required property color playedColor
    required property color unplayedColor
    property color outlineColor: "black"
    required property int fontSize
    required property string fontFamily
    property real lineHeightScale: 1.5
    property string textAlign: "center"
    property bool marqueeEnabled: true
    property bool translationEnabled: false
    property int translationFontSize: 18
    property string lrcText: (root.lyricLine && root.lyricLine.text !== undefined) ? root.lyricLine.text : ""
    property string translatedText: (root.lyricLine && root.lyricLine.translatedLyric !== undefined) ? root.lyricLine.translatedLyric : ""
    property string wordKey: ""
    property var wordList: []
    property var prevWordList: []
    property real wordInScale: 1.0
    property real wordOutScale: 1.0
    property real wordInOpacity: 1.0
    property real wordOutOpacity: 0.0
    property real lrcInScale: 1.0
    property real lrcOutScale: 1.0
    property real lrcMarqueeX: 0

    property bool backgroundEnabled: false
    property color backgroundColor: "#80000000"
    property int backgroundRadius: 8

    property bool translationVisible: root.translationEnabled && root.translatedText !== ""
    implicitHeight: (fontSize * lineHeightScale) + (translationVisible ? (4 + translationText.implicitHeight) : 0)

    // 歌词背景
    Rectangle {
        id: lyricBgRect
        visible: root.backgroundEnabled
        color: root.backgroundColor
        radius: root.backgroundRadius
        
        property real lrcWidth: lrcClip.visible ? lrcLayer.width : (wordClip.visible ? wordInRow.implicitWidth : 0)
        
        width: Math.min(root.width, lrcWidth + 20)
        height: root.fontSize * root.lineHeightScale
        
        x: {
            if (width >= root.width) return 0
            if (root.textAlign === "center") return (root.width - width) / 2
            if (root.textAlign === "right") return root.width - width + 10
            return -10
        }
        y: 0
    }

    // 翻译背景
    Rectangle {
        id: transBgRect
        visible: root.backgroundEnabled && root.translationVisible
        color: root.backgroundColor
        radius: root.backgroundRadius
        
        property real transWidth: translationText.implicitWidth
        
        width: Math.min(root.width, transWidth + 20)
        height: translationText.implicitHeight + 4 // 添加一些内边距
        
        x: {
            if (width >= root.width) return 0
            if (root.textAlign === "center") return (root.width - width) / 2
            if (root.textAlign === "right") return root.width - width + 10
            return -10
        }
        y: root.fontSize * root.lineHeightScale + 2 // 稍微调整 Y
    }

    function staticX(containerWidth, contentWidth) {
        if (contentWidth <= containerWidth) {
            if (textAlign === "right") return containerWidth - contentWidth
            if (textAlign === "center") return (containerWidth - contentWidth) / 2
            return 0
        }
        return 0
    }

    function updateLrcMarquee() {
        if (!lrcClip.visible || !root.marqueeEnabled) {
            lrcMarqueeAnim.stop()
            lrcMarqueeX = 0
            return
        }
        if (lrcLayer.width > lrcClip.width + 1) {
            lrcMarqueeX = 0
            lrcMarqueeAnim.restart()
        } else {
            lrcMarqueeAnim.stop()
            lrcMarqueeX = staticX(lrcClip.width, lrcLayer.width)
        }
    }

    function wordKeyFor(words) {
        if (!words || words.length <= 0) return ""
        var first = words[0]
        var last = words[words.length - 1]
        var key = "" + words.length + ":" + first.startTime + "-" + last.endTime + ":"
        var limit = Math.min(words.length, 12)
        for (var i = 0; i < limit; i++) {
            key += words[i].word
        }
        return key
    }

    function syncWordData() {
        var words = (root.lyricLine && root.lyricLine.words) ? root.lyricLine.words : []
        if (!words || words.length <= 0) {
            root.wordKey = ""
            root.wordList = []
            root.prevWordList = []
            root.wordInScale = 1.0
            root.wordOutScale = 1.0
            root.wordInOpacity = 1.0
            root.wordOutOpacity = 0.0
            return
        }

        var nextKey = wordKeyFor(words)
        if (nextKey === root.wordKey) {
            root.wordList = words
            return
        }

        root.prevWordList = root.wordList
        root.wordList = words
        root.wordKey = nextKey
        wordTransAnim.restart()
    }

    onWidthChanged: {
        updateLrcMarquee()
    }
    onTextAlignChanged: {
        updateLrcMarquee()
    }
    onMarqueeEnabledChanged: {
        updateLrcMarquee()
    }
    onLyricLineChanged: Qt.callLater(function() {
        root.syncWordData()
        root.updateLrcMarquee()
    })
    Component.onCompleted: Qt.callLater(function() {
        root.syncWordData()
        root.updateLrcMarquee()
    })

    Item {
        id: wordClip
        visible: root.wordList && root.wordList.length > 0
        width: root.width
        height: root.fontSize * root.lineHeightScale
        anchors.top: parent.top
        anchors.left: parent.left
        clip: true

        Component {
            id: wordDelegate
            Item {
                property var wordData: modelData
                property string textStr: wordData.word !== undefined ? wordData.word : ""
                property double startTime: wordData.startTime !== undefined ? wordData.startTime : 0
                property double endTime: wordData.endTime !== undefined ? wordData.endTime : 0
                property int playState: {
                    if (root.currentTime >= endTime) return 2;
                    if (root.currentTime <= startTime) return 0;
                    return 1;
                }

                width: baseText.implicitWidth
                height: root.fontSize * root.lineHeightScale

                Text {
                    id: baseText
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: textStr
                    color: root.unplayedColor
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    font.weight: Font.DemiBold
                    style: Text.Outline
                    styleColor: root.outlineColor
                }

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: textStr
                    color: root.playedColor
                    font: baseText.font
                    style: Text.Outline
                    styleColor: root.outlineColor
                    visible: playState === 2
                }

                Item {
                    id: clipper
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    clip: playState === 1
                    visible: playState === 1

                    width: {
                        if (playState !== 1) return 0

                        var duration = endTime - startTime;
                        if (duration <= 0.001) return parent.width;

                        var progress = (root.currentTime - startTime) / duration;
                        return parent.width * progress;
                    }

                    Text {
                        text: textStr
                        color: root.playedColor
                        font: baseText.font
                        style: Text.Outline
                        styleColor: root.outlineColor

                        width: baseText.implicitWidth
                        height: parent.height

                        anchors.left: parent.left
                        anchors.top: parent.top

                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        Item {
            id: wordOutLayer
            anchors.fill: parent
            opacity: root.wordOutOpacity
            scale: root.wordOutScale
            transformOrigin: Item.Center
            visible: root.wordOutOpacity > 0.001

            Row {
                id: wordOutRow
                spacing: 0
                x: root.staticX(wordClip.width, wordOutRow.implicitWidth)
                y: (wordClip.height - wordOutRow.implicitHeight) / 2

                Repeater {
                    model: root.prevWordList ? root.prevWordList : []
                    delegate: wordDelegate
                }
            }
        }

        Item {
            id: wordInLayer
            anchors.fill: parent
            opacity: root.wordInOpacity
            scale: root.wordInScale
            transformOrigin: Item.Center

            Row {
                id: wordInRow
                spacing: 0
                x: {
                    if (!root.marqueeEnabled) return root.staticX(wordClip.width, wordInRow.implicitWidth)
                    var maxOffset = Math.max(0, wordInRow.implicitWidth - wordClip.width)
                    if (maxOffset <= 0) return root.staticX(wordClip.width, wordInRow.implicitWidth)
                    if (!root.wordList || root.wordList.length <= 0) return 0

                    var start = root.wordList[0].startTime
                    var end = root.wordList[root.wordList.length - 1].endTime
                    var duration = end - start
                    if (duration <= 0.001) return 0

                    var p = (root.currentTime - start) / duration
                    if (p < 0) p = 0
                    if (p > 1) p = 1
                    return -maxOffset * p
                }
                y: (wordClip.height - wordInRow.implicitHeight) / 2

                Behavior on x {
                    NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                }

                Repeater {
                    model: root.wordList ? root.wordList : []
                    delegate: wordDelegate
                }
            }
        }
    }

    ParallelAnimation {
        id: wordTransAnim
        running: false

        SequentialAnimation {
            ScriptAction {
                script: {
                    root.wordOutScale = 1.0
                    root.wordOutOpacity = (root.prevWordList && root.prevWordList.length > 0) ? 1.0 : 0.0
                    root.wordInScale = 0.85
                    root.wordInOpacity = 0.0
                }
            }
            ParallelAnimation {
                NumberAnimation { target: root; property: "wordOutScale"; to: 0.85; duration: 140; easing.type: Easing.InCubic }
                NumberAnimation { target: root; property: "wordOutOpacity"; to: 0.0; duration: 140; easing.type: Easing.InCubic }
            }
        }

        SequentialAnimation {
            PauseAnimation { duration: 60 }
            ParallelAnimation {
                NumberAnimation { target: root; property: "wordInScale"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
                NumberAnimation { target: root; property: "wordInOpacity"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
            }
        }
    }

    Item {
        id: lrcClip
        visible: !(root.lyricLine && root.lyricLine.words && root.lyricLine.words.length > 0)
        width: root.width
        height: root.fontSize * root.lineHeightScale
        anchors.top: parent.top
        anchors.left: parent.left
        clip: true

        Item {
            id: lrcLayer
            width: Math.max(lrcInText.implicitWidth, lrcOutText.implicitWidth)
            height: root.fontSize * root.lineHeightScale
            x: (lrcLayer.width > lrcClip.width + 1) ? root.lrcMarqueeX : root.staticX(lrcClip.width, lrcLayer.width)
            y: 0

            Text {
                id: lrcOutText
                anchors.left: parent.left
                anchors.top: parent.top
                text: ""
                color: root.playedColor
                font.pixelSize: root.fontSize
                font.family: root.fontFamily
                font.weight: Font.DemiBold
                style: Text.Outline
                styleColor: root.outlineColor
                opacity: 0.0
                scale: root.lrcOutScale
                transformOrigin: Item.Center
                width: parent.width
                height: parent.height
                horizontalAlignment: root.textAlign === "right" ? Text.AlignRight : (root.textAlign === "center" ? Text.AlignHCenter : Text.AlignLeft)
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                id: lrcInText
                anchors.left: parent.left
                anchors.top: parent.top
                text: root.lrcText
                color: (root.lyricLine && root.lyricLine.time !== undefined && root.currentTime >= root.lyricLine.time) ? root.playedColor : root.unplayedColor
                font.pixelSize: root.fontSize
                font.family: root.fontFamily
                font.weight: Font.DemiBold
                style: Text.Outline
                styleColor: root.outlineColor
                opacity: 1.0
                scale: root.lrcInScale
                transformOrigin: Item.Center
                width: parent.width
                height: parent.height
                horizontalAlignment: root.textAlign === "right" ? Text.AlignRight : (root.textAlign === "center" ? Text.AlignHCenter : Text.AlignLeft)
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Text {
        id: translationText
        visible: root.translationVisible
        x: 0
        y: root.fontSize * root.lineHeightScale + 4
        width: root.width
        text: root.translatedText
        color: root.unplayedColor
        opacity: 0.85
        font.pixelSize: root.translationFontSize
        font.family: root.fontFamily
        style: Text.Outline
        styleColor: root.outlineColor
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
        horizontalAlignment: root.textAlign === "right" ? Text.AlignRight : (root.textAlign === "center" ? Text.AlignHCenter : Text.AlignLeft)
        verticalAlignment: Text.AlignVCenter
    }

    onLrcTextChanged: {
        if (root.lyricLine && root.lyricLine.words && root.lyricLine.words.length > 0) {
            return
        }
        if (!lrcClip.visible) {
            return
        }
        if (lrcInText.text === root.lrcText) {
            return
        }

        lrcOutText.text = lrcInText.text
        lrcInText.text = root.lrcText
        lrcTransAnim.restart()
        Qt.callLater(function() { root.updateLrcMarquee() })
    }

    SequentialAnimation {
        id: lrcMarqueeAnim
        loops: Animation.Infinite
        running: false
        PauseAnimation { duration: 600 }
        NumberAnimation {
            target: root
            property: "lrcMarqueeX"
            to: -(lrcLayer.width - lrcClip.width)
            duration: Math.min(12000, Math.max(2500, (lrcLayer.width - lrcClip.width) * 18))
            easing.type: Easing.InOutSine
        }
        PauseAnimation { duration: 600 }
        NumberAnimation {
            target: root
            property: "lrcMarqueeX"
            to: 0
            duration: 500
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: lrcTransAnim
        running: false

        SequentialAnimation {
            ScriptAction {
                script: {
                    root.lrcOutScale = 1.0
                    lrcOutText.opacity = 1.0
                    root.lrcInScale = 0.85
                    lrcInText.opacity = 0.0
                }
            }
            ParallelAnimation {
                NumberAnimation { target: root; property: "lrcOutScale"; to: 0.85; duration: 140; easing.type: Easing.InCubic }
                NumberAnimation { target: lrcOutText; property: "opacity"; to: 0.0; duration: 140; easing.type: Easing.InCubic }
            }
        }

        SequentialAnimation {
            PauseAnimation { duration: 60 }
            ParallelAnimation {
                NumberAnimation { target: root; property: "lrcInScale"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
                NumberAnimation { target: lrcInText; property: "opacity"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
            }
        }
    }
}
