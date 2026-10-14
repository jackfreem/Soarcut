// 1280x640 GitHub social preview: icon + name + tagline on the icon's gradient.
import AppKit
let icon = NSImage(contentsOfFile: CommandLine.arguments[1])!
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1280, pixelsHigh: 640, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGradient(colors: [NSColor(deviceRed: 0.07, green: 0.09, blue: 0.35, alpha: 1), NSColor(deviceRed: 0.10, green: 0.30, blue: 0.80, alpha: 1)])!
    .draw(in: NSRect(x: 0, y: 0, width: 1280, height: 640), angle: 30)
icon.draw(in: NSRect(x: 90, y: 150, width: 340, height: 340))
let title: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 104, weight: .bold), .foregroundColor: NSColor.white]
let sub: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 34, weight: .medium), .foregroundColor: NSColor(white: 1, alpha: 0.85)]
let small: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 28, weight: .regular), .foregroundColor: NSColor(deviceRed: 1, green: 0.75, blue: 0.45, alpha: 1)]
("Soarcut" as NSString).draw(at: NSPoint(x: 480, y: 330), withAttributes: title)
("Clipboard manager for macOS developers" as NSString).draw(at: NSPoint(x: 486, y: 270), withAttributes: sub)
("Jumpcut → Flycut → Soarcut" as NSString).draw(at: NSPoint(x: 486, y: 215), withAttributes: small)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
