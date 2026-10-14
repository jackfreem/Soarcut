// Builds Soarcut icons from the generator's symbol-on-white image (right half of the source).
// Usage: mkicon <source.png> <outdir>
import AppKit

let src = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))!
let out = CommandLine.arguments[2]
let W = src.pixelsWide, H = src.pixelsHigh

// 1. Find the symbol's bounding box in the right half (anything clearly not white).
var minX = W, minY = H, maxX = 0, maxY = 0
for y in 0..<H { for x in (W/2 + 110)..<W {
    let c = src.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
    if min(c.redComponent, c.greenComponent, c.blueComponent) < 0.9 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
}}
let pad = 6; minX -= pad; minY -= pad; maxX += pad; maxY += pad
let cw = maxX - minX + 1, ch = maxY - minY + 1

// 2. "Color to alpha" against white: recovers clean anti-aliased edges, white pivot hole becomes transparent.
let sym = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: cw, pixelsHigh: ch, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
for y in 0..<ch { for x in 0..<cw {
    let c = src.colorAt(x: x + minX, y: y + minY)!.usingColorSpace(.deviceRGB)!
    let r = c.redComponent, g = c.greenComponent, b = c.blueComponent
    var a = min(1, max(1 - r, 1 - g, 1 - b) * 3)  // solid inside, soft only at the anti-aliased edge
    if a < 0.04 { a = 0 }
    let f = { (v: CGFloat) in a == 0 ? 0 : min(1, max(0, (v - (1 - a)) / a)) }
    sym.setColor(NSColor(deviceRed: f(r), green: f(g), blue: f(b), alpha: a), atX: x, y: y)
}}
let symImg = NSImage(size: NSSize(width: cw, height: ch)); symImg.addRepresentation(sym)

func render(_ size: Int, _ draw: (CGFloat) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current!.imageInterpolation = .high
    draw(CGFloat(size)); NSGraphicsContext.restoreGraphicsState(); return rep
}
func save(_ rep: NSBitmapImageRep, _ name: String) { try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name)")) }
func fit(_ box: NSRect) -> NSRect { // aspect-fit the symbol into box
    let s = min(box.width / CGFloat(cw), box.height / CGFloat(ch)); let w = CGFloat(cw) * s, h = CGFloat(ch) * s
    return NSRect(x: box.midX - w/2, y: box.midY - h/2, width: w, height: h)
}

// 3. App icon on Apple's macOS grid: 824/1024 rounded rect, ~185 corner radius, indigo -> cyan.
let master = render(1024) { s in
    let k = s / 1024, body = NSRect(x: 100*k, y: 100*k, width: 824*k, height: 824*k)
    let path = NSBezierPath(roundedRect: body, xRadius: 185*k, yRadius: 185*k)
    let sh = NSShadow(); sh.shadowColor = NSColor(white: 0, alpha: 0.30); sh.shadowOffset = NSSize(width: 0, height: -10*k); sh.shadowBlurRadius = 24*k
    NSGraphicsContext.saveGraphicsState(); sh.set(); NSColor(deviceRed: 0.12, green: 0.2, blue: 0.85, alpha: 1).setFill(); path.fill(); NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [NSColor(deviceRed: 0.13, green: 0.16, blue: 0.70, alpha: 1),   // deep indigo, bottom-left
                        NSColor(deviceRed: 0.10, green: 0.42, blue: 0.95, alpha: 1),
                        NSColor(deviceRed: 0.30, green: 0.85, blue: 1.00, alpha: 1)])!  // cyan, top-right
        .draw(in: path, angle: 50)
    NSGradient(colors: [NSColor(white: 1, alpha: 0.22), NSColor(white: 1, alpha: 0)])!  // soft top gloss
        .draw(in: path, relativeCenterPosition: NSPoint(x: 0, y: 1))  // radial shine from the top, clipped to the icon shape
    let ss = NSShadow(); ss.shadowColor = NSColor(deviceRed: 0.05, green: 0.05, blue: 0.3, alpha: 0.35); ss.shadowOffset = NSSize(width: 0, height: -8*k); ss.shadowBlurRadius = 18*k
    NSGraphicsContext.saveGraphicsState(); ss.set()
    symImg.draw(in: fit(body.insetBy(dx: 824*k*0.14, dy: 824*k*0.14)).offsetBy(dx: 0, dy: 10*k)); NSGraphicsContext.restoreGraphicsState()
}
save(master, "Soarcut-1024.png")
let masterImg = NSImage(size: NSSize(width: 1024, height: 1024)); masterImg.addRepresentation(master)

// 4. .iconset for iconutil
let iconset = "\(out)/Soarcut.iconset"; try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] { for scale in [1, 2] {
    let px = base * scale
    save(render(px) { s in masterImg.draw(in: NSRect(x: 0, y: 0, width: s, height: s)) }, "Soarcut.iconset/icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png")
}}

// 5. Menu bar icons (16 and 32 px, matching Flycut's color / black / x-out set).
func tinted(_ color: NSColor) -> NSImage {
    let img = NSImage(size: symImg.size); img.lockFocus()
    symImg.draw(at: .zero, from: .zero, operation: .copy, fraction: 1); color.set()
    NSRect(origin: .zero, size: symImg.size).fill(using: .sourceAtop); img.unlockFocus(); return img
}
let black = tinted(.black)
for px in [16, 32] {
    let box = { (s: CGFloat) in NSRect(x: 0, y: 0, width: s, height: s).insetBy(dx: s * 0.02, dy: s * 0.02) }
    save(render(px) { s in symImg.draw(in: fit(box(s))) }, "soarcut.\(px).png")
    save(render(px) { s in black.draw(in: fit(box(s))) }, "soarcut.black.\(px).png")
    save(render(px) { s in
        black.draw(in: fit(box(s)), from: .zero, operation: .sourceOver, fraction: 0.35)
        let p = NSBezierPath(); p.move(to: NSPoint(x: s*0.12, y: s*0.12)); p.line(to: NSPoint(x: s*0.88, y: s*0.88))
        p.lineWidth = max(1.5, s/10); p.lineCapStyle = .round; NSColor.black.setStroke(); p.stroke()
    }, "soarcut.xout.\(px).png")
}
print("symbol box \(cw)x\(ch)")
