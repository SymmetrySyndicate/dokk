import SwiftUI

@main
struct dokkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
        
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
