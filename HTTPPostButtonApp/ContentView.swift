import SwiftUI

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
    
    @State private var showingConfirmation = false
    @State private var pendingRequest: PostRequestConfig? = nil
    
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
        .alert("Response", isPresented: $showingResponse) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(responseMessage)
        }
        .alert(pendingRequest?.buttonTitle ?? "Confirm", isPresented: $showingConfirmation) {
            Button("Send", role: .destructive) {
                if let request = pendingRequest { proceedWithRequest(request) }
            }
            Button("Cancel", role: .cancel) { pendingRequest = nil }
        } message: {
            Text(pendingRequest?.confirmationMessage ?? "Confirm to send ?")
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
                self.responseMessage = "Authentication Failed:\n\(error.localizedDescription)"
                self.isError = true
                self.showingResponse = true
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
                self.responseMessage = "Authentication Failed:\n\(error.localizedDescription)"
                self.isError = true
                self.showingResponse = true
            }
        }
    }
    
    private func authenticateThenShowSecrets() {
        BiometricAuth.authenticate(reason: "Authenticate to manage secrets") { result in
            switch result {
            case .success:
                self.showingSecrets = true
            case .failure(let error):
                self.responseMessage = "Authentication Failed:\n\(error.localizedDescription)"
                self.isError = true
                self.showingResponse = true
            }
        }
    }
    
    private func authenticateThenManagePages() {
        BiometricAuth.authenticate(reason: "Authenticate to manage pages") { result in
            switch result {
            case .success:
                self.showingManagePages = true
            case .failure(let error):
                self.responseMessage = "Authentication Failed:\n\(error.localizedDescription)"
                self.isError = true
                self.showingResponse = true
            }
        }
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
                    self.responseMessage = "Authentication Failed:\n\(error.localizedDescription)"
                    self.isError = true
                    self.showingResponse = true
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
                responseMessage = "OTP Generation Failed:\nInvalid secret key. Please check your secret format."
                isError = true
                showingResponse = true
            }
        } else {
            sendMainRequest(request, otp: nil)
        }
    }
    
    private func sendMainRequest(_ request: PostRequestConfig, otp: String?) {
        HTTPService.sendPostRequest(config: request, otp: otp) { result in
            self.isLoading = false
            switch result {
            case .success(let response):
                self.responseMessage = response
                self.isError = false
                self.showingResponse = true
            case .failure(let error):
                self.responseMessage = error.localizedDescription
                self.isError = true
                self.showingResponse = true
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
