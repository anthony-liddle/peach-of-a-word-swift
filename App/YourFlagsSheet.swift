import PeachEngine
import SwiftUI

/// Your flags, on its own (Antoine, 22 November): a sheet, never inside
/// Settings, so the list can't push the game's settings out of view. Opened
/// from Settings' row, or over a card from its line. The web's `YourFlags`.
///
/// Each flag, newest first: the word and its reason, Sent or Waiting to send,
/// and Take back. Taking back the last one closes the list. At the default
/// size Take back sits beside its flag; at the accessibility sizes, under it,
/// the same on every row.
struct YourFlagsSheet: View {
    let store: FlagStore
    let onClose: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var hadFlags = false

    private var card: RoundedRectangle {
        RoundedRectangle(cornerRadius: Cute.cardRadius, style: .continuous)
    }

    var body: some View {
        let newest = Array(store.list.reversed())
        ZStack {
            Cute.pageBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(FlagCopy.yourFlags)
                            .font(CuteFont.display(26, relativeTo: .title2))
                            .foregroundStyle(Cute.ink)
                            .frame(maxWidth: .infinity)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("YourFlagsTitle")
                        VStack(spacing: 0) {
                            ForEach(newest) { flag in
                                row(flag)
                                if flag.id != newest.last?.id {
                                    Rectangle().fill(Cute.rule).frame(height: 1).padding(.leading, 18)
                                }
                            }
                        }
                        .background(card.fill(Cute.paperDeep))
                        .overlay(card.stroke(Cute.tileEdge, lineWidth: 1))
                        Text(store.isFull ? FlagCopy.listNote + " " + FlagCopy.full : FlagCopy.listNote)
                            .font(CuteFont.body(13, relativeTo: .footnote))
                            .foregroundStyle(Cute.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 28)
                }
                .scrollBounceBehavior(.basedOnSize)
                SheetCloseButton(identifier: "YourFlagsClose", action: onClose)
            }
        }
        .onAppear { hadFlags = !store.list.isEmpty }
        // Taking back the last flag leaves nothing to show, so the list closes.
        .onChange(of: store.list.isEmpty) { _, empty in
            if empty && hadFlags { onClose() }
        }
    }

    private func row(_ flag: DeviceFlag) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return layout {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(flag.state == .sent ? "✓" : "◷")
                    .foregroundStyle(Cute.inkFaint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(FlagCopy.row(word: flag.word, reason: flag.reason))
                        .font(CuteFont.body(16, weight: "SemiBold", relativeTo: .body))
                        .foregroundStyle(Cute.ink)
                    Text(FlagCopy.state(flag.state))
                        .font(CuteFont.body(13, relativeTo: .footnote))
                        .foregroundStyle(Cute.inkFaint)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Button { Task { await store.takeBack(flag.id) } } label: {
                Text(FlagCopy.takeBack)
                    .font(CuteFont.body(14, weight: "SemiBold", relativeTo: .subheadline))
                    .foregroundStyle(Cute.accentDeep)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // Named "Take back" on every row, and told apart by its row's word
            // and reason, as the web's `aria-describedby` does.
            .accessibilityLabel(FlagCopy.takeBack)
            .accessibilityValue(FlagCopy.row(word: flag.word, reason: flag.reason))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
