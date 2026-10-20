import QtQuick

// Vector icons drawn on a Canvas (no emoji / image assets => identical on every device).
Canvas {
    id: c
    property string name: "check"
    property color color: "#FFFFFF"
    property real size: 24
    property real stroke: 2.2
    width: size
    height: size
    antialiasing: true
    onColorChanged: requestPaint()
    onNameChanged: requestPaint()
    onSizeChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var s = width
        ctx.strokeStyle = color
        ctx.fillStyle = color
        ctx.lineWidth = stroke * s / 24
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.beginPath()
        if (name === "check") {
            ctx.moveTo(.2*s, .54*s); ctx.lineTo(.42*s, .74*s); ctx.lineTo(.8*s, .28*s); ctx.stroke()
        } else if (name === "plus") {
            ctx.moveTo(.5*s, .2*s); ctx.lineTo(.5*s, .8*s); ctx.moveTo(.2*s, .5*s); ctx.lineTo(.8*s, .5*s); ctx.stroke()
        } else if (name === "close") {
            ctx.moveTo(.26*s, .26*s); ctx.lineTo(.74*s, .74*s); ctx.moveTo(.74*s, .26*s); ctx.lineTo(.26*s, .74*s); ctx.stroke()
        } else if (name === "tasks") {
            var ys = [.28, .5, .72]
            for (var i = 0; i < 3; i++) {
                ctx.beginPath(); ctx.arc(.18*s, ys[i]*s, .055*s, 0, 2*Math.PI); ctx.fill()
                ctx.beginPath(); ctx.moveTo(.36*s, ys[i]*s); ctx.lineTo(.86*s, ys[i]*s); ctx.stroke()
            }
        } else if (name === "chart") {
            ctx.lineWidth = 3.6 * s / 24
            ctx.moveTo(.22*s, .84*s); ctx.lineTo(.22*s, .52*s)
            ctx.moveTo(.5*s, .84*s); ctx.lineTo(.5*s, .2*s)
            ctx.moveTo(.78*s, .84*s); ctx.lineTo(.78*s, .38*s); ctx.stroke()
        } else if (name === "clock") {
            ctx.arc(.5*s, .5*s, .38*s, 0, 2*Math.PI); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(.5*s, .28*s); ctx.lineTo(.5*s, .5*s); ctx.lineTo(.66*s, .6*s); ctx.stroke()
        } else if (name === "flame") {
            ctx.moveTo(.5*s, .04*s)
            ctx.bezierCurveTo(.56*s, .3*s, .86*s, .4*s, .84*s, .66*s)
            ctx.bezierCurveTo(.82*s, .86*s, .66*s, .96*s, .5*s, .96*s)
            ctx.bezierCurveTo(.32*s, .96*s, .16*s, .84*s, .16*s, .64*s)
            ctx.bezierCurveTo(.16*s, .46*s, .3*s, .38*s, .34*s, .22*s)
            ctx.bezierCurveTo(.4*s, .3*s, .44*s, .36*s, .5*s, .04*s)
            ctx.closePath(); ctx.fill()
        } else if (name === "trash") {
            ctx.moveTo(.18*s, .27*s); ctx.lineTo(.82*s, .27*s)
            ctx.moveTo(.38*s, .27*s); ctx.lineTo(.38*s, .15*s); ctx.lineTo(.62*s, .15*s); ctx.lineTo(.62*s, .27*s)
            ctx.moveTo(.27*s, .27*s); ctx.lineTo(.31*s, .86*s); ctx.lineTo(.69*s, .86*s); ctx.lineTo(.73*s, .27*s)
            ctx.stroke()
        } else if (name === "bell") {
            ctx.moveTo(.2*s, .72*s); ctx.lineTo(.8*s, .72*s)
            ctx.bezierCurveTo(.7*s, .62*s, .7*s, .5*s, .7*s, .4*s)
            ctx.bezierCurveTo(.7*s, .24*s, .6*s, .16*s, .5*s, .16*s)
            ctx.bezierCurveTo(.4*s, .16*s, .3*s, .24*s, .3*s, .4*s)
            ctx.bezierCurveTo(.3*s, .5*s, .3*s, .62*s, .2*s, .72*s)
            ctx.stroke()
            ctx.beginPath(); ctx.arc(.5*s, .8*s, .07*s, 0, 2*Math.PI); ctx.fill()
        }
    }
}
