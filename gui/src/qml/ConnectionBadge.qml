import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.streetpea.chiaking

// Hebrew connection-quality badge shown over the stream when the network struggles.
// Loaded through a Loader so a problem here can never break the stream view itself.
Item {
    id: badge
    anchors.fill: parent

    readonly property real loss: (Chiaki.session && isFinite(Chiaki.session.averagePacketLoss)) ? Chiaki.session.averagePacketLoss : 0
    readonly property int level: loss > 0.05 ? 2 : (loss > 0.01 ? 1 : 0)
    property int shownLevel: 0

    onLevelChanged: {
        if (level > 0) {
            shownLevel = level;
            holdTimer.restart();
        }
    }

    Timer {
        id: holdTimer
        interval: 5000
        onTriggered: {
            if (badge.level > 0) {
                badge.shownLevel = badge.level;
                restart();
            } else {
                badge.shownLevel = 0;
            }
        }
    }

    Rectangle {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 18
        }
        width: badgeRow.implicitWidth + 36
        height: badgeRow.implicitHeight + 18
        radius: height / 2
        color: "#d0101218"
        border.width: 1
        border.color: badge.shownLevel == 2 ? "#ff5a5a" : "#ffb347"
        opacity: badge.shownLevel > 0 && Chiaki.session ? 1.0 : 0.0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 300 } }

        RowLayout {
            id: badgeRow
            anchors.centerIn: parent
            layoutDirection: qsTr("LTR") === "RTL" ? Qt.RightToLeft : Qt.LeftToRight
            spacing: 10

            Rectangle {
                width: 14
                height: 14
                radius: 7
                color: badge.shownLevel == 2 ? "#ff5a5a" : "#ffb347"
            }
            Label {
                font.pixelSize: 18
                color: "white"
                text: badge.shownLevel == 2
                    ? qsTr("Very weak connection - move closer to the router or pick Fast response")
                    : qsTr("Unstable connection - the picture may stutter")
            }
        }
    }
}
