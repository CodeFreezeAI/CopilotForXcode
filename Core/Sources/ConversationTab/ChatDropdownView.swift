import ConversationServiceProvider
import AppKit
import SwiftUI
import ComposableArchitecture

protocol DropDownItem: Equatable {
    var id: String { get }
    var displayName: String { get }
    var displayDescription: String { get }
}

extension ChatTemplate: DropDownItem {
    var displayName: String { id }
    var displayDescription: String { description }
}

extension ChatAgent: DropDownItem {
    var id: String { slug }
    var displayName: String { slug }
    var displayDescription: String { description }
}

struct ChatDropdownView<T: DropDownItem>: View {
    @Binding var items: [T]
    let prefixSymbol: String
    let onSelect: (T) -> Void
    @State private var selectedIndex = 0
    @State private var frameHeight: CGFloat = 0
    @State private var localMonitor: Any? = nil

    public var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack {
                        Text(prefixSymbol + item.displayName)
                            .hoverPrimaryForeground(isHovered: selectedIndex == index)
                        Spacer()
                        Text(item.displayDescription)
                            .hoverSecondaryForeground(isHovered: selectedIndex == index)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(item)
                    }
                    .hoverBackground(isHovered: selectedIndex == index)
                    .onHover { isHovered in
                        if isHovered {
                            selectedIndex = index
                        }
                    }
                }
            }
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { frameHeight = geometry.size.height }
                        .onChange(of: geometry.size.height) { newHeight in
                            frameHeight = newHeight
                        }
                }
            )
            .background(.ultraThickMaterial)
            .cornerRadius(6)
            .shadow(radius: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .frame(maxWidth: .infinity)
            .offset(y: -1 * frameHeight)
            .onChange(of: items) { _ in
                selectedIndex = 0
            }
            .onAppear {
                selectedIndex = 0
                localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    switch event.keyCode {
                    case 126: // Up arrow
                        moveSelection(up: true)
                        return nil
                    case 125: // Down arrow
                        moveSelection(up: false)
                        return nil
                    case 36: // Return key
                        handleEnter()
                        return nil
                    case 48: // Tab key
                        handleTab()
                        return nil // not forwarding the Tab Event which will replace the typed message to "\t"
                    default:
                        break
                    }
                    return event
                }
            }
            .onDisappear {
                if let monitor = localMonitor {
                    NSEvent.removeMonitor(monitor)
                    localMonitor = nil
                }
            }
        }
    }

    private func moveSelection(up: Bool) {
        guard !items.isEmpty else { return }
        let lowerBound = 0
        let upperBound = items.count - 1
        let newIndex = selectedIndex + (up ? -1 : 1)
        selectedIndex = newIndex < lowerBound ? upperBound : (newIndex > upperBound ? lowerBound : newIndex)
    }
    
    private func handleEnter() {
        handleTemplateSelection()
    }
    
    private func handleTab() {
        handleTemplateSelection()
    }
    
    private func handleTemplateSelection() {
        if items.count > 0 && selectedIndex < items.count {
            onSelect(items[selectedIndex])
        }
    }
}
