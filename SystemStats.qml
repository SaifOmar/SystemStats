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
    property var netHistory: []

    // Per-widget overrides from the widget's shell.json layout entry.
    readonly property int refreshMs: Math.max(500, Number(setting("refreshMs", 2000)) || 2000)
    readonly property int historySeconds: Math.max(10, Number(setting("historySeconds", 60)) || 60)
    readonly property bool showDisks: setting("showDisks", true) !== false
    readonly property bool showNetwork: setting("showNetwork", true) !== false

    readonly property int maxSamples: Math.max(5, Math.round(historySeconds * 1000 / refreshMs))

    readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
    readonly property color dim: Qt.darker(root.fg, 1.55)
    readonly property color urgent: root.bar ? root.bar.urgent : Color.urgent
    readonly property color track: Style.selectedFillFor(root.fg, Color.accent)
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

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function formatSpeed(bytesPerSec) {
        var v = Number(bytesPerSec) || 0;
        if (v < 1024)
            return Math.round(v) + " B/s";
        if (v < 1048576)
            return (v / 1024).toFixed(1) + " KB/s";
        if (v < 1073741824)
            return (v / 1048576).toFixed(2) + " MB/s";
        return (v / 1073741824).toFixed(2) + " GB/s";
    }

    function formatUptime(secs) {
        var s = Math.floor(Number(secs) || 0);
        var d = Math.floor(s / 86400);
        var h = Math.floor(s / 3600);
        var m = Math.floor(s / 60);
        if (d > 0)
            return d + "d " + (h % 24) + "h";
        if (h > 0)
            return h + "h " + (m % 60) + "m";
        return m + "m";
    }

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
        var net = root.stats.net || {};
        root.netHistory = root.netHistory.concat([{
                    "down": Number(net.down) || 0,
                    "up": Number(net.up) || 0
                }]).slice(-root.maxSamples);
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
            spacing: Style.space(10)

            PanelHero {
                id: hero
                iconComponent: Component {
                    Text {
                        text: "󰓅"
                        color: root.fg
                        font.family: root.heroFont
                        font.pixelSize: Style.font.display
                    }
                }
                title: "System"
                detail: root.stats.uptime !== undefined ? "Up " + root.formatUptime(root.stats.uptime) : ""
                meta: root.summaryLine
                foreground: root.fg
                fontFamily: root.heroFont
            }

            PanelSeparator {
                foreground: root.fg
            }

            // ---------- System ----------
            Column {
                width: parent.width
                spacing: Style.space(9)

                PanelSectionHeader {
                    width: parent.width
                    text: "SYSTEM"
                    foreground: root.fg
                    fontFamily: root.heroFont
                }

                UsageRow {
                    width: parent.width
                    label: "CPU"
                    valueText: root.stats.cpu !== undefined ? root.stats.cpu + "%" : "…"
                    ratio: (Number(root.stats.cpu) || 0) / 100
                    alarming: (Number(root.stats.cpu) || 0) >= 90
                }

                UsageRow {
                    width: parent.width
                    label: "Temp"
                    valueText: root.stats.temp !== undefined ? root.stats.temp + "°" : "…"
                    ratio: root.clamp((Number(root.stats.temp) || 0) / 100, 0, 1)
                    alarming: (Number(root.stats.temp) || 0) >= 80
                }

                UsageRow {
                    width: parent.width
                    label: "Memory"
                    valueText: root.stats.mem ? root.stats.mem.used + "G / " + root.stats.mem.total + "G  (" + root.stats.mem.percent + "%)" : "…"
                    ratio: root.stats.mem ? (Number(root.stats.mem.percent) || 0) / 100 : 0
                    alarming: !!root.stats.mem && (Number(root.stats.mem.percent) || 0) >= 90
                }

                UsageRow {
                    width: parent.width
                    label: "Swap"
                    valueText: root.stats.mem ? root.stats.mem.swapUsed + "G / " + root.stats.mem.swapTotal + "G  (" + root.stats.mem.swapPercent + "%)" : "…"
                    ratio: root.stats.mem ? (Number(root.stats.mem.swapPercent) || 0) / 100 : 0
                    alarming: !!root.stats.mem && (Number(root.stats.mem.swapPercent) || 0) >= 90
                }
            }

            // ---------- Disk ----------
            PanelSeparator {
                visible: root.showDisks && root.stats.disks !== undefined && root.stats.disks.length > 0
                foreground: root.fg
            }

            Column {
                visible: root.showDisks && root.stats.disks !== undefined && root.stats.disks.length > 0
                width: parent.width
                spacing: Style.space(9)

                PanelSectionHeader {
                    width: parent.width
                    text: "DISK"
                    foreground: root.fg
                    fontFamily: root.heroFont
                }

                Repeater {
                    model: root.stats.disks || []

                    UsageRow {
                        required property var modelData
                        width: parent.width
                        label: modelData.mount
                        valueText: modelData.used + "G / " + modelData.total + "G  (" + modelData.percent + "%)"
                        ratio: (Number(modelData.percent) || 0) / 100
                        alarming: (Number(modelData.percent) || 0) >= 90
                    }
                }
            }

            // ---------- Network ----------
            PanelSeparator {
                visible: root.showNetwork && root.stats.net !== undefined
                foreground: root.fg
            }

            Column {
                visible: root.showNetwork && root.stats.net !== undefined
                width: parent.width
                spacing: Style.space(8)

                PanelSectionHeader {
                    width: parent.width
                    text: "NETWORK"
                    foreground: root.fg
                    fontFamily: root.heroFont
                }

                Item {
                    width: parent.width
                    implicitHeight: downCaption.implicitHeight

                    Text {
                        id: downCaption
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↓ " + root.formatSpeed(root.stats.net ? root.stats.net.down : 0)
                        color: root.fg
                        font.family: root.heroFont
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↑ " + root.formatSpeed(root.stats.net ? root.stats.net.up : 0)
                        color: root.dim
                        font.family: root.heroFont
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }
                }

                UsageGraph {
                    width: parent.width
                    samples: root.netHistory
                    showLevels: true
                    formatter: root.formatSpeed
                    series: [{
                            "key": "up",
                            "fill": root.alpha(Color.accent, 0.35),
                            "stroke": root.alpha(Color.accent, 0.8)
                        }, {
                            "key": "down",
                            "fill": root.alpha(root.fg, 0.3),
                            "stroke": root.alpha(root.fg, 0.7)
                        }]
                }
            }
        }
    }

    // Label and current value over a full-width horizontal meter.
    component UsageRow: Column {
        id: usageRow
        required property string label
        required property string valueText
        required property real ratio
        required property bool alarming

        spacing: Style.space(6)

        Item {
            width: parent.width
            implicitHeight: Math.max(rowLabel.implicitHeight, rowValue.implicitHeight)

            Text {
                id: rowLabel
                text: usageRow.label
                color: usageRow.alarming ? root.urgent : root.fg
                font.family: root.heroFont
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
                anchors.left: parent.left
                anchors.right: rowValue.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: rowValue
                text: usageRow.valueText
                color: usageRow.alarming ? root.urgent : root.dim
                font.family: root.heroFont
                font.pixelSize: Style.font.caption
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Meter {
            width: parent.width
            value: usageRow.ratio
            alarming: usageRow.alarming
        }
    }

    // Rounded track with an animated fill; turns urgent when alarming.
    component Meter: Item {
        id: meter
        property real value: -1
        property bool alarming: false
        property real thickness: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))

        implicitHeight: thickness

        Rectangle {
            id: meterTrack
            anchors.fill: parent
            radius: height / 2
            color: root.track
        }

        Rectangle {
            anchors.left: meterTrack.left
            anchors.verticalCenter: meterTrack.verticalCenter
            height: meterTrack.height
            radius: meterTrack.radius
            width: meterTrack.width * root.clamp(meter.value, 0, 1)
            color: meter.alarming ? root.urgent : root.fg

            Behavior on width {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    // btop-style scrolling area chart. Draws each entry of `series` over the
    // sample buffer, auto-scaled to the busiest value — unless `maxValue` is
    // set (e.g. 1 for CPU), which pins the scale instead. With `showLevels`,
    // faint gridlines at 50%/100% carry labels of what those heights mean,
    // because a rescaling graph otherwise reads full at any magnitude.
    component UsageGraph: Item {
        id: graph
        property var samples: []
        property var series: []
        property real maxValue: 0
        property bool showLevels: false
        property var formatter: null

        implicitHeight: Style.space(72)

        // Single source of truth for the scale, shared by the canvas paint
        // and the level labels so they can never disagree.
        function computePeak() {
            var peak = graph.maxValue > 0 ? graph.maxValue : canvas.peakFloor;
            if (graph.maxValue <= 0) {
                var data = graph.samples || [];
                for (var s = 0; s < graph.series.length; s++) {
                    var key = graph.series[s].key;
                    for (var i = 0; i < data.length; i++)
                        peak = Math.max(peak, data[i][key]);
                }
            }
            return peak;
        }

        function labelFor(value) {
            return !!graph.formatter ? graph.formatter(value) : "";
        }

        onSamplesChanged: canvas.requestPaint()
        onSeriesChanged: canvas.requestPaint()

        Canvas {
            id: canvas
            anchors.fill: parent
            antialiasing: true

            readonly property int maxPoints: root.maxSamples
            readonly property real peakFloor: 10 * 1024

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                ctx.strokeStyle = root.alpha(root.fg, 0.15);
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(0, height - 0.5);
                ctx.lineTo(width, height - 0.5);
                ctx.stroke();

                var data = graph.samples || [];
                var peak = graph.computePeak();
                if (data.length === 0)
                    return;

                if (graph.showLevels) {
                    ctx.strokeStyle = root.alpha(root.fg, 0.08);
                    ctx.lineWidth = 1;
                    ctx.setLineDash([2, 4]);
                    ctx.beginPath();
                    ctx.moveTo(0, Math.round(height / 2) + 0.5);
                    ctx.lineTo(width, Math.round(height / 2) + 0.5);
                    ctx.moveTo(0, 0.5);
                    ctx.lineTo(width, 0.5);
                    ctx.stroke();
                    ctx.setLineDash([]);
                }

                var step = width / (canvas.maxPoints - 1);
                var x0 = width - step * (data.length - 1);

                for (var k = 0; k < graph.series.length; k++)
                    drawSeries(graph.series[k]);

                function drawSeries(s) {
                    ctx.beginPath();
                    ctx.moveTo(x0, height);
                    for (var i = 0; i < data.length; i++) {
                        var x = x0 + step * i;
                        var y = height - root.clamp(data[i][s.key] / peak, 0, 1) * (height - 2);
                        ctx.lineTo(x, y);
                    }
                    ctx.lineTo(x0 + step * (data.length - 1), height);
                    ctx.closePath();
                    ctx.fillStyle = s.fill;
                    ctx.fill();
                    ctx.strokeStyle = s.stroke;
                    ctx.lineWidth = 1.5;
                    ctx.beginPath();
                    for (var j = 0; j < data.length; j++) {
                        var px = x0 + step * j;
                        var py = height - root.clamp(data[j][s.key] / peak, 0, 1) * (height - 2);
                        if (j === 0)
                            ctx.moveTo(px, py);
                        else
                            ctx.lineTo(px, py);
                    }
                    ctx.stroke();
                }
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        Text {
            visible: graph.showLevels && !!graph.formatter && (graph.samples || []).length > 0
            anchors.right: parent.right
            anchors.top: parent.top
            text: graph.labelFor(graph.computePeak())
            color: root.dim
            font.family: root.heroFont
            font.pixelSize: Style.font.caption
        }

        Text {
            visible: graph.showLevels && !!graph.formatter && (graph.samples || []).length > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: graph.labelFor(graph.computePeak() / 2)
            color: root.alpha(root.dim, 0.7)
            font.family: root.heroFont
            font.pixelSize: Style.font.caption
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
            target: hero
            property: "metaOpacity"
            to: 0.0
            duration: 180
            easing.type: Easing.OutQuad
        }
        ScriptAction {
            script: root.summaryLineIndex = (root.summaryLineIndex + 1) % root.summaryLines.length
        }
        PropertyAnimation {
            target: hero
            property: "metaOpacity"
            to: 1.0
            duration: 260
            easing.type: Easing.InQuad
        }
    }

    Timer {
        id: statsTimer
        interval: root.refreshMs
        running: root.popupOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: statsProc.running = true
    }
}
