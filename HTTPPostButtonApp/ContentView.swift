import SwiftUI
import UserNotifications
import UniformTypeIdentifiers

//
// ContentView.swift
// Version 0.8 - Main view with page picker in navigation title
// Cleaner design with more screen space for buttons
//

struct ContentView: View {
    @StateObject private var requestStore = RequestStore()
    @StateObject private var pageStore = PageStore()
    @State private var selectedPageId: UUID?
    
    var selectedPage: PageConfig? {
        if let id = selectedPageId {
            // Check if the selected page still exists
            if let page = pageStore.pages.first(where: { $0.id == id }) {
                return page
            } else {
                // Selected page no longer exists, update to a valid page
                DispatchQueue.main.async {
                    if let defaultPageId = pageStore.getDefaultPageId() {
                        selectedPageId = defaultPageId
                    } else if let firstPage = pageStore.pages.first {
                        selectedPageId = firstPage.id
                    } else {
                        selectedPageId = nil
                    }
                }
                return nil
            }
        }
        return pageStore.pages.first
    }
    
    var body: some View {
        NavigationView {
            if let page = selectedPage {
                PageContentView(
                    page: page,
                    requestStore: requestStore,
                    pageStore: pageStore,
                    selectedPageId: $selectedPageId
                )
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No pages created")
                        .font(.title3)
                        .foregroundColor(.gray)
                    Text("Use the menu to create a page")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if selectedPageId == nil {
                selectedPageId = pageStore.getDefaultPageId()
            }
        }
    }
}

// MARK: - Page Content View

struct PageContentView: View {
    let page: PageConfig
    @ObservedObject var requestStore: RequestStore
    @ObservedObject var pageStore: PageStore
    @Binding var selectedPageId: UUID?
    
    @State private var editingRequest: PostRequestConfig?
    @State private var showingResponse = false
    @State private var responseMessage = ""
    @State private var isError = false
    @State private var isLoading = false
    
    @State private var isReordering = false
    @State private var showingAbout = false
    @State private var showingSecrets = false
    @State private var showingManagePages = false
    @State private var backupFileURL: IdentifiableURL? = nil
    @State private var showingRestorePicker = false
    @State private var showingRestoreConfirm = false
    @State private var pendingRestoreURL: URL? = nil
    
    @State private var showingConfirmation = false
    @State private var pendingRequest: PostRequestConfig? = nil
    @State private var responseTimer: DispatchWorkItem? = nil
    
    var buttonsOnThisPage: [PostRequestConfig] {
        requestStore.requests.filter { $0.pageId == page.id }
    }
    
