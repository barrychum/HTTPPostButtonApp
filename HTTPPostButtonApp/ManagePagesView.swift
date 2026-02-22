import SwiftUI

//
// ManagePagesView.swift
// Version 0.8 - UI for managing pages (tabs)
// Allows creating, editing, reordering, and deleting pages
//

struct ManagePagesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var pageStore: PageStore
    @ObservedObject var requestStore: RequestStore
    @Binding var selectedPageId: UUID?
    
    @State private var editingPage: PageConfig? = nil
    @State private var showingAddPage = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(pageStore.pages) { page in
                    PageRow(
                        page: page,
                        buttonCount: requestStore.requests.filter { $0.pageId == page.id }.count,
                        isDefault: pageStore.getDefaultPageId() == page.id,
                        onTap: {
                            editingPage = page
                        }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if pageStore.getDefaultPageId() != page.id {
                            Button(role: .destructive, action: {
                                if let index = pageStore.pages.firstIndex(where: { $0.id == page.id }) {
                                    handleDelete(at: IndexSet(integer: index))
                                }
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .onMove { source, destination in
                    pageStore.movePage(from: source, to: destination)
                }
                
                Button(action: {
                    showingAddPage = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Add New Page")
                            .foregroundColor(.blue)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Manage Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $editingPage) { page in
                EditPageView(
                    page: page,
                    pageStore: pageStore,
                    requestStore: requestStore,
                    selectedPageId: $selectedPageId,
                    isNew: false
                )
            }
            .sheet(isPresented: $showingAddPage) {
                EditPageView(
                    page: PageConfig(name: "New Page", order: pageStore.pages.count),
                    pageStore: pageStore,
                    requestStore: requestStore,
                    selectedPageId: $selectedPageId,
                    isNew: true
                )
            }
        }
    }
    
    private func handleDelete(at offsets: IndexSet) {
        // Check if any of the pages being deleted is the default page
        for index in offsets {
            let page = pageStore.pages[index]
            if pageStore.getDefaultPageId() == page.id {
                // Don't allow deleting the default page - open it to show the message
                editingPage = page
                return
            }
        }
        
        // Check if any pages have buttons
        for index in offsets {
            let page = pageStore.pages[index]
            let buttonsOnPage = requestStore.requests.filter { $0.pageId == page.id }
            
            if !buttonsOnPage.isEmpty {
                // This page has buttons - open it to handle them
                editingPage = page
                return
            }
        }
        
        // Check if we're deleting the currently selected page
        var isDeletingCurrentPage = false
        for index in offsets {
            let page = pageStore.pages[index]
            if selectedPageId == page.id {
                isDeletingCurrentPage = true
                break
            }
        }
        
        // All pages are safe to delete (not default, no buttons)
        pageStore.deletePage(at: offsets)
        
        // If we just deleted the currently selected page, switch to another page
        if isDeletingCurrentPage {
            // Switch to the default page, or the first available page
            if let defaultPageId = pageStore.getDefaultPageId() {
                selectedPageId = defaultPageId
            } else if let firstPage = pageStore.pages.first {
                selectedPageId = firstPage.id
            } else {
                selectedPageId = nil
            }
        }
    }
}

// MARK: - Page Row

struct PageRow: View {
    let page: PageConfig
    let buttonCount: Int
    let isDefault: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: page.iconName)
                    .font(.title3)
                    .foregroundColor(page.iconColor)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(page.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if isDefault {
                            Text("DEFAULT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("\(buttonCount) button\(buttonCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .deleteDisabled(true)
    }
}

// MARK: - Edit Page View

struct EditPageView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var editablePage: PageConfig
    @ObservedObject var pageStore: PageStore
    @ObservedObject var requestStore: RequestStore
    @Binding var selectedPageId: UUID?
    let isNew: Bool
    
    @State private var showingDeleteAlert = false
    @State private var showingMoveButtonsSheet = false
    @State private var selectedDestinationPage: PageConfig?
    @State private var deleteButtons = false
    
    init(page: PageConfig, pageStore: PageStore, requestStore: RequestStore, selectedPageId: Binding<UUID?>, isNew: Bool) {
        _editablePage = State(initialValue: page)
        self.pageStore = pageStore
        self.requestStore = requestStore
        _selectedPageId = selectedPageId
        self.isNew = isNew
    }
    
    var buttonsOnThisPage: [PostRequestConfig] {
        requestStore.requests.filter { $0.pageId == editablePage.id }
    }
    
    var otherPages: [PageConfig] {
        pageStore.pages.filter { $0.id != editablePage.id }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Page Details")) {
                    TextField("Page Name", text: $editablePage.name)
                }
                
                Section(header: Text("Page Icon")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                        ForEach(availablePageIcons, id: \.symbol) { icon in
                            PageIconButton(
                                symbolName: icon.symbol,
                                color: editablePage.iconColor,
                                isSelected: editablePage.iconName == icon.symbol,
                                onTap: {
                                    editablePage.iconName = icon.symbol
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Icon Color")) {
                    HStack {
                        Text("Select Color")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Color picker as a colored circle
                        ColorPicker("", selection: Binding(
                            get: { editablePage.iconColor },
                            set: { newColor in
                                editablePage.iconColorHex = newColor.hexString
                            }
                        ))
                        .labelsHidden()
                        .scaleEffect(1.2)
                    }
                    .padding(.vertical, 4)
                    
                    // Preview with icon
                    HStack {
                        Text("Preview:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: editablePage.iconName)
                            .font(.system(size: 40))
                            .foregroundColor(editablePage.iconColor)
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    HStack {
                        Text("Buttons on this page")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(buttonsOnThisPage.count)")
                            .fontWeight(.semibold)
                    }
                    
                    Toggle("Set as Default Page", isOn: Binding(
                        get: { pageStore.getDefaultPageId() == editablePage.id },
                        set: { isDefault in
                            if isDefault {
                                pageStore.setDefaultPage(editablePage.id)
                            }
                        }
                    ))
                }
                
                if !isNew {
                    Section {
                        Button(role: .destructive, action: {
                            if buttonsOnThisPage.isEmpty {
                                pageStore.deletePage(editablePage)
                                dismiss()
                            } else {
                                showingDeleteAlert = true
                            }
                        }) {
                            HStack {
                                Spacer()
                                Text("Delete Page")
                                Spacer()
                            }
                        }
                        .disabled(pageStore.getDefaultPageId() == editablePage.id)
                    } footer: {
                        if pageStore.getDefaultPageId() == editablePage.id {
                            Text("Cannot delete the default page. Set another page as default first.")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New Page" : "Edit Page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if isNew {
                            pageStore.addPage(editablePage)
                        } else {
                            pageStore.updatePage(editablePage)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(editablePage.name.isEmpty)
                }
            }
            .alert("Delete Page", isPresented: $showingDeleteAlert) {
                Button("Move Buttons to Another Page", role: .none) {
                    showingMoveButtonsSheet = true
                }
                Button("Delete All Buttons", role: .destructive) {
                    deleteButtons = true
                    performDelete()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This page has \(buttonsOnThisPage.count) button\(buttonsOnThisPage.count == 1 ? "" : "s"). What would you like to do?")
            }
            .sheet(isPresented: $showingMoveButtonsSheet) {
                MoveButtonsSheet(
                    pages: otherPages,
                    onSelect: { destinationPage in
                        selectedDestinationPage = destinationPage
                        performDelete()
                    }
                )
            }
        }
    }
    
    private func performDelete() {
        // Check if we're deleting the currently selected page
        let isDeletingCurrentPage = selectedPageId == editablePage.id
        
        // Move buttons to another page or delete them
        if let destinationPage = selectedDestinationPage {
            for button in buttonsOnThisPage {
                var updatedButton = button
                updatedButton.pageId = destinationPage.id
                requestStore.updateRequest(updatedButton)
            }
        } else if deleteButtons {
            for button in buttonsOnThisPage {
                if let index = requestStore.requests.firstIndex(where: { $0.id == button.id }) {
                    requestStore.deleteRequest(at: IndexSet(integer: index))
                }
            }
        }
        
        // Delete the page
        pageStore.deletePage(editablePage)
        
        // If we just deleted the currently selected page, switch to another page
        if isDeletingCurrentPage {
            // Switch to the default page, or the first available page
            if let defaultPageId = pageStore.getDefaultPageId() {
                selectedPageId = defaultPageId
            } else if let firstPage = pageStore.pages.first {
                selectedPageId = firstPage.id
            } else {
                selectedPageId = nil
            }
        }
        
        dismiss()
    }
}

// MARK: - Page Icon Button

struct PageIconButton: View {
    let symbolName: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(isSelected ? color.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: symbolName)
                    .font(.title3)
                    .foregroundColor(isSelected ? color : .secondary)
                
                if isSelected {
                    Circle()
                        .strokeBorder(color, lineWidth: 2)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Move Buttons Sheet

struct MoveButtonsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let pages: [PageConfig]
    let onSelect: (PageConfig) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(pages) { page in
                    Button(action: {
                        onSelect(page)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: page.iconName)
                                .foregroundColor(page.iconColor)
                            Text(page.name)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Move Buttons To")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
