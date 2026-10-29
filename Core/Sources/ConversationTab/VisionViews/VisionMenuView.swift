import SwiftUI
import SharedUIComponents
import Logger
import ComposableArchitecture
import ConversationServiceProvider
import AppKit
import UniformTypeIdentifiers

public struct VisionMenuView: View {
    let chat: StoreOf<Chat>
    @AppStorage(\.capturePermissionShown) var capturePermissionShown: Bool
    @State private var shouldPresentScreenRecordingPermissionAlert: Bool = false

    func showImagePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .bmp, .gif, .tiff, .webP]
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.level = .modalPanel
        
        // Position the panel relative to the current window
        if let window = NSApplication.shared.keyWindow {
            let windowFrame = window.frame
            let panelSize = CGSize(width: 600, height: 400)
            let x = windowFrame.midX - panelSize.width / 2
            let y = windowFrame.midY - panelSize.height / 2
            panel.setFrame(NSRect(origin: CGPoint(x: x, y: y), size: panelSize), display: true)
        }
        
        panel.begin { response in
            if response == .OK {
                let selectedImageURLs = panel.urls
                handleSelectedImages(selectedImageURLs)
            }
        }
    }

    func handleSelectedImages(_ urls: [URL]) {
        for url in urls {
            let gotAccess = url.startAccessingSecurityScopedResource()
            if gotAccess {
                // Process the image file
                if let imageData = try? Data(contentsOf: url) {
                    // imageData now contains the binary data of the image
                    Logger.client.info("Add selected image from URL: \(url)")
                    let imageReference = ImageReference(data: imageData, fileUrl: url)
                    chat.send(.addSelectedImage(imageReference))
                }
                
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
    
    func runScreenCapture(args: [String] = []) {
        let hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
        if !hasScreenRecordingPermission {
            if capturePermissionShown {
                shouldPresentScreenRecordingPermissionAlert = true
            } else {
                CGRequestScreenCaptureAccess()
                capturePermissionShown = true
            }
            return
        }
        
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = args
        task.terminationHandler = { _ in
            DispatchQueue.main.async {
                if task.terminationStatus == 0 {
                    if let data = NSPasteboard.general.data(forType: .png) {
                        chat.send(.addSelectedImage(ImageReference(data: data, source: .screenshot)))
                    } else if let tiffData = NSPasteboard.general.data(forType: .tiff),
                              let imageRep = NSBitmapImageRep(data: tiffData),
                              let pngData = imageRep.representation(using: .png, properties: [:]) {
                        chat.send(.addSelectedImage(ImageReference(data: pngData, source: .screenshot)))
                    }
                }
            }
        }
        task.launch()
        task.waitUntilExit()
    }
    
    public var body: some View {
        Menu {
            Button(action: { runScreenCapture(args: ["-w", "-c"]) }) {
                Image(systemName: "macwindow")
                Text("Capture Window")
            }
            .scaledFont(.body)
            
            Button(action: { runScreenCapture(args: ["-s", "-c"]) }) {
                Image(systemName: "macwindow.and.cursorarrow")
                Text("Capture Selection")
            }
            .scaledFont(.body)
            
            Button(action: { showImagePicker() }) {
                Image(systemName: "photo")
                Text("Attach File")
            }
            .scaledFont(.body)
        } label: {
            Image(systemName: "photo.badge.plus")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaledFrame(width: 16, height: 16)
                .scaledPadding(4)
                .foregroundColor(.primary.opacity(0.85))
                .scaledFont(size: 11, weight: .semibold)
        }
        .buttonStyle(HoverButtonStyle(padding: 0))
        .help("Attach images")
        .cornerRadius(6)
        .alert(
            "Enable Screen & System Recording Permission",
            isPresented: $shouldPresentScreenRecordingPermissionAlert
        ) {
            Button(
            "Open System Settings",
            action: {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture")!)
            }).keyboardShortcut(.defaultAction)
                .scaledFont(.body)
            
            Button("Deny", role: .cancel, action: {})
                .scaledFont(.body)
        } message: {
            Text("Grant access to this application in Privacy & Security settings, located in System Settings")
                .scaledFont(.body)
        }
    }
}
