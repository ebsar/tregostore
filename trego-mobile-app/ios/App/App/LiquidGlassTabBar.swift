import SwiftUI

// Why the previous version felt wrong:
// - It was too opaque, so it read like a slab instead of a light glass surface above content.
// - The warm peach tint was too visible, which pushed it away from Apple's neutral Liquid Glass language.
// - The selected state looked like a flat card sitting on top of the bar instead of a brighter glass lobe inside it.
// - Depth was shallow: not enough translucency, not enough edge light, and the fill dominated the glass behavior.

enum LiquidGlassTab: String, CaseIterable, Identifiable {
    case home
    case kerko
    case wishlist
    case cart
    case llogaria

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .kerko: return "Kerko"
        case .wishlist: return "Wishlist"
        case .cart: return "Cart"
        case .llogaria: return "Llogaria"
        }
    }

    var symbolName: String {
        switch self {
        case .home: return "house"
        case .kerko: return "magnifyingglass"
        case .wishlist: return "heart"
        case .cart: return "cart"
        case .llogaria: return "person.circle"
        }
    }
}

struct LiquidGlassTabBar: View {
    @Binding var selection: LiquidGlassTab
    var badges: [LiquidGlassTab: String] = [:]
    var onSelectionChange: ((LiquidGlassTab) -> Void)? = nil
    @Namespace private var selectionNamespace
    @Namespace private var glassNamespace

    var body: some View {
        Group {
#if compiler(>=6.2)
            if #available(iOS 26.0, *) {
                LiquidGlassTabBarModern(
                    selection: $selection,
                    badges: badges,
                    onSelectionChange: onSelectionChange,
                    selectionNamespace: selectionNamespace,
                    glassNamespace: glassNamespace
                )
            } else {
                LiquidGlassTabBarFallback(
                    selection: $selection,
                    badges: badges,
                    onSelectionChange: onSelectionChange,
                    selectionNamespace: selectionNamespace
                )
            }
#else
            LiquidGlassTabBarFallback(
                selection: $selection,
                badges: badges,
                onSelectionChange: onSelectionChange,
                selectionNamespace: selectionNamespace
            )
#endif
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}

#if compiler(>=6.2)
@available(iOS 26.0, *)
private struct LiquidGlassTabBarModern: View {
    @Binding var selection: LiquidGlassTab
    let badges: [LiquidGlassTab: String]
    let onSelectionChange: ((LiquidGlassTab) -> Void)?
    let selectionNamespace: Namespace.ID
    let glassNamespace: Namespace.ID

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            ZStack {
                // Outer glass container:
                // This is the shared capsule that holds the whole navigation group.
                // The glass effect lives on a clear host view so the result stays airy and translucent,
                // while the thin white stroke provides the edge highlight seen in native iOS glass.
                Color.clear
                    .frame(height: 82)
                    .glassEffect(
                        .regular
                            .tint(.white.opacity(0.015)),
                        in: Capsule()
                    )
                    .glassEffectID("liquid-glass-tabbar-shell", in: glassNamespace)
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.56), lineWidth: 0.9)
                            .blendMode(.screen)
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.44),
                                        .white.opacity(0.14),
                                        .white.opacity(0.3),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                            .padding(1)
                    }
                    .shadow(color: .black.opacity(0.055), radius: 16, y: 8)

                HStack(spacing: 0) {
                    ForEach(LiquidGlassTab.allCases) { tab in
                        Button {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0.18)) {
                                selection = tab
                            }
                            onSelectionChange?(tab)
                        } label: {
                            tabButton(tab, badge: badges[tab])
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func tabButton(_ tab: LiquidGlassTab, badge: String?) -> some View {
        let isSelected = selection == tab

        ZStack {
            // Selected glass blob:
            // Instead of a flat tile, the selected tab gets its own brighter glass shape,
            // still inside the same glass container. This makes it feel embedded into the bar.
            if isSelected {
                Color.clear
                    .matchedGeometryEffect(id: "liquid-glass-selected-tab", in: selectionNamespace)
                    .glassEffect(
                        .regular
                            .tint(.white.opacity(0.045))
                            .interactive(),
                        in: Capsule()
                    )
                    .glassEffectID("liquid-glass-selected-blob", in: glassNamespace)
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.42), lineWidth: 0.75)
                    }
                    .overlay {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.26),
                                        .white.opacity(0.08),
                                        .clear,
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .padding(1)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }

            VStack(spacing: 6) {
                Image(systemName: tab.symbolName)
                    .font(.system(size: 22, weight: .medium))
                    .frame(height: 22)

                Text(tab.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .contentShape(Rectangle())
            .foregroundStyle(
                isSelected
                    ? Color.black.opacity(0.84)
                    : Color.black.opacity(0.64)
            )

            if let badge, !badge.isEmpty {
                badgeView(badge)
                    .offset(x: 20, y: -18)
            }
        }
        // Animation:
        // matchedGeometryEffect keeps the selected blob moving as one continuous surface
        // instead of fading out/in between tabs.
        .frame(maxWidth: .infinity)
    }

    private func badgeView(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.black.opacity(0.84))
            .padding(.horizontal, 7)
            .frame(minWidth: 18, minHeight: 18)
            .background(
                Capsule()
                    .fill(.white.opacity(0.62))
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.74), lineWidth: 0.6)
                    }
            )
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}
#endif

