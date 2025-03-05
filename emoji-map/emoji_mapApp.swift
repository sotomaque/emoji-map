//
//  emoji_mapApp.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import SwiftUI

@main
struct emoji_mapApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(MapViewModel(googlePlacesService: GooglePlacesService()))
        }
    }
}
