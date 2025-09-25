import SharedUIComponents
import SwiftUI

/// Reusable search control with a toggleable magnifying glass button that expands
/// into a styled search field with clear button, focus handling, and auto-hide
/// when focus is lost and the text is empty.
///
/// Usage:
/// SearchBar(isVisible: $isSearchBarVisible, text: $searchText)
struct SearchBar: View {
    @Binding var isVisible: Bool
    @Binding var text: String

    @FocusState private var isFocused: Bool

    var placeholder: String = "Search..."
    var accessibilityIdentifier: String = "searchTextField"

    var body: some View {
        Group {
            if isVisible {
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .onTapGesture { withAnimation(.easeInOut) {
                            isVisible = false
                        } }

                    TextField(placeholder, text: $text)
                        .accessibilityIdentifier(accessibilityIdentifier)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isFocused)

                    if !text.isEmpty {
                        Button(action: { text = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Clear search")
                    }
                }
                .padding(.leading, 7)
                .padding(.trailing, 3)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(.textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(
                            isFocused
                                ? Color(red: 0, green: 0.48, blue: 1).opacity(0.5)
                                : Color.gray.opacity(0.4),
                            lineWidth: isFocused ? 3 : 1
                        )
                )
                .cornerRadius(5)
                .frame(width: 212, height: 20, alignment: .leading)
                .shadow(color: Color(red: 0, green: 0.48, blue: 1).opacity(0.5), radius: isFocused ? 1.25 : 0, x: 0, y: 0)
                .shadow(color: .black.opacity(0.05), radius: 0, x: 0, y: 0)
                .shadow(color: .black.opacity(0.3), radius: 1.25, x: 0, y: 0.5)
                .padding(2)
                // Removed the move(edge: .trailing) to prevent overlap; keep a clean fade instead
                .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                .onChange(of: isFocused) { focused in
                    if !focused && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        withAnimation(.easeInOut) {
                            isVisible = false
                        }
                    }
                }
                .onChange(of: isVisible) { newValue in
                    if newValue {
                        // Delay to ensure the field is mounted before requesting focus.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isFocused = true
                        }
                    }
                }
            } else {
                Button(action: {
                    withAnimation(.easeInOut) {
                        isVisible = true
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                        .padding(.trailing, 2)
                }
                .buttonStyle(HoverButtonStyle())
                .frame(height: 24)
                .transition(.opacity)
                .help("Show search")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if isFocused { isFocused = false } }
    }
}
