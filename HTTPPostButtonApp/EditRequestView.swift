import SwiftUI

//
// EditRequestView.swift
// Version 0.7 - Edit screen for configuring POST request details
// Includes colour picker (12 swatches), security options, OTP settings, headers and body
//

struct EditRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var editableRequest: PostRequestConfig
    let requestStore: RequestStore
    let pageStore: PageStore
    let currentPageId: UUID
    let isNew: Bool
    let onDelete: () -> Void
    
    @State private var showingDeleteButtonAlert = false
    @State private var showingDeleteHeaderAlert = false
    @State private var headerToDelete: PostRequestConfig.HTTPHeader? = nil
    
    init(request: PostRequestConfig, requestStore: RequestStore, pageStore: PageStore, currentPageId: UUID, isNew: Bool = false, onDelete: @escaping () -> Void) {
        _editableRequest = State(initialValue: request)
        self.requestStore = requestStore
        self.pageStore = pageStore
        self.currentPageId = currentPageId
        self.isNew = isNew
        self.onDelete = onDelete
    }
    
    var body: some View {
        Form {
            // MARK: - Button Configuration
            Section(header: Text("Button Configuration")) {
                TextField("Button Title", text: $editableRequest.buttonTitle)
                
                // MARK: - Page Selection
                Picker("Page", selection: Binding(
                    get: { editableRequest.pageId ?? currentPageId },
                    set: { editableRequest.pageId = $0 }
                )) {
                    ForEach(pageStore.pages) { page in
                        HStack {
                            Image(systemName: page.iconName)
                                .foregroundColor(page.iconColor)
                            Text(page.name)
                        }
                        .tag(page.id)
                    }
                }
                
                // MARK: - Color Picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("Button Color")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // 6 columns × 2 rows grid of swatches
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(buttonColorSwatches, id: \.hex) { swatch in
                            ColorSwatch(
                                hex: swatch.hex,
                                name: swatch.name,
                                isSelected: editableRequest.buttonColorHex == swatch.hex
                            ) {
                                editableRequest.buttonColorHex = swatch.hex
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            
            // MARK: - Security
            Section(header: Text("Security")) {
                Toggle(BiometricAuth.isAvailable() ? "Require \(BiometricAuth.biometricType())" : "Require Authentication", isOn: $editableRequest.requireBiometric)
                
                if editableRequest.requireBiometric {
                    if BiometricAuth.isAvailable() {
                        Text("You will be prompted for \(BiometricAuth.biometricType()) before sending this request.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("⚠️ Biometric authentication is not available. Passcode will be required instead.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Toggle("Require Confirmation", isOn: $editableRequest.requireConfirmation)
                
                if editableRequest.requireConfirmation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirmation Message")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter confirmation message", text: $editableRequest.confirmationMessage)
                    }
                    Text("A confirmation alert will be shown before sending the request.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            
            // MARK: - OTP Settings
            Section(header: Text("OTP Settings (Optional)")) {
                Toggle("Enable Local OTP Generation", isOn: $editableRequest.otpEnabled)
                
                if editableRequest.otpEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TOTP Secret Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter Base32-encoded secret", text: $editableRequest.otpSecret)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                    }
                    Text("The app will generate a 6-digit TOTP code locally. Use {{OTP}} in your request body where you want the OTP inserted.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    Text("💡 Secret format: Base32 (A-Z, 2-7), hex, or plain text")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                }
            }
            
            // MARK: - Request Details
            Section(header: Text("Request Details")) {
                TextField("URL", text: $editableRequest.url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }
            
            // MARK: - Headers
            Section(header: Text("Headers")) {
                ForEach(editableRequest.headers) { header in
                    if let index = editableRequest.headers.firstIndex(where: { $0.id == header.id }) {
                        HStack {
                            VStack(spacing: 8) {
                                TextField("Header Key", text: Binding(
                                    get: { editableRequest.headers[index].key },
                                    set: { editableRequest.headers[index].key = $0 }
                                ))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                
                                TextField("Header Value", text: Binding(
                                    get: { editableRequest.headers[index].value },
                                    set: { editableRequest.headers[index].value = $0 }
                                ))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            }
                            Button(action: {
                                headerToDelete = header
                                showingDeleteHeaderAlert = true
                            }) {
                                Image(systemName: "trash.circle.fill")
                                    .foregroundColor(.red)
                                    .imageScale(.large)
                            }
                        }
                    }
                }
                Button(action: {
                    withAnimation {
                        editableRequest.headers.append(PostRequestConfig.HTTPHeader(key: "", value: ""))
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                        Text("Add Header")
                    }
                }
                
                Text("💡 You can use {{KEY_NAME}} in header values too")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.top, 4)
            }
            
            // MARK: - Request Body
            Section(header: Text("Request Body (JSON)")) {
                TextEditor(text: $editableRequest.body)
                    .frame(minHeight: 150)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if editableRequest.otpEnabled {
                    Text("💡 Use {{OTP}} as a placeholder. It will be replaced with the actual 6-digit OTP.")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                }
                Text("💡 Use {{KEY_NAME}} to insert secrets. Manage secrets from the menu.")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.top, 4)
            }
            
            // MARK: - Delete Button
            Section {
                Button(role: .destructive, action: {
                    showingDeleteButtonAlert = true
                }) {
                    HStack {
                        Spacer()
                        Text("Delete Button")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Edit Request")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    if isNew {
                        requestStore.addRequest(editableRequest)
                    } else {
                        requestStore.updateRequest(editableRequest)
                    }
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .alert("Delete Button", isPresented: $showingDeleteButtonAlert) {
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(editableRequest.buttonTitle)\"?")
        }
        .alert("Delete Header", isPresented: $showingDeleteHeaderAlert) {
            Button("Delete", role: .destructive) {
                if let header = headerToDelete {
                    withAnimation {
                        editableRequest.headers.removeAll(where: { $0.id == header.id })
                    }
                    headerToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { headerToDelete = nil }
        } message: {
            Text("Are you sure you want to delete the header \"\(headerToDelete?.key.isEmpty == false ? headerToDelete!.key : "unnamed")\"?")
        }
    }
}

// MARK: - Color Swatch View

struct ColorSwatch: View {
    let hex: String
    let name: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color(hex: hex) ?? .blue)
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                
                if isSelected {
                    Circle()
                        .strokeBorder(.white, lineWidth: 2.5)
                        .frame(width: 40, height: 40)
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }
}
