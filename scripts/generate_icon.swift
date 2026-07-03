#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let assets = root.appendingPathComponent("Packaging/Assets", isDirectory: true)
let iconset = assets.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let pngURL = assets.appendingPathComponent("AppIcon.png")
let icnsURL = assets.appendingPathComponent("AppIcon.icns")

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, scale: CGFloat) -> NSRect {
    NSRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
}

func roundedRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ radius: CGFloat, _ scale: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect(x, y, width, height, scale: scale), xRadius: radius * scale, yRadius: radius * scale)
}

func polygon(_ points: [(CGFloat, CGFloat)], scale: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    guard let first = points.first else { return path }
    path.move(to: NSPoint(x: first.0 * scale, y: first.1 * scale))
    for point in points.dropFirst() {
        path.line(to: NSPoint(x: point.0 * scale, y: point.1 * scale))
    }
    path.close()
    return path
}

func strokePath(_ path: NSBezierPath, color strokeColor: NSColor, width: CGFloat, scale: CGFloat) {
    strokeColor.setStroke()
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.lineWidth = width * scale
    path.stroke()
}

func savePNG(_ image: NSImage, to url: URL) throws {
    guard let rep = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
          let data = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "ChumenIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render PNG"])
    }
    try data.write(to: url, options: .atomic)
}

func bitmapImage(size: Int, draw: () -> Void) -> NSImage {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw()
    NSGraphicsContext.current?.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    let image = NSImage(size: NSSize(width: size, height: size))
    image.addRepresentation(rep)
    return image
}

func resized(_ image: NSImage, size target: Int) -> NSImage {
    bitmapImage(size: target) {
        image.draw(in: NSRect(x: 0, y: 0, width: target, height: target), from: .zero, operation: .copy, fraction: 1)
    }
}

func drawSparkle(center: NSPoint, radius: CGFloat) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: center.x, y: center.y + radius))
    path.line(to: NSPoint(x: center.x + radius * 0.22, y: center.y + radius * 0.22))
    path.line(to: NSPoint(x: center.x + radius, y: center.y))
    path.line(to: NSPoint(x: center.x + radius * 0.22, y: center.y - radius * 0.22))
    path.line(to: NSPoint(x: center.x, y: center.y - radius))
    path.line(to: NSPoint(x: center.x - radius * 0.22, y: center.y - radius * 0.22))
    path.line(to: NSPoint(x: center.x - radius, y: center.y))
    path.line(to: NSPoint(x: center.x - radius * 0.22, y: center.y + radius * 0.22))
    path.close()
    color(255, 255, 255, 0.88).setFill()
    path.fill()
}

