import SwiftUI

// SpektraLab for iPad — MVP (free, personal build).
// This is NOT the paid iOS app from the App Store, and it does not use
// that app's code, assets or membership system. It reuses only the
// open-source Mac engine (GPL-3.0-or-later) and its CC BY-SA 4.0 profiles
// from github.com/JamesQiu2005/SpektraLab, with a new iPad frontend.
//
// MVP scope, deliberately small:
//   - import one photo from Photos or Files (JPEG/HEIF/PNG/TIFF first;
//     RAW is best-effort in v1, see ImageDecode.swift)
//   - pick a film + paper, adjust a few core parameters
//   - Metal/C++ engine preview, then full-resolution export
// Not in v1: Film Edge, half-frame pairs, Date Back, batch export,
// light table, CLI/MCP, library/catalogue management.

@main
struct SpektraLab_iPadApp: App {
    @StateObject private var engine = EngineBridge()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
        }
    }
}
