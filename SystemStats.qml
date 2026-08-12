import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

BarWidget {
    id: root
    moduleName: "saif.system-stats"

    property bool pinned: false
    property bool popupOpen: false
    property var stats: ({})

    readonly property color heroFg: root.bar ? root.bar.foreground : Color.foreground
    readonly property string heroFont: root.bar ? root.bar.fontFamily : Style.font.family

    property int summaryLineIndex: 0
    readonly property var summaryLines: [
        "Gathering stats",
        "Loading stats",
        "Fetching stats",
        "Calculating stats",
        "Processing stats",
        "Analyzing stats",
        "Interpreting stats",
    ]
    readonly property string summaryLine: summaryLines[summaryLineIndex % summaryLines.length]

    readonly property bool iconHovered: button.tooltipHovered

    function updateOpen() {
        if (root.pinned) {
            root.popupOpen = true;
            return;
        }
        root.popupOpen = root.iconHovered || (root.popupOpen && popup.containsMouse);
    }

    function close() {
        root.pinned = false;
        root.popupOpen = false;
    }

    function parseStats(raw) {
        try {
            root.stats = JSON.parse(String(raw || "").trim()) || {};
        } catch (e) {
            root.stats = {};
        }
    }

    onIconHoveredChanged: root.updateOpen()
    onPinnedChanged: root.updateOpen()

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    WidgetButton {
        id: button
        anchors.verticalCenter: parent.verticalCenter
        bar: root.bar
        text: "󰓅"
        tooltipText: ""
        horizontalMargin: 7.5

        onPressed: function (b) {
            if (!root.bar)
                return;
            if (b === Qt.RightButton)
                root.bar.run("omarchy-launch-or-focus-tui btop");
            else if (b === Qt.MiddleButton)
                statsProc.running = true;
            else
                root.pinned = !root.pinned;
        }
    }

    PopupCard {
        id: popup
        anchorItem: button
        bar: root.bar
        owner: root
        open: root.popupOpen
        triggerMode: root.pinned ? "click" : "hover"
        contentWidth: popup.fittedContentWidth(Style.space(280))
        contentHeight: popup.fittedContentHeight(column.implicitHeight)

        onContainsMouseChanged: root.updateOpen()

        Column {
            id: column
            anchors.fill: parent
            spacing: Style.space(5)

            PanelHero {
                id: hero
                iconComponent: Component {
                    Text {
                        text: "󰓅"
                        color: root.heroFg
                        font.family: root.heroFont
                        font.pixelSize: Style.font.display
                    }
                }
                title: "System"
                detail: root.stats.cpu !== undefined ? root.stats.cpu + "%" : ""
                meta: root.summaryLine
                foreground: root.heroFg
                fontFamily: root.heroFont
            }

            PanelSeparator {
                foreground: root.heroFg
            }

            Item {
                width: parent.width
                height: Style.space(19)

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CPU"
                    color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.25)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    width: Style.space(62)
                    elide: Text.ElideRight
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.stats.cpu !== undefined ? root.stats.cpu + "%" : "…"
                    color: root.bar ? root.bar.foreground : Color.foreground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    horizontalAlignment: Text.AlignRight
                    width: parent.width - Style.space(70)
                }
            }

            Item {
                width: parent.width
                height: Style.space(19)

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Temp"
                    color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.25)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    width: Style.space(62)
                    elide: Text.ElideRight
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.stats.temp !== undefined ? root.stats.temp + "°" : "…"
                    color: root.bar ? root.bar.foreground : Color.foreground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    horizontalAlignment: Text.AlignRight
                    width: parent.width - Style.space(70)
                }
            }

            Item {
                width: parent.width
                height: Style.space(19)

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Memory"
                    color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.25)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    width: Style.space(62)
                    elide: Text.ElideRight
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.stats.mem ? root.stats.mem.used + "G / " + root.stats.mem.total + "G  (" + root.stats.mem.percent + "%)" : "…"
                    color: root.bar ? root.bar.foreground : Color.foreground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    horizontalAlignment: Text.AlignRight
                    width: parent.width - Style.space(70)
                }
            }

            Item {
                width: parent.width
                height: Style.space(19)

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Swap"
                    color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.25)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    width: Style.space(62)
                    elide: Text.ElideRight
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.stats.mem ? root.stats.mem.swapUsed + "G / " + root.stats.mem.swapTotal + "G  (" + root.stats.mem.swapPercent + "%)" : "…"
                    color: root.bar ? root.bar.foreground : Color.foreground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    horizontalAlignment: Text.AlignRight
                    width: parent.width - Style.space(70)
                }
            }
        }
    }

    Process {
        id: statsProc
        command: ["bash", "-lc", String(Qt.resolvedUrl("sys-stats.sh")).replace(/^file:\/\//, "")]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseStats(text)
        }
    }

  Timer {
      id: phraseTimer
      interval: 2800
      running: root.popupOpen
      repeat: true
      onTriggered: connectionPhraseSwap.restart()
  }

  SequentialAnimation {
    id: connectionPhraseSwap
    PropertyAnimation {
      target: hero; property: "metaOpacity"
      to: 0.0; duration: 180; easing.type: Easing.OutQuad
    }
    ScriptAction {
        script: root.summaryLineIndex = (root.summaryLineIndex + 1) % root.summaryLines.length
    }
    PropertyAnimation {
      target: hero; property: "metaOpacity"
      to: 1.0; duration: 260; easing.type: Easing.InQuad
    }
  }
    Timer {
        id: statsTimer
        interval: 2000
        running: root.popupOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: statsProc.running = true
    }
}
