#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let assets = root.appendingPathComponent("Packaging/Assets", isDirectory: true)
let closedURL = assets.appendingPathComponent("StatusBarDoorClosed.png")
let proxyURL = assets.appendingPathComponent("StatusBarDoorProxy.png")
let openURL = assets.appendingPathComponent("StatusBarDoorOpen.png")
let openWithDoorURL = assets.appendingPathComponent("StatusBarDoorOpenWithDoor.png")
let openDoorwayURL = assets.appendingPathComponent("StatusBarDoorOpenDoorway.png")
let previewURL = assets.appendingPathComponent("StatusBarDoorStatesPreview.png")
let colorOptionsURL = assets.appendingPathComponent("StatusBarDoorClosedColorOptions.png")
let openingOptionsURL = assets.appendingPathComponent("StatusBarDoorOpeningOptions.png")

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func roundedRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ radius: CGFloat, scale: CGFloat) -> NSBezierPath {
    NSBezierPath(
        roundedRect: NSRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale),
        xRadius: radius * scale,
        yRadius: radius * scale
    )
}

func bitmapImage(width: Int, height: Int, draw: () -> Void) -> NSImage {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: CGFloat(width), height: CGFloat(height))

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw()
    NSGraphicsContext.current?.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    let image = NSImage(size: rep.size)
    image.addRepresentation(rep)
    return image
}

func savePNG(_ image: NSImage, to url: URL) throws {
    guard let rep = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
          let data = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "ChumenStatusBarIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render PNG"])
    }
    try data.write(to: url)
}

@discardableResult
func drawTile(scale: CGFloat) -> NSBezierPath {
    let tile = roundedRect(1.0, 1.0, 16.0, 16.0, 3.8, scale: scale)
    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    NSGradient(colors: [
        color(217, 249, 255),
        color(91, 205, 244),
        color(45, 123, 221)
    ])?.draw(in: tile.bounds, angle: -35)
    color(255, 255, 255, 0.26).setFill()
    NSBezierPath(ovalIn: NSRect(x: -2.2 * scale, y: 9.2 * scale, width: 10.2 * scale, height: 5.0 * scale)).fill()
    color(255, 255, 255, 0.16).setFill()
    NSBezierPath(ovalIn: NSRect(x: 9.7 * scale, y: 2.5 * scale, width: 8.8 * scale, height: 4.8 * scale)).fill()
    NSGraphicsContext.restoreGraphicsState()
    return tile
}

func drawClosedDoor(scale: CGFloat) {
    let tile = drawTile(scale: scale)

    let frame = roundedRect(3.4, 2.0, 10.2, 14.0, 2.3, scale: scale)
    color(248, 253, 255).setFill()
    frame.fill()
    color(56, 130, 180, 0.24).setStroke()
    frame.lineWidth = 0.75 * scale
    frame.stroke()

    let opening = roundedRect(5.0, 3.9, 5.8, 10.5, 1.3, scale: scale)
    NSGraphicsContext.saveGraphicsState()
    opening.addClip()
    NSGradient(colors: [
        color(255, 246, 197),
        color(89, 218, 238),
        color(40, 123, 222)
    ])?.draw(in: opening.bounds, angle: 90)
    color(255, 221, 90, 0.95).setFill()
    NSBezierPath(ovalIn: NSRect(x: 8.3 * scale, y: 10.8 * scale, width: 2.0 * scale, height: 2.0 * scale)).fill()
    NSGraphicsContext.restoreGraphicsState()

    let door = roundedRect(5.3, 3.45, 7.9, 11.8, 1.25, scale: scale)
    NSGradient(colors: [
        color(253, 255, 255),
        color(229, 247, 253)
    ])?.draw(in: door, angle: -10)
    color(74, 150, 192, 0.42).setStroke()
    door.lineWidth = 0.75 * scale
    door.stroke()

    color(255, 255, 255, 0.44).setStroke()
    let highlight = NSBezierPath()
    highlight.move(to: NSPoint(x: 6.5 * scale, y: 4.8 * scale))
    highlight.line(to: NSPoint(x: 6.5 * scale, y: 13.7 * scale))
    highlight.lineWidth = 0.55 * scale
    highlight.lineCapStyle = .round
    highlight.stroke()

    color(48, 143, 190, 0.62).setFill()
    NSBezierPath(ovalIn: NSRect(x: 11.0 * scale, y: 8.2 * scale, width: 1.15 * scale, height: 1.15 * scale)).fill()

    let threshold = NSBezierPath()
    threshold.move(to: NSPoint(x: 2.5 * scale, y: 3.6 * scale))
    threshold.curve(
        to: NSPoint(x: 7.0 * scale, y: 5.0 * scale),
        controlPoint1: NSPoint(x: 3.7 * scale, y: 3.7 * scale),
        controlPoint2: NSPoint(x: 5.5 * scale, y: 4.2 * scale)
    )
    color(255, 255, 255, 0.78).setStroke()
    threshold.lineWidth = 1.0 * scale
    threshold.lineCapStyle = .round
    threshold.stroke()
    color(13, 181, 211, 0.82).setStroke()
    threshold.lineWidth = 0.55 * scale
    threshold.stroke()

    color(255, 255, 255, 0.42).setStroke()
    tile.lineWidth = 0.45 * scale
    tile.stroke()
}

