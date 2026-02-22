import SwiftUI

//
// SecretsView.swift
// Version 0.7 - UI for managing key-value secrets
// Secrets are stored securely in Keychain and can be used as {{KEY}} placeholders
//

struct SecretsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var secretsManager = SecretsManager()
    
    @State private var showingDeleteAlert = false
    @State private var secretToDelete: SecretItem? = nil
    @State private var showingAddSheet = false
    @State private var editingSecret: SecretItem? = nil
    
    var body: some View {
        NavigationStack {
            Group {
                if secretsManager.secrets.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No secrets configured")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("Tap + to add a key-value secret")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(secretsManager.secrets.sorted(by: { $0.key.lowercased() < $1.key.lowercased() })) { secret in
                            SecretRow(secret: secret, onTap: {
                                editingSecret = secret
                            })
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(action: { editingSecret = secret }) {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.gray)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Secrets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                EditSecretView(
                    secret: SecretItem(),
                    secretsManager: secretsManager,
                    isNew: true,
                    onDelete: { }
                )
            }
            .sheet(item: $editingSecret) { secret in
                EditSecretView(
                    secret: secret,
                    secretsManager: secretsManager,
                    isNew: false,
                    onDelete: {
                        if let index = secretsManager.secrets.firstIndex(where: { $0.id == secret.id }) {
                            secretsManager.deleteSecret(at: IndexSet(integer: index))
                        }
                        editingSecret = nil
                    }
                )
            }
        }
    }
}

// MARK: - Secret Row

struct SecretRow: View {
    let secret: SecretItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(secret.key.isEmpty ? "(unnamed)" : secret.key)
                    .font(.headline)
                    .foregroundColor(secret.key.isEmpty ? .secondary : .primary)
                
                Text("{{\(secret.key)}}")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .opacity(secret.key.isEmpty ? 0.3 : 1.0)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Secret View

struct EditSecretView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var editableSecret: SecretItem
    @ObservedObject var secretsManager: SecretsManager
    let isNew: Bool
    let onDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    @State private var showValue = false
    
    init(secret: SecretItem, secretsManager: SecretsManager, isNew: Bool, onDelete: @escaping () -> Void) {
        _editableSecret = State(initialValue: secret)
        self.secretsManager = secretsManager
        self.isNew = isNew
        self.onDelete = onDelete
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Secret Details")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Key Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., API_KEY, TOKEN", text: $editableSecret.key)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Secret Value")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {
                                showValue.toggle()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: showValue ? "eye.slash.fill" : "eye.fill")
                                    Text(showValue ? "Hide" : "Show")
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                        
                        if showValue {
                            TextEditor(text: $editableSecret.value)
                                .frame(minHeight: 100)
                                .font(.system(.body, design: .monospaced))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            ZStack(alignment: .leading) {
                                if editableSecret.value.isEmpty {
                                    Text("Enter secret value")
                                        .foregroundColor(.secondary.opacity(0.5))
                                        .font(.system(.body, design: .monospaced))
                                }
                                TextField("", text: $editableSecret.value)
                                    .font(.system(.body, design: .monospaced))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textContentType(.none)
                                    .keyboardType(.asciiCapable)
                                    .foregroundColor(.clear)
                                    .accentColor(.clear)
                                    .overlay(
                                        Text(String(repeating: "•", count: editableSecret.value.count))
                                            .font(.system(.body, design: .monospaced))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .allowsHitTesting(false)
                                    )
                            }
                        }
                    }
                }
                
                Section(header: Text("Usage")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Use this secret in your POST request body by adding:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if !editableSecret.key.isEmpty {
                            Text("{{\(editableSecret.key)}}")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        } else {
                            Text("{{YOUR_KEY_NAME}}")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        Text("The placeholder will be replaced with your secret value when the request is sent.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                
                Section(header: Text("Security")) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stored in iOS Keychain")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Your secrets are encrypted and protected by the secure enclave")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                if !isNew {
                    Section {
                        Button(role: .destructive, action: {
                            showingDeleteAlert = true
                        }) {
                            HStack {
                                Spacer()
                                Text("Delete Secret")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Add Secret" : "Edit Secret")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if isNew {
                            secretsManager.addSecret(editableSecret)
                        } else {
                            secretsManager.updateSecret(editableSecret)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(editableSecret.key.isEmpty || editableSecret.value.isEmpty)
                }
            }
            .alert("Delete Secret", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete the secret \"\(editableSecret.key.isEmpty ? "this secret" : editableSecret.key)\"? This cannot be undone.")
            }
        }
    }
}
