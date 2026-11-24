/*
 * Photo slideshow screensaver for LG webOS.
 *
 * apply.sh bind-mounts this file over
 *   /usr/palm/applications/com.webos.app.screensaver/qml/main.qml
 * Each time the screensaver starts, it picks a random order of the images in the photos
 * folder and repeats that order until the TV wakes, with a crossfade between photos.
 *
 * Test launch:
 *   luna-send -n 1 'luna://com.webos.service.tvpower/power/turnOnScreenSaver' '{}'
 */
import QtQuick 2.12
import QtQuick.Window 2.2
import Eos.Window 0.1
import Qt.labs.folderlistmodel 2.1

WebOSWindow {
    id: window

    width: 1920
    height: 1080
    windowType: "_WEBOS_WINDOW_TYPE_SCREENSAVER"
    color: "black"
    title: "Screensaver"
    appId: "com.webos.app.screensaver"
    visible: true

    // How long each photo stays, and the crossfade length
    property int holdMs: 15000
    property int fadeMs: 2000

    property var order: []
    property int orderPos: 0
    property string lastShown: ""
    property int failures: 0
    property Item front: slideA
    property Item back: slideB
    property Item leaving: null

    FolderListModel {
        id: photos
        folder: "file:///media/developer/webos-custom-screens/photos"
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.JPG", "*.JPEG", "*.PNG"]
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        onCountChanged: if (count > 0 && window.lastShown === "") window.advance()
    }

    Image {
        id: slideA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        sourceSize.width: 1920
        sourceSize.height: 1080
        opacity: 0
        onStatusChanged: window.handleSlideStatus(slideA)
    }

    Image {
        id: slideB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        sourceSize.width: 1920
        sourceSize.height: 1080
        opacity: 0
        onStatusChanged: window.handleSlideStatus(slideB)
    }

    // The incoming photo fades in on top of the outgoing one, which stays fully visible
    // underneath, so the picture never dips towards black mid-fade.
    SequentialAnimation {
        id: crossfade
        NumberAnimation {
            id: fadeIn
            property: "opacity"
            from: 0
            to: 1
            duration: window.fadeMs
            easing.type: Easing.InOutQuad
        }
        ScriptAction { script: window.finishFade() }
    }

    Timer {
        id: hold
        interval: window.holdMs + window.fadeMs
        onTriggered: window.advance()
    }

    Timer {
        id: retry
        interval: 200
        onTriggered: window.advance()
    }

    // Shuffled photo indexes. The first one is never the photo on screen now, which matters
    // only when the photo count changes while the screensaver runs.
    function shuffledOrder() {
        var a = []
        for (var i = 0; i < photos.count; i++)
            a.push(i)
        for (var j = a.length - 1; j > 0; j--) {
            var k = Math.floor(Math.random() * (j + 1))
            var t = a[j]; a[j] = a[k]; a[k] = t
        }
        if (a.length > 1 && photos.get(a[0], "filePath") === lastShown) {
            var s = a[0]; a[0] = a[1]; a[1] = s
        }
        return a
    }

    // The order is shuffled once and then repeated. It is shuffled again only if photos are
    // added or removed while the screensaver runs.
    function nextPath() {
        if (order.length === 0 || order.length !== photos.count) {
            order = shuffledOrder()
            orderPos = 0
        }
        var p = photos.get(order[orderPos], "filePath")
        orderPos = (orderPos + 1) % order.length
        return p
    }

    // Loads the next photo into the hidden slide. handleSlideStatus reveals it once decoded.
    function advance() {
        if (photos.count === 0)
            return
        var p = nextPath()
        lastShown = p
        back.source = ""
        back.source = "file://" + p
    }

    function handleSlideStatus(slide) {
        if (slide !== back)
            return
        if (slide.status === Image.Ready) {
            failures = 0
            reveal()
        } else if (slide.status === Image.Error) {
            failures++
            if (failures < photos.count)
                retry.start()
        }
    }

    function reveal() {
        if (crossfade.running) {
            crossfade.stop()
            finishFade()
        }
        var incoming = back
        leaving = front
        leaving.z = 0
        incoming.z = 1
        incoming.opacity = 0
        fadeIn.target = incoming
        crossfade.start()
        front = incoming
        back = leaving
        hold.restart()
    }

    function finishFade() {
        if (leaving) {
            leaving.opacity = 0
            leaving.source = ""
        }
        leaving = null
    }
}