    var body: some View {
        Group {
            if buttonsOnThisPage.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No buttons on this page")
                        .font(.title3)
                        .foregroundColor(.gray)
                    Text("Tap ☰ then \"Add Button\" to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isReordering {
                List {
                    ForEach(buttonsOnThisPage) { request in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(request.buttonColor)
                                .frame(width: 12, height: 12)
                            Text(request.buttonTitle)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .onMove { source, destination in
                        moveButtonsOnPage(from: source, to: destination)
                    }
                }
                .listStyle(.insetGrouped)
                .environment(\.editMode, .constant(.active))
            } else {
                List {
                    ForEach(buttonsOnThisPage) { request in
                        RequestButton(
                            request: request,
                            isLoading: isLoading,
                            onTap: { sendRequest(request) },
                            onEdit: { authenticateThenEdit(request) }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(isReordering ? "Reorder Buttons" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // MARK: - Title (Page Picker)
            ToolbarItem(placement: .principal) {
                if !isReordering {
                    PagePickerView(
                        pages: pageStore.pages,
                        selectedPageId: $selectedPageId
                    )
                } else {
                    Text("Reorder Buttons")
                        .font(.headline)
                }
            }
            
            // MARK: - Menu Button
            ToolbarItem(placement: .navigationBarTrailing) {
                if isReordering {
                    Button(action: {
                        withAnimation { isReordering = false }
                    }) {
                        Text("Done").fontWeight(.semibold)
                    }
                } else {
                    Menu {
                        Button(action: { authenticateThenAdd() }) {
                            Label("Add Button", systemImage: "plus.circle")
                        }
                        Button(action: {
                            withAnimation { isReordering = true }
                        }) {
                            Label("Reorder Buttons", systemImage: "arrow.up.arrow.down")
                        }
                        .disabled(buttonsOnThisPage.count < 2)

                        Divider()
                        
                        Button(action: { authenticateThenManagePages() }) {
                            Label("Manage Pages", systemImage: "square.grid.2x2")
                        }
                        
                        Button(action: { authenticateThenShowSecrets() }) {
                            Label("Secrets", systemImage: "key.fill")
                        }

                        Divider()

                        Button(action: { authenticateThenBackup() }) {
                            Label("Backup Config", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: { authenticateThenRestore() }) {
                            Label("Restore Config", systemImage: "square.and.arrow.down")
                        }

                        Divider()

                        Button(action: { showingAbout = true }) {
                            Label("About", systemImage: "info.circle")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .imageScale(.large)
                    }
                }
            }
        }
        .sheet(item: $editingRequest) { request in
            NavigationStack {
                EditRequestView(
                    request: request,
                    requestStore: requestStore,
                    pageStore: pageStore,
                    currentPageId: page.id,
                    isNew: !requestStore.requests.contains(where: { $0.id == request.id }),
                    onDelete: {
                        if let index = requestStore.requests.firstIndex(where: { $0.id == request.id }) {
                            requestStore.deleteRequest(at: IndexSet(integer: index))
                        }
                        editingRequest = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingSecrets) {
            SecretsView()
        }
        .sheet(isPresented: $showingManagePages) {
            ManagePagesView(pageStore: pageStore, requestStore: requestStore, selectedPageId: $selectedPageId)
        }
        .sheet(item: $backupFileURL, onDismiss: {
            // Clean up temp file after sharing
            if let url = backupFileURL?.url {
                try? FileManager.default.removeItem(at: url)
            }
        }) { identifiableURL in
            ShareSheet(activityItems: [identifiableURL.url])
        }
        .fileImporter(
            isPresented: $showingRestorePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    pendingRestoreURL = url
                    showingRestoreConfirm = true
                }
            case .failure(let error):
                showResponseToast(message: "Could not open file:\n\(error.localizedDescription)", isError: true, timeout: 0)
            }
        }
        .alert("Restore Configuration?", isPresented: $showingRestoreConfirm) {
            Button("Restore", role: .destructive) {
                if let url = pendingRestoreURL {
                    performRestore(from: url)
                    pendingRestoreURL = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingRestoreURL = nil
            }
        } message: {
            Text("This will overwrite ALL existing pages and buttons. Secrets will not be affected. This cannot be undone.")
        }
        .alert(pendingRequest?.buttonTitle ?? "Confirm", isPresented: $showingConfirmation) {
            Button("Send", role: .destructive) {
                if let request = pendingRequest { proceedWithRequest(request) }
            }
            Button("Cancel", role: .cancel) { pendingRequest = nil }
        } message: {
            Text(pendingRequest?.confirmationMessage ?? "Confirm to send ?")
        }
        .sheet(isPresented: $showingResponse) {
            ResponsePopupView(
                message: responseMessage,
                isError: isError,
                onDismiss: { dismissResponse() }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Response Dismissal
    
    private func dismissResponse() {
        responseTimer?.cancel()
        responseTimer = nil
        showingResponse = false
    }
    
    private func sendSentNotification(for request: PostRequestConfig) {
        let content = UNMutableNotificationContent()
        content.title = request.buttonTitle
        content.body = "Command sent"
        content.sound = .default
        content.categoryIdentifier = "COMMAND_SENT"
        content.interruptionLevel = .active
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }
    
    private func showResponseToast(message: String, isError: Bool, timeout: Int) {
        responseMessage = message
        self.isError = isError
        showingResponse = true
        
        responseTimer?.cancel()
        if timeout > 0 {
            let item = DispatchWorkItem { dismissResponse() }
            responseTimer = item
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(timeout), execute: item)
        }
    }
    
    // MARK: - Reordering within page
    
    private func moveButtonsOnPage(from source: IndexSet, to destination: Int) {
        var pageButtons = buttonsOnThisPage
        pageButtons.move(fromOffsets: source, toOffset: destination)
        
        // Update the order in the main request store
        var allRequests = requestStore.requests
        
        // Remove buttons on this page from the main list
        allRequests.removeAll(where: { $0.pageId == page.id })
        
        // Insert reordered page buttons back at the beginning
        for button in pageButtons.reversed() {
            allRequests.insert(button, at: 0)
        }
        
        requestStore.requests = allRequests
        requestStore.saveRequests()
    }
    
    // MARK: - Authentication
    
    private func authenticateThenEdit(_ request: PostRequestConfig) {
        BiometricAuth.authenticate(reason: "Authenticate to edit button settings") { result in
            switch result {
            case .success:
                self.editingRequest = request
            case .failure(let error):
                self.showResponseToast(message: "Authentication Failed:\n\(error.localizedDescription)", isError: true, timeout: 0)
            }
        }
    }
    
    private func authenticateThenAdd() {
        BiometricAuth.authenticate(reason: "Authenticate to add a new button") { result in
            switch result {
            case .success:
                var newButton = PostRequestConfig()
                newButton.pageId = page.id
                self.editingRequest = newButton
            case .failure(let error):
                self.showResponseToast(message: "Authentication Failed:\n\(error.localizedDescription)", isError: true, timeout: 0)
            }
        }
    }
    
    private func authenticateThenShowSecrets() {
        BiometricAuth.authenticate(reason: "Authenticate to manage secrets") { result in
            switch result {
            case .success:
                self.showingSecrets = true
            case .failure(let error):
                self.showResponseToast(message: "Authentication Failed:\n\(error.localizedDescription)", isError: true, timeout: 0)
            }
        }
    }
    
    private func authenticateThenManagePages() {
        BiometricAuth.authenticate(reason: "Authenticate to manage pages") { result in
            switch result {
            case .success:
                self.showingManagePages = true
            case .failure(let error):
                self.showResponseToast(message: "Authentication Failed:\n\(error.localizedDescription)", isError: true, timeout: 0)
            }
        }
    }
    
    private func authenticateThenBackup() {
        BiometricAuth.authenticate(reason: "Authenticate to backup your configuration") { result in
            switch result {
            case .success:
                self.performBackup()
            case .failure(let error):
                self.showResponseToast(message: "Authentication Failed:\n\(error.localizedDescription)", isError: true, timeout: 0)
            }
        }
    }
    
    private func authenticateThenRestore() {
        BiometricAuth.authenticate(reason: "Authenticate to restore your configuration") { result in
            switch result {
            case .success:
                self.showingRestorePicker = true
            case .failure(let error):
                self.showResponseToast(message: "Authentication Failed:\n\(error.localizedDescription)", isError: true, timeout: 0)
            }
        }
    }
    
    private func performBackup() {
        struct BackupPayload: Codable {
            let version: Int
            let exportedAt: String
            let pages: [PageConfig]
            let buttons: [PostRequestConfig]
        }
        
        // Scrub OTP secrets: keep {{PLACEHOLDER}} references, blank out raw secrets
        let safeButtons = requestStore.requests.map { button -> PostRequestConfig in
            var b = button
            if b.otpEnabled {
                let isPlaceholder = b.otpSecret.hasPrefix("{{") && b.otpSecret.hasSuffix("}}")
                if !isPlaceholder {
                    b.otpSecret = ""   // Raw secret — strip it from backup
                }
                // Placeholder references like {{MY_OTP_KEY}} are kept as-is
            }
            return b
        }
        
        let formatter = ISO8601DateFormatter()
        let payload = BackupPayload(
            version: 1,
            exportedAt: formatter.string(from: Date()),
            pages: pageStore.pages,
            buttons: safeButtons
        )
        
        guard let data = try? JSONEncoder().encode(payload) else {
            showResponseToast(message: "Backup failed: could not encode configuration.", isError: true, timeout: 0)
            return
        }
        
        // Write to a temp file with a dated name
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let fileName = "QikPOST_Backup_\(dateStr).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempURL)
            backupFileURL = IdentifiableURL(url: tempURL)
        } catch {
            showResponseToast(message: "Backup failed: \(error.localizedDescription)", isError: true, timeout: 0)
        }
    }
    
    private func performRestore(from url: URL) {
        struct BackupPayload: Codable {
            let version: Int
            let exportedAt: String?
            let pages: [PageConfig]
            let buttons: [PostRequestConfig]
        }
        
        // Security-scoped resource access needed for files picked via Files app
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        
        guard let data = try? Data(contentsOf: url) else {
            showResponseToast(message: "Restore failed: could not read file.", isError: true, timeout: 0)
            return
        }
        
        guard let payload = try? JSONDecoder().decode(BackupPayload.self, from: data) else {
            showResponseToast(message: "Restore failed: invalid or corrupted backup file.", isError: true, timeout: 0)
            return
        }
        
        guard !payload.pages.isEmpty else {
            showResponseToast(message: "Restore failed: backup contains no pages.", isError: true, timeout: 0)
            return
        }
        
        // Overwrite pages
        pageStore.pages = payload.pages.sorted(by: { $0.order < $1.order })
        pageStore.savePages()
        
        // Overwrite buttons (secrets untouched — they live in Keychain separately)
        requestStore.requests = payload.buttons
        requestStore.saveRequests()
        
        // Navigate to the first page of the restored config
        selectedPageId = pageStore.pages.first?.id
        
        let buttonCount = payload.buttons.count
        let pageCount = payload.pages.count
        showResponseToast(
            message: "Restore complete.\n\(pageCount) page\(pageCount == 1 ? "" : "s") and \(buttonCount) button\(buttonCount == 1 ? "" : "s") restored.",
            isError: false,
            timeout: 5
        )
    }
    
    // MARK: - Request Handling
    
    private func sendRequest(_ request: PostRequestConfig) {
        if request.requireConfirmation {
            pendingRequest = request
            showingConfirmation = true
            return
        }
        proceedWithRequest(request)
    }
    
    private func proceedWithRequest(_ request: PostRequestConfig) {
        if request.requireBiometric {
            BiometricAuth.authenticate(reason: "Authenticate to send request") { result in
                switch result {
                case .success:
                    self.performRequest(request)
                case .failure(let error):
                    self.showResponseToast(message: "Authentication Failed:\n\(error.localizedDescription)", isError: true, timeout: 0)
                }
            }
        } else {
            performRequest(request)
        }
    }
    
    private func performRequest(_ request: PostRequestConfig) {
        isLoading = true
        if request.otpEnabled {
            // Replace {{KEY}} placeholders in the OTP secret
            let resolvedSecret = SecretsManager.replacePlaceholdersStatic(in: request.otpSecret)
            
            if let otp = OTPGenerator.generateTOTP(secret: resolvedSecret) {
                sendMainRequest(request, otp: otp)
            } else {
                isLoading = false
                if request.showResponse {
                    showResponseToast(message: "OTP Generation Failed:\nInvalid secret key. Please check your secret format.", isError: true, timeout: 0)
                } else {
                    sendSentNotification(for: request)
                }
            }
        } else {
            sendMainRequest(request, otp: nil)
        }
    }
    
    private func sendMainRequest(_ request: PostRequestConfig, otp: String?) {
        HTTPService.sendPostRequest(config: request, otp: otp) { result in
            self.isLoading = false
            if request.showResponse {
                switch result {
                case .success(let response):
                    self.showResponseToast(message: response, isError: false, timeout: request.responseTimeout)
                case .failure(let error):
                    self.showResponseToast(message: error.localizedDescription, isError: true, timeout: request.responseTimeout)
                }
            } else {
                self.sendSentNotification(for: request)
            }
        }
    }
}

// MARK: - Page Picker View

struct PagePickerView: View {
    let pages: [PageConfig]
    @Binding var selectedPageId: UUID?
    
    var body: some View {
        Menu {
            ForEach(pages) { page in
                Button(action: {
                    selectedPageId = page.id
                }) {
                    HStack {
                        Image(systemName: page.iconName)
                            .foregroundColor(page.iconColor)
                        Text(page.name)
                        if selectedPageId == page.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let currentPage = pages.first(where: { $0.id == selectedPageId }) {
                    Image(systemName: currentPage.iconName)
                        .font(.headline)
                        .foregroundColor(currentPage.iconColor)
                    Text(currentPage.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                } else {
                    Text("Select Page")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                Image("AboutIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .cornerRadius(18)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 8) {
                    Text(Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
                         ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
                         ?? "HTTP POST buttons")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("(HTTP Post)")
                        .font(.title3)
                    Text("Version \(appVersion)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Divider().padding(.horizontal, 40)
                VStack(spacing: 4) {
                    Text("Created by")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Barry")
                        .font(.headline)
                }
                Spacer()
                Spacer()
            }
            .padding()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Request Button

struct RequestButton: View {
    let request: PostRequestConfig
    let isLoading: Bool
    let onTap: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Spacer()
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Text(request.buttonTitle)
                        .fontWeight(.medium)
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(request.buttonColor)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(isLoading)
        .highPriorityGesture(LongPressGesture(minimumDuration: 0.5))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.gray)
        }
    }
}

// MARK: - Response Popup View

/// A sheet presented in the centre of the screen (using .presentationDetents)
/// that mimics the system alert style with a large, easy-to-tap Dismiss button.
struct ResponsePopupView: View {
    let message: String
    let isError: Bool
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(isError ? .red : .green)
                    .padding(.top, 28)

                Text(isError ? "Error" : "Response")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding(.bottom, 16)

            Divider()

            // Scrollable response body
            ScrollView {
                Text(message)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }

            Divider()

            // Large, easy-to-tap dismiss button
            Button(action: onDismiss) {
                Text("Dismiss")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .foregroundColor(.blue)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - IdentifiableURL (for sheet(item:) presentation)

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Share Sheet (UIActivityViewController wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
