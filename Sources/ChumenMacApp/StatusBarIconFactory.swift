import AppKit

enum StatusBarDoorIconState: Equatable {
    case closed
    case proxy
    case open
}

enum StatusBarIconFactory {
    static func image(for state: StatusBarDoorIconState) -> NSImage {
        switch state {
        case .closed:
            closedImage
        case .proxy:
            proxyImage
        case .open:
            openImage
        }
    }

    private static let closedImage = assetImage(named: "StatusBarDoorClosed") ?? makeImage(for: .closed)
    private static let proxyImage = assetImage(named: "StatusBarDoorProxy") ?? makeImage(for: .proxy)
    private static let openImage = assetImage(named: "StatusBarDoorOpen") ?? makeImage(for: .open)

    private static func assetImage(named name: String) -> NSImage? {
        for url in assetURLs(named: name) {
            guard let image = NSImage(contentsOf: url), image.isValid else { continue }
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = false
            return image
        }
        return nil
    }

    private static func assetURLs(named name: String) -> [URL] {
        var urls: [URL] = []
        if let bundleURL = Bundle.main.url(forResource: name, withExtension: "png") {
            urls.append(bundleURL)
        }

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        urls.append(
            repositoryRoot
                .appendingPathComponent("Packaging/Assets", isDirectory: true)
                .appendingPathComponent("\(name).png")
        )
        return urls
    }