func drawDoorGlyph(scale: CGFloat) {
    drawSparkle(center: NSPoint(x: 796 * scale, y: 768 * scale), radius: 24 * scale)

    let portalShadow = roundedRect(206, 112, 576, 800, 112, scale)
    NSGraphicsContext.saveGraphicsState()
    let portalDropShadow = NSShadow()
    portalDropShadow.shadowColor = color(20, 54, 88, 0.26)
    portalDropShadow.shadowBlurRadius = 24 * scale
    portalDropShadow.shadowOffset = NSSize(width: 0, height: -12 * scale)
    portalDropShadow.set()
    color(255, 255, 255, 0.96).setFill()
    portalShadow.fill()
    NSGraphicsContext.restoreGraphicsState()

    let opening = roundedRect(300, 220, 320, 586, 66, scale)
    NSGraphicsContext.saveGraphicsState()
    opening.addClip()
    NSGradient(
        colors: [
            color(255, 248, 218),
            color(105, 224, 255),
            color(18, 104, 218)
        ]
    )?.draw(in: opening, angle: 90)
    color(255, 219, 88, 0.94).setFill()
    NSBezierPath(ovalIn: rect(476, 608, 92, 92, scale: scale)).fill()
    color(255, 255, 255, 0.82).setStroke()
    let innerHorizon = NSBezierPath()
    innerHorizon.move(to: NSPoint(x: 344 * scale, y: 520 * scale))
    innerHorizon.curve(
        to: NSPoint(x: 590 * scale, y: 532 * scale),
        controlPoint1: NSPoint(x: 420 * scale, y: 562 * scale),
        controlPoint2: NSPoint(x: 526 * scale, y: 560 * scale)
    )
    innerHorizon.lineWidth = 10 * scale
    innerHorizon.lineCapStyle = .round
    innerHorizon.stroke()
    NSGraphicsContext.restoreGraphicsState()

    color(255, 255, 255, 0.98).setFill()
    let frameOuter = NSBezierPath()
    frameOuter.append(roundedRect(198, 112, 590, 806, 118, scale))
    frameOuter.append(opening.reversed)
    frameOuter.windingRule = .evenOdd
    frameOuter.fill()

    color(59, 112, 153, 0.18).setStroke()
    let frameStroke = roundedRect(208, 122, 570, 786, 110, scale)
    frameStroke.lineWidth = 3 * scale
    frameStroke.stroke()

    let door = polygon(
        [
            (596, 218),
            (806, 134),
            (806, 858),
            (596, 774)
        ],
        scale: scale
    )
    NSGraphicsContext.saveGraphicsState()
    let doorShadow = NSShadow()
    doorShadow.shadowColor = color(20, 52, 80, 0.24)
    doorShadow.shadowBlurRadius = 16 * scale
    doorShadow.shadowOffset = NSSize(width: 0, height: -8 * scale)
    doorShadow.set()
    color(247, 253, 255, 0.98).setFill()
    door.fill()
    NSGraphicsContext.restoreGraphicsState()
    color(83, 151, 192, 0.34).setStroke()
    door.lineWidth = 5 * scale
    door.stroke()

    color(42, 132, 178, 0.62).setFill()
    NSBezierPath(ovalIn: rect(692, 490, 34, 34, scale: scale)).fill()

    let pathBase = NSBezierPath()
    pathBase.move(to: NSPoint(x: 162 * scale, y: 238 * scale))
    pathBase.curve(
        to: NSPoint(x: 430 * scale, y: 382 * scale),
        controlPoint1: NSPoint(x: 266 * scale, y: 260 * scale),
        controlPoint2: NSPoint(x: 350 * scale, y: 326 * scale)
    )
    pathBase.curve(
        to: NSPoint(x: 600 * scale, y: 534 * scale),
        controlPoint1: NSPoint(x: 510 * scale, y: 434 * scale),
        controlPoint2: NSPoint(x: 548 * scale, y: 474 * scale)
    )
    strokePath(pathBase, color: color(255, 255, 255, 0.98), width: 58, scale: scale)
    strokePath(pathBase, color: color(19, 181, 211, 1), width: 26, scale: scale)

    let arrow = polygon(
        [
            (604, 538),
            (538, 512),
            (580, 474)
        ],
        scale: scale
    )
    color(19, 181, 211, 1).setFill()
    arrow.fill()
}

func makeIcon(size: Int = 1024) -> NSImage {
    let scale = CGFloat(size) / 1024
    return bitmapImage(size: size) {
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let tile = roundedRect(8, 8, 1008, 1008, 232, scale)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(5, 28, 54, 0.28)
    shadow.shadowBlurRadius = 26 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -12 * scale)
    shadow.set()
    color(66, 148, 211).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    NSGradient(
        colors: [
            color(222, 249, 255),
            color(109, 208, 255),
            color(37, 112, 220)
        ]
    )?.draw(in: tile, angle: -38)

    color(255, 255, 255, 0.28).setFill()
    NSBezierPath(ovalIn: rect(-150, 612, 780, 420, scale: scale)).fill()
    color(255, 255, 255, 0.18).setFill()
    NSBezierPath(ovalIn: rect(560, 118, 560, 310, scale: scale)).fill()

    let horizon = NSBezierPath()
    horizon.move(to: NSPoint(x: 172 * scale, y: 525 * scale))
    horizon.curve(
        to: NSPoint(x: 852 * scale, y: 560 * scale),
        controlPoint1: NSPoint(x: 360 * scale, y: 605 * scale),
        controlPoint2: NSPoint(x: 640 * scale, y: 610 * scale)
    )
    strokePath(horizon, color: color(255, 255, 255, 0.42), width: 12, scale: scale)
    NSGraphicsContext.restoreGraphicsState()

    drawDoorGlyph(scale: scale)

    color(255, 255, 255, 0.56).setStroke()
    tile.lineWidth = 4 * scale
    tile.stroke()

    }
}

func main() throws {
    try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

    let icon = makeIcon()
    try savePNG(icon, to: pngURL)

    let sizes: [(String, Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    for (name, size) in sizes {
        try savePNG(resized(icon, size: size), to: iconset.appendingPathComponent(name))
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", "-o", icnsURL.path, iconset.path]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "ChumenIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
    }
}

do {
    try main()
} catch {
    FileHandle.standardError.write(Data("generate_icon failed: \(error)\n".utf8))
    exit(1)
}
