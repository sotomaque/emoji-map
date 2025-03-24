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

// User info form for Apple private relay emails
struct UserInfoSheet: View {
    @Environment(Clerk.self) private var clerk
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var email: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    // Focus state for managing keyboard navigation
    @FocusState private var focusedField: Field?
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "UserInfoSheet")
    
    // Define focus fields for form navigation
    enum Field: Hashable {
        case email
        case firstName
        case lastName
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background color based on color scheme
                Color(colorScheme == .dark ? .black : .systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Additional Information Needed")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("We need a little more information to complete your signup.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.bottom, 8)
                        
                        // Form fields
                        VStack(spacing: 20) {
                            // Email Field (Required)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.headline)
                                
                                TextField("Your email address", text: $email)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .email)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .firstName
                                    }
                            }
                            
                            // First Name Field (Optional)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("First Name (Optional)")
                                    .font(.headline)
                                
                                TextField("Your first name", text: $firstName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textContentType(.givenName)
                                    .focused($focusedField, equals: .firstName)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .lastName
                                    }
                            }
                            
                            // Last Name Field (Optional)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Last Name (Optional)")
                                    .font(.headline)
                                
                                TextField("Your last name", text: $lastName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textContentType(.familyName)
                                    .focused($focusedField, equals: .lastName)
                                    .submitLabel(.done)
                                    .onSubmit(submitInfo)
                            }
                            
                            if let errorMessage = errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.callout)
                                    .padding(.vertical, 4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.horizontal, 6)
                        
                        // Submit button
                        Button(action: submitInfo) {
                            ZStack {
                                Text("Continue")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(isValidEmail(email) ? Color.accentColor : Color.gray.opacity(0.5))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                            }
                        }
                        .disabled(!isValidEmail(email) || isLoading)
                        .padding(.top, 16)
                    }
                    .padding()
                    .frame(maxWidth: 500) // Limit width on larger devices
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            .navigationTitle("Complete Your Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        // Sign out since the user didn't complete profile
                        Task {
                            try? await clerk.signOut()
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                    }
                }
            }
            .onAppear {
                // Auto-focus the email field when the view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.focusedField = .email
                }
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func submitInfo() {
        guard isValidEmail(email) else { return }
        
        // Clear keyboard focus
        focusedField = nil
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Get Clerk service from viewModel
                let clerkService = DefaultClerkService()
                
                // Get auth token using the proper method
                guard let token = try await clerkService.getSessionToken() else {
                    errorMessage = "Authentication error. Please try again."
                    isLoading = false
                    return
                }
                
                // Send the verification request
                try await viewModel.verifyUserInfo(
                    email: email,
                    firstName: firstName.isEmpty ? nil : firstName,
                    lastName: lastName.isEmpty ? nil : lastName,
                    token: token
                )
                
                // Fetch updated user data
                await viewModel.fetchUserData()
                
                // Dismiss the sheet
                dismiss()
            } catch {
                logger.error("Failed to verify user info: \(error.localizedDescription)")
                errorMessage = "Failed to update profile: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

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
    
    // State for showing user info form
    @State private var showUserInfoForm = false
    
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
                        
                        // Account Management Button
                        Button(action: {
                            if let url = URL(string: "\(Configuration.backendURL)/account") {
                                UIApplication.shared.open(url)
                                logger.notice("Opening account deletion page at \(url)")
                            }
                        }) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.minus")
                                    .foregroundColor(.red)
                                Text("Manage My Account")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Delete My Account Button
                        Button(action: {
                            if let url = URL(string: "\(Configuration.backendURL)/account/delete") {
                                UIApplication.shared.open(url)
                                logger.notice("Opening account deletion page at \(url)")
                            }
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                Text("Delete My Account")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
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
                
                
                // Developer Section
                if viewModel.isAdmin {
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
                }
                
                Spacer()
                
                // Version info
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown") (Build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"))")
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
        .fullScreenCover(isPresented: $showUserInfoForm) {
            UserInfoSheet(viewModel: viewModel)
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
    
    // Change from private to internal for testing
    func randomNonceString(length: Int = 32) -> String {
        // Use the method that was moved to HomeViewModel
        return viewModel.generateRandomNonce(length: length)
    }
    
    // Change from private to internal for testing
    // Hashes a string using SHA256
    func sha256(_ input: String) -> String {
        // Use the method that was moved to HomeViewModel
        return viewModel.sha256(input)
    }
    
    // Handle Sign in with Apple completion
    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        Task {
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
                    
                    // Check if this is a private relay email
                    if email.hasSuffix("@privaterelay.appleid.com") {
                        logger.notice("Detected Apple private relay email during sign-in: \(email)")
                    }
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
                
                // Use the HomeViewModel method for sign-in
                do {
                    try await signInWithIdentityToken(idToken)
                    
                    // After successful sign-in, check if the user has a private relay email
                    if let user = clerk.user, 
                       let email = user.emailAddresses.first?.emailAddress,
                       email.hasSuffix("@privaterelay.appleid.com") {
                        showUserInfoForm = true
                    }
                    
                    isAppleSignInLoading = false
                } catch let clerkError {
                    logger.error("Clerk authentication error: \(clerkError.localizedDescription)")
                    appleSignInError = "Authentication error: \(clerkError.localizedDescription)"
                    showAppleSignInError = true
                    isAppleSignInLoading = false
                }
                
            case .failure(let error):
                logger.error("Apple Sign In failed: \(error.localizedDescription)")
                appleSignInError = "Sign in failed: \(error.localizedDescription)"
                showAppleSignInError = true
                isAppleSignInLoading = false
            }
        }
    }
    
    /// Helper method for testing and code organization
    /// Signs in with an identity token and fetches user data
    @MainActor
    func signInWithIdentityToken(_ idToken: String) async throws {
        // Use the HomeViewModel method for sign-in
        try await viewModel.signInWithApple(idToken: idToken)
    }
}

