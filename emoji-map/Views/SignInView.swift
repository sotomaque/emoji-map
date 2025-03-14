//
//  SignInView.swift
//  emoji-map
//
//  Created by Enrique on 3/2/25.
//

import SwiftUI
import os.log
import Clerk

struct SignInView: View {
    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "SignInView")
    
    // Access to Clerk for authentication
    @Environment(Clerk.self) private var clerk
    
    // Environment value to dismiss the view
    @Environment(\.dismiss) private var dismiss
    
    // State for sign-in/sign-up toggle
    @State private var isSignUp = false
    
    // Form fields
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var isVerifying = false
    
    // Focus state
    @FocusState private var focusedField: Field?
    
    // Error handling
    @State private var errorMessage: String? = nil
    @State private var showError = false
    
    // Loading state
    @State private var isLoading = false
    
    // Focus fields enum
    enum Field: Hashable {
        case email, password, code
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack {
                        Text("🗺️")
                            .font(.system(size: 70))
                            .padding(.top, 20)
                        
                        Text("Emoji Map")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.top, 8)
                        
                        Text(isSignUp ? "Create an account to save your favorite places" : "Sign in to access your favorite places")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 10)
                    
                    // Sign Up Form
                    if isSignUp {
                        if isVerifying {
                            // Verification code form
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Verification")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Enter the verification code sent to your email")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                TextField("Code", text: $code)
                                    .font(.title3)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .keyboardType(.numberPad)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .focused($focusedField, equals: .code)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        verifyCode()
                                    }
                                    .onAppear {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            focusedField = .code
                                        }
                                    }
                                
                                Button(action: verifyCode) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .padding(.trailing, 5)
                                        }
                                        Text("Verify")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                    .font(.headline)
                                }
                                .disabled(isLoading)
                            }
                            .padding(.horizontal)
                        } else {
                            // Sign up form
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Sign Up")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                TextField("Email", text: $email)
                                    .font(.title3)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .focused($focusedField, equals: .email)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .password
                                    }
                                    .onAppear {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            focusedField = .email
                                        }
                                    }
                                
                                SecureField("Password", text: $password)
                                    .font(.title3)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .focused($focusedField, equals: .password)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        signUpUser()
                                    }
                                
                                Button(action: signUpUser) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .padding(.trailing, 5)
                                        }
                                        Text("Create Account")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                    .font(.headline)
                                }
                                .disabled(isLoading)
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        // Sign in form
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Sign In")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            TextField("Email", text: $email)
                                .font(.title3)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .password
                                }
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        focusedField = .email
                                    }
                                }
                            
                            SecureField("Password", text: $password)
                                .font(.title3)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.done)
                                .onSubmit {
                                    signInUser()
                                }
                            
                            Button(action: signInUser) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .padding(.trailing, 5)
                                    }
                                    Text("Sign In")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .font(.headline)
                            }
                            .disabled(isLoading)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Toggle between sign in and sign up
                    Button {
                        isSignUp.toggle()
                        errorMessage = nil
                        showError = false
                        isLoading = false
                        
                        // Reset focus when switching modes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            focusedField = .email
                        }
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .foregroundColor(.blue)
                            .font(.headline)
                    }
                    .padding(.top, 8)
                    
                    // Skip button
                    Button("Continue without signing in") {
                        logger.notice("User skipped sign in")
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                }
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $showError, content: {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            })
            .onAppear {
                logger.notice("SignInView appeared")
            }
        }
    }
    
    // Helper functions for form actions
    private func signInUser() {
        isLoading = true
        focusedField = nil
        Task {
            await signIn(email: email, password: password)
            isLoading = false
        }
    }
    
    private func signUpUser() {
        isLoading = true
        focusedField = nil
        Task {
            await signUp(email: email, password: password)
            isLoading = false
        }
    }
    
    private func verifyCode() {
        isLoading = true
        focusedField = nil
        Task {
            await verify(code: code)
            isLoading = false
        }
    }
}

// Authentication methods
extension SignInView {
    func signIn(email: String, password: String) async {
        do {
            try await SignIn.create(
                strategy: .identifier(email, password: password)
            )
            logger.notice("User signed in successfully")
            dismiss()
        } catch {
            logger.error("Sign in error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func signUp(email: String, password: String) async {
        do {
            let signUp = try await SignUp.create(
                strategy: .standard(emailAddress: email, password: password)
            )
            
            try await signUp.prepareVerification(strategy: .emailCode)
            logger.notice("Verification code sent to email")
            isVerifying = true
        } catch {
            logger.error("Sign up error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func verify(code: String) async {
        do {
            guard let signUp = Clerk.shared.client?.signUp else {
                logger.error("Sign up session not found")
                errorMessage = "Sign up session not found"
                showError = true
                isVerifying = false
                return
            }
            
            try await signUp.attemptVerification(.emailCode(code: code))
            logger.notice("User verified and signed in successfully")
            dismiss()
        } catch {
            logger.error("Verification error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    SignInView()
        .environment(Clerk.shared)
} 