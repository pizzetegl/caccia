import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var username   = ""
    @State private var password   = ""
    @State private var showError  = false
    @State private var errorMessage = ""
    @State private var showPassword = false

    // Persist username for polling in ContentView
    @AppStorage("username") private var storedUsername: String = ""

    // Focus handling for full-cell tap
    @FocusState private var focusedField: Field?
    private enum Field {
        case username, password
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .drawingGroup()    // rasterizza il gradiente una volta per migliorare le performance
            .ignoresSafeArea()

            VStack(spacing: 40) {
                // App logo
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                // Card container
                VStack(spacing: 20) {
                    Text("Benvenuto")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    // Username field
                    ZStack {
                        // White background rectangle
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                        HStack {
                            // Placeholder
                            if username.isEmpty {
                                Text("Username")
                                    .foregroundColor(.gray)      // lighter placeholder
                                    .allowsHitTesting(false)
                            }
                            // User input
                            TextField("", text: $username)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .foregroundColor(.black)
                                .accentColor(.black)
                                .focused($focusedField, equals: .username)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 16)
                    }
                    .contentShape(Rectangle())              // make whole cell tappable
                    .onTapGesture { focusedField = .username }
                    .frame(height: 44)

                    // Password field
                    ZStack {
                        // White background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)

                        HStack {
                            // Placeholder
                            if password.isEmpty {
                                Text("Password")
                                    .foregroundColor(.gray)    // lighter placeholder
                                    .allowsHitTesting(false)
                            }
                            // User input or visible text
                            Group {
                                if showPassword {
                                    TextField("", text: $password)
                                        .focused($focusedField, equals: .password)
                                } else {
                                    SecureField("", text: $password)
                                        .focused($focusedField, equals: .password)
                                }
                            }
                            .foregroundColor(.black)
                            .accentColor(.black)
                            .frame(maxWidth: .infinity)

                            // Toggle visibility button
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                            .padding(.trailing, 16)
                        }
                        .padding(.horizontal, 16)
                    }
                    .contentShape(Rectangle())               // make whole cell tappable
                    .onTapGesture { focusedField = .password }
                    .frame(height: 44)

                    // Login button
                    Button(action: {
                        APIClient.shared.login(username: username,
                                               password: password) { success, _, error in
                            if success {
                                storedUsername = username
                                isLoggedIn = true
                            } else {
                                errorMessage = error ?? "Errore sconosciuto"
                                showError = true
                            }
                        }
                    }) {
                        Text("Accedi")
                            .font(.headline)
                            .foregroundColor(Color.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(8)
                    }
                    .alert("Login fallito", isPresented: $showError) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text(errorMessage)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.25))
                .cornerRadius(16)
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 50)
        }
    }
}
