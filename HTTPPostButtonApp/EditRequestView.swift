import SwiftUI

//
// EditRequestView.swift
// Version 0.9 - Edit screen for configuring POST request details
// v0.9: ⓘ info buttons placed inline after label text
//

struct EditRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var editableRequest: PostRequestConfig
    let requestStore: RequestStore
    let pageStore: PageStore
    let currentPageId: UUID
    @State private var isNew: Bool
    let onDelete: () -> Void
    
    @State private var showingDeleteButtonAlert = false
    @State private var showingDeleteHeaderAlert = false
    @State private var headerToDelete: PostRequestConfig.HTTPHeader? = nil
    @State private var showingDuplicateAlert = false
    
    init(request: PostRequestConfig, requestStore: RequestStore, pageStore: PageStore, currentPageId: UUID, isNew: Bool = false, onDelete: @escaping () -> Void) {
        _editableRequest = State(initialValue: request)
        self.requestStore = requestStore
        self.pageStore = pageStore
        self.currentPageId = currentPageId
        _isNew = State(initialValue: isNew)
        self.onDelete = onDelete
    }
    
    // MARK: - Duplicate
    private func duplicateAndRename() {
        var duplicate = editableRequest
        duplicate.id = UUID()
        duplicate.buttonTitle = ""
        duplicate.pageId = editableRequest.pageId ?? currentPageId
        editableRequest = duplicate
        isNew = true
    }
    
    var body: some View {
        Form {
            // MARK: - Button Configuration
            Section(header: Text("Button Configuration")) {
                TextField("Button Title", text: $editableRequest.buttonTitle)
                
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
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Button Color")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                // Toggle with inline ⓘ: label built manually, toggle uses empty label
                Toggle(isOn: $editableRequest.requireBiometric) {
                    HStack(spacing: 4) {
                        Text(BiometricAuth.isAvailable()
                             ? "Require \(BiometricAuth.biometricType())"
                             : "Require Authentication")
                        InfoButton(
                            title: BiometricAuth.isAvailable()
                                ? "Require \(BiometricAuth.biometricType())"
                                : "Require Authentication",
                            message: BiometricAuth.isAvailable()
                                ? "You will be prompted for \(BiometricAuth.biometricType()) before this request is sent."
                                : "⚠️ Biometric authentication is not available on this device. Your passcode will be required instead."
                        )
                    }
                }
                
                Toggle(isOn: $editableRequest.requireConfirmation) {
                    HStack(spacing: 4) {
                        Text("Require Confirmation")
                        InfoButton(
                            title: "Require Confirmation",
                            message: "A confirmation alert will be shown before the request is sent, giving you a chance to cancel."
                        )
                    }
                }
                
                if editableRequest.requireConfirmation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirmation Message")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter confirmation message", text: $editableRequest.confirmationMessage)
                    }
                }
            }
            
            // MARK: - Response
            Section(header: Text("Response")) {
                Toggle(isOn: $editableRequest.showResponse) {
                    HStack(spacing: 4) {
                        Text("Show Response")
                        InfoButton(
                            title: "Show Response",
                            message: "When enabled, the full HTTP response is shown in a popup after sending. When disabled, a brief \"Command sent\" notification appears instead."
                        )
                    }
                }
                
                if editableRequest.showResponse {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("Auto-dismiss")
                            InfoButton(
                                title: "Auto-dismiss",
                                message: "Set how many seconds before the response popup closes automatically. Set to 0 to keep it open until you tap Dismiss."
                            )
                            Spacer()
                            Text(editableRequest.responseTimeout == 0
                                 ? "Off"
                                 : "\(editableRequest.responseTimeout)s")
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(editableRequest.responseTimeout) },
                                set: { editableRequest.responseTimeout = Int($0.rounded()) }
                            ),
                            in: 0...30,
                            step: 1
                        )
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // MARK: - OTP Settings
            Section(header: Text("OTP Settings (Optional)")) {
                Toggle(isOn: $editableRequest.otpEnabled) {
                    HStack(spacing: 4) {
                        Text("Enable Local OTP Generation")
                        InfoButton(
                            title: "OTP Generation",
                            message: "Generates a 6-digit TOTP code locally on your device (RFC 6238). Use {{OTP}} as a placeholder in your request body — it will be replaced with the live code at send time.\n\nSecret formats accepted: Base32 (A–Z, 2–7), hex, or plain text."
                        )
                    }
                }
                
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
                
                HStack(spacing: 4) {
                    Text("Secrets can be used in header values")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    InfoButton(
                        title: "Secrets in Headers",
                        message: "Use {{KEY_NAME}} in any header value to insert a stored secret at send time. Manage your secrets from the main menu."
                    )
                }
            }
            
            // MARK: - Request Body
            Section(header: Text("Request Body (JSON)")) {
                TextEditor(text: $editableRequest.body)
                    .frame(minHeight: 150)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                HStack(spacing: 4) {
                    Text("Placeholders available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    InfoButton(
                        title: "Body Placeholders",
                        message: "Use {{KEY_NAME}} to insert a stored secret.\(editableRequest.otpEnabled ? "\n\nUse {{OTP}} to insert the generated 6-digit OTP code." : "")\n\nManage secrets from the main menu."
                    )
                }
            }
            
            // MARK: - Duplicate / Delete Buttons
            Section {
                Button(action: { showingDuplicateAlert = true }) {
                    HStack {
                        Spacer()
                        Label("Duplicate Button", systemImage: "doc.on.doc")
                        Spacer()
                    }
                }
                .foregroundColor(.blue)
                .disabled(isNew)

                Button(role: .destructive, action: { showingDeleteButtonAlert = true }) {
                    HStack {
                        Spacer()
                        Label("Delete Button", systemImage: "trash")
                        Spacer()
                    }
                }
                .disabled(isNew)
            }
        }
        .navigationTitle(isNew ? "New Button" : "Edit Request")
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
            Button("Delete", role: .destructive) { onDelete(); dismiss() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(editableRequest.buttonTitle)\"?")
        }
        .alert("Delete Header", isPresented: $showingDeleteHeaderAlert) {
            Button("Delete", role: .destructive) {
                if let header = headerToDelete {
                    withAnimation { editableRequest.headers.removeAll(where: { $0.id == header.id }) }
                    headerToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { headerToDelete = nil }
        } message: {
            Text("Are you sure you want to delete the header \"\(headerToDelete?.key.isEmpty == false ? headerToDelete!.key : "unnamed")\"?")
        }
        .alert("Duplicate Button", isPresented: $showingDuplicateAlert) {
            Button("Duplicate") { duplicateAndRename() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will create a copy of \"\(editableRequest.buttonTitle)\". You'll need to enter a new name before saving.")
        }
    }
}

// MARK: - Info Button

/// A small ⓘ placed inline after label text, opens a half-screen explanation sheet.
struct InfoButton: View {
    let title: String
    let message: String
    @State private var isPresented = false
    
    var body: some View {
        Button(action: { isPresented = true }) {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
                .imageScale(.medium)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title2)
                    }
                }
                Divider()
                Text(message)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(24)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
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
