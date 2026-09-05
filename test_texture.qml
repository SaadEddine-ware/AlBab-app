import QtQuick 2.15
import QtQuick.Window 2.15

Window {
    visible: true
    width: 400
    height: 400
    
    Canvas {
        id: canvas
        anchors.fill: parent
        
        property bool texLoaded: false
        
        Timer {
            interval: 200
            running: true
            onTriggered: {
                console.log('Loading image...')
                canvas.loadImage("earth", "file:///E:/albab-app/assets/earth_texture.jpg")
            }
        }
        
        onImageLoaded: {
            console.log('onImageLoaded called, name:', name, 'loaded:', isImageLoaded("earth"))
            texLoaded = true
            requestPaint()
        }
        
        onPaint: {
            var ctx = getContext("2d")
            var w = width, h = height
            ctx.clearRect(0, 0, w, h)
            
            if (isImageLoaded("earth")) {
                console.log('Drawing texture, size:', imageWidth("earth"), imageHeight("earth"))
                ctx.drawImage("earth", 0, 0, w, h)
                console.log('Drew texture successfully')
            } else {
                console.log('No texture loaded, drawing red')
                ctx.fillStyle = "red"
                ctx.fillRect(0, 0, w, h)
            }
        }
    }
    
    Timer {
        interval: 3000
        running: true
        onTriggered: app.quit()
    }
}