private struct LiquidGlassTabBarFallback: View {
    @Binding var selection: LiquidGlassTab
    let badges: [LiquidGlassTab: String]
    let onSelectionChange: ((LiquidGlassTab) -> Void)?
    let selectionNamespace: Namespace.ID

    var body: some View {
        ZStack {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(0.58), lineWidth: 0.9)
                }
                .shadow(color: .black.opacity(0.05), radius: 16, y: 8)

            HStack(spacing: 0) {
                ForEach(LiquidGlassTab.allCases) { tab in
                    Button {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0.18)) {
                            selection = tab
                        }
                        onSelectionChange?(tab)
                    } label: {
                        fallbackTabButton(tab, badge: badges[tab])
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 82)
    }

    @ViewBuilder
    private func fallbackTabButton(_ tab: LiquidGlassTab, badge: String?) -> some View {
        let isSelected = selection == tab

        ZStack {
            if isSelected {
                Capsule()
                    .fill(.regularMaterial)
                    .matchedGeometryEffect(id: "liquid-glass-selected-tab", in: selectionNamespace)
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.42), lineWidth: 0.75)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }

            VStack(spacing: 6) {
                Image(systemName: tab.symbolName)
                    .font(.system(size: 22, weight: .medium))
                    .frame(height: 22)

                Text(tab.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .contentShape(Rectangle())
            .foregroundStyle(
                isSelected
                    ? Color.black.opacity(0.84)
                    : Color.black.opacity(0.62)
            )

            if let badge, !badge.isEmpty {
                Text(badge)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .padding(.horizontal, 7)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.72))
                            .overlay {
                                Capsule()
                                    .strokeBorder(.white.opacity(0.8), lineWidth: 0.6)
                            }
                    )
                    .offset(x: 20, y: -18)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct ContentView: View {
    @State private var selection: LiquidGlassTab = .home

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("NOW TRENDING")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("Pick The Perfect Tab")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                ForEach(0..<12, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    Color.white.opacity(0.68),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(alignment: .leading) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Featured \(index + 1)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text("Liquid Glass Demo Card")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text("This background exists only to show the translucency and layered reflection of the floating tab bar.")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(24)
                        }
                        .frame(height: 180)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 140)
        }
        .background(demoBackground)
        .safeAreaInset(edge: .bottom) {
            LiquidGlassTabBar(selection: $selection)
        }
    }

    private var demoBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.96, blue: 0.95),
                Color(red: 0.91, green: 0.93, blue: 0.96),
                Color(red: 0.97, green: 0.96, blue: 0.95),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.62))
                    .frame(width: 260, height: 260)
                    .blur(radius: 16)
                    .offset(x: -120, y: -240)

                Circle()
                    .fill(Color.black.opacity(0.06))
                    .frame(width: 220, height: 220)
                    .blur(radius: 32)
                    .offset(x: 130, y: -120)
            }
        }
        .ignoresSafeArea()
    }
}
