//
//  MapViewModel.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import SwiftUI
import MapKit
import CoreLocation

class MapViewModel: ObservableObject {
    let categories = [
        ("🍕", "pizza", "restaurant"),
        ("🍺", "beer", "bar"),
        ("🍣", "sushi", "restaurant"),
        ("☕️", "coffee", "cafe"),
        ("🍔", "burger", "restaurant")
    ]
    
    @Published var selectedCategories: Set<String> = ["pizza", "beer", "sushi", "coffee", "burger"]
    @Published var region: MKCoordinateRegion
    @Published var places: [Place] = []
    @Published var selectedPlace: Place?
    @Published private(set) var lastQueriedCenter: CoordinateWrapper
    @Published var isLoading: Bool = false
    @Published var error: NetworkError?
    @Published var showError: Bool = false
    
    private let locationManager = LocationManager()
    private let googlePlacesService: GooglePlacesServiceProtocol
    private var shouldCenterOnLocation = true
    
    var isLocationAvailable: Bool {
        locationManager.location != nil
    }
    
    init(googlePlacesService: GooglePlacesServiceProtocol) {
        self.googlePlacesService = googlePlacesService
        
        let defaultCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        self.region = MKCoordinateRegion(
            center: defaultCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        self.lastQueriedCenter = CoordinateWrapper(defaultCoordinate)
        
        setupLocationUpdates()
    }
    
    private func setupLocationUpdates() {
        locationManager.onLocationUpdate = { [weak self] location in
            guard let self = self else { return }
            if self.shouldCenterOnLocation {
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.updateRegion(to: location.coordinate)
                    try await self.fetchAndUpdatePlaces()
                    self.shouldCenterOnLocation = false
                }
            }
        }
        
        if let initialLocation = locationManager.location {
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.updateRegion(to: initialLocation.coordinate)
                try await self.fetchAndUpdatePlaces()
                self.shouldCenterOnLocation = false
            }
        }
    }
    
    func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            try await self.fetchAndUpdatePlaces()
        }
    }
    
    func categoryEmoji(for category: String) -> String {
        categories.first(where: { $0.1 == category })?.0 ?? "📍"
    }
    
    func onRegionChange(newCenter: CoordinateWrapper) {
        if distance(from: lastQueriedCenter.coordinate, to: newCenter.coordinate) > 500 {
            lastQueriedCenter = newCenter
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                try await self.fetchAndUpdatePlaces()
            }
        }
    }
    
    func onAppear() {
        if let userLocation = locationManager.location {
            updateRegion(to: userLocation.coordinate)
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                try await self.fetchAndUpdatePlaces()
                self.shouldCenterOnLocation = false
            }
        } else {
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                try await self.fetchAndUpdatePlaces()
            }
        }
    }
    
    func recenterMap() {
        if let userLocation = locationManager.location {
            updateRegion(to: userLocation.coordinate)
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                try await self.fetchAndUpdatePlaces()
            }
        }
    }
    
    // Synchronous wrapper for the async fetchAndUpdatePlaces method
    func retryFetchPlaces() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            try? await self.fetchAndUpdatePlaces()
        }
    }
    
    @MainActor
    func fetchAndUpdatePlaces() async throws {
        isLoading = true
        error = nil
        showError = false
        
        do {
            let activeCategories = selectedCategories.isEmpty ? categories : categories.filter { selectedCategories.contains($0.1) }
            let fetchedPlaces = try await fetchPlaces(center: region.center, categories: activeCategories)
            self.places = fetchedPlaces
        } catch let networkError as NetworkError {
            self.error = networkError
            self.showError = true
            print("Network error: \(networkError.localizedDescription)")
        } catch {
            self.error = .unknownError(error)
            self.showError = true
            print("Unknown error: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private func fetchPlaces(center: CLLocationCoordinate2D, categories: [(emoji: String, name: String, type: String)]) async throws -> [Place] {
        return try await withCheckedThrowingContinuation { continuation in
            googlePlacesService.fetchPlaces(center: center, categories: categories) { result in
                switch result {
                case .success(let places):
                    continuation.resume(returning: places)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func updateRegion(to coordinate: CLLocationCoordinate2D) {
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        lastQueriedCenter = CoordinateWrapper(coordinate)
    }
    
    private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let location2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return location1.distance(from: location2)
    }
}
