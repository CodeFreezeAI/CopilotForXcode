import SwiftUI
import ComposableArchitecture
import ConversationServiceProvider
import SharedUIComponents

struct ThinkingView: View {
    let thinking: MessageThinking
    let isStreaming: Bool

    @AppStorage(\.chatFontSize) var chatFontSize
    @State private var isExpandedOverride: Bool? = nil

    private var sections: [ThinkingSection] {
        MessageThinking.parseSections(from: thinking.text?.joined() ?? "")
    }

    private var titleText: String {
        if isStreaming {
            return "Thinking..."
        }
        if let title = thinking.title, !title.isEmpty {
            return title
        }
        return "Thinking"
    }

    private var isExpanded: Bool {
        if let override = isExpandedOverride { return override }
        return isStreaming
    }

    private var isAutoExpandedWhileStreaming: Bool {
        isStreaming && isExpandedOverride == nil
    }

    private static let autoExpandMaxHeight: CGFloat = 180
    private static let scrollAnchorID = "thinking-bottom-anchor"

    var body: some View {
        WithPerceptionTracking {
            let sections = sections
            let hasContent = sections.contains { $0.title != nil || !$0.body.isEmpty }
            if hasContent || isStreaming {
                content(sections: sections, hasContent: hasContent)
            }
        }
    }

    @ViewBuilder
    private func content(sections: [ThinkingSection], hasContent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isExpandedOverride = !isExpanded
            } label: {
                HStack(spacing: 2) {
                    Text(titleText)
                        .scaledFont(size: chatFontSize - 1)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                        .scaledFrame(width: 16, height: 16)
                        .scaledFont(size: 10, weight: .medium)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if isExpanded, hasContent {
                sectionsContainer(sections: sections)
            }
        }
    }

    @ViewBuilder
    private func sectionsContainer(sections: [ThinkingSection]) -> some View {
        let stack = VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                sectionView(section)
            }
            Color.clear
                .frame(height: 0)
                .id(Self.scrollAnchorID)
        }
        .fixedSize(horizontal: false, vertical: true)

        if isAutoExpandedWhileStreaming {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    stack
                }
                .frame(maxHeight: Self.autoExpandMaxHeight)
                .onChange(of: thinking.text?.joined() ?? "") { _ in
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(Self.scrollAnchorID, anchor: .bottom)
                    }
                }
                .onAppear {
                    proxy.scrollTo(Self.scrollAnchorID, anchor: .bottom)
                }
            }
        } else {
            stack
        }
    }

    @ViewBuilder
    private func sectionView(_ section: ThinkingSection) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 4) {
                Circle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 4, height: 4)
                    .padding(.top, 6)
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                if let title = section.title, !title.isEmpty {
                    Text(title)
                        .scaledFont(size: chatFontSize - 1)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !section.body.isEmpty {
                    ThemedMarkdownText(
                        text: section.body,
                        context: MarkdownActionProvider(supportInsert: false),
                        foregroundColor: .secondary
                    )
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