#Preview {
    // Setup
    let mockViewModel = {
        let mockService = PreviewMockPlacesService()
        let mockUserPreferences = UserPreferences(userDefaults: UserDefaults.standard)
        let viewModel = HomeViewModel(placesService: mockService, userPreferences: mockUserPreferences)
        
        // Configure mock data
        viewModel.setPlaces([
            Place(id: "1", emoji: "🍕", location: Place.Location(latitude: 37.7749, longitude: -122.4194)),
            Place(id: "2", emoji: "🍺", location: Place.Location(latitude: 37.7749, longitude: -122.4194))
        ])
        viewModel.selectedCategoryKeys = [1]
        
        return viewModel
    }()
    
    // Return the view
    return SettingsSheet(viewModel: mockViewModel)
        .environment(Clerk.shared)
}

// Mock service for preview
private class PreviewMockPlacesService: PlacesServiceProtocol {
    func fetchPlacesByCategories(location: CLLocationCoordinate2D, categoryKeys: [Int], bypassCache: Bool, radius: Int) async throws -> [Place] {
        return []
    }
    
    func fetchPlacesByCategories(location: CLLocationCoordinate2D, categoryKeys: [Int], bypassCache: Bool, openNow: Bool?, priceLevels: [Int]?, minimumRating: Int?, radius: Int) async throws -> [Place] {
        return []
    }
    
    func fetchNearbyPlaces(location: CLLocationCoordinate2D, useCache: Bool, radius: Int) async throws -> [Place] {
        return []
    }
    
    func fetchPlacesByCategories(location: CLLocationCoordinate2D, categoryKeys: [Int], bypassCache: Bool, openNow: Bool?, priceLevels: [Int]?, minimumRating: Int?) async throws -> [Place] {
        return []
    }
    
    @MainActor func fetchNearbyPlacesPublisher(location: CLLocationCoordinate2D, useCache: Bool) -> AnyPublisher<[Place], Error> {
        return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    @MainActor func fetchPlacesByCategories(location: CLLocationCoordinate2D, categoryKeys: [Int], bypassCache: Bool = false) async throws -> [Place] {
        return []
    }
    
    @MainActor func fetchWithFilters(location: CLLocationCoordinate2D, requestBody: PlaceSearchRequest) async throws -> PlacesResponse {
        return PlacesResponse(results: [], count: 0, cacheHit: false)
    }
    
    @MainActor func clearCache() {
        // No-op for preview
    }
} 