    private static func makeImage(for state: StatusBarDoorIconState) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { bounds in
            switch state {
            case .closed:
                drawClosedDoor(in: bounds)
            case .proxy:
                drawHalfOpenDoor(in: bounds)
            case .open:
                drawOpenDoor(in: bounds)
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func drawClosedDoor(in bounds: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        scaleContext(to: bounds)

        let tile = drawAppIconTile()

        let frame = roundedRect(x: 3.4, y: 2.0, width: 10.2, height: 14.0, radius: 2.3)
        color(248, 253, 255).setFill()
        frame.fill()
        color(56, 130, 180, alpha: 0.24).setStroke()
        frame.lineWidth = 0.75
        frame.stroke()

        let opening = roundedRect(x: 5.0, y: 3.9, width: 5.8, height: 10.5, radius: 1.3)
        NSGraphicsContext.saveGraphicsState()
        opening.addClip()
        NSGradient(colors: [
            color(255, 246, 197),
            color(89, 218, 238),
            color(40, 123, 222)
        ])?.draw(in: opening.bounds, angle: 90)
        color(255, 221, 90, alpha: 0.95).setFill()
        NSBezierPath(ovalIn: NSRect(x: 8.3, y: 10.8, width: 2.0, height: 2.0)).fill()
        NSGraphicsContext.restoreGraphicsState()

        let door = roundedRect(x: 5.3, y: 3.45, width: 7.9, height: 11.8, radius: 1.25)
        NSGradient(colors: [
            color(253, 255, 255),
            color(229, 247, 253)
        ])?.draw(in: door, angle: -10)
        color(74, 150, 192, alpha: 0.42).setStroke()
        door.lineWidth = 0.75
        door.stroke()

        color(255, 255, 255, alpha: 0.44).setStroke()
        let highlight = NSBezierPath()
        highlight.move(to: NSPoint(x: 6.5, y: 4.8))
        highlight.line(to: NSPoint(x: 6.5, y: 13.7))
        highlight.lineWidth = 0.55
        highlight.lineCapStyle = .round
        highlight.stroke()

        color(48, 143, 190, alpha: 0.62).setFill()
        NSBezierPath(ovalIn: NSRect(x: 11.0, y: 8.2, width: 1.15, height: 1.15)).fill()

        let threshold = NSBezierPath()
        threshold.move(to: NSPoint(x: 2.5, y: 3.6))
        threshold.curve(
            to: NSPoint(x: 7.0, y: 5.0),
            controlPoint1: NSPoint(x: 3.7, y: 3.7),
            controlPoint2: NSPoint(x: 5.5, y: 4.2)
        )
        color(255, 255, 255, alpha: 0.78).setStroke()
        threshold.lineWidth = 1.0
        threshold.lineCapStyle = .round
        threshold.stroke()
        color(13, 181, 211, alpha: 0.82).setStroke()
        threshold.lineWidth = 0.55
        threshold.stroke()

        color(255, 255, 255, alpha: 0.42).setStroke()
        tile.lineWidth = 0.45
        tile.stroke()

        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawHalfOpenDoor(in bounds: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        scaleContext(to: bounds)

        let tile = drawAppIconTile()

        let portalFrame = roundedRect(x: 3.4, y: 2.0, width: 10.2, height: 14.0, radius: 2.3)
        color(248, 253, 255).setFill()
        portalFrame.fill()
        color(56, 130, 180, alpha: 0.24).setStroke()
        portalFrame.lineWidth = 0.75
        portalFrame.stroke()

        let opening = roundedRect(x: 5.0, y: 3.9, width: 5.8, height: 10.5, radius: 1.3)
        NSGraphicsContext.saveGraphicsState()
        opening.addClip()
        NSGradient(colors: [
            color(255, 246, 197),
            color(89, 218, 238),
            color(40, 123, 222)
        ])?.draw(in: opening, angle: 90)
        color(255, 221, 90, alpha: 0.95).setFill()
        NSBezierPath(ovalIn: NSRect(x: 8.3, y: 10.8, width: 2.0, height: 2.0)).fill()
        NSGraphicsContext.restoreGraphicsState()

        let door = NSBezierPath()
        door.move(to: NSPoint(x: 7.8, y: 3.4))
        door.line(to: NSPoint(x: 14.0, y: 2.6))
        door.line(to: NSPoint(x: 14.0, y: 15.1))
        door.line(to: NSPoint(x: 7.8, y: 14.4))
        door.close()
        color(242, 252, 255, alpha: 0.98).setFill()
        door.fill()
        color(75, 151, 193, alpha: 0.42).setStroke()
        door.lineWidth = 0.75
        door.lineJoinStyle = .round
        door.stroke()

        color(70, 157, 199, alpha: 0.76).setFill()
        NSBezierPath(ovalIn: NSRect(x: 11.3, y: 8.0, width: 1.15, height: 1.15)).fill()

        let path = NSBezierPath()
        path.move(to: NSPoint(x: 2.3, y: 4.1))
        path.curve(
            to: NSPoint(x: 8.2, y: 7.0),
            controlPoint1: NSPoint(x: 4.1, y: 4.4),
            controlPoint2: NSPoint(x: 6.5, y: 5.7)
        )
        color(255, 255, 255, alpha: 0.86).setStroke()
        path.lineWidth = 1.8
        path.lineCapStyle = .round
        path.stroke()
        color(13, 181, 211, alpha: 0.88).setStroke()
        path.lineWidth = 0.85
        path.stroke()

        color(255, 255, 255, alpha: 0.42).setStroke()
        tile.lineWidth = 0.45
        tile.stroke()

        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawOpenDoor(in bounds: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        scaleContext(to: bounds)

        let tile = drawAppIconTile()

        let portalFrame = roundedRect(x: 3.4, y: 2.0, width: 10.2, height: 14.0, radius: 2.3)
        color(248, 253, 255).setFill()
        portalFrame.fill()
        color(56, 130, 180, alpha: 0.24).setStroke()
        portalFrame.lineWidth = 0.75
        portalFrame.stroke()

        let opening = roundedRect(x: 5.0, y: 3.9, width: 5.8, height: 10.5, radius: 1.3)
        NSGraphicsContext.saveGraphicsState()
        opening.addClip()
        NSGradient(colors: [
            color(255, 246, 197),
            color(89, 218, 238),
            color(40, 123, 222)
        ])?.draw(in: opening, angle: 90)
        color(255, 221, 90, alpha: 0.95).setFill()
        NSBezierPath(ovalIn: NSRect(x: 8.3, y: 10.8, width: 2.0, height: 2.0)).fill()
        NSGraphicsContext.restoreGraphicsState()

        let door = NSBezierPath()
        door.move(to: NSPoint(x: 10.6, y: 3.3))
        door.line(to: NSPoint(x: 15.9, y: 2.0))
        door.line(to: NSPoint(x: 15.9, y: 15.8))
        door.line(to: NSPoint(x: 10.6, y: 14.3))
        door.close()
        color(241, 251, 255, alpha: 0.98).setFill()
        door.fill()
        color(75, 151, 193, alpha: 0.42).setStroke()
        door.lineWidth = 0.75
        door.lineJoinStyle = .round
        door.stroke()

        color(70, 157, 199, alpha: 0.80).setFill()
        NSBezierPath(ovalIn: NSRect(x: 13.0, y: 8.0, width: 1.25, height: 1.25)).fill()

        let path = NSBezierPath()
        path.move(to: NSPoint(x: 2.1, y: 4.1))
        path.curve(
            to: NSPoint(x: 10.9, y: 8.9),
            controlPoint1: NSPoint(x: 4.9, y: 4.7),
            controlPoint2: NSPoint(x: 8.3, y: 7.1)
        )
        color(255, 255, 255, alpha: 0.95).setStroke()
        path.lineWidth = 2.2
        path.lineCapStyle = .round
        path.stroke()
        color(13, 181, 211).setStroke()
        path.lineWidth = 1.15
        path.stroke()

        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: 11.5, y: 9.2))
        arrow.line(to: NSPoint(x: 9.3, y: 9.0))
        arrow.line(to: NSPoint(x: 10.5, y: 7.4))
        arrow.close()
        color(13, 181, 211).setFill()
        arrow.fill()

        color(255, 255, 255, alpha: 0.42).setStroke()
        tile.lineWidth = 0.45
        tile.stroke()

        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawAppIconTile() -> NSBezierPath {
        let tile = roundedRect(x: 1.0, y: 1.0, width: 16.0, height: 16.0, radius: 3.8)
        NSGraphicsContext.saveGraphicsState()
        tile.addClip()
        NSGradient(colors: [
            color(217, 249, 255),
            color(91, 205, 244),
            color(45, 123, 221)
        ])?.draw(in: tile.bounds, angle: -35)
        color(255, 255, 255, alpha: 0.26).setFill()
        NSBezierPath(ovalIn: NSRect(x: -2.2, y: 9.2, width: 10.2, height: 5.0)).fill()
        color(255, 255, 255, alpha: 0.16).setFill()
        NSBezierPath(ovalIn: NSRect(x: 9.7, y: 2.5, width: 8.8, height: 4.8)).fill()
        NSGraphicsContext.restoreGraphicsState()
        return tile
    }

    private static func scaleContext(to bounds: NSRect) {
        let context = NSGraphicsContext.current?.cgContext
        let scale = min(bounds.width, bounds.height) / 18
        context?.translateBy(
            x: bounds.minX + (bounds.width - 18 * scale) / 2,
            y: bounds.minY + (bounds.height - 18 * scale) / 2
        )
        context?.scaleBy(x: scale, y: scale)
    }

    private static func roundedRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: height), xRadius: radius, yRadius: radius)
    }

    private static func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
    }
}
