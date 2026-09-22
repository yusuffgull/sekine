#!/usr/bin/swift
// Renders a local HTML file to a PNG at an exact pixel size using WKWebView (WebKit).
// Usage: swift html-to-png.swift <input.html> <output.png> <width> <height>
import Cocoa
import WebKit

let args = CommandLine.arguments
guard args.count == 5,
      let width = Double(args[3]), let height = Double(args[4]) else {
    print("Usage: html-to-png.swift <input.html> <output.png> <width> <height>")
    exit(1)
}
let inputPath = args[1]
let outputPath = args[2]

let app = NSApplication.shared
let frame = NSRect(x: 0, y: 0, width: width, height: height)
let config = WKWebViewConfiguration()
let webView = WKWebView(frame: frame, configuration: config)
webView.setValue(false, forKey: "drawsBackground")

class NavDelegate: NSObject, WKNavigationDelegate {
    let outputPath: String
    let width: Double
    let height: Double
    init(outputPath: String, width: Double, height: Double) {
        self.outputPath = outputPath
        self.width = width
        self.height = height
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let config = WKSnapshotConfiguration()
        config.rect = NSRect(x: 0, y: 0, width: self.width, height: self.height)
        // Give web fonts / layout a brief moment to settle before snapshotting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            webView.takeSnapshot(with: config) { image, error in
                if let error = error {
                    print("Snapshot error: \(error)")
                    exit(1)
                }
                guard let image = image,
                      let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    print("Failed to encode PNG")
                    exit(1)
                }
                do {
                    try png.write(to: URL(fileURLWithPath: self.outputPath))
                    print("OK: wrote \(self.outputPath)")
                } catch {
                    print("Write error: \(error)")
                    exit(1)
                }
                exit(0)
            }
        }
    }
}

let delegate = NavDelegate(outputPath: outputPath, width: width, height: height)
webView.navigationDelegate = delegate
webView.loadFileURL(URL(fileURLWithPath: inputPath), allowingReadAccessTo: URL(fileURLWithPath: inputPath).deletingLastPathComponent())

RunLoop.main.run(until: Date(timeIntervalSinceNow: 20))
print("Timed out")
exit(1)