func drawHalfOpenDoor(scale: CGFloat) {
    let tile = drawTile(scale: scale)

    let portalFrame = roundedRect(3.4, 2.0, 10.2, 14.0, 2.3, scale: scale)
    color(248, 253, 255).setFill()
    portalFrame.fill()
    color(56, 130, 180, 0.24).setStroke()
    portalFrame.lineWidth = 0.75 * scale
    portalFrame.stroke()

    let opening = roundedRect(5.0, 3.9, 5.8, 10.5, 1.3, scale: scale)
    NSGraphicsContext.saveGraphicsState()
    opening.addClip()
    NSGradient(colors: [
        color(255, 246, 197),
        color(89, 218, 238),
        color(40, 123, 222)
    ])?.draw(in: opening, angle: 90)
    color(255, 221, 90, 0.95).setFill()
    NSBezierPath(ovalIn: NSRect(x: 8.3 * scale, y: 10.8 * scale, width: 2.0 * scale, height: 2.0 * scale)).fill()
    NSGraphicsContext.restoreGraphicsState()

    let door = NSBezierPath()
    door.move(to: NSPoint(x: 7.8 * scale, y: 3.4 * scale))
    door.line(to: NSPoint(x: 14.0 * scale, y: 2.6 * scale))
    door.line(to: NSPoint(x: 14.0 * scale, y: 15.1 * scale))
    door.line(to: NSPoint(x: 7.8 * scale, y: 14.4 * scale))
    door.close()
    color(242, 252, 255, 0.98).setFill()
    door.fill()
    color(75, 151, 193, 0.42).setStroke()
    door.lineWidth = 0.75 * scale
    door.lineJoinStyle = .round
    door.stroke()

    color(70, 157, 199, 0.76).setFill()
    NSBezierPath(ovalIn: NSRect(x: 11.3 * scale, y: 8.0 * scale, width: 1.15 * scale, height: 1.15 * scale)).fill()

    let path = NSBezierPath()
    path.move(to: NSPoint(x: 2.3 * scale, y: 4.1 * scale))
    path.curve(
        to: NSPoint(x: 8.2 * scale, y: 7.0 * scale),
        controlPoint1: NSPoint(x: 4.1 * scale, y: 4.4 * scale),
        controlPoint2: NSPoint(x: 6.5 * scale, y: 5.7 * scale)
    )
    color(255, 255, 255, 0.86).setStroke()
    path.lineWidth = 1.8 * scale
    path.lineCapStyle = .round
    path.stroke()
    color(13, 181, 211, 0.88).setStroke()
    path.lineWidth = 0.85 * scale
    path.stroke()

    color(255, 255, 255, 0.42).setStroke()
    tile.lineWidth = 0.45 * scale
    tile.stroke()
}

func drawOpenDoor(scale: CGFloat, includeDoorPanel: Bool = true) {
    let tile = drawTile(scale: scale)

    let portalFrame = roundedRect(3.4, 2.0, 10.2, 14.0, 2.3, scale: scale)
    color(248, 253, 255).setFill()
    portalFrame.fill()
    color(56, 130, 180, 0.24).setStroke()
    portalFrame.lineWidth = 0.75 * scale
    portalFrame.stroke()

    let opening = roundedRect(5.0, 3.9, 5.8, 10.5, 1.3, scale: scale)
    NSGraphicsContext.saveGraphicsState()
    opening.addClip()
    NSGradient(colors: [
        color(255, 246, 197),
        color(89, 218, 238),
        color(40, 123, 220)
    ])?.draw(in: opening, angle: 90)
    color(255, 221, 90, 0.95).setFill()
    NSBezierPath(ovalIn: NSRect(x: 8.3 * scale, y: 10.8 * scale, width: 2.0 * scale, height: 2.0 * scale)).fill()
    NSGraphicsContext.restoreGraphicsState()

    if includeDoorPanel {
        let door = NSBezierPath()
        door.move(to: NSPoint(x: 10.6 * scale, y: 3.3 * scale))
        door.line(to: NSPoint(x: 15.9 * scale, y: 2.0 * scale))
        door.line(to: NSPoint(x: 15.9 * scale, y: 15.8 * scale))
        door.line(to: NSPoint(x: 10.6 * scale, y: 14.3 * scale))
        door.close()
        color(241, 251, 255, 0.98).setFill()
        door.fill()
        color(75, 151, 193, 0.42).setStroke()
        door.lineWidth = 0.75 * scale
        door.lineJoinStyle = .round
        door.stroke()

        color(70, 157, 199, 0.80).setFill()
        NSBezierPath(ovalIn: NSRect(x: 13.0 * scale, y: 8.0 * scale, width: 1.25 * scale, height: 1.25 * scale)).fill()
    }

    let path = NSBezierPath()
    path.move(to: NSPoint(x: 2.1 * scale, y: 4.1 * scale))
    path.curve(
        to: NSPoint(x: 10.9 * scale, y: 8.9 * scale),
        controlPoint1: NSPoint(x: 4.9 * scale, y: 4.7 * scale),
        controlPoint2: NSPoint(x: 8.3 * scale, y: 7.1 * scale)
    )
    color(255, 255, 255, 0.95).setStroke()
    path.lineWidth = 2.2 * scale
    path.lineCapStyle = .round
    path.stroke()
    color(13, 181, 211).setStroke()
    path.lineWidth = 1.15 * scale
    path.stroke()

    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 11.5 * scale, y: 9.2 * scale))
    arrow.line(to: NSPoint(x: 9.3 * scale, y: 9.0 * scale))
    arrow.line(to: NSPoint(x: 10.5 * scale, y: 7.4 * scale))
    arrow.close()
    color(13, 181, 211).setFill()
    arrow.fill()

    color(255, 255, 255, 0.42).setStroke()
    tile.lineWidth = 0.45 * scale
    tile.stroke()
}

