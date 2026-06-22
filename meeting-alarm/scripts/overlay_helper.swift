import AppKit
import Foundation

let scriptsDir = "\(NSHomeDirectory())/.claude/scripts/meeting_alarm"
let triggerFile  = "\(scriptsDir)/overlay_trigger"
let disabledFile = "\(scriptsDir)/disabled"
let depth: CGFloat = 220
let strips = 14

// ── Overlay ───────────────────────────────────────────────────────────────────

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
        addLayer(0,           fi*sw,       W,  sw)
        addLayer(0,           H-(fi+1)*sw, W,  sw)
        addLayer(fi*sw,       0,           sw, H)
        addLayer(W-(fi+1)*sw, 0,           sw, H)
    }

    panel.orderFrontRegardless()

    var tick = 0
    Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { timer in
        root.sublayers?.forEach { $0.opacity = tick % 2 == 0 ? 1.0 : 0.0 }
        tick += 1
        if tick >= 67 { timer.invalidate(); panel.orderOut(nil) }
    }
}

// ── Menu bar ──────────────────────────────────────────────────────────────────

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    var isEnabled: Bool {
        get { !FileManager.default.fileExists(atPath: disabledFile) }
        set {
            if newValue {
                try? FileManager.default.removeItem(atPath: disabledFile)
            } else {
                FileManager.default.createFile(atPath: disabledFile, contents: nil)
            }
            rebuildMenu()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        rebuildMenu()

        // Poll for trigger file every second
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if FileManager.default.fileExists(atPath: triggerFile) {
                try? FileManager.default.removeItem(atPath: triggerFile)
                showOverlay()
            }
        }
    }

    func rebuildMenu() {
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: isEnabled ? "bell.fill" : "bell.slash.fill",
                                 accessibilityDescription: "Meeting Alarm") {
                img.isTemplate = true
                button.image = img
                button.title = ""
            } else {
                button.image = nil
                button.title = isEnabled ? "🔔" : "🔕"
            }
        }

        let menu = NSMenu()

        let label = NSMenuItem(title: "Meeting Alarm: \(isEnabled ? "ON ✓" : "OFF")", action: nil, keyEquivalent: "")
        label.isEnabled = false
        menu.addItem(label)

        menu.addItem(.separator())

        let toggle = NSMenuItem(
            title: isEnabled ? "Pause Alarms" : "Resume Alarms",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        let test = NSMenuItem(title: "Test Alarm Now", action: #selector(runTest), keyEquivalent: "")
        test.target = self
        menu.addItem(test)

        statusItem.menu = menu
    }

    @objc func toggleEnabled() {
        isEnabled = !isEnabled
    }

    @objc func runTest() {
        showOverlay()
        DispatchQueue.global().async {
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", "display notification \"Test — alarm is working!\" with title \"Meeting Alert\" sound name \"Ping\""]
            try? task.run(); task.waitUntilExit()

            let spotify = Process()
            spotify.launchPath = "/usr/bin/osascript"
            // Read Spotify command from daemon.sh so it plays the configured track
            let daemonPath = "\(scriptsDir)/daemon.sh"
            var spotifyArgs = ["-e", "tell application \"Spotify\" to play"]
            if let src = try? String(contentsOfFile: daemonPath, encoding: .utf8),
               let range = src.range(of: #"spotify:track:[A-Za-z0-9]+"#, options: .regularExpression) {
                let uri = String(src[range])
                spotifyArgs = ["-e", "tell application \"Spotify\" to play track \"\(uri)\""]
            }
            spotify.arguments = spotifyArgs
            try? spotify.run(); spotify.waitUntilExit()
        }
    }
}

// ── Main ──────────────────────────────────────────────────────────────────────

// Keep delegate alive — NSApplication holds only a weak reference
var _delegate: AppDelegate?

NSApplication.shared.setActivationPolicy(.accessory)
_delegate = AppDelegate()
NSApplication.shared.delegate = _delegate
NSApplication.shared.run()
