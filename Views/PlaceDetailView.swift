                ActionButton(
                    title: "View on Map",
                    icon: "map.fill",
                    foregroundColor: .blue,
                    backgroundColor: Color.blue.opacity(0.1),
                    hasBorder: true,
                    action: {
                        // Use the default map app to view the location
                        let defaultMapAppName = mapViewModel.preferences.defaultMapApp
                        let installedApps = MapAppUtility.shared.getInstalledMapApps()
                        
                        // Find the default map app
                        if let defaultApp = installedApps.first(where: { $0.rawValue == defaultMapAppName }) {
                            // Use the default map app
                            MapAppUtility.shared.openInMapApp(
                                mapApp: defaultApp,
                                coordinate: place.coordinate,
                                name: place.name
                            )
                        } else if let firstApp = installedApps.first {
                            // Use the first available map app if default is not found
                            MapAppUtility.shared.openInMapApp(
                                mapApp: firstApp,
                                coordinate: place.coordinate,
                                name: place.name
                            )
                        }
                        
                        // Dismiss the sheet after launching the map app
                        dismiss()
                    }
                )
                .disabled(viewModel.isLoading)
                .opacity(viewModel.isLoading ? 0.7 : 1.0)
                .contextMenu {
                    // Context menu to choose a different map app
                    Text("Open with...")
                    
                    ForEach(MapAppUtility.shared.getInstalledMapApps()) { app in
                        Button {
                            MapAppUtility.shared.openInMapApp(
                                mapApp: app,
                                coordinate: place.coordinate,
                                name: place.name
                            )
                            dismiss()
                        } label: {
                            Label(app.rawValue, systemImage: "map.fill")
                        }
                    }
                } 