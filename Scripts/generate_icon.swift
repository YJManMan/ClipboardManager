#!/usr/bin/env swift
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count == 2 else {
    print("Usage: generate_icon.swift <output_icns_path>")
    exit(1)
}

let outputPath = args[1]
let workDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")

try? FileManager.default.removeItem(at: workDir)
try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

let config: [(CGFloat, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

let iconColor = NSColor(red: 0.18, green: 0.55, blue: 0.85, alpha: 1.0)

for (size, name) in config {
    renderIcon(size: size, color: iconColor, saveTo: workDir.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", "-o", outputPath, workDir.path]
try process.run()
process.waitUntilExit()

try? FileManager.default.removeItem(at: workDir)

if FileManager.default.fileExists(atPath: outputPath) {
    print("Icon created: \(outputPath)")
} else {
    print("Failed to create icon")
    exit(1)
}

func renderIcon(size: CGFloat, color: NSColor, saveTo url: URL) {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let image = NSImage(size: rect.size, flipped: false) { drawRect in
        let bgPath = NSBezierPath(
            roundedRect: drawRect,
            xRadius: size * 0.225,
            yRadius: size * 0.225
        )
        color.setFill()
        bgPath.fill()

        let symbolSize = size * 0.52
        if let symbol = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: nil
        ) {
            let cfg = NSImage.SymbolConfiguration(
                pointSize: symbolSize,
                weight: .bold
            )
            if let tinted = symbol.withSymbolConfiguration(cfg) {
                let imgSize = tinted.size
                let imgRect = NSRect(
                    x: (size - imgSize.width) / 2,
                    y: (size - imgSize.height) / 2,
                    width: imgSize.width,
                    height: imgSize.height
                )
                NSColor.white.setFill()
                tinted.draw(in: imgRect)
            }
        }
        return true
    }

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("Warning: failed to render \(size)x\(size)")
        return
    }

    try? png.write(to: url)
}
