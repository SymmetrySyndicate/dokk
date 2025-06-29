import Cocoa

enum DockPosition {
    case bottom
    case left
    case right
}

enum DockColor {
    case black
    case clear
}

class DockWindow: NSWindow {
    private var currentPosition: DockPosition = .bottom
    private var currentColor: DockColor = .black

    private var dockView: NSView!

    override init(contentRect: NSRect,
                  styleMask style: NSWindow.StyleMask,
                  backing backingStoreType: NSWindow.BackingStoreType,
                  defer flag: Bool) {
        super.init(contentRect: contentRect,
                   styleMask: style,
                   backing: backingStoreType,
                   defer: flag)
        setupWindow()
    }

    private func setupWindow() {
        self.styleMask = [.borderless]
        self.level = .floating
        self.hidesOnDeactivate = false
        self.isMovable = false
        self.isOpaque = false
        self.hasShadow = false
        self.backgroundColor = .clear
        
        setDockPosition(.bottom)
        setupDockView()
    }

    func setDockPosition(_ position: DockPosition) {
        currentPosition = position
        guard let screenFrame = NSScreen.main?.frame else { return }

        let dockWidth: CGFloat = 400
        let dockHeight: CGFloat = 80
        var newFrame = NSRect.zero

        switch position {
        case .bottom:
            newFrame = NSRect(
                x: (screenFrame.width - dockWidth) / 2,
                y: 5,
                width: dockWidth,
                height: dockHeight
            )
        case .left:
            newFrame = NSRect(
                x: 5,
                y: (screenFrame.height - dockWidth) / 2,
                width: dockHeight,
                height: dockWidth
            )
        case .right:
            newFrame = NSRect(
                x: screenFrame.width - dockHeight - 5,
                y: (screenFrame.height - dockWidth) / 2,
                width: dockHeight,
                height: dockWidth
            )
        }

        self.setFrame(newFrame, display: true, animate: true)
    }
    
    func setDockColor(_ color: DockColor) {
        currentColor = color
        switch color {
        case .black:
            dockView.layer?.backgroundColor = NSColor.black.cgColor
        case .clear:
            dockView.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    private func setupDockView() {
        dockView = NSView()
        dockView.wantsLayer = true
        dockView.layer?.cornerRadius = 15
        dockView.layer?.borderWidth = 1
        dockView.layer?.borderColor = NSColor.gray.withAlphaComponent(0.5).cgColor
        
        // Initial background color
        setDockColor(.black)

        let menu = NSMenu()
        
        // ============= position =============
        let positionSubmenu = NSMenu()
        
        let bottomItem = NSMenuItem(title: "Bottom", action: #selector(changeDockPosition(_:)), keyEquivalent: "")
        bottomItem.representedObject = DockPosition.bottom
        positionSubmenu.addItem(bottomItem)
        
        let leftItem = NSMenuItem(title: "Left", action: #selector(changeDockPosition(_:)), keyEquivalent: "")
        leftItem.representedObject = DockPosition.left
        positionSubmenu.addItem(leftItem)

        let rightItem = NSMenuItem(title: "Right", action: #selector(changeDockPosition(_:)), keyEquivalent: "")
        rightItem.representedObject = DockPosition.right
        positionSubmenu.addItem(rightItem)

        let positionMenuItem = NSMenuItem(title: "Position", action: nil, keyEquivalent: "")
        menu.setSubmenu(positionSubmenu, for: positionMenuItem)
        menu.addItem(positionMenuItem)
        
        // ============= color =============
        let colorSubmenu = NSMenu()
        let blackItem = NSMenuItem(title: "Black", action: #selector(changeDockColor(_:)), keyEquivalent: "")
        blackItem.representedObject = DockColor.black
        colorSubmenu.addItem(blackItem)

        let clearItem = NSMenuItem(title: "Clear", action: #selector(changeDockColor(_:)), keyEquivalent: "")
        clearItem.representedObject = DockColor.clear
        colorSubmenu.addItem(clearItem)

        let colorMenuItem = NSMenuItem(title: "Color", action: nil, keyEquivalent: "")
        menu.setSubmenu(colorSubmenu, for: colorMenuItem)
        menu.addItem(colorMenuItem)

        dockView.menu = menu
        self.contentView = dockView
    }

    @objc private func changeDockPosition(_ sender: NSMenuItem) {
        if let newPosition = sender.representedObject as? DockPosition {
            setDockPosition(newPosition)
        }
    }
    
    @objc private func changeDockColor(_ sender: NSMenuItem) {
        if let newColor = sender.representedObject as? DockColor {
            setDockColor(newColor)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var dockWindow: DockWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        dockWindow = DockWindow(
            contentRect: NSRect.zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        dockWindow?.makeKeyAndOrderFront(nil)
        dockWindow?.orderFrontRegardless()
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
