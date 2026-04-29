import SwiftUI
import UIKit

enum LiquidGlassTab: String, CaseIterable, Identifiable {
    case home
    case kerko
    case businesses
    case cart
    case llogaria

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .kerko: return "Kerko"
        case .businesses: return "Bizneset"
        case .cart: return "Cart"
        case .llogaria: return "Llogaria"
        }
    }

    var symbolName: String {
        switch self {
        case .home: return "house"
        case .kerko: return "magnifyingglass"
        case .businesses: return "storefront"
        case .cart: return "cart"
        case .llogaria: return "person.circle"
        }
    }
}

struct LiquidGlassTabBar: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selection: LiquidGlassTab
    var badges: [LiquidGlassTab: String] = [:]
    var progress: CGFloat? = nil
    var scrollProgress: CGFloat = 0
    var onSelectionChange: ((LiquidGlassTab) -> Void)? = nil

    @State private var animatedProgress: CGFloat = 0

    private let groupedTabs: [LiquidGlassTab] = [.home, .businesses, .cart, .llogaria]
    private let shellHeight: CGFloat = 58
    private let searchOrbSize: CGFloat = 56
    private let innerInset: CGFloat = 5
    private let gap: CGFloat = 8
    private let groupedShadowRadius: CGFloat = 10

    var body: some View {
        HStack(spacing: gap) {
            groupedTabShell
            searchOrb
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .onAppear {
            animatedProgress = resolvedProgress
        }
        .onChange(of: selection) { _ in
            if selection != .kerko {
                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.78)) {
                    animatedProgress = resolvedProgress
                }
            }
        }
        .onChange(of: progress ?? resolvedProgress) { newValue in
            guard selection != .kerko else { return }
            animatedProgress = newValue
        }
    }

    private var groupedTabShell: some View {
        GeometryReader { proxy in
            let shellWidth = proxy.size.width
            let slotWidth = shellWidth / CGFloat(groupedTabs.count)

            ZStack(alignment: .leading) {
                shellSurface

                if selection != .kerko {
                    activePill(slotWidth: slotWidth)
                        .offset(x: pillOffset(slotWidth: slotWidth))
                }

                HStack(spacing: 0) {
                    ForEach(groupedTabs) { tab in
                        groupedTabButton(tab)
                            .frame(width: slotWidth, height: shellHeight)
                    }
                }
            }
            .frame(height: shellHeight)
            .clipShape(Capsule())
            .compositingGroup()
            .overlay {
                Capsule()
                    .strokeBorder(shellStroke, lineWidth: 0.9)
            }
            .shadow(color: shadowColor, radius: groupedShadowRadius, x: 0, y: 5)
        }
        .frame(height: shellHeight)
    }

    private var searchOrb: some View {
        Button {
            select(.kerko)
        } label: {
            ZStack {
                orbShellSurface

                if selection == .kerko {
                    activeOrb
                }

                if let badge = badges[.kerko], !badge.isEmpty {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(height: 16)
                        .background(TregoTabBarPalette.badge, in: Capsule())
                        .offset(x: 16, y: -18)
                }

                Image(systemName: LiquidGlassTab.kerko.symbolName)
                    .font(.system(size: 19, weight: selection == .kerko ? .bold : .semibold))
                    .foregroundStyle(selection == .kerko ? selectedForeground : unselectedForeground)
            }
            .frame(width: searchOrbSize, height: searchOrbSize)
            .compositingGroup()
                    .shadow(color: shadowColor.opacity(0.72), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LiquidGlassTab.kerko.title))
    }

    private func groupedTabButton(_ tab: LiquidGlassTab) -> some View {
        Button {
            select(tab)
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.symbolName)
                        .font(.system(size: 17, weight: selection == tab ? .semibold : .medium))
                        .symbolRenderingMode(.hierarchical)

                    if let badge = badges[tab], !badge.isEmpty {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(height: 16)
                            .background(TregoTabBarPalette.badge, in: Capsule())
                            .offset(x: 12, y: -8)
                    }
                }

                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(selection == tab ? selectedForeground : unselectedForeground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(tab.title))
    }

    @ViewBuilder
    private var shellSurface: some View {
        Capsule()
            .fill(Color.clear)
            .background {
                if #available(iOS 26.0, *) {
                    Capsule()
                        .glassEffect(.regular.tint(shellTint))
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(colorScheme == .dark ? 0.06 : 0.22),
                                            .white.opacity(colorScheme == .dark ? 0.02 : 0.08),
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                            )
                                )
                        }
                }
            }
            .overlay {
                capsuleDynamicLight
            }
            .overlay {
                TregoGlassNoiseTexture(seed: 17, grainOpacity: noiseOpacity)
                    .clipShape(Capsule())
                    .blendMode(.softLight)
            }
    }

    @ViewBuilder
    private var orbShellSurface: some View {
        Circle()
            .fill(Color.clear)
            .background {
                if #available(iOS 26.0, *) {
                    Circle()
                        .glassEffect(.regular.tint(shellTint))
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                orbDynamicLight
            }
            .overlay {
                TregoGlassNoiseTexture(seed: 41, grainOpacity: noiseOpacity * 0.9)
                    .clipShape(Circle())
                    .blendMode(.softLight)
            }
            .overlay {
                Circle()
                    .strokeBorder(shellStroke, lineWidth: 0.85)
            }
    }

    @ViewBuilder
    private func activePill(slotWidth: CGFloat) -> some View {
        Capsule()
            .fill(Color.clear)
            .background {
                if #available(iOS 26.0, *) {
                    Capsule()
                        .glassEffect(.regular.tint(selectedTint).interactive())
                } else {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(colorScheme == .dark ? 0.18 : 0.78),
                                    .white.opacity(colorScheme == .dark ? 0.08 : 0.38),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .frame(width: pillWidth(slotWidth: slotWidth), height: shellHeight - 10)
            .overlay {
                capsuleDynamicLight
                    .opacity(0.92)
            }
            .overlay {
                TregoGlassNoiseTexture(seed: 77, grainOpacity: noiseOpacity * 1.15)
                    .clipShape(Capsule())
                    .blendMode(.softLight)
            }
            .overlay {
                Capsule()
                    .strokeBorder(selectedStroke, lineWidth: 0.72)
            }
            .padding(.leading, innerInset)
            .compositingGroup()
    }

    @ViewBuilder
    private var activeOrb: some View {
        Circle()
            .fill(Color.clear)
            .background {
                if #available(iOS 26.0, *) {
                    Circle()
                        .glassEffect(.regular.tint(selectedTint).interactive())
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(colorScheme == .dark ? 0.18 : 0.8),
                                    .white.opacity(colorScheme == .dark ? 0.08 : 0.4),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .padding(4)
            .overlay {
                orbDynamicLight
            }
            .overlay {
                TregoGlassNoiseTexture(seed: 91, grainOpacity: noiseOpacity)
                    .clipShape(Circle())
                    .blendMode(.softLight)
                    .padding(4)
            }
            .overlay {
                Circle()
                    .strokeBorder(selectedStroke, lineWidth: 0.72)
                    .padding(4)
            }
            .compositingGroup()
    }

    private var resolvedProgress: CGFloat {
        if let progress {
            return progress
        }
        return CGFloat(groupedIndex(for: selection))
    }

    private func groupedIndex(for tab: LiquidGlassTab) -> Int {
        groupedTabs.firstIndex(of: tab) ?? 0
    }

    private func pillOffset(slotWidth: CGFloat) -> CGFloat {
        animatedProgress * slotWidth
    }

    private func pillWidth(slotWidth: CGFloat) -> CGFloat {
        let base = slotWidth - 10
        let fractional = abs(animatedProgress.truncatingRemainder(dividingBy: 1))
        let stretch = sin(fractional * .pi) * 18
        return base + stretch
    }

    private var normalizedScroll: CGFloat {
        min(max(scrollProgress, 0), 1)
    }

    private var noiseOpacity: Double {
        colorScheme == .dark ? 0.1 : 0.18
    }

    private var lightCenterX: CGFloat {
        0.18 + (normalizedScroll * 0.38)
    }

    private var lightCenterY: CGFloat {
        0.06 + (normalizedScroll * 0.08)
    }

    private var capsuleDynamicLight: some View {
        RadialGradient(
            colors: [
                .white.opacity(colorScheme == .dark ? 0.22 : 0.34),
                .white.opacity(colorScheme == .dark ? 0.1 : 0.14),
                .clear,
            ],
            center: UnitPoint(x: lightCenterX, y: lightCenterY),
            startRadius: 1,
            endRadius: 210
        )
        .clipShape(Capsule())
        .allowsHitTesting(false)
    }

    private var orbDynamicLight: some View {
        RadialGradient(
            colors: [
                .white.opacity(colorScheme == .dark ? 0.18 : 0.28),
                .white.opacity(colorScheme == .dark ? 0.08 : 0.12),
                .clear,
            ],
            center: UnitPoint(x: 0.3 + (normalizedScroll * 0.16), y: 0.12),
            startRadius: 2,
            endRadius: 82
        )
        .clipShape(Circle())
        .allowsHitTesting(false)
    }

    private var shellTint: Color {
        colorScheme == .dark ? .white.opacity(0.05) : .white.opacity(0.94)
    }

    private var selectedTint: Color {
        colorScheme == .dark ? Color(red: 1.0, green: 0.435, blue: 0.094).opacity(0.16) : Color(red: 1.0, green: 0.953, blue: 0.918)
    }

    private var shellStroke: Color {
        colorScheme == .dark ? .white.opacity(0.12) : Color(red: 0.898, green: 0.906, blue: 0.922)
    }

    private var selectedStroke: Color {
        colorScheme == .dark ? Color(red: 1.0, green: 0.435, blue: 0.094).opacity(0.28) : Color(red: 1.0, green: 0.435, blue: 0.094).opacity(0.28)
    }

    private var selectedForeground: Color {
        colorScheme == .dark
            ? .white.opacity(0.98)
            : Color(red: 0.14, green: 0.17, blue: 0.22)
    }

    private var unselectedForeground: Color {
        colorScheme == .dark
            ? .white.opacity(0.68)
            : Color(red: 0.24, green: 0.28, blue: 0.34).opacity(0.72)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.2) : .black.opacity(0.08)
    }

    private func select(_ tab: LiquidGlassTab) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if selection == tab {
            onSelectionChange?(tab)
            return
        }

        let animation = Animation.interactiveSpring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.12)
        withAnimation(animation) {
            selection = tab
            if tab != .kerko {
                animatedProgress = CGFloat(groupedIndex(for: tab))
            }
        }
        onSelectionChange?(tab)
    }
}

private enum TregoTabBarPalette {
    static let badge = Color(red: 1.0, green: 0.435, blue: 0.094)
}

private struct TregoGlassNoiseTexture: View {
    let seed: Int
    let grainOpacity: Double

    var body: some View {
        Canvas { context, size in
            for index in 0..<56 {
                let point = noisePoint(index: index, size: size)
                let radius = 0.45 + noiseUnit(index * 13 + 5) * 1.15
                let alpha = grainOpacity * (0.08 + noiseUnit(index * 19 + 11) * 0.34)
                let rect = CGRect(x: point.x, y: point.y, width: radius, height: radius)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(.white.opacity(alpha))
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func noisePoint(index: Int, size: CGSize) -> CGPoint {
        CGPoint(
            x: noiseUnit(index * 37 + 7) * size.width,
            y: noiseUnit(index * 53 + 17) * size.height
        )
    }

    private func noiseUnit(_ value: Int) -> CGFloat {
        let scrambled = (value &* 1103515245 &+ seed &* 12345) & 0x7fffffff
        return CGFloat(scrambled % 1000) / 999
    }
}