func makeDoorImage(state: StatusBarPreviewState, size: Int = 54) -> NSImage {
    let scale = CGFloat(size) / 18
    return bitmapImage(width: size, height: size) {
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
        switch state {
        case .closed:
            drawClosedDoor(scale: scale)
        case .proxy:
            drawHalfOpenDoor(scale: scale)
        case .open:
            drawOpenDoor(scale: scale)
        }
    }
}

func makeOpenDoorWithPanelImage(size: Int = 54) -> NSImage {
    let scale = CGFloat(size) / 18
    return bitmapImage(width: size, height: size) {
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
        drawOpenDoor(scale: scale, includeDoorPanel: true)
    }
}

func makeOpenDoorwayImage(size: Int = 54) -> NSImage {
    let scale = CGFloat(size) / 18
    return bitmapImage(width: size, height: size) {
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
        drawOpenDoor(scale: scale, includeDoorPanel: false)
    }
}

enum StatusBarPreviewState {
    case closed
    case proxy
    case open
}

func makePreview(closed: NSImage, proxy: NSImage, open: NSImage) -> NSImage {
    bitmapImage(width: 420, height: 104) {
        color(136, 124, 190).setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 22, width: 420, height: 58), xRadius: 18, yRadius: 18).fill()
        closed.draw(in: NSRect(x: 34, y: 42, width: 18, height: 18))
        proxy.draw(in: NSRect(x: 74, y: 42, width: 18, height: 18))
        open.draw(in: NSRect(x: 114, y: 42, width: 18, height: 18))
        closed.draw(in: NSRect(x: 168, y: 16, width: 54, height: 54))
        proxy.draw(in: NSRect(x: 238, y: 16, width: 54, height: 54))
        open.draw(in: NSRect(x: 308, y: 16, width: 54, height: 54))
    }
}

func makeDoorOpeningOptionsPreview(closed: NSImage, proxy: NSImage, open: NSImage, openDoorway: NSImage) -> NSImage {
    return bitmapImage(width: 560, height: 112) {
        color(136, 124, 190).setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 24, width: 560, height: 64), xRadius: 18, yRadius: 18).fill()
        closed.draw(in: NSRect(x: 34, y: 47, width: 18, height: 18))
        proxy.draw(in: NSRect(x: 74, y: 47, width: 18, height: 18))
        open.draw(in: NSRect(x: 114, y: 47, width: 18, height: 18))
        openDoorway.draw(in: NSRect(x: 154, y: 47, width: 18, height: 18))
        closed.draw(in: NSRect(x: 200, y: 16, width: 54, height: 54))
        proxy.draw(in: NSRect(x: 270, y: 16, width: 54, height: 54))
        open.draw(in: NSRect(x: 340, y: 16, width: 54, height: 54))
        openDoorway.draw(in: NSRect(x: 410, y: 16, width: 54, height: 54))
    }
}

do {
    try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
    let closed = makeDoorImage(state: .closed)
    let proxy = makeDoorImage(state: .proxy)
    let open = makeDoorImage(state: .open)
    let openWithDoor = makeOpenDoorWithPanelImage()
    let openDoorway = makeOpenDoorwayImage()
    try savePNG(closed, to: closedURL)
    try savePNG(proxy, to: proxyURL)
    try savePNG(open, to: openURL)
    try savePNG(openWithDoor, to: openWithDoorURL)
    try savePNG(openDoorway, to: openDoorwayURL)
    try savePNG(makePreview(closed: closed, proxy: proxy, open: open), to: previewURL)
    let openingOptions = makeDoorOpeningOptionsPreview(closed: closed, proxy: proxy, open: open, openDoorway: openDoorway)
    try savePNG(openingOptions, to: colorOptionsURL)
    try savePNG(openingOptions, to: openingOptionsURL)
} catch {
    FileHandle.standardError.write(Data("generate_status_bar_icons failed: \(error)\n".utf8))
    exit(1)
}
