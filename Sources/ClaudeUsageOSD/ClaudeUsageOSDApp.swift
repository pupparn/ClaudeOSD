import SwiftUI

@main
struct ClaudeUsageOSDApp: App {
    var body: some Scene {
        MenuBarExtra {
            OSDPanelView()
        } label: {
            Image(systemName: "circle.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
