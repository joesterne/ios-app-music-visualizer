import SwiftUI

@main
@MainActor
struct AfterglowApp: App {
    @StateObject private var model = StudioModel()
    var body: some Scene {
        #if os(macOS)
        Window("Afterglow", id: "studio") {
            StudioView().environmentObject(model).frame(minWidth: 720, minHeight: 600)
        }
        .defaultSize(width: 1400, height: 900)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import Audio…") { model.showImporter = true }.keyboardShortcut("o")
                Button("Music Sources…") { model.showSources = true }.keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandMenu("Visuals") {
                ForEach(VisualizerStyle.allCases) { style in Button(style.title) { model.settings.style = style } }
                Divider()
                Button(model.immersive ? "Exit Immersive Mode" : "Enter Immersive Mode") { model.immersive.toggle() }.keyboardShortcut("i")
                Button(model.motionPaused ? "Resume Motion" : "Pause Motion") { model.motionPaused.toggle() }.keyboardShortcut("p", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { model.showSettings = true }.keyboardShortcut(",")
            }
        }
        #else
        WindowGroup { StudioView().environmentObject(model) }
        #endif
    }
}
