import QtQuick 2.0
import QtQuick.Layouts 1.11
import QtQuick.Controls 2.5

import "."

ColumnLayout {
    anchors.fill: parent
    spacing: 1

    property var isConnected: false
    property var isRunning: false
    property var lokiAddress: ""
    property var numPathsBuilt: 0
    property var numRoutersKnown: 0
    property var downloadUsage: 0
    property var uploadUsage: 0

    LogoHeaderPanel {
    }

    // placeholder for main on/off button
    ConnectionButtonPanel {
        connected: isConnected
        running: isRunning
    }

    // address panel
    AddressPanel {
        address: lokiAddress
    }

    // router stats
    RouteStatsPanel {
        paths: numPathsBuilt
        routers: numRoutersKnown
    }

    // placeholder for performance graph panel
    Rectangle {
        color: Style.panelBackgroundColor
        Layout.preferredHeight: 159
        Layout.preferredWidth: Style.appWidth
    }

    // usage
    UsagePanel {
        down: downloadUsage
        up: uploadUsage
    }

    // placeholder / empty space
    Rectangle {
        color: Style.panelBackgroundColor
        Layout.preferredHeight: 79
        Layout.preferredWidth: Style.appWidth
    }

    // dismiss panel
    DismissPanel { }


    Component.onCompleted: {
        stateApiPoller.statusAvailable.connect(handleStateResults);
        stateApiPoller.pollImmediately();
        stateApiPoller.setIntervalMs(3000);
        stateApiPoller.startPolling();
    }

    function handleStateResults(payload, error) {
        let stats = null;
        
        if (! error) {
            try {
                stats = JSON.parse(payload);
            } catch (err) {
                console.log("Couldn't parse JSON-RPC payload", err);
            }
        }

        // calculate our new state in local scope before updating global scope
        let newConnected = (! error && stats != null);
        let newRunning = false;
        let newLokiAddress = "";
        let newNumRouters = 0;

        if (! error) {
            try {
                newRunning = stats.result.running;
            } catch (err) {
                console.log("Couldn't pull running status of payload", err);
            }

            try {
                newLokiAddress = stats.result.services.default.identity;
            } catch (err) {
                console.log("Couldn't pull loki address out of payload", err);
            }

            try {
                newNumRouters = stats.result.numNodesKnown;
            } catch (err) {
                console.log("Couldn't pull numNodesKnown out of payload", err);
            }

            try {
                numPathsBuilt = stats.result.services.default.numPaths;
            } catch (err) {
                console.log("Couldn't pull services.numPaths out of payload", err);
            }
        }

        // only update global state if there is actually a change.
        // this prevents propagating state change events when there aren't
        // really changes in the first place
        if (newConnected !== isConnected) isConnected = newConnected;
        if (newRunning !== isRunning) isRunning = newRunning;
        if (newLokiAddress !== lokiAddress) lokiAddress = newLokiAddress;
        if (newNumRouters !== numRoutersKnown) numRoutersKnown = newNumRouters;

    }
}
