//
//  SettingsSheet.swift
//  emoji-map
//
//  Created by Enrique on 3/14/25.
//

import SwiftUI
import os.log
import Combine
import CoreLocation
import MapKit
import _MapKit_SwiftUI
import SwiftUICore
import Clerk
import AuthenticationServices
import CryptoKit

struct SettingsSheet: View {
    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "SettingsSheet")
    
    // ViewModel
    @ObservedObject var viewModel: HomeViewModel
    
    // Access to user preferences
    @ObservedObject private var userPreferences = ServiceContainer.shared.userPreferences
    
    // Access to Clerk for authentication
    @Environment(Clerk.self) private var clerk
    
    // State for showing onboarding
    @State private var showOnboarding = false
    
    // State for confirmation dialog
    @State private var showResetConfirmation = false
        
    // State for Apple Sign In
    @State private var isAppleSignInLoading = false
    @State private var appleSignInError: String? = nil
    @State private var showAppleSignInError = false
    @State private var currentNonce: String?
    
    // Consistent height for account section
    private let accountSectionMinHeight: CGFloat = 120
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("Settings")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text("⚙️")
                        .font(.largeTitle)
                }
                .padding(.bottom, 8)
                
                // Divider
                Divider()
                
                // Account Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Account")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.bottom, 4)
                    
                    if let user = clerk.user {
                        // User is logged in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Logged in as")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                if let email = user.emailAddresses.first?.emailAddress {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else if let username = user.username {
                                    Text(username)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(user.id)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        
                        // Log Out Button
                        Button(action: {
                            Task {
                                try? await clerk.signOut()
                                logger.notice("User signed out")
                            }
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red)
                                Text("Sign Out")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        // User is not logged in
                        VStack(spacing: 8) {
                            ZStack {
                                SignInWithAppleButton(
                                    onRequest: { request in
                                        logger.notice("Apple Sign In request started")
                                        logger.notice("Requesting scopes: email and fullName")
                                        request.requestedScopes = [.email, .fullName]
                                        
                                        // Generate a secure, random nonce for authentication
                                        let nonce = randomNonceString()
                                        currentNonce = nonce
                                        logger.notice("Generated nonce for Apple Sign In: \(nonce)")
                                        
                                        // Set the SHA256 hashed nonce
                                        let hashedNonce = sha256(nonce)
                                        logger.notice("Hashed nonce: \(hashedNonce)")
                                        request.nonce = hashedNonce
                                    },
                                    onCompletion: handleSignInWithAppleCompletion
                                )
                                .signInWithAppleButtonStyle(.black)
                                .frame(height: 44)
                                .cornerRadius(8)
                                
                                if isAppleSignInLoading {
                                    Color.black.opacity(0.3)
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                            }
                            .frame(height: 44)
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.vertical, 8)
                .frame(minHeight: accountSectionMinHeight)
                
                // App Settings Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("App Settings")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.bottom, 4)
                    
                    // View Onboarding Button
                    Button(action: {
                        logger.notice("View onboarding requested")
                        showOnboarding = true
                    }) {
                        HStack {
                            Image(systemName: "book")
                                .foregroundColor(.blue)
                            Text("View Onboarding")
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Reset All Settings Button
                    Button(action: {
                        logger.notice("Reset all settings requested")
                        showResetConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.red)
                            Text("Reset All Settings")
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.vertical, 8)
                
                // Developer Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Developer")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.bottom, 4)
                    
                    // Places Cache Info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Places Cache")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(viewModel.places.count) places")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Filtered Places")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(viewModel.filteredPlaces.count) places")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Selected Categories")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(viewModel.selectedCategoryKeys.count) categories")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Clear Cache Button
                    Button(action: {
                        viewModel.clearPlaces()
                        viewModel.placesService.clearCache()
                        logger.notice("Cache cleared from settings")
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear Places Cache")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Refresh Places Button
                    Button(action: {
                        viewModel.refreshPlaces(clearExisting: true)
                        logger.notice("Places refreshed from settings")
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                            Text("Refresh Places")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.vertical, 8)
                
                Spacer()
                
                // Version info
                Text("Version 1.0.0 (Build 42)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top)
            }
            .padding()
        }
        .onAppear {
            logger.notice("Settings sheet appeared")
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(userPreferences: userPreferences, isFromSettings: true)
        }
        .alert(isPresented: $showAppleSignInError, content: {
            Alert(
                title: Text("Sign In Error"),
                message: Text(appleSignInError ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        })
        .confirmationDialog(
            "Reset All Settings?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                // Reset all settings
                ServiceContainer.shared.resetAllServices()
                logger.notice("All settings have been reset")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all settings to their default values and clear all cached data. This action cannot be undone.")
        }
    }
    
    // MARK: - Nonce Generation
    
    // Adapted from Apple's example: https://developer.apple.com/documentation/authenticationservices/implementing_user_authentication_with_sign_in_with_apple
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    logger.error("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                    fatalError("Unable to generate random nonce: \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    // Hashes a string using SHA256
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // Handle Sign in with Apple completion
    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        Task {
            do {
                isAppleSignInLoading = true
                logger.notice("Apple Sign In completion handler called")
                
                switch result {
                case .success(let authorization):
                    // Access the Apple ID Credential
                    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                        logger.error("Unable to get credential of type ASAuthorizationAppleIDCredential")
                        appleSignInError = "Unable to get Apple credentials"
                        showAppleSignInError = true
                        isAppleSignInLoading = false
                        return
                    }
                    
                    logger.notice("Successfully obtained Apple ID credential")
                    logger.notice("User identifier: \(credential.user)")
                    
                    // Log credential details for debugging (excluding sensitive info)
                    if let email = credential.email {
                        logger.notice("Apple credential includes email: \(email)")
                    } else {
                        logger.notice("Apple credential does not include email")
                    }
                    
                    if let _ = credential.fullName {
                        logger.notice("Apple credential includes full name")
                    } else {
                        logger.notice("Apple credential does not include full name")
                    }
                    
                    // Verify that we have a valid nonce
                    guard currentNonce != nil else {
                        logger.error("Invalid state: A login callback was received, but no login request was sent.")
                        appleSignInError = "Invalid state: Missing authentication data"
                        showAppleSignInError = true
                        isAppleSignInLoading = false
                        return
                    }
                    
                    // Access the necessary identity token on the Apple ID Credential
                    guard let identityToken = credential.identityToken else {
                        logger.error("Identity token is nil in Apple ID Credential")
                        appleSignInError = "Unable to get Apple ID token"
                        showAppleSignInError = true
                        isAppleSignInLoading = false
                        return
                    }
                    
                    logger.notice("Identity token data length: \(identityToken.count) bytes")
                    
                    guard let idToken = String(data: identityToken, encoding: .utf8) else {
                        logger.error("Unable to convert identity token to string")
                        appleSignInError = "Unable to process Apple ID token"
                        showAppleSignInError = true
                        isAppleSignInLoading = false
                        return
                    }
                    
                    logger.notice("Successfully extracted identity token from Apple credential")
                    logger.notice("Token prefix: \(String(idToken.prefix(15)))...")
                    
                    // Authenticate with Clerk
                    logger.notice("Attempting to authenticate with Clerk using Apple ID token")
                    do {
                        // Use the standard authenticateWithIdToken method
                        try await SignIn.authenticateWithIdToken(provider: .apple, idToken: idToken)
                        logger.notice("User signed in with Apple successfully")
                        // Fetch user data which will sync favorites with API
                        await viewModel.fetchUserData()
                        isAppleSignInLoading = false
                    } catch let clerkError {
                        logger.error("Clerk authentication error: \(clerkError.localizedDescription)")
                        appleSignInError = "Authentication error: \(clerkError.localizedDescription)"
                        showAppleSignInError = true
                        isAppleSignInLoading = false
                    }
                    
                case .failure(let error):
                    // Handle specific error cases
                    logger.error("Apple Sign In failed with error: \(error.localizedDescription)")
                    
                    if let authError = error as? ASAuthorizationError {
                        switch authError.code {
                        case .canceled:
                            logger.notice("User canceled Sign in with Apple")
                            // User canceled, no need to show error
                            isAppleSignInLoading = false
                            return
                        case .unknown:
                            appleSignInError = "An unknown error occurred (code: \(authError.code.rawValue))"
                            logger.error("Unknown Apple Sign In error with code: \(authError.code.rawValue)")
                        case .invalidResponse:
                            appleSignInError = "Invalid response from Apple"
                        case .notHandled:
                            appleSignInError = "Request not handled"
                        case .failed:
                            appleSignInError = "Authorization failed: \(error.localizedDescription)"
                        default:
                            appleSignInError = "Error \(authError.code.rawValue): \(error.localizedDescription)"
                        }
                    } else {
                        appleSignInError = "Error: \(error.localizedDescription)"
                    }
                    
                    logger.error("Sign in with Apple error: \(error.localizedDescription)")
                    showAppleSignInError = true
                    isAppleSignInLoading = false
                }
            } catch {
                logger.error("Unexpected error in Apple Sign In process: \(error.localizedDescription)")
                appleSignInError = "Unexpected error: \(error.localizedDescription)"
                showAppleSignInError = true
                isAppleSignInLoading = false
            }
        }
    }
}

#Preview {
    // Create a mock HomeViewModel for the preview
    let mockService = PreviewMockPlacesService()
    let mockUserPreferences = UserPreferences(userDefaults: UserDefaults.standard)
    let viewModel = HomeViewModel(placesService: mockService, userPreferences: mockUserPreferences)
    
    // Add some mock data
    viewModel.places = [
        Place(id: "1", emoji: "🍕", location: Place.Location(latitude: 37.7749, longitude: -122.4194)),
        Place(id: "2", emoji: "🍺", location: Place.Location(latitude: 37.7749, longitude: -122.4194))
    ]
    viewModel.filteredPlaces = [viewModel.places[0]]
    viewModel.selectedCategoryKeys = [1]
    
    return SettingsSheet(viewModel: viewModel)
        .environment(Clerk.shared)
}

// Mock service for preview
private class PreviewMockPlacesService: PlacesServiceProtocol {
    @MainActor func fetchNearbyPlaces(location: CLLocationCoordinate2D, useCache: Bool) async throws -> [Place] {
        return []
    }
    
    @MainActor func fetchNearbyPlacesPublisher(location: CLLocationCoordinate2D, useCache: Bool) -> AnyPublisher<[Place], Error> {
        return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    @MainActor func fetchPlacesByCategories(location: CLLocationCoordinate2D, categoryKeys: [Int]) async throws -> [Place] {
        return []
    }
    
    @MainActor func clearCache() {
        // No-op for preview
    }
} 
