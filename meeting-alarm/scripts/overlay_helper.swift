import AppKit
import Foundation

NSApplication.shared.setActivationPolicy(.accessory)

let triggerFile = "\(NSHomeDirectory())/.claude/scripts/meeting_alarm/overlay_trigger"
let depth: CGFloat = 220
let strips = 12

func showOverlay() {
    guard let screen = NSScreen.main else { return }
    let frame = screen.frame
    let W = frame.width, H = frame.height

    let panel = NSPanel(
        contentRect: frame,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    panel.isOpaque = false
    panel.hasShadow = false
    panel.ignoresMouseEvents = true
    panel.level = .screenSaver
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    panel.backgroundColor = .clear

    guard let view = panel.contentView else { return }
    view.wantsLayer = true
    guard let root = view.layer else { return }

    let sw = depth / CGFloat(strips)
    for i in 0..<strips {
        let alpha = CGFloat(0.82 * pow(1.0 - Double(i) / Double(strips), 1.5))
        let color = NSColor(red: 1, green: 0, blue: 0, alpha: alpha).cgColor
        let fi = CGFloat(i)

        func addLayer(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
            let l = CALayer(); l.frame = CGRect(x: x, y: y, width: w, height: h)
            l.backgroundColor = color; root.addSublayer(l)
        }
        addLayer(0,           fi*sw,       W,  sw)   // bottom
        addLayer(0,           H-(fi+1)*sw, W,  sw)   // top
        addLayer(fi*sw,       0,           sw, H)    // left
        addLayer(W-(fi+1)*sw, 0,           sw, H)    // right
    }

    panel.orderFrontRegardless()

    var tick = 0
    Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { timer in
        let opacity: Float = tick % 2 == 0 ? 1.0 : 0.0
        root.sublayers?.forEach { $0.opacity = opacity }
        tick += 1
        if tick >= 67 { timer.invalidate(); panel.orderOut(nil) }
    }
}

// Poll for trigger file every second
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    if FileManager.default.fileExists(atPath: triggerFile) {
        try? FileManager.default.removeItem(atPath: triggerFile)
        showOverlay()
    }
}

NSApp.run()
