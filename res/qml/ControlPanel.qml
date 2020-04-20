import QtQuick 2.7
import QtQuick.Layouts 1.0
import QtQuick.Controls 2.0

import "."

ColumnLayout {
    anchors.fill: parent
    spacing: 1

    property var isConnected: false
    property var isRunning: false
    property var lokiVersion: ""
    property var lokiAddress: ""
    property int lokiUptime: 0
    property var numPathsBuilt: 0
    property var numRoutersKnown: 0
    property var downloadUsage: 0
    property var uploadUsage: 0
    property var numPeersConnected: 0

    LogoHeaderPanel {
    }

    // connection button panel
    ConnectionButtonPanel {
        connected: isConnected
        running: isRunning
    }

    // version panel
    VersionPanel {
        version: lokiVersion
    }

    // uptime panel
    UptimePanel {
        uptime: lokiUptime
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

    // usage
    UsagePanel {
        down: downloadUsage
        up: uploadUsage
    }

    // dismiss panel
    DismissPanel {
        visible: !notray
    }


    Component.onCompleted: {
        stateApiPoller.statusAvailable.connect(handleStateResults);
        stateApiPoller.pollImmediately();
        stateApiPoller.setIntervalMs(500);
        stateApiPoller.startPolling();

        statusApiPoller.statusAvailable.connect(handleStatusResults);
        statusApiPoller.pollImmediately();
        statusApiPoller.setIntervalMs(500);
        statusApiPoller.startPolling();

    }

    onIsConnectedChanged: function() {
        if (! isConnected) {
            console.log("Detected disconnection");
            // zero-out values that would otherwise be stale in the UI
            isRunning = false;
            lokiVersion = "";
            lokiAddress = "";
            lokiUptime = 0;
            numPathsBuilt = 0;
            numRoutersKnown = 0;
            downloadUsage = 0;
            uploadUsage = 0;
            numPeersConnected = 0;
        } else {
            console.log("Detected [re-]connection");
            queryVersion();
        }
    }

    function handleStateResults(payload, error) {
        var stats = null;
        
        if (! error) {
            try {
                stats = JSON.parse(payload);
            } catch (err) {
                console.log("Couldn't parse 'dumpState' JSON-RPC payload", err);
            }
        }
        var forEachSession = function(visit) {
           var st = stats.result;
           for(var idx in st.links)
           {
             if(!st.links[idx])
               continue;
             else
             {
               var links = st.links[idx];
               for(var l_idx in links)
               {
                 var link = links[l_idx];
                 if(!link)
                   continue;
                 var peers = link.sessions.established;
                 for(var p_idx in peers)
                 {
                   visit(peers[p_idx]);
                 }
               }
             }
           }
        };
        // calculate our new state in local scope before updating global scope
        var newConnected = (! error && stats != null);
        var newRunning = false;
        var newLokiAddress = "";
        var newNumRouters = 0;
        var txRate = 0;
        var rxRate = 0;
        var peers = 0;
        if (! error) {
            try {
                forEachSession(function(s) {
                   txRate += s.tx;
                   rxRate += s.rx;
                   peers += 1;
                });
            } catch (err) {
                txRate = 0;
                rxRate = 0;
                peers = 0;
                console.log("Couldn't pull tx/rx of payload", err);
            }

            // we're polling every 500ms, so our per-second rate is half of the
            // rate we tallied up in this sample
            // TODO: don't be so sloppy
            uploadUsage = (txRate / 2);
            downloadUsage = (rxRate / 2);

            numPeersConnected = peers;
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
                numPathsBuilt = stats.result.services.default.buildStats.success;
            } catch (err) {
                console.log("Couldn't pull buildStats out of payload", err);
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

    function handleStatusResults(payload, error) {
        if (! error) {
            try {
                const responseObj = JSON.parse(payload);
                lokiUptime = responseObj.result.uptime;
            } catch (err) {
                console.log("Couldn't parse 'status' JSON-RPC payload", err);
            }
        }
    }

    function queryVersion() {

        // query daemon version
        apiClient.llarpVersion(function(response, err) {
            if (err) {
                console.log("Received error when trying to wakeup lokinet daemon: ", err);
            } else {
                try {
                     const msg = JSON.parse(response);
                     lokiVersion = msg.result.version;
                 } catch (e) {
                     console.log("Couldn't pull version out of payload", e);
                 }
            }
        });
    }
}

