//
//  AdditionalUserInfo.swift
//  emoji-map
//
//  Created by Enrique on 3/28/25.
//

import SwiftUI

struct TallTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

struct AdditionalUserInfo: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: HomeViewModel
    
    @State private var email = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isEmailValid = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showError = false
  
    @FocusState private var focusedField: Field?

    enum Field {
        case email
        case firstName
        case lastName
    }
    
    private let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color(.systemBackground).opacity(0.8)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Image("Logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                                )
                            
                            Text("Complete Your Profile")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Help us personalize your experience")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)
                        
                        // Form
                        VStack(spacing: 24) {
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Email")
                                        .font(.headline)
                                    Text("*")
                                        .foregroundStyle(.red)
                                }
                                
                                TextField("Enter your email", text: $email)
                                    .textFieldStyle(TallTextFieldStyle())
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .focused($focusedField, equals: .email)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .firstName
                                    }
                                    .onChange(of: email) { _, newValue in
                                        isEmailValid = newValue.range(of: emailRegex, options: .regularExpression) != nil
                                    }
                                
                                if !email.isEmpty && !isEmailValid {
                                    Text("Please enter a valid email address")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                            .id("emailField")
                            
                            // First Name Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("First Name")
                                    .font(.headline)
                                
                                TextField("Enter your first name", text: $firstName)
                                    .textFieldStyle(TallTextFieldStyle())
                                    .textContentType(.givenName)
                                    .autocapitalization(.words)
                                    .focused($focusedField, equals: .firstName)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .lastName
                                    }
                            }
                            .id("firstNameField")
                            
                            // Last Name Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Last Name")
                                    .font(.headline)
                                
                                TextField("Enter your last name", text: $lastName)
                                    .textFieldStyle(TallTextFieldStyle())
                                    .textContentType(.familyName)
                                    .autocapitalization(.words)
                                    .focused($focusedField, equals: .lastName)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        Task {
                                            await submitForm()
                                        }
                                    }
                            }
                            .id("lastNameField")
                        }
                        .padding(.horizontal)
                        
                        // Submit Button
                        Button(action: {
                            Task {
                                await submitForm()
                            }
                        }) {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Continue")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(isEmailValid ? Color.blue : Color.gray)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(!isEmailValid || isSubmitting)
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                }
                .onChange(of: focusedField) { _, newField in
                    if let field = newField {
                        withAnimation {
                            switch field {
                            case .email:
                                proxy.scrollTo("emailField", anchor: .center)
                            case .firstName:
                                proxy.scrollTo("firstNameField", anchor: .center)
                            case .lastName:
                                proxy.scrollTo("lastNameField", anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .onAppear {
            focusedField = .email
        }
    }
    
    private func submitForm() async {
        isSubmitting = true
        errorMessage = nil
        
        do {
            try await viewModel.updateUserInfo(
                email: email,
                firstName: firstName,
                lastName: lastName
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isSubmitting = false
    }
}


