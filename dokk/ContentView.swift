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

struct DockApp {
    let name: String
    let bundleIdentifier: String
    let icon: NSImage
    let url: URL
}

class DockItemView: NSView {
    private let app: DockApp
    private let imageView: NSImageView
    private let onRemove: (DockApp) -> Void
    
    init(app: DockApp, onRemove: @escaping (DockApp) -> Void) {
        self.app = app
        self.onRemove = onRemove
        self.imageView = NSImageView()
        super.init(frame: NSRect.zero)
        
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        imageView.image = app.icon
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5)
        ])
        
        // Add click gesture
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(launchApp))
        addGestureRecognizer(clickGesture)
        
        // Add right-click menu
        let menu = NSMenu()
        let removeItem = NSMenuItem(title: "Remove from Dock", action: #selector(removeApp), keyEquivalent: "")
        removeItem.target = self
        menu.addItem(removeItem)
        self.menu = menu
        
        // Add hover effect
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    @objc private func launchApp() {
        NSWorkspace.shared.open(app.url)
    }
    
    @objc private func removeApp() {
        onRemove(app)
    }
    
    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            imageView.animator().layer?.transform = CATransform3DMakeScale(1.2, 1.2, 1.0)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            imageView.animator().layer?.transform = CATransform3DIdentity
        }
    }
}

class DockContainerView: NSView {
    private(set) var dockApps: [DockApp] = []
    private var stackView: NSStackView!
    private var dockPosition: DockPosition = .bottom
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
        
        // Register for drag and drop
        registerForDraggedTypes([.fileURL])
    }
    
    func updateOrientation(for position: DockPosition) {
        dockPosition = position
        stackView.orientation = (position == .bottom) ? .horizontal : .vertical
    }
    
    func addApp(_ app: DockApp) {
        // Check if app already exists (but be more lenient with the check)
        let exists = dockApps.contains { existingApp in
            existingApp.bundleIdentifier == app.bundleIdentifier ||
            existingApp.url.path == app.url.path
        }
        
        if exists {
            print("App already exists in dock: \(app.name)")
            return
        }
        
        print("Adding app to dock: \(app.name)")
        dockApps.append(app)
        
        let itemView = DockItemView(app: app) { [weak self] appToRemove in
            self?.removeApp(appToRemove)
        }
        
        // Set explicit size for the item view
        itemView.widthAnchor.constraint(equalToConstant: 64).isActive = true
        itemView.heightAnchor.constraint(equalToConstant: 64).isActive = true
        
        stackView.addArrangedSubview(itemView)
        
        // Update dock size
        updateDockSize()
        
        // Animate addition
        itemView.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            itemView.animator().alphaValue = 1
        }
    }
    
    private func removeApp(_ app: DockApp) {
        guard let index = dockApps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) else {
            return
        }
        
        dockApps.remove(at: index)
        let viewToRemove = stackView.arrangedSubviews[index]
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            viewToRemove.animator().alphaValue = 0
        }) {
            self.stackView.removeArrangedSubview(viewToRemove)
            viewToRemove.removeFromSuperview()
            self.updateDockSize()
        }
    }
    
    private func updateDockSize() {
        // Notify the dock window that size needs to be updated
        if let dockWindow = self.window as? DockWindow {
            dockWindow.updateDockSize(for: dockApps.count)
        }
    }
    
    // MARK: - Drag and Drop
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if canAcceptDrag(sender) {
            return .copy
        }
        return []
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if canAcceptDrag(sender) {
            return .copy
        }
        return []
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else {
            print("Could not read URLs from pasteboard")
            return false
        }
        
        print("Attempting to add \(urls.count) apps")
        var addedAny = false
        
        for url in urls {
            print("Processing URL: \(url.path)")
            if let app = createDockApp(from: url) {
                print("Successfully created DockApp: \(app.name)")
                addApp(app)
                addedAny = true
            } else {
                print("Failed to create DockApp from: \(url.path)")
            }
        }
        
        return addedAny
    }
    
    private func canAcceptDrag(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else {
            print("Could not read URLs from drag pasteboard")
            return false
        }
        
        let validApps = urls.filter { url in
            let isApp = url.pathExtension.lowercased() == "app"
            if isApp {
                print("Found valid app: \(url.lastPathComponent)")
            }
            return isApp
        }
        
        print("Found \(validApps.count) valid apps out of \(urls.count) items")
        return !validApps.isEmpty
    }
    
    private func createDockApp(from url: URL) -> DockApp? {
        print("Creating DockApp from URL: \(url.path)")
        
        // Check if it's an app bundle
        guard url.pathExtension.lowercased() == "app" else {
            print("Not an app bundle: \(url.pathExtension)")
            return nil
        }
        
        guard let bundle = Bundle(url: url) else {
            print("Could not create bundle from URL: \(url)")
            return nil
        }
        
        guard let bundleIdentifier = bundle.bundleIdentifier else {
            print("Could not get bundle identifier from: \(url)")
            return nil
        }
        
        // Try to get app name from different sources
        let appName = bundle.infoDictionary?["CFBundleDisplayName"] as? String ??
                     bundle.infoDictionary?["CFBundleName"] as? String ??
                     url.deletingPathExtension().lastPathComponent
        
        print("App name: \(appName), Bundle ID: \(bundleIdentifier)")
        
        // Get app icon
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 64, height: 64)
        
        return DockApp(
            name: appName,
            bundleIdentifier: bundleIdentifier,
            icon: icon,
            url: url
        )
    }
}

class DockWindow: NSWindow {
    private var currentPosition: DockPosition = .bottom
    private var currentColor: DockColor = .black
    private var dockView: NSView!
    private var dockContainer: DockContainerView!

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
        
        setupDockView()
        setDockPosition(.bottom)
    }

    func setDockPosition(_ position: DockPosition) {
        currentPosition = position
        updateDockSize(for: dockContainer?.dockApps.count ?? 0)
        dockContainer?.updateOrientation(for: position)
    }
    
    func updateDockSize(for appCount: Int) {
        guard let screenFrame = NSScreen.main?.frame else {
            print("Error: Could not get main screen frame")
            return
        }

        let iconSize: CGFloat = 64
        let spacing: CGFloat = 10
        let padding: CGFloat = 20
        let minSize: CGFloat = 100
        
        var newFrame = NSRect.zero
        
        switch currentPosition {
        case .bottom:
            let calculatedWidth = max(minSize, CGFloat(appCount) * iconSize + CGFloat(max(0, appCount - 1)) * spacing + padding)
            let dockWidth = min(calculatedWidth, screenFrame.width - 20)
            let dockHeight: CGFloat = iconSize + padding
            
            newFrame = NSRect(
                x: (screenFrame.width - dockWidth) / 2,
                y: 5,
                width: dockWidth,
                height: dockHeight
            )
        case .left:
            let calculatedHeight = max(minSize, CGFloat(appCount) * iconSize + CGFloat(max(0, appCount - 1)) * spacing + padding)
            let dockHeight = min(calculatedHeight, screenFrame.height - 20)
            let dockWidth: CGFloat = iconSize + padding
            
            newFrame = NSRect(
                x: 5,
                y: (screenFrame.height - dockHeight) / 2,
                width: dockWidth,
                height: dockHeight
            )
        case .right:
            let calculatedHeight = max(minSize, CGFloat(appCount) * iconSize + CGFloat(max(0, appCount - 1)) * spacing + padding)
            let dockHeight = min(calculatedHeight, screenFrame.height - 20)
            let dockWidth: CGFloat = iconSize + padding
            
            newFrame = NSRect(
                x: screenFrame.width - dockWidth - 5,
                y: (screenFrame.height - dockHeight) / 2,
                width: dockWidth,
                height: dockHeight
            )
        }

        self.setFrame(newFrame, display: true, animate: true)
    }
    
    func setDockColor(_ color: DockColor) {
        currentColor = color
        switch color {
        case .black:
            dockView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
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
        
        // Create dock container
        dockContainer = DockContainerView()
        dockContainer.translatesAutoresizingMaskIntoConstraints = false
        dockView.addSubview(dockContainer)
        
        NSLayoutConstraint.activate([
            dockContainer.topAnchor.constraint(equalTo: dockView.topAnchor),
            dockContainer.bottomAnchor.constraint(equalTo: dockView.bottomAnchor),
            dockContainer.leadingAnchor.constraint(equalTo: dockView.leadingAnchor),
            dockContainer.trailingAnchor.constraint(equalTo: dockView.trailingAnchor)
        ])
        
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
        
        // ============= clear dock =============
        menu.addItem(NSMenuItem.separator())
        let clearDockItem = NSMenuItem(title: "Clear Dock", action: #selector(clearDock), keyEquivalent: "")
        clearDockItem.target = self
        menu.addItem(clearDockItem)

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
    
    @objc private func clearDock() {
        // Remove all apps by creating a new container
        let oldContainer = dockContainer
        dockContainer = DockContainerView()
        dockContainer.translatesAutoresizingMaskIntoConstraints = false
        dockContainer.updateOrientation(for: currentPosition)
        
        dockView.addSubview(dockContainer)
        NSLayoutConstraint.activate([
            dockContainer.topAnchor.constraint(equalTo: dockView.topAnchor),
            dockContainer.bottomAnchor.constraint(equalTo: dockView.bottomAnchor),
            dockContainer.leadingAnchor.constraint(equalTo: dockView.leadingAnchor),
            dockContainer.trailingAnchor.constraint(equalTo: dockView.trailingAnchor)
        ])
        
        oldContainer?.removeFromSuperview()
        updateDockSize(for: 0)
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
