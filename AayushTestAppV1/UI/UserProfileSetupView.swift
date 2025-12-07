//
//  UserProfileSetupView.swift
//  AayushTestAppV1
//
//  Created on 2024
//  Copyright © 2024. All rights reserved.
//

import SwiftUI

/// View for setting up user profile information.
///
/// **Purpose**: Allows users to enter and update their contact information
/// (name, email, phone) which will be pre-filled in forms throughout the app.
struct UserProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var profileStore: UserProfileStore
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [SteelersTheme.steelersBlack, SteelersTheme.darkGray],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        VStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(SteelersTheme.steelersGold)
                            Text("Setup Profile")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(SteelersTheme.textPrimary)
                            Text("Your information will be pre-filled in forms")
                                .font(.subheadline)
                                .foregroundColor(SteelersTheme.textSecondary)
                        }
                        .padding(.top, 20)
                        
                        // Profile Form Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Your Information")
                                .font(.headline)
                                .foregroundColor(SteelersTheme.textPrimary)
                            
                            // Name Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(.subheadline)
                                    .foregroundColor(SteelersTheme.textSecondary)
                                TextField("Enter your name", text: $name)
                                    .textFieldStyle(.plain)
                                    .padding(12)
                                    .background(SteelersTheme.darkGray)
                                    .cornerRadius(8)
                                    .foregroundColor(SteelersTheme.textPrimary)
                            }
                            
                            Divider()
                                .background(SteelersTheme.steelersGold.opacity(0.3))
                            
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.subheadline)
                                    .foregroundColor(SteelersTheme.textSecondary)
                                TextField("Enter your email", text: $email)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .padding(12)
                                    .background(SteelersTheme.darkGray)
                                    .cornerRadius(8)
                                    .foregroundColor(SteelersTheme.textPrimary)
                            }
                            
                            Divider()
                                .background(SteelersTheme.steelersGold.opacity(0.3))
                            
                            // Phone Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Phone")
                                    .font(.subheadline)
                                    .foregroundColor(SteelersTheme.textSecondary)
                                TextField("Enter your phone number", text: $phone)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.phonePad)
                                    .padding(12)
                                    .background(SteelersTheme.darkGray)
                                    .cornerRadius(8)
                                    .foregroundColor(SteelersTheme.textPrimary)
                            }
                        }
                        .padding()
                        .steelersCard()
                        .padding(.horizontal, 20)
                        
                        // Save Button
                        Button {
                            saveProfile()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save Profile")
                                    .fontWeight(.semibold)
                            }
                        }
                        .steelersButton()
                        .padding(.horizontal, 20)
                        .disabled(name.isEmpty || email.isEmpty || phone.isEmpty)
                        
                        // Info Card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(SteelersTheme.steelersGold)
                                Text("Privacy")
                                    .font(.headline)
                                    .foregroundColor(SteelersTheme.textPrimary)
                            }
                            Text("Your information is stored locally on your device and is only used to pre-fill forms. All fields remain editable at any time.")
                                .font(.caption)
                                .foregroundColor(SteelersTheme.textSecondary)
                        }
                        .padding()
                        .steelersCard()
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Cancel")
                        }
                        .foregroundColor(SteelersTheme.steelersGold)
                    }
                }
            }
            .onAppear {
                // Load existing profile
                name = profileStore.profile.name
                email = profileStore.profile.email
                phone = profileStore.profile.phone
            }
        }
    }
    
    private func saveProfile() {
        profileStore.update(name: name, email: email, phone: phone)
        dismiss()
    }
}

#Preview("UserProfileSetupView Preview") {
    UserProfileSetupView(profileStore: UserProfileStore())
}
