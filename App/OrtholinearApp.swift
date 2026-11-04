import SwiftUI

@main
struct KeyScratchApp: App {
    init() {
        #if PRO
        ProEdition.install()
        #endif
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        var preferences = PreferenceStore.load()
        if arguments.contains("-suggestion-ui-tests") { preferences.suggestionsEnabled = true }
        // Tests written before automatic capitals type lowercase keys by identifier.
        if arguments.contains("-no-auto-capitals") { preferences.autoCapitalize = false }
        if arguments.contains("-auto-capitals") { preferences.autoCapitalize = true }
        if arguments.contains("-reset-custom-layouts") { preferences.customLayouts = [:] }
        if arguments.contains("-reset-layers") { preferences.layers = []; preferences.showLayerKey = false }
        if arguments.contains("-reset-extras") {
            (preferences.layers, preferences.showLayerKey, preferences.keycaps, preferences.expansions) = ([], false, nil, [])
        }
        if preferences != PreferenceStore.load() { try? KeyboardPublisher.publish(preferences) }
        #endif

    }
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
