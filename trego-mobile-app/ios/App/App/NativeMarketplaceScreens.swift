import SwiftUI
import UIKit
import AVFoundation
import Speech
import AuthenticationServices
import SafariServices
import CoreLocation
import PassKit
import UniformTypeIdentifiers
import ImageIO

struct TregoNativeRootView: View {
    @StateObject private var store = TregoNativeAppStore()
    @State private var tabBarScrollProgress: CGFloat = 0
    @State private var isBootstrapping = true
    @State private var didStartBootstrap = false
    @State private var isLaunchPromoPresented = false

    var body: some View {
        ZStack {
            rootTabs

            if let prompt = store.authenticationPrompt {
                TregoAuthenticationPromptOverlay(
                    prompt: prompt,
                    onLogin: {
                        store.authenticationPrompt = nil
                        store.dismissPresentedNativeFlow()
                        store.openAccountAuth(.login)
                    },
                    onSignup: {
                        store.authenticationPrompt = nil
                        store.dismissPresentedNativeFlow()
                        store.openAccountAuth(.signup)
                    },
                    onCancel: {
                        store.authenticationPrompt = nil
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(15)
            }

            if !isBootstrapping && isLaunchPromoPresented && shouldShowLaunchPromo {
                TregoLaunchPromoOverlay(
                    isPresented: $isLaunchPromoPresented,
                    launchAds: store.launchAds,
                    onShopNow: {
                        store.selectedTab = .home
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(18)
            }

            if isBootstrapping {
                TregoLaunchLoadingScreen()
                    .transition(.opacity.animation(.easeOut(duration: 0.42)))
                    .zIndex(10)
            }
        }
        .background(TregoNativeTheme.background.ignoresSafeArea())
        .preferredColorScheme(store.appSettings.preferredColorScheme)
        .tregoTapOutsideKeyboardDismiss()
        .sheet(item: $store.authRoute) { route in
            NavigationView {
                TregoAuthSheetView(store: store, route: route)
            }
            .navigationViewStyle(.stack)
            .tregoTapOutsideKeyboardDismiss()
            .tregoPresentationDragIndicatorVisible()
        }
        .sheet(item: $store.selectedProduct) { product in
            NavigationView {
                TregoProductDetailView(store: store, product: product)
            }
            .navigationViewStyle(.stack)
            .tregoTapOutsideKeyboardDismiss()
        }
        .sheet(item: $store.selectedConversation) { conversation in
            NavigationView {
                TregoConversationScreen(store: store, conversation: conversation)
            }
            .navigationViewStyle(.stack)
            .tregoTapOutsideKeyboardDismiss()
        }
        .sheet(item: $store.presentedScreen) { screen in
            NavigationView {
                TregoPresentedScreenHost(store: store, screen: screen)
            }
            .navigationViewStyle(.stack)
            .tregoTapOutsideKeyboardDismiss()
        }
        .overlay(alignment: .top) {
            if let toast = store.toastMessage {
                TregoToastView(message: toast)
                    .padding(.top, 18)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .alert("TREGIO", isPresented: Binding(
            get: { store.globalMessage != nil },
            set: { if !$0 { store.globalMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                store.globalMessage = nil
            }
        } message: {
            Text(store.globalMessage ?? "")
        }
        .task {
            guard !didStartBootstrap else { return }
            didStartBootstrap = true
            TregoNativeKeyboard.removeLegacyTapOutsideDismissRecognizers()

            Task {
                await store.bootstrap()
            }

            try? await Task.sleep(nanoseconds: 650_000_000)

            withAnimation(.easeOut(duration: 0.38)) {
                isBootstrapping = false
            }

            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                isLaunchPromoPresented = true
            }
        }
        .onChange(of: store.selectedTab) { newValue in
            if newValue == .llogaria && store.user == nil {
                withAnimation(.easeOut(duration: 0.2)) {
                    isLaunchPromoPresented = false
                }
            }
            if newValue != .home && newValue != .kerko {
                withAnimation(.easeOut(duration: 0.22)) {
                    tabBarScrollProgress = 0
                }
            }
            Task {
                await handleTabChange(for: newValue)
            }
        }
        .onChange(of: store.authRoute) { route in
            if route != nil {
                withAnimation(.easeOut(duration: 0.2)) {
                    isLaunchPromoPresented = false
                }
            }
        }
        .onChange(of: store.authenticationPrompt?.id) { promptID in
            if promptID != nil {
                withAnimation(.easeOut(duration: 0.2)) {
                    isLaunchPromoPresented = false
                }
            }
        }
    }

    @ViewBuilder
    private var rootTabs: some View {
        if #available(iOS 26.0, *) {
            modernRootTabs
        } else {
            legacyRootTabs
        }
    }

    @available(iOS 26.0, *)
    private var modernRootTabs: some View {
        TabView(selection: $store.selectedTab) {
            Tab("Home", systemImage: LiquidGlassTab.home.symbolName, value: LiquidGlassTab.home) {
                TregoHomeScreen(store: store, tabBarScrollProgress: $tabBarScrollProgress)
            }

            Tab("Bizneset", systemImage: LiquidGlassTab.businesses.symbolName, value: LiquidGlassTab.businesses) {
                TregoBusinessesRootScreen(store: store)
            }

            Tab("Cart", systemImage: LiquidGlassTab.cart.symbolName, value: LiquidGlassTab.cart) {
                TregoCartScreen(store: store)
            }
            .badge(store.tabBadges[.cart].map(Text.init))

            Tab("Llogaria", systemImage: LiquidGlassTab.llogaria.symbolName, value: LiquidGlassTab.llogaria) {
                TregoAccountScreen(store: store)
            }
            .badge(store.tabBadges[.llogaria].map(Text.init))

            Tab(value: LiquidGlassTab.kerko, role: .search) {
                TregoSearchScreen(store: store, tabBarScrollProgress: $tabBarScrollProgress)
            }
        }
        .tabBarMinimizeBehavior(.automatic)
        .tint(TregoNativeTheme.accent)
    }

    private var legacyRootTabs: some View {
        TabView(selection: $store.selectedTab) {
            TregoHomeScreen(store: store, tabBarScrollProgress: $tabBarScrollProgress)
                .tabItem {
                    Label("Home", systemImage: LiquidGlassTab.home.symbolName)
                }
                .tag(LiquidGlassTab.home)

            TregoBusinessesRootScreen(store: store)
                .tabItem {
                    Label("Bizneset", systemImage: LiquidGlassTab.businesses.symbolName)
                }
                .tag(LiquidGlassTab.businesses)

            TregoCartScreen(store: store)
                .tabItem {
                    Label("Cart", systemImage: LiquidGlassTab.cart.symbolName)
                }
                .tag(LiquidGlassTab.cart)
                .badge(store.tabBadges[.cart])

            TregoAccountScreen(store: store)
                .tabItem {
                    Label("Llogaria", systemImage: LiquidGlassTab.llogaria.symbolName)
                }
                .tag(LiquidGlassTab.llogaria)
                .badge(store.tabBadges[.llogaria])

            TregoSearchScreen(store: store, tabBarScrollProgress: $tabBarScrollProgress)
                .tabItem {
                    Label("Kerko", systemImage: LiquidGlassTab.kerko.symbolName)
                }
                .tag(LiquidGlassTab.kerko)
        }
        .tint(TregoNativeTheme.accent)
    }

    private func handleTabChange(for tab: LiquidGlassTab) async {
        switch tab {
        case .home:
            await store.loadHomeIfNeeded()
        case .kerko:
            await store.loadSearchIfNeeded()
        case .businesses:
            await store.loadPublicBusinesses()
        case .cart:
            await store.loadCart()
        case .llogaria:
            store.warmSessionRefreshInBackground()
        }
    }

    private var shouldShowLaunchPromo: Bool {
        if store.authenticationPrompt != nil || store.authRoute != nil {
            return false
        }
        if store.selectedTab == .llogaria && store.user == nil {
            return false
        }
        return true
    }
}

private struct TregoPresentedScreenHost: View {
    @ObservedObject var store: TregoNativeAppStore
    let screen: TregoNativePresentedScreen

    var body: some View {
        switch screen.kind {
        case .notifications:
            TregoNotificationsScreen(store: store)
        case .orders:
            TregoOrdersScreen(store: store)
        case .messages:
            TregoMessagesScreen(store: store)
        case .returns:
            TregoReturnsScreen(store: store)
        case .businessHub:
            TregoBusinessHubScreen(store: store)
        case .adminControl:
            TregoAdminControlScreen(store: store)
        }
    }
}

private extension View {
    @ViewBuilder
    func tregoHideTabBarOnSecondaryPage() -> some View {
        if #available(iOS 16.0, *) {
            self.toolbar(.hidden, for: .tabBar)
        } else {
            self
        }
    }
}

private struct TregoLaunchLoadingScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animateBackdrop = false

    var body: some View {
        ZStack {
            TregoNativeTheme.background.ignoresSafeArea()

            Circle()
                .fill(TregoNativeTheme.accent.opacity(colorScheme == .dark ? 0.34 : 0.26))
                .frame(width: 280, height: 280)
                .blur(radius: 96)
                .offset(x: animateBackdrop ? 120 : 72, y: -280)

            Circle()
                .fill(TregoNativeTheme.softAccent.opacity(colorScheme == .dark ? 0.28 : 0.24))
                .frame(width: 260, height: 260)
                .blur(radius: 102)
                .offset(x: animateBackdrop ? -136 : -88, y: 290)

            Circle()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.34))
                .frame(width: 220, height: 220)
                .blur(radius: 88)
                .offset(x: 18, y: animateBackdrop ? 104 : 58)

            VStack(spacing: 12) {
                TregoLaunchSpinner()
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 6.4).repeatForever(autoreverses: true)) {
                animateBackdrop = true
            }
        }
    }
}

private struct TregoLaunchSpinner: View {
    @State private var spin = false

    var body: some View {
        Circle()
            .trim(from: 0.08, to: 0.74)
            .stroke(
                Color.orange,
                style: StrokeStyle(lineWidth: 5, lineCap: .round)
            )
            .frame(width: 34, height: 34)
            .rotationEffect(.degrees(spin ? 360 : 0))
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                spin = true
            }
        }
    }
}

private struct TregoLaunchPromoOverlay: View {
    @Binding var isPresented: Bool
    let launchAds: [TregoLaunchAd]
    let onShopNow: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedSlide = 0

    private let fallbackSlides = [
        TregoLaunchPromoSlide(
            id: "fallback-launch-man",
            imageName: "PromoSpringMan",
            imagePath: nil,
            badge: "Spring Drop",
            title: "Fresh looks for this week",
            subtitle: "Oferta te reja me vibe social dhe styling me impakt direkt ne home.",
            ctaLabel: "Shop now"
        ),
        TregoLaunchPromoSlide(
            id: "fallback-launch-shoes",
            imageName: "PromoSpringShoes",
            imagePath: nil,
            badge: "Shoes Sale",
            title: "Up to 50% off picks",
            subtitle: "Sneakers dhe sale highlights te vendosura si promo popup ne hyrje.",
            ctaLabel: "Shop now"
        ),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(colorScheme == .dark ? 0.62 : 0.32)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPromo()
                }

            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TREGIO Promo")
                            .font(.system(size: 12, weight: .black))
                            .textCase(.uppercase)
                            .foregroundStyle(TregoNativeTheme.accent)

                        Text("Shop the latest ad")
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(Color.primary)
                    }

                    Spacer(minLength: 0)

                    Button {
                        dismissPromo()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 34, height: 34)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close promo")
                }

                TabView(selection: $selectedSlide) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                        VStack(alignment: .leading, spacing: 0) {
                            launchImage(for: slide)
                                .frame(height: 360)
                                .frame(maxWidth: .infinity)
                                .clipped()

                            VStack(alignment: .leading, spacing: 10) {
                                Text(slide.badge)
                                    .font(.system(size: 11, weight: .black))
                                    .textCase(.uppercase)
                                    .foregroundStyle(TregoNativeTheme.accent)

                                Text(slide.title)
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundStyle(.primary)

                                Text(slide.subtitle)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(TregoNativeTheme.cardFill.opacity(colorScheme == .dark ? 0.92 : 0.98))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.48), lineWidth: 0.85)
                        }
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.34 : 0.12), radius: 22, y: 12)
                        .padding(.horizontal, 2)
                        .tag(index)
                    }
                }
                .frame(height: 520)
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button {
                    onShopNow()
                    dismissPromo()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bag.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(activeSlide.ctaLabel)
                            .font(.system(size: 16, weight: .black))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(TregoPrimaryButtonStyle())
            }
            .frame(maxWidth: 430)
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .onChange(of: slides.count) { count in
            guard count > 0 else {
                selectedSlide = 0
                return
            }
            if selectedSlide >= count {
                selectedSlide = count - 1
            }
        }
    }

    private func dismissPromo() {
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
    }

    private var slides: [TregoLaunchPromoSlide] {
        let remoteSlides = launchAds.compactMap { launchAd -> TregoLaunchPromoSlide? in
            let title = launchAd.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let imagePath = launchAd.imagePath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty, !imagePath.isEmpty else {
                return nil
            }

            let badge = launchAd.badge?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? (launchAd.badge ?? "")
                : "TREGIO Promo"
            let subtitle = launchAd.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? (launchAd.subtitle ?? "")
                : "Promo popup i menaxhuar nga admini."
            let ctaLabel = launchAd.ctaLabel?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? (launchAd.ctaLabel ?? "")
                : "Shop now"

            return TregoLaunchPromoSlide(
                id: "launch-ad-\(launchAd.id)",
                imageName: nil,
                imagePath: imagePath,
                badge: badge,
                title: title,
                subtitle: subtitle,
                ctaLabel: ctaLabel
            )
        }

        return remoteSlides.isEmpty ? fallbackSlides : remoteSlides
    }

    private var activeSlide: TregoLaunchPromoSlide {
        let safeIndex = max(0, min(selectedSlide, max(slides.count - 1, 0)))
        return slides[safeIndex]
    }

    @ViewBuilder
    private func launchImage(for slide: TregoLaunchPromoSlide) -> some View {
        if let imageName = slide.imageName {
            Image(imageName)
                .resizable()
                .scaledToFill()
        } else {
            TregoRemoteImage(imagePath: slide.imagePath)
        }
    }
}

private struct TregoLaunchPromoSlide: Identifiable {
    let id: String
    let imageName: String?
    let imagePath: String?
    let badge: String
    let title: String
    let subtitle: String
    let ctaLabel: String
}

private struct TregoBusinessPushLink: View {
    @ObservedObject var store: TregoNativeAppStore
    @Binding var selection: TregoBusinessSelection?

    var body: some View {
        NavigationLink(
            destination: destinationView,
            isActive: Binding(
                get: { selection != nil },
                set: { isActive in
                    if !isActive {
                        selection = nil
                    }
                }
            )
        ) {
            EmptyView()
        }
        .frame(width: 0, height: 0)
        .hidden()
    }

    @ViewBuilder
    private var destinationView: some View {
        if let selection {
            TregoPublicBusinessScreen(store: store, selection: selection)
        } else {
            EmptyView()
        }
    }
}

private struct TregoBusinessesRootScreen: View {
    @ObservedObject var store: TregoNativeAppStore

    var body: some View {
        NavigationView {
            TregoBusinessesExplorerScreen(store: store)
        }
        .navigationViewStyle(.stack)
    }
}

private struct TregoHomeRailModel: Identifiable {
    let id: String
    let title: String
    let tint: Color
    let cardStyle: TregoHomeRailCardStyle
    let products: [TregoProduct]
    let subtitle: String
}

private struct TregoHomeScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    @Binding var tabBarScrollProgress: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @State private var openedRecommendationSection: TregoRecommendationSection?
    @State private var openedBusinessSelection: TregoBusinessSelection?
    @State private var showsPersonalizationPrompt = false
    @State private var showsMessages = false
    @State private var selectedHomeCategoryKey = "all"
    @State private var pickerSource: TregoImagePickerSource?
    @State private var alertState: TregoSearchBarAlert?

    private let grid = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: TregoTabBarScrollPreferenceKey.self,
                            value: max(0, -proxy.frame(in: .named("trego-home-scroll")).minY)
                        )
                }
                .frame(height: 0)

                VStack(alignment: .leading, spacing: 18) {
                    if store.homeLoading && store.homeProducts.isEmpty {
                        TregoHomeRailSkeletonSection(title: "Recommended", tint: Color(red: 0.16, green: 0.65, blue: 0.34))
                        TregoHomeRailSkeletonSection(title: "New arrivals", tint: Color.orange.opacity(0.88))
                        TregoHomeRailSkeletonSection(title: "Best sellers", tint: Color.red.opacity(0.88))
                        TregoHairlineDivider()
                        TregoSectionHeader(title: "Te gjitha")
                        LazyVGrid(columns: grid, spacing: 14) {
                            ForEach(0..<6, id: \.self) { _ in
                                TregoProductCardSkeleton()
                            }
                        }
                    } else {
                        ForEach(homeRailSections) { railSection in
                            TregoHomeRailSection(
                                title: railSection.title,
                                tint: railSection.tint,
                                products: railSection.products,
                                cardStyle: railSection.cardStyle,
                                onViewAll: {
                                    openedRecommendationSection = TregoRecommendationSection(
                                        key: railSection.id,
                                        title: railSection.title,
                                        subtitle: railSection.subtitle,
                                        products: railSection.products
                                    )
                                },
                                onOpenProduct: { store.selectedProduct = $0 },
                                onOpenBusiness: { product in
                                    if let businessId = product.businessProfileId {
                                        openedBusinessSelection = TregoBusinessSelection(id: businessId)
                                    }
                                },
                                isWishlisted: { product in
                                    store.isWishlisted(productId: product.id)
                                },
                                onWishlist: { product in
                                    Task { await store.toggleWishlist(for: product) }
                                },
                                onAddToCart: { product in
                                    Task { await store.addToCart(product: product) }
                                }
                            )
                        }

                        if !recommendedGridProducts.isEmpty {
                            if homeCategoryOptions.count > 1 {
                                TregoHairlineDivider()
                                    .padding(.horizontal, -18)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(homeCategoryOptions) { option in
                                            Button {
                                                selectedHomeCategoryKey = option.key
                                            } label: {
                                                Text(option.title)
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(
                                                        selectedHomeCategoryKey == option.key
                                                        ? .white
                                                        : Color.primary.opacity(colorScheme == .dark ? 0.94 : 0.82)
                                                    )
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 9)
                                                    .background(
                                                        Capsule()
                                                            .fill(
                                                                selectedHomeCategoryKey == option.key
                                                                ? TregoNativeTheme.accent
                                                                : (
                                                                    colorScheme == .dark
                                                                    ? Color.white.opacity(0.08)
                                                                    : Color.white.opacity(0.82)
                                                                )
                                                            )
                                                    )
                                                    .overlay {
                                                        Capsule()
                                                            .strokeBorder(
                                                                selectedHomeCategoryKey == option.key
                                                                ? TregoNativeTheme.accent.opacity(0.18)
                                                                : (
                                                                    colorScheme == .dark
                                                                    ? Color.white.opacity(0.14)
                                                                    : Color.white.opacity(0.42)
                                                                ),
                                                                lineWidth: 0.7
                                                            )
                                                    }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 18)
                                }
                                .padding(.horizontal, -18)

                                TregoHairlineDivider()
                                    .padding(.horizontal, -18)
                            }

                            TregoSectionHeader(title: "Te gjitha")

                            LazyVGrid(columns: grid, spacing: 14) {
                                ForEach(filteredRecommendedGridProducts) { product in
                                    TregoProductCard(
                                        product: product,
                                        isWishlisted: store.isWishlisted(productId: product.id),
                                        onTap: { store.selectedProduct = product },
                                        onOpenBusiness: {
                                            if let businessId = product.businessProfileId {
                                                openedBusinessSelection = TregoBusinessSelection(id: businessId)
                                            }
                                        },
                                        onWishlist: {
                                            Task { await store.toggleWishlist(for: product) }
                                        },
                                        onAddToCart: {
                                            Task { await store.addToCart(product: product) }
                                        }
                                    )
                                    .onAppear {
                                        if product.id == filteredRecommendedGridProducts.last?.id {
                                            Task { await store.loadMoreHomeIfNeeded() }
                                        }
                                    }
                                }

                                if store.homeLoadingMore {
                                    ForEach(0..<2, id: \.self) { _ in
                                        TregoProductCardSkeleton()
                                    }
                                }
                            }
                        } else if isGridWaitingForMore {
                            TregoSectionHeader(title: "Te gjitha")

                            LazyVGrid(columns: grid, spacing: 14) {
                                ForEach(0..<4, id: \.self) { _ in
                                    TregoProductCardSkeleton()
                                }
                            }
                            .task {
                                await store.loadMoreHomeIfNeeded()
                            }
                        } else if !hasAnyHomeContent {
                            TregoEmptyStateView(
                                title: "Nuk ka produkte",
                                subtitle: "Nuk u gjet asnje produkt per home page."
                            )
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 132)
            }
            .coordinateSpace(name: "trego-home-scroll")
            .background(TregoBusinessPushLink(store: store, selection: $openedBusinessSelection))
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Menu {
                        Button {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                pickerSource = .camera
                            } else {
                                alertState = .cameraUnavailable
                            }
                        } label: {
                            Label("Take photo", systemImage: "camera")
                        }

                        Button {
                            pickerSource = .photoLibrary
                        } label: {
                            Label("Choose from library", systemImage: "photo.on.rectangle")
                        }
                    } label: {
                        TregoVisualSearchIcon(symbolName: resolvedVisualSearchSymbolName)
                    }
                    .accessibilityLabel("Visual Search")

                    Spacer()

                    ZStack {
                        NavigationLink(destination: TregoMessagesScreen(store: store), isActive: $showsMessages) {
                            EmptyView()
                        }
                        .frame(width: 0, height: 0)
                        .hidden()

                        Button {
                            showsMessages = true
                        } label: {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(TregoNativeTheme.accent)
                                .frame(width: 42, height: 42)
                                .background(.ultraThinMaterial, in: Circle())
                                .shadow(color: TregoNativeTheme.accent.opacity(0.18), radius: 8, y: 4)
                                .overlay {
                                    Circle()
                                        .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.42), lineWidth: 0.7)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Mesazhet")
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .fullScreenCover(isPresented: isCameraPickerPresented) {
                TregoImagePicker(source: .camera) { upload in
                    Task {
                        await store.performImageSearch(upload: upload)
                    }
                }
            }
            .sheet(isPresented: isPhotoLibraryPickerPresented) {
                TregoImagePicker(source: .photoLibrary) { upload in
                    Task {
                        await store.performImageSearch(upload: upload)
                    }
                }
            }
            .alert(item: $alertState) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
            .sheet(item: $openedRecommendationSection) { section in
                NavigationView {
                    TregoHomeCollectionScreen(
                        store: store,
                        title: section.title,
                        products: section.products
                    )
                }
                .navigationViewStyle(.stack)
            }
            .onAppear {
                tabBarScrollProgress = 0
                if store.personalizationConsentPending {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showsPersonalizationPrompt = true
                    }
                }
            }
            .onChange(of: homeCategoryOptions) { options in
                guard options.contains(where: { $0.key == selectedHomeCategoryKey }) else {
                    selectedHomeCategoryKey = "all"
                    return
                }
            }
            .confirmationDialog(
                "Rekomandime personale",
                isPresented: $showsPersonalizationPrompt,
                titleVisibility: .visible
            ) {
                Button("Lejo") { store.allowPersonalizedRecommendations() }
                Button("Cancel", role: .cancel) { store.declinePersonalizedRecommendations() }
            } message: {
                Text("Lejo personalizimin e home page bazuar ne aktivitetin tend brenda app-it.")
            }
            .onPreferenceChange(TregoTabBarScrollPreferenceKey.self) { value in
                let normalized = min(max(value / 240, 0), 1)
                if abs(tabBarScrollProgress - normalized) > 0.01 {
                    tabBarScrollProgress = normalized
                }
            }
            .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }

    private var homeRailSections: [TregoHomeRailModel] {
        store.homeFeedSnapshot.railSections.compactMap { section in
            let tint: Color
            let cardStyle: TregoHomeRailCardStyle
            switch section.key {
            case "recommended-for-you":
                tint = Color(red: 0.16, green: 0.65, blue: 0.34)
                cardStyle = .metricsOnly
            case "new-arrivals":
                tint = Color.orange.opacity(0.88)
                cardStyle = .standard
            case "best-sellers":
                tint = Color.red.opacity(0.88)
                cardStyle = .metricsOnly
            default:
                tint = TregoNativeTheme.accent
                cardStyle = .standard
            }

            return TregoHomeRailModel(
                id: section.key,
                title: section.title,
                tint: tint,
                cardStyle: cardStyle,
                products: section.products,
                subtitle: section.subtitle ?? ""
            )
        }
    }

    private var filteredRecommendedGridProducts: [TregoProduct] {
        guard selectedHomeCategoryKey != "all" else { return store.homeFeedSnapshot.gridProducts }
        return store.homeFeedSnapshot.gridProducts.filter { homeCategoryKey(for: $0) == selectedHomeCategoryKey }
    }

    private var recommendedGridProducts: [TregoProduct] {
        store.homeFeedSnapshot.gridProducts
    }

    private var homeCategoryOptions: [TregoHomeCategoryOption] {
        store.homeFeedSnapshot.categoryOptions
    }

    private var hasAnyHomeContent: Bool {
        !homeRailSections.isEmpty || !recommendedGridProducts.isEmpty
    }

    private var isGridWaitingForMore: Bool {
        recommendedGridProducts.isEmpty && store.homeHasMore && !store.homeLoadingMore
    }

    private func homeCategoryKey(for product: TregoProduct) -> String? {
        let rawValue = (product.category?.isEmpty == false ? product.category : product.productType)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let rawValue, !rawValue.isEmpty else { return nil }
        return TregoNativeProductCatalog.section(for: rawValue)
    }

    private var isCameraPickerPresented: Binding<Bool> {
        Binding(
            get: { pickerSource == .camera },
            set: { newValue in
                if !newValue, pickerSource == .camera {
                    pickerSource = nil
                }
            }
        )
    }

    private var isPhotoLibraryPickerPresented: Binding<Bool> {
        Binding(
            get: { pickerSource == .photoLibrary },
            set: { newValue in
                if !newValue, pickerSource == .photoLibrary {
                    pickerSource = nil
                }
            }
        )
    }

    private var resolvedVisualSearchSymbolName: String {
        let candidates = [
            "apple.intelligence",
            "sparkles.rectangle.stack",
            "viewfinder.circle",
            "camera.viewfinder",
            "sparkles",
        ]

        for symbol in candidates where UIImage(systemName: symbol) != nil {
            return symbol
        }

        return "camera.viewfinder"
    }
}

private struct TregoSearchScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    @Binding var tabBarScrollProgress: CGFloat

    private let grid = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    @State private var searchTask: Task<Void, Never>?
    @State private var openedBusinessSelection: TregoBusinessSelection?
    @State private var pickerSource: TregoImagePickerSource?
    @State private var alertState: TregoSearchBarAlert?

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: TregoTabBarScrollPreferenceKey.self,
                            value: max(0, -proxy.frame(in: .named("trego-search-scroll")).minY)
                        )
                }
                .frame(height: 0)

                VStack(alignment: .leading, spacing: 14) {
                    if #unavailable(iOS 26.0) {
                        TregoGlassSearchBar(
                            text: $store.searchQuery,
                            placeholder: "Kerko",
                            onSubmit: {
                                Task {
                                    await store.performSearch()
                                }
                            },
                            onImagePicked: { upload in
                                Task {
                                    await store.performImageSearch(upload: upload)
                                }
                            }
                        )
                    }

                    if #available(iOS 26.0, *) {
                        Color.clear
                            .frame(height: 2)
                    }

                    if store.searchLoading {
                        LazyVGrid(columns: grid, spacing: 14) {
                            ForEach(0..<6, id: \.self) { _ in
                                TregoProductCardSkeleton()
                            }
                        }
                    } else if store.searchResults.isEmpty {
                        TregoEmptyStateView(
                            title: "Asnje rezultat",
                            subtitle: "Provo nje kerkese tjeter ose kerkim me foto."
                        )
                    } else {
                        LazyVGrid(columns: grid, spacing: 14) {
                            ForEach(store.searchResults) { product in
                                TregoProductCard(
                                    product: product,
                                    isWishlisted: store.isWishlisted(productId: product.id),
                                    onTap: { store.selectedProduct = product },
                                    onOpenBusiness: {
                                        if let businessId = product.businessProfileId {
                                            openedBusinessSelection = TregoBusinessSelection(id: businessId)
                                        }
                                    },
                                    onWishlist: {
                                        Task { await store.toggleWishlist(for: product) }
                                    },
                                    onAddToCart: {
                                        Task { await store.addToCart(product: product) }
                                    }
                                )
                                .onAppear {
                                    if product.id == store.searchResults.last?.id {
                                        Task { await store.loadMoreSearchIfNeeded() }
                                    }
                                }
                            }

                            if store.searchLoadingMore {
                                ForEach(0..<2, id: \.self) { _ in
                                    TregoProductCardSkeleton()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, searchContentTopPadding)
                .padding(.bottom, 132)
            }
            .coordinateSpace(name: "trego-search-scroll")
            .background(TregoBusinessPushLink(store: store, selection: $openedBusinessSelection))
            .onAppear {
                tabBarScrollProgress = 0
            }
            .onChange(of: store.searchQuery) { newValue in
                guard #available(iOS 26.0, *) else { return }
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 260_000_000)
                    guard !Task.isCancelled else { return }
                    await store.performSearch()
                }
            }
            .onPreferenceChange(TregoTabBarScrollPreferenceKey.self) { value in
                let normalized = min(max(value / 240, 0), 1)
                if abs(tabBarScrollProgress - normalized) > 0.01 {
                    tabBarScrollProgress = normalized
                }
            }
            .background(TregoNativeTheme.background.ignoresSafeArea())
            .modifier(TregoSearchScreenNavigationChrome(searchText: $store.searchQuery) {
                Task {
                    await store.performSearch()
                }
            } onTakePhoto: {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    pickerSource = .camera
                } else {
                    alertState = .cameraUnavailable
                }
            } onChooseFromLibrary: {
                pickerSource = .photoLibrary
            })
            .fullScreenCover(isPresented: isCameraPickerPresented) {
                TregoImagePicker(source: .camera) { upload in
                    Task {
                        await store.performImageSearch(upload: upload)
                    }
                }
            }
            .sheet(isPresented: isPhotoLibraryPickerPresented) {
                TregoImagePicker(source: .photoLibrary) { upload in
                    Task {
                        await store.performImageSearch(upload: upload)
                    }
                }
            }
            .alert(item: $alertState) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
        }
        .navigationViewStyle(.stack)
    }

    private var searchContentTopPadding: CGFloat {
        if #available(iOS 26.0, *) {
            return 2
        }
        return 6
    }

    private var isCameraPickerPresented: Binding<Bool> {
        Binding(
            get: { pickerSource == .camera },
            set: { newValue in
                if !newValue, pickerSource == .camera {
                    pickerSource = nil
                }
            }
        )
    }

    private var isPhotoLibraryPickerPresented: Binding<Bool> {
        Binding(
            get: { pickerSource == .photoLibrary },
            set: { newValue in
                if !newValue, pickerSource == .photoLibrary {
                    pickerSource = nil
                }
            }
        )
    }
}

private struct TregoSearchScreenNavigationChrome: ViewModifier {
    @Binding var searchText: String
    let onSubmit: () -> Void
    let onTakePhoto: () -> Void
    let onChooseFromLibrary: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText, placement: .automatic, prompt: Text("Kerko"))
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(action: onTakePhoto) {
                                Label("Take photo", systemImage: "camera")
                            }

                            Button(action: onChooseFromLibrary) {
                                Label("Choose from library", systemImage: "photo.on.rectangle")
                            }
                        } label: {
                            TregoVisualSearchIcon(symbolName: resolvedVisualSearchSymbolName)
                        }
                        .accessibilityLabel("Visual Search")
                    }
                }
                .onSubmit(of: .search, onSubmit)
        } else {
            content
                .navigationBarHidden(true)
        }
    }

    private var resolvedVisualSearchSymbolName: String {
        let candidates = [
            "apple.intelligence",
            "sparkles.rectangle.stack",
            "viewfinder.circle",
            "camera.viewfinder",
            "sparkles",
        ]

        for symbol in candidates where UIImage(systemName: symbol) != nil {
            return symbol
        }

        return "camera.viewfinder"
    }
}

private struct TregoTabBarScrollPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct TregoWishlistScreen: View {
    @ObservedObject var store: TregoNativeAppStore

    var body: some View {
        NavigationView {
            GeometryReader { proxy in
                Group {
                    if store.isResolvingSession || store.wishlistLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.top, 80)
                    } else if store.user == nil {
                        VStack {
                            Spacer(minLength: 0)
                            TregoGuestCardView(
                                title: "Kycu ose krijo llogari",
                                subtitle: "Ruaj produktet qe i pelqen dhe kthehu te to sa here te duash.",
                                primaryTitle: "Log in",
                                secondaryTitle: "Sign up",
                                onPrimary: { store.openAccountAuth(.login) },
                                onSecondary: { store.openAccountAuth(.signup) }
                            )
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 28)
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 18) {
                                if store.wishlist.isEmpty {
                                    VStack {
                                        Spacer(minLength: 0)
                                        TregoWishlistEmptyCard()
                                        Spacer(minLength: 0)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: max(proxy.size.height - 144, 420))
                                } else {
                                    VStack(spacing: 14) {
                                        ForEach(store.wishlist) { product in
                                            TregoSavedProductRow(
                                                product: product,
                                                buttonTitle: "Open",
                                                buttonTint: .blue,
                                                onPrimary: { store.selectedProduct = product },
                                                onSecondary: {
                                                    Task { await store.toggleWishlist(for: product) }
                                                },
                                                secondaryTitle: "Remove"
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 132)
                        }
                    }
                }
            }
            .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                await store.loadWishlist()
            }
        }
        .navigationViewStyle(.stack)
        .tregoHideTabBarOnSecondaryPage()
    }
}

private struct TregoCartScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    @State private var selectedCartLineIds: Set<Int> = []
    @State private var knownCartLineIds: Set<Int> = []
    @State private var pricingDraft = TregoCheckoutDraft(
        addressLine: "",
        city: "",
        country: "Kosove",
        zipCode: "",
        phoneNumber: ""
    )
    @State private var summaryPricing: TregoCheckoutPricing?
    @State private var summaryRefreshTask: Task<Void, Never>?
    @State private var summaryLoading = false
    @State private var didLoadPricingDraft = false
    @State private var updatingCartLineIds: Set<Int> = []

    var body: some View {
        NavigationView {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cart")
                                .font(.system(size: 20, weight: .bold))
                            if store.user != nil && !store.cart.isEmpty {
                                Text("\(selectedItems.count) nga \(store.cart.count) artikuj te selektuar")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if store.user != nil {
                            if !store.cart.isEmpty {
                                Button {
                                    toggleAllSelection()
                                } label: {
                                    Image(systemName: areAllSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(areAllSelected ? TregoNativeTheme.accent : .secondary)
                                        .frame(width: 40, height: 40)
                                        .background(.ultraThinMaterial, in: Circle())
                                }
                                .buttonStyle(.plain)
                            }

                            NavigationLink(destination: TregoWishlistScreen(store: store)) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.red)
                                    .frame(width: 40, height: 40)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .background(TregoNativeTheme.systemBackground)
                    .zIndex(1)

                    Group {
                        if store.isResolvingSession || store.cartLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .padding(.top, 80)
                        } else if store.user == nil {
                            VStack {
                                Spacer(minLength: 0)
                                TregoGuestCardView(
                                    title: "Kycu ose krijo llogari",
                                    subtitle: "Ruaj artikujt ne karte dhe vazhdo checkout-in me vone.",
                                    primaryTitle: "Log in",
                                    secondaryTitle: "Sign up",
                                    onPrimary: { store.openAccountAuth(.login) },
                                    onSecondary: { store.openAccountAuth(.signup) }
                                )
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 28)
                        } else {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 18) {
                                    if store.cart.isEmpty {
                                        VStack {
                                            Spacer(minLength: 0)
                                            TregoCartEmptyCard()
                                            Spacer(minLength: 0)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: max(proxy.size.height - 208, 420))
                                    } else {
                                        VStack(spacing: 14) {
                                            ForEach(cartGroups) { group in
                                                TregoCartBusinessGroupCard(
                                                    group: group,
                                                    selectedCartLineIds: selectedCartLineIds,
                                                    updatingCartLineIds: updatingCartLineIds,
                                                    onToggleGroup: { toggleGroupSelection(group) },
                                                    onToggleItem: { toggleItemSelection($0) },
                                                    onDecreaseQuantity: { item in
                                                        Task { await adjustQuantity(for: item, delta: -1) }
                                                    },
                                                    onIncreaseQuantity: { item in
                                                        Task { await adjustQuantity(for: item, delta: 1) }
                                                    },
                                                    onRemove: { item in
                                                        Task {
                                                            await store.removeFromCart(cartLineId: item.id)
                                                        }
                                                    }
                                                )
                                            }

                                            Color.clear
                                                .frame(height: 18)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 4)
                                .padding(.bottom, 146)
                            }
                        }
                    }
                }
            }
            .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                await store.loadCart()
                await ensurePricingDraftLoaded()
                syncSelectionWithCart()
                scheduleSummaryRefresh()
            }
            .onChange(of: store.cart) { _ in
                syncSelectionWithCart()
                scheduleSummaryRefresh()
            }
            .onChange(of: selectedCartLineIds) { _ in
                scheduleSummaryRefresh()
            }
            .safeAreaInset(edge: .bottom) {
                if store.user != nil && !store.cart.isEmpty {
                    TregoCartStickySummaryCard(
                        selectedItemsCount: selectedItems.count,
                        subtotal: selectedSubtotal,
                        itemSavings: selectedItemSavings,
                        checkoutDiscount: checkoutDiscount,
                        shippingAmount: shippingAmount,
                        totalAmount: totalAmount,
                        isLoading: summaryLoading,
                        isCheckoutEnabled: !selectedItems.isEmpty,
                        checkoutDestination: TregoCheckoutScreen(store: store, cartItems: selectedItems)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var cartGroups: [TregoCartBusinessGroup] {
        Dictionary(grouping: store.cart) { item in
            let businessId = item.businessProfileId ?? 0
            let businessName = item.businessName?.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(businessId)|\(businessName?.lowercased() ?? "biznesi")"
        }
        .map { _, items in
            let sortedItems = items.sorted {
                ($0.title).localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return TregoCartBusinessGroup(
                businessId: sortedItems.first?.businessProfileId,
                businessName: sortedItems.first?.businessName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? (sortedItems.first?.businessName ?? "Biznesi")
                    : "Biznesi",
                items: sortedItems
            )
        }
        .sorted {
            $0.businessName.localizedCaseInsensitiveCompare($1.businessName) == .orderedAscending
        }
    }

    private var allCartLineIds: Set<Int> {
        Set(store.cart.map(\.id))
    }

    private var areAllSelected: Bool {
        !allCartLineIds.isEmpty && allCartLineIds.isSubset(of: selectedCartLineIds)
    }

    private var selectedItems: [TregoCartItem] {
        store.cart.filter { selectedCartLineIds.contains($0.id) }
    }

    private var selectedSubtotal: Double {
        selectedItems.reduce(0.0) { partial, item in
            partial + (Double(item.quantity ?? 1) * (item.price ?? 0))
        }
    }

    private var selectedItemSavings: Double {
        selectedItems.reduce(0.0) { partial, item in
            let compareAt = item.compareAtPrice ?? 0
            let currentPrice = item.price ?? 0
            let savings = max(0, compareAt - currentPrice) * Double(item.quantity ?? 1)
            return partial + savings
        }
    }

    private var checkoutDiscount: Double {
        summaryPricing?.discountAmount ?? 0
    }

    private var shippingAmount: Double {
        summaryPricing?.shippingAmount ?? 0
    }

    private var totalAmount: Double {
        summaryPricing?.total ?? max(0, selectedSubtotal + shippingAmount - checkoutDiscount)
    }

    private func toggleAllSelection() {
        if areAllSelected {
            selectedCartLineIds.removeAll()
        } else {
            selectedCartLineIds = allCartLineIds
        }
    }

    private func toggleGroupSelection(_ group: TregoCartBusinessGroup) {
        let groupIds = Set(group.items.map(\.id))
        if groupIds.isSubset(of: selectedCartLineIds) {
            selectedCartLineIds.subtract(groupIds)
        } else {
            selectedCartLineIds.formUnion(groupIds)
        }
    }

    private func toggleItemSelection(_ item: TregoCartItem) {
        if selectedCartLineIds.contains(item.id) {
            selectedCartLineIds.remove(item.id)
        } else {
            selectedCartLineIds.insert(item.id)
        }
    }

    private func syncSelectionWithCart() {
        let validIds = Set(store.cart.map(\.id))
        selectedCartLineIds = selectedCartLineIds.intersection(validIds)

        let newIds = validIds.subtracting(knownCartLineIds)
        selectedCartLineIds.formUnion(newIds)
        knownCartLineIds = validIds
    }

    private func ensurePricingDraftLoaded() async {
        guard !didLoadPricingDraft else { return }
        didLoadPricingDraft = true

        if let address = await store.api.fetchDefaultAddress() {
            pricingDraft = TregoCheckoutDraft(
                addressLine: address.addressLine ?? "",
                city: address.city ?? "",
                country: address.country?.isEmpty == false ? (address.country ?? "") : "Kosove",
                zipCode: address.zipCode ?? "",
                phoneNumber: address.phoneNumber?.isEmpty == false ? (address.phoneNumber ?? "") : (store.user?.phoneNumber ?? "")
            )
        } else {
            pricingDraft.phoneNumber = store.user?.phoneNumber ?? ""
        }
    }

    private func scheduleSummaryRefresh() {
        summaryRefreshTask?.cancel()
        let selectionSnapshot = selectedItems.map(\.id)
        summaryRefreshTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await refreshSummaryPricing(for: selectionSnapshot)
        }
    }

    private func refreshSummaryPricing(for selectionSnapshot: [Int]) async {
        guard !selectionSnapshot.isEmpty else {
            summaryPricing = nil
            return
        }

        guard !pricingDraft.addressLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !pricingDraft.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !pricingDraft.country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !pricingDraft.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            summaryPricing = nil
            return
        }

        summaryLoading = true
        defer { summaryLoading = false }

        let (_, pricing) = await store.api.fetchCheckoutPricing(
            cartLineIds: selectionSnapshot,
            draft: pricingDraft,
            promoCode: "",
            deliveryMethod: "standard"
        )

        guard Set(selectionSnapshot) == Set(selectedItems.map(\.id)) else { return }
        summaryPricing = pricing
    }

    private func adjustQuantity(for item: TregoCartItem, delta: Int) async {
        let currentQuantity = max(1, item.quantity ?? 1)
        let nextQuantity = currentQuantity + delta
        guard nextQuantity >= 1 else { return }
        guard !updatingCartLineIds.contains(item.id) else { return }

        updatingCartLineIds.insert(item.id)
        defer { updatingCartLineIds.remove(item.id) }

        await store.updateCartQuantity(cartLineId: item.id, quantity: nextQuantity)
    }
}

private struct TregoCartBusinessGroup: Identifiable {
    let businessId: Int?
    let businessName: String
    let items: [TregoCartItem]

    var id: String {
        "\(businessId ?? 0)-\(businessName.lowercased())"
    }
}

private struct TregoCartBusinessGroupCard: View {
    let group: TregoCartBusinessGroup
    let selectedCartLineIds: Set<Int>
    let updatingCartLineIds: Set<Int>
    let onToggleGroup: () -> Void
    let onToggleItem: (TregoCartItem) -> Void
    let onDecreaseQuantity: (TregoCartItem) -> Void
    let onIncreaseQuantity: (TregoCartItem) -> Void
    let onRemove: (TregoCartItem) -> Void

    private var groupIds: Set<Int> {
        Set(group.items.map(\.id))
    }

    private var isGroupSelected: Bool {
        !groupIds.isEmpty && groupIds.isSubset(of: selectedCartLineIds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onToggleGroup) {
                    Image(systemName: isGroupSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(isGroupSelected ? TregoNativeTheme.accent : .secondary)
                }
                .buttonStyle(.plain)

                Text(group.businessName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.92))

                Spacer(minLength: 0)

                Text("\(selectedCount)/\(group.items.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            VStack(spacing: 12) {
                ForEach(group.items) { item in
                    TregoCartRow(
                        item: item,
                        isSelected: selectedCartLineIds.contains(item.id),
                        isUpdatingQuantity: updatingCartLineIds.contains(item.id),
                        onToggleSelection: { onToggleItem(item) },
                        onDecreaseQuantity: { onDecreaseQuantity(item) },
                        onIncreaseQuantity: { onIncreaseQuantity(item) },
                        onRemove: { onRemove(item) }
                    )
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.38), lineWidth: 0.8)
        }
    }

    private var selectedCount: Int {
        group.items.filter { selectedCartLineIds.contains($0.id) }.count
    }
}

private struct TregoAccountScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isShortcutSearchFocused: Bool
    @State private var pickerSource: TregoImagePickerSource?
    @State private var isUploadingPhoto = false
    @State private var showsShortcutSearch = false
    @State private var shortcutSearchText = ""
    private let shortcutColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let user = store.user {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(spacing: 10) {
                                Button {
                                    store.globalMessage = "Customer Service eshte nen construction."
                                } label: {
                                    Label("Customer Service", systemImage: "headphones")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(.ultraThinMaterial, in: Capsule())
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Button {
                                    withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                                        showsShortcutSearch.toggle()
                                        if !showsShortcutSearch {
                                            shortcutSearchText = ""
                                            isShortcutSearchFocused = false
                                        }
                                    }
                                    if showsShortcutSearch {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                            isShortcutSearchFocused = true
                                        }
                                    }
                                } label: {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(TregoNativeTheme.primaryText)
                                        .frame(width: 40, height: 40)
                                        .tregoGlassCircleBackground()
                                }
                                .buttonStyle(.plain)
                            }

                            TregoUserCard(
                                user: user,
                                isUploadingPhoto: isUploadingPhoto,
                                onTakePhoto: {
                                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                        pickerSource = .camera
                                    } else {
                                        store.globalMessage = "Kamera nuk eshte e disponueshme tani."
                                    }
                                },
                                onChooseFromLibrary: {
                                    pickerSource = .photoLibrary
                                }
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                        .background(TregoNativeTheme.systemBackground)
                        .zIndex(1)

                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 18) {
                                LazyVGrid(columns: shortcutColumns, spacing: 10) {
                                    ForEach(filteredShortcutItems(for: user)) { item in
                                        NavigationLink(destination: destinationView(for: item.destination)) {
                                            TregoFeatureGridCard(
                                                title: item.title,
                                                subtitle: item.subtitle,
                                                icon: item.icon
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                if filteredShortcutItems(for: user).isEmpty {
                                    TregoEmptyStateView(
                                        title: "Asnje rezultat",
                                        subtitle: "Nuk u gjet asnje seksion per kerkimin tend."
                                    )
                                }

                                Button {
                                    Task { await store.logout() }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .font(.system(size: 15, weight: .bold))
                                        Text("Shkyçu")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                    .foregroundStyle(colorScheme == .dark ? Color.red.opacity(0.94) : Color.red.opacity(0.86))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .strokeBorder(
                                                colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.56),
                                                lineWidth: 0.9
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, 28)
                        }
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            if store.sessionRefreshing || !store.sessionLoaded {
                                HStack(spacing: 12) {
                                    ProgressView()
                                    Text("Po kontrollojme llogarine ne background...")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.8)
                                }
                            }

                            TregoAccountLoginPromptView(store: store)
                        }
                        .padding(.top, 36)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if showsShortcutSearch {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.secondary)

                        TextField("Kerko settings, porosi, njoftime...", text: $shortcutSearchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .focused($isShortcutSearchFocused)

                        Button {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                                shortcutSearchText = ""
                                showsShortcutSearch = false
                                isShortcutSearchFocused = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(width: min(UIScreen.main.bounds.width - 88, 310))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 14, y: 10)
                    .padding(.top, 60)
                    .padding(.trailing, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
                }
            }
            .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(item: $pickerSource) { source in
                TregoImagePicker(source: source) { upload in
                    Task { await uploadProfilePhoto(upload) }
                }
            }
            .task {
                if !store.sessionLoaded {
                    store.warmSessionRefreshInBackground(force: true)
                }
            }
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationViewStyle(.stack)
    }

    private func uploadProfilePhoto(_ upload: TregoImageSearchUpload) async {
        guard let user = store.user else { return }
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }

        guard let uploadedPath = await store.api.uploadProfilePhoto(upload: upload) else {
            store.globalMessage = "Fotoja e profilit nuk u ngarkua."
            return
        }

        let (response, _) = await store.api.updateProfile(
            firstName: user.firstName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? (user.firstName ?? "")
                : TregoNativeFormatting.firstName(from: user.fullName),
            lastName: user.lastName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? (user.lastName ?? "")
                : TregoNativeFormatting.lastName(from: user.fullName),
            birthDate: user.birthDate?.isEmpty == false
                ? (user.birthDate ?? "")
                : TregoNativeFormatting.storageDateString(from: TregoNativeFormatting.defaultBirthDate),
            gender: TregoNativeFormatting.genderPickerValue(from: user.gender),
            profileImagePath: uploadedPath
        )

        guard response.ok == true else {
            store.globalMessage = response.message ?? "Fotoja e profilit nuk u ruajt."
            return
        }

        await store.refreshSession(force: true)
        store.presentToast(response.message ?? "Fotoja e profilit u perditesua.")
    }

    private func filteredShortcutItems(for user: TregoSessionUser) -> [TregoAccountShortcutItem] {
        let items = shortcutItems(for: user)
        let trimmed = shortcutSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return items }

        return items.filter { item in
            let haystack = ([item.title, item.subtitle] + item.keywords)
                .joined(separator: " ")
                .lowercased()
            return haystack.contains(trimmed)
        }
    }

    private func shortcutItems(for user: TregoSessionUser) -> [TregoAccountShortcutItem] {
        var items: [TregoAccountShortcutItem] = [
            .init(
                id: "personal-data",
                title: "Te dhenat personale",
                subtitle: "Emri, fotoja dhe profili",
                icon: "person.crop.circle",
                keywords: ["profili", "emri", "foto", "user"],
                destination: .personalData
            ),
            .init(
                id: "change-password",
                title: "Ndrysho fjalekalimin",
                subtitle: "Siguria e llogarise",
                icon: "key.fill",
                keywords: ["password", "siguria", "login"],
                destination: .changePassword
            ),
            .init(
                id: "addresses",
                title: "Adresat",
                subtitle: "Dergesa dhe porosite",
                icon: "location.fill",
                keywords: ["adresa", "shipping", "delivery"],
                destination: .addresses
            ),
            .init(
                id: "history",
                title: "Historia",
                subtitle: "Produktet e shikuara",
                icon: "clock.arrow.circlepath",
                keywords: ["history", "historia", "recent", "viewed"],
                destination: .history
            ),
            .init(
                id: "notifications",
                title: "Njoftimet",
                subtitle: "Porosi dhe mesazhe",
                icon: "bell.badge.fill",
                keywords: ["notifications", "alerts", "porosi", "mesazhe"],
                destination: .notifications
            ),
            .init(
                id: "returns",
                title: "Refund / Returne",
                subtitle: "Kerkesat e kthimit",
                icon: "arrow.uturn.backward.circle.fill",
                keywords: ["refund", "return", "kthim"],
                destination: .returns
            ),
            .init(
                id: "app-settings",
                title: "App settings",
                subtitle: "Theme dhe privatësia",
                icon: "gearshape.fill",
                keywords: ["settings", "theme", "privacy", "privatesia"],
                destination: .settings
            ),
            .init(
                id: "orders",
                title: "Orders",
                subtitle: "Statuset e porosive",
                icon: "shippingbox.fill",
                keywords: ["orders", "porosite", "status"],
                destination: .orders
            ),
            .init(
                id: "messages",
                title: "Messages",
                subtitle: "Bisedat dhe support",
                icon: "bubble.left.and.bubble.right.fill",
                keywords: ["messages", "chat", "support", "mesazhe"],
                destination: .messages
            ),
        ]

        if user.role == "business" {
            items.append(
                .init(
                    id: "business-hub",
                    title: "Business Studio",
                    subtitle: "Produktet dhe porosite",
                    icon: "briefcase.fill",
                    keywords: ["business", "studio", "products", "analytics"],
                    destination: .businessHub
                )
            )
        }

        if user.role == "admin" {
            items.append(
                .init(
                    id: "admin-control",
                    title: "Admin Control",
                    subtitle: "Users dhe raporte",
                    icon: "shield.lefthalf.filled",
                    keywords: ["admin", "users", "reports", "control"],
                    destination: .adminControl
                )
            )
        }

        return items
    }

    @ViewBuilder
    private func destinationView(for destination: TregoAccountShortcutDestination) -> some View {
        switch destination {
        case .personalData:
            TregoPersonalDataScreen(store: store)
        case .changePassword:
            TregoChangePasswordScreen(store: store)
        case .addresses:
            TregoAddressesScreen(store: store)
        case .history:
            TregoHistoryScreen(store: store)
        case .notifications:
            TregoNotificationsScreen(store: store)
        case .returns:
            TregoReturnsScreen(store: store)
        case .settings:
            TregoAppSettingsScreen(store: store)
        case .orders:
            TregoOrdersScreen(store: store)
        case .messages:
            TregoMessagesScreen(store: store)
        case .businesses:
            TregoBusinessesExplorerScreen(store: store)
        case .businessHub:
            TregoBusinessHubScreen(store: store)
        case .adminControl:
            TregoAdminControlScreen(store: store)
        }
    }
}

private enum TregoAccountShortcutDestination {
    case personalData
    case changePassword
    case addresses
    case history
    case notifications
    case returns
    case settings
    case orders
    case messages
    case businesses
    case businessHub
    case adminControl
}

private struct TregoAccountShortcutItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let keywords: [String]
    let destination: TregoAccountShortcutDestination
}

private struct TregoAppSettingsScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    @State private var showsTrackingDialog = false

    private let themeOptions = [("system", "System"), ("light", "Light"), ("dark", "Dark")]
    private let languageOptions = [("sq", "Shqip"), ("en", "English")]
    private let currencyOptions = [("EUR", "EUR"), ("USD", "USD"), ("CHF", "CHF")]
    private let notificationOptions = [("all", "Te gjitha"), ("orders", "Vetem porosite"), ("essential", "Essential"), ("off", "Off")]
    private let privacyOptions = [("standard", "Standard"), ("strict", "Strict")]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                TregoNoticeCard(
                    title: "App settings",
                    subtitle: "Keto preferenca ruhen lokalisht ne app-in native dhe tema aplikohet menjehere ne iOS."
                )

                TregoSettingsSelectionCard(
                    title: "Theme",
                    subtitle: "Pamja e aplikacionit",
                    icon: "circle.lefthalf.filled",
                    currentValue: label(for: store.appSettings.theme, options: themeOptions),
                    options: themeOptions
                ) { store.updateAppTheme($0) }

                TregoSettingsSelectionCard(
                    title: "Gjuha",
                    subtitle: "Gjuha kryesore e app-it",
                    icon: "globe",
                    currentValue: label(for: store.appSettings.language, options: languageOptions),
                    options: languageOptions
                ) { store.updateAppLanguage($0) }

                TregoSettingsSelectionCard(
                    title: "Valuta",
                    subtitle: "Valuta e preferuar per shfaqje",
                    icon: "eurosign.circle",
                    currentValue: label(for: store.appSettings.currency, options: currencyOptions),
                    options: currencyOptions
                ) { store.updateAppCurrency($0) }

                TregoSettingsSelectionCard(
                    title: "Njoftimet",
                    subtitle: "Cfare lloji njoftimesh deshironi",
                    icon: "bell.badge",
                    currentValue: label(for: store.appSettings.notificationMode, options: notificationOptions),
                    options: notificationOptions
                ) { store.updateAppNotificationMode($0) }

                Button {
                    Task {
                        let response = await store.enableNativePushNotifications()
                        if response.ok == true {
                            store.globalMessage = response.message ?? "Push notifications u aktivizuan."
                        } else {
                            store.globalMessage = response.message ?? "Njoftimet nuk u aktivizuan."
                        }
                    }
                } label: {
                    TregoFeatureLinkRow(
                        title: "Push notifications",
                        subtitle: "Lock screen alerts per porosi dhe mesazhe"
                    )
                }
                .buttonStyle(.plain)

#if DEBUG
                Button {
                    Task {
                        let response = await store.scheduleDebugLocalNotification()
                        if response.ok == true {
                            store.globalMessage = response.message ?? "Njoftimi lokal u planifikua."
                        } else {
                            store.globalMessage = response.message ?? "Njoftimi lokal nuk u planifikua."
                        }
                    }
                } label: {
                    TregoFeatureLinkRow(
                        title: "Test local notification",
                        subtitle: "Simulon nje push me njoftim lokal ne kete build"
                    )
                }
                .buttonStyle(.plain)
#endif

                TregoSettingsSelectionCard(
                    title: "Privatesia",
                    subtitle: "Kontrolli i rekomandimeve dhe tracking-ut",
                    icon: "lock.shield",
                    currentValue: label(for: store.appSettings.privacyMode, options: privacyOptions),
                    options: privacyOptions
                ) { store.updateAppPrivacyMode($0) }

                Button {
                    showsTrackingDialog = true
                } label: {
                    TregoFeatureLinkRow(
                        title: "Cookies & Tracking",
                        subtitle: trackingConsentSubtitle
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .padding(.bottom, 90)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("App settings")
        .navigationBarTitleDisplayMode(.inline)
        .tregoHideTabBarOnSecondaryPage()
        .confirmationDialog(
            "Cookies & Tracking",
            isPresented: $showsTrackingDialog,
            titleVisibility: .visible
        ) {
            Button("Lejo") { store.allowPersonalizedRecommendations() }
            Button("Cancel", role: .cancel) { store.declinePersonalizedRecommendations() }
        } message: {
            Text("Lejo rekomandimet personale bazuar ne aktivitetin tend brenda app-it.")
        }
    }

    private func label(for value: String, options: [(String, String)]) -> String {
        options.first(where: { $0.0 == value })?.1 ?? value.capitalized
    }

    private var trackingConsentSubtitle: String {
        switch store.appSettings.personalizationConsentStatus {
        case "allowed":
            return "Aktive"
        case "declined":
            return "E anuluar"
        default:
            return "Pret konfirmim"
        }
    }
}

private struct TregoBusinessesExplorerScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    @State private var searchText = ""
    @State private var selectedCategoryKey = "all"
    @State private var previewProductsByBusiness: [Int: [TregoProduct]] = [:]
    @State private var previewLoadingBusinessIDs: Set<Int> = []
    @State private var visibleBusinessCount = 8
    @State private var openedBusinessSelection: TregoBusinessSelection?

    private let businessPageSize = 8

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Shkruaj emrin e biznesit ose qytetin", text: $searchText)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.search)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(.white.opacity(0.34), lineWidth: 0.8)
                    }

                if businessCategoryOptions.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(businessCategoryOptions, id: \.0) { option in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        selectedCategoryKey = option.0
                                    }
                                } label: {
                                    Text(option.1)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(selectedCategoryKey == option.0 ? .white : Color.primary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background {
                                            Capsule(style: .continuous)
                                                .fill(
                                                    selectedCategoryKey == option.0
                                                    ? TregoNativeTheme.accent
                                                    : Color.white.opacity(0.18)
                                                )
                                        }
                                        .overlay {
                                            Capsule(style: .continuous)
                                                .strokeBorder(
                                                    selectedCategoryKey == option.0
                                                    ? TregoNativeTheme.accent.opacity(0.18)
                                                    : Color.white.opacity(0.34),
                                                    lineWidth: 0.8
                                                )
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 14)
            .background(TregoNativeTheme.systemBackground)
            .zIndex(1)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if store.publicBusinessesLoading && store.publicBusinesses.isEmpty {
                        VStack(spacing: 16) {
                            ForEach(0..<4, id: \.self) { _ in
                                TregoBusinessExplorerCardSkeleton()
                            }
                        }
                    } else if filteredBusinesses.isEmpty {
                        TregoEmptyStateView(
                            title: "Nuk ka biznese",
                            subtitle: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "Bizneset publike do te shfaqen ketu sapo te jene aktive."
                                : "Nuk u gjet asnje biznes per kerkimin aktual."
                        )
                    } else {
                        ForEach(visibleBusinesses) { business in
                            TregoPublicBusinessExplorerCard(
                                business: business,
                                previewProducts: previewProductsByBusiness[business.id] ?? [],
                                isPreviewLoading: previewLoadingBusinessIDs.contains(business.id),
                                onOpen: {
                                    openedBusinessSelection = TregoBusinessSelection(id: business.id)
                                },
                                onFollow: {
                                    Task {
                                        await store.togglePublicBusinessFollow(business)
                                    }
                                },
                                onMessage: {
                                    Task {
                                        await store.startConversationWithBusiness(businessId: business.id)
                                    }
                                },
                                onOpenProduct: { product in
                                    store.selectedProduct = product
                                }
                            )
                            .task {
                                await ensurePreviewProducts(for: business.id)
                            }
                            .onAppear {
                                guard business.id == visibleBusinesses.last?.id, hasMoreVisibleBusinesses else { return }
                                visibleBusinessCount += businessPageSize
                                Task {
                                    await primePreviewProducts(for: visibleBusinesses)
                                }
                            }
                        }

                        if hasMoreVisibleBusinesses {
                            VStack(spacing: 16) {
                                ForEach(0..<2, id: \.self) { _ in
                                    TregoBusinessExplorerCardSkeleton()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 90)
            }
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .background(TregoBusinessPushLink(store: store, selection: $openedBusinessSelection))
        .navigationBarHidden(true)
        .onChange(of: searchText) { _ in
            visibleBusinessCount = businessPageSize
            Task {
                await primePreviewProducts(for: visibleBusinesses)
            }
        }
        .onChange(of: selectedCategoryKey) { _ in
            visibleBusinessCount = businessPageSize
            Task {
                await primePreviewProducts(for: visibleBusinesses)
            }
        }
        .task {
            if store.publicBusinesses.isEmpty {
                await store.loadPublicBusinesses()
            }
            visibleBusinessCount = businessPageSize
            await primePreviewProducts(for: visibleBusinesses)
        }
        .refreshable {
            let didRefreshBusinesses = await store.loadPublicBusinesses(force: true)
            if didRefreshBusinesses {
                previewProductsByBusiness = [:]
                previewLoadingBusinessIDs = []
                visibleBusinessCount = businessPageSize
                await primePreviewProducts(for: visibleBusinesses)
            }
        }
    }

    private var filteredBusinesses: [TregoPublicBusinessProfile] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.publicBusinesses.filter { business in
            let haystack = [
                business.businessName ?? "",
                business.businessDescription ?? "",
                business.city ?? "",
            ]
            .joined(separator: " ")
            .lowercased()

            let matchesSearch = trimmed.isEmpty || haystack.contains(trimmed)
            let matchesCategory = selectedCategoryKey == "all" || previewProductsForBusinessMatchSelectedCategory(business.id)
            return matchesSearch && matchesCategory
        }
    }

    private var visibleBusinesses: [TregoPublicBusinessProfile] {
        Array(filteredBusinesses.prefix(visibleBusinessCount))
    }

    private var hasMoreVisibleBusinesses: Bool {
        filteredBusinesses.count > visibleBusinesses.count
    }

    private var businessCategoryOptions: [(String, String)] {
        let categoryKeys = Set(
            previewProductsByBusiness.values
                .flatMap { $0 }
                .compactMap { businessCategoryKey(for: $0) }
        )

        let sorted = categoryKeys.sorted { businessCategoryLabel(for: $0) < businessCategoryLabel(for: $1) }
        return [("all", "Te gjitha")] + sorted.map { ($0, businessCategoryLabel(for: $0)) }
    }

    private func previewProductsForBusinessMatchSelectedCategory(_ businessID: Int) -> Bool {
        guard selectedCategoryKey != "all" else { return true }
        guard let products = previewProductsByBusiness[businessID] else { return false }
        return products.contains { businessCategoryKey(for: $0) == selectedCategoryKey }
    }

    private func businessCategoryKey(for product: TregoProduct) -> String? {
        let rawValue = (product.category?.isEmpty == false ? product.category : product.productType)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let rawValue, !rawValue.isEmpty else { return nil }
        return rawValue
    }

    private func businessCategoryLabel(for key: String) -> String {
        if let section = TregoNativeProductCatalog.sections.first(where: { $0.0 == key }) {
            return section.1
        }
        return key.capitalized
    }

    private func primePreviewProducts(for businesses: [TregoPublicBusinessProfile]? = nil) async {
        for business in (businesses ?? Array(store.publicBusinesses.prefix(businessPageSize))) {
            await ensurePreviewProducts(for: business.id)
        }
    }

    private func ensurePreviewProducts(for businessID: Int) async {
        if previewProductsByBusiness[businessID] != nil || previewLoadingBusinessIDs.contains(businessID) {
            return
        }

        _ = await MainActor.run {
            previewLoadingBusinessIDs.insert(businessID)
        }

        let result = await store.api.fetchPublicBusinessProductsPageResult(id: businessID, limit: 10, offset: 0)

        _ = await MainActor.run {
            previewLoadingBusinessIDs.remove(businessID)
            if result.didSucceed {
                previewProductsByBusiness[businessID] = result.page.items
            }
        }
    }
}

private struct TregoPersonalDataScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TregoNativeAppStore

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var birthDate = TregoNativeFormatting.defaultBirthDate
    @State private var gender = "femer"
    @State private var remoteProfileImagePath = ""
    @State private var selectedPhotoUpload: TregoImageSearchUpload?
    @State private var pickerSource: TregoImagePickerSource?
    @State private var showsPhotoOptions = false
    @State private var saveMessage = ""
    @State private var saveMessageTone: TregoStatusMessageTone?
    @State private var deletePassword = ""
    @State private var deleteMessage = ""
    @State private var deleteMessageTone: TregoStatusMessageTone?
    @State private var showsDeleteAccountSheet = false
    @State private var isSaving = false
    @State private var isDeleting = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                if let user = store.user {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Profili yt")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(TregoNativeTheme.primaryText)
                        Text("Menaxho foton, te dhenat personale dhe sigurine e llogarise ne nje vend.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(TregoNativeTheme.secondaryText)
                    }

                    TregoProfileImageEditorCard(
                        title: user.fullName ?? "Perdoruesi",
                        subtitle: user.email ?? user.phoneNumber ?? "TREGIO account",
                        imagePath: remoteProfileImagePath,
                        upload: selectedPhotoUpload,
                        onChoosePhoto: { showsPhotoOptions = true },
                        onRemovePhoto: {
                            selectedPhotoUpload = nil
                            remoteProfileImagePath = ""
                        }
                    )

                    if let tone = saveMessageTone, !saveMessage.isEmpty {
                        TregoStatusMessageCard(message: saveMessage, tone: tone)
                    }

                    TregoSettingsSectionCard(title: "Kontakt") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Detajet e kontaktit qe perdoren per hyrje, komunikim dhe perditesime te llogarise.")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(TregoNativeTheme.secondaryText)

                            VStack(spacing: 0) {
                                TregoAccountDetailRow(
                                    title: "Email",
                                    value: user.email ?? "",
                                    systemImage: "envelope.fill",
                                    helper: "Per hyrje dhe njoftime"
                                )
                                Divider()
                                    .overlay(Color.white.opacity(0.08))
                                TregoAccountDetailRow(
                                    title: "Telefoni",
                                    value: user.phoneNumber ?? "",
                                    systemImage: "phone.fill",
                                    helper: "Per kontakt dhe verifikim"
                                )
                            }
                        }
                    }

                    TregoSettingsSectionCard(title: "Detajet personale") {
                        TregoInputCard(title: "Emri", text: $firstName, placeholder: "Shkruaj emrin", textContentType: .givenName, disableAutocorrection: false)
                        TregoInputCard(title: "Mbiemri", text: $lastName, placeholder: "Shkruaj mbiemrin", textContentType: .familyName, disableAutocorrection: false)
                        TregoBirthDateGenderRow(
                            birthDate: $birthDate,
                            gender: $gender
                        )

                        HStack(spacing: 12) {
                            Button {
                                Task { await saveProfile() }
                            } label: {
                                if isSaving {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text("Ruaj ndryshimet")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(TregoPrimaryButtonStyle())

                            Button("Anulo") {
                                hydrateFromCurrentUser()
                            }
                            .buttonStyle(TregoSecondaryButtonStyle())
                        }
                    }

                    if let tone = deleteMessageTone, !deleteMessage.isEmpty {
                        TregoStatusMessageCard(message: deleteMessage, tone: tone)
                    }

                    TregoSettingsSectionCard(title: "Veprime") {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Fshirja e llogarise eshte veprim permanent dhe do te humbasesh te gjitha te dhenat e ruajtura.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(TregoNativeTheme.secondaryText)

                            Button {
                                showsDeleteAccountSheet = true
                            } label: {
                                Label("Fshi llogarine", systemImage: "exclamationmark.triangle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(TregoDangerButtonStyle())
                        }
                    }
                } else {
                    TregoScreenGuestNotice(
                        title: "Kyçu për te dhenat personale",
                        subtitle: "Kjo faqe hapet pasi të kycësh llogarinë tende."
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.vertical, 18)
            .padding(.bottom, 90)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Te dhenat personale")
        .navigationBarTitleDisplayMode(.inline)
        .tregoHideTabBarOnSecondaryPage()
        .confirmationDialog("Foto e profilit", isPresented: $showsPhotoOptions) {
            Button("Bej foto") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    pickerSource = .camera
                } else {
                    store.globalMessage = "Kamera nuk eshte e disponueshme tani."
                }
            }
            Button("Zgjidh nga galeria") {
                pickerSource = .photoLibrary
            }
            Button("Anulo", role: .cancel) {}
        }
        .sheet(item: $pickerSource) { source in
            TregoImagePicker(source: source) { upload in
                selectedPhotoUpload = upload
            }
        }
        .sheet(isPresented: $showsDeleteAccountSheet) {
            NavigationView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.red, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fshij llogarine")
                                .font(.system(size: 20, weight: .bold))
                            Text("Nese e fshin llogarine, do t'i humbasesh pergjithmone te gjitha te dhenat e ruajtura.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    TregoSecureInputCard(title: "Fjalekalimi", text: $deletePassword, textContentType: .password)

                    if let tone = deleteMessageTone, !deleteMessage.isEmpty {
                        TregoStatusMessageCard(message: deleteMessage, tone: tone)
                    }

                    Button {
                        Task { await deleteAccount() }
                    } label: {
                        if isDeleting {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Fshi llogarine", systemImage: "exclamationmark.triangle.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(TregoDangerButtonStyle())

                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
                .navigationTitle("Fshij llogarine")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Anulo") {
                            showsDeleteAccountSheet = false
                            deletePassword = ""
                            deleteMessage = ""
                            deleteMessageTone = nil
                        }
                    }
                }
            }
            .tregoPopupSheetStyle(height: 360)
        }
        .task {
            hydrateFromCurrentUser()
        }
    }

    private func hydrateFromCurrentUser() {
        guard let user = store.user else { return }
        firstName = user.firstName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (user.firstName ?? "")
            : TregoNativeFormatting.firstName(from: user.fullName)
        lastName = user.lastName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (user.lastName ?? "")
            : TregoNativeFormatting.lastName(from: user.fullName)
        birthDate = TregoNativeFormatting.date(fromStorage: user.birthDate)
        gender = TregoNativeFormatting.genderPickerValue(from: user.gender)
        remoteProfileImagePath = user.profileImagePath ?? ""
        selectedPhotoUpload = nil
        saveMessage = ""
        saveMessageTone = nil
        deleteMessage = ""
        deleteMessageTone = nil
    }

    private func saveProfile() async {
        guard !isSaving else { return }
        guard store.user != nil else { return }
        isSaving = true
        defer { isSaving = false }

        var nextImagePath = remoteProfileImagePath
        if let upload = selectedPhotoUpload {
            if let uploadedPath = await store.api.uploadProfilePhoto(upload: upload) {
                nextImagePath = uploadedPath
            } else {
                saveMessage = "Fotoja e profilit nuk u ngarkua."
                saveMessageTone = .error
                return
            }
        }

        let (response, _) = await store.api.updateProfile(
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            birthDate: TregoNativeFormatting.storageDateString(from: birthDate),
            gender: gender,
            profileImagePath: nextImagePath
        )

        guard response.ok == true else {
            saveMessage = response.message ?? "Ruajtja e profilit nuk funksionoi."
            saveMessageTone = .error
            return
        }

        remoteProfileImagePath = nextImagePath
        selectedPhotoUpload = nil
        await store.refreshSession(force: true)
        saveMessage = response.message ?? "Profili u ruajt me sukses."
        saveMessageTone = .success
    }

    private func deleteAccount() async {
        guard !isDeleting else { return }
        guard !deletePassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            deleteMessage = "Shkruaj fjalekalimin para se ta fshish llogarine."
            deleteMessageTone = .error
            return
        }

        isDeleting = true
        defer { isDeleting = false }

        let response = await store.api.deleteOwnAccount(password: deletePassword)
        guard response.ok == true else {
            deleteMessage = response.message ?? "Llogaria nuk u fshi."
            deleteMessageTone = .error
            deletePassword = ""
            return
        }

        store.resetSessionState()
        store.selectedTab = .llogaria
        showsDeleteAccountSheet = false
        store.globalMessage = response.message ?? "Llogaria u fshi me sukses."
        dismiss()
    }
}

private struct TregoChangePasswordScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TregoNativeAppStore

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var message = ""
    @State private var messageTone: TregoStatusMessageTone?
    @State private var isSubmitting = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if store.user != nil {
                    TregoNoticeCard(
                        title: "Ndrysho fjalëkalimin",
                        subtitle: "Pasi ta perditesosh, do te duhet te kyçesh perseri per arsye sigurie."
                    )

                    TregoSecureInputCard(title: "Fjalëkalimi aktual", text: $currentPassword, textContentType: .password, submitLabel: .next)
                    TregoSecureInputCard(title: "Fjalëkalimi i ri", text: $newPassword, textContentType: .newPassword, submitLabel: .next)
                    TregoSecureInputCard(title: "Konfirmo fjalëkalimin e ri", text: $confirmPassword, textContentType: .newPassword, submitLabel: .done)

                    if let tone = messageTone, !message.isEmpty {
                        TregoStatusMessageCard(message: message, tone: tone)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Ruaj fjalëkalimin")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(TregoPrimaryButtonStyle())
                } else {
                    TregoScreenGuestNotice(
                        title: "Kyçu për sigurine",
                        subtitle: "Pasi të kyçesh, mund ta ndryshosh fjalëkalimin nga kjo faqe."
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .padding(.bottom, 90)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Ndrysho fjalekalimin")
        .navigationBarTitleDisplayMode(.inline)
        .tregoHideTabBarOnSecondaryPage()
    }

    private func submit() async {
        guard !isSubmitting else { return }
        guard !currentPassword.isEmpty, !newPassword.isEmpty, !confirmPassword.isEmpty else {
            message = "Ploteso te gjitha fushat."
            messageTone = .error
            return
        }
        guard newPassword == confirmPassword else {
            message = "Konfirmimi i fjalekalimit nuk perputhet."
            messageTone = .error
            confirmPassword = ""
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let response = await store.api.changePassword(currentPassword: currentPassword, newPassword: newPassword)
        guard response.ok == true else {
            message = response.message ?? "Fjalekalimi nuk u ndryshua."
            messageTone = .error
            currentPassword = ""
            return
        }

        store.resetSessionState()
        store.selectedTab = .llogaria
        store.globalMessage = response.message ?? "Fjalekalimi u ndryshua. Kyçu perseri."
        dismiss()
    }
}

private struct TregoAddressesScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    @StateObject private var locationHelper = TregoAddressLocationHelper()

    @State private var savedAddress: TregoAddress?
    @State private var addressLine = ""
    @State private var city = ""
    @State private var country = ""
    @State private var zipCode = ""
    @State private var phoneNumber = ""
    @State private var message = ""
    @State private var messageTone: TregoStatusMessageTone?
    @State private var isLoading = false
    @State private var isSaving = false

    private let infoColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if store.user != nil {
                    TregoNoticeCard(
                        title: "Adresa default",
                        subtitle: "Kjo adrese ruhet per porosite, dergesat dhe lidhjen me bizneset."
                    )

                    if let savedAddress {
                        LazyVGrid(columns: infoColumns, spacing: 12) {
                            TregoInfoTile(title: "Adresa", value: savedAddress.addressLine ?? "-")
                            TregoInfoTile(title: "Qyteti", value: savedAddress.city ?? "-")
                            TregoInfoTile(title: "Shteti", value: savedAddress.country ?? "-")
                            TregoInfoTile(title: "Zip code", value: savedAddress.zipCode ?? "-")
                        }
                    }

                    if let tone = messageTone, !message.isEmpty {
                        TregoStatusMessageCard(message: message, tone: tone)
                    }

                    if isLoading && savedAddress == nil {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 30)
                    } else {
                        Button {
                            locationHelper.requestCurrentAddress()
                        } label: {
                            HStack(spacing: 10) {
                                if locationHelper.isLoading {
                                    ProgressView()
                                } else {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                Text(locationHelper.isLoading ? "Po marr adresen nga lokacioni..." : "Perdor lokacionin aktual")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(TregoSecondaryButtonStyle())

                        TregoInputCard(title: "Adresa e vendbanimit", text: $addressLine, placeholder: "Rruga, numri, hyrja", textContentType: .fullStreetAddress, disableAutocorrection: false)
                        TregoInputCard(title: "Qyteti", text: $city, placeholder: "Shkruaj qytetin", textContentType: .addressCity, disableAutocorrection: false)
                        TregoInputCard(title: "Shteti", text: $country, placeholder: "Shkruaj shtetin", textContentType: .countryName, disableAutocorrection: false)
                        TregoInputCard(title: "Zip code", text: $zipCode, placeholder: "Shkruaj zip code", textContentType: .postalCode)
                        TregoInputCard(title: "Numri i telefonit", text: $phoneNumber, keyboardType: .phonePad, placeholder: "+383 44 123 456", autocapitalization: .never, textContentType: .telephoneNumber)

                        HStack(spacing: 12) {
                            Button {
                                Task { await saveAddress() }
                            } label: {
                                if isSaving {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text("Ruaj adresen")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(TregoPrimaryButtonStyle())

                            Button("Anulo") {
                                hydrateAddress(savedAddress)
                            }
                            .buttonStyle(TregoSecondaryButtonStyle())
                        }
                    }
                } else {
                    TregoScreenGuestNotice(
                        title: "Kyçu për adresat",
                        subtitle: "Pasi të kyçesh, mund ta ruash adresen default nga kjo faqe."
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .padding(.bottom, 90)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Adresat")
        .navigationBarTitleDisplayMode(.inline)
        .tregoHideTabBarOnSecondaryPage()
        .task {
            await loadAddress()
        }
        .onChange(of: locationHelper.resolvedAddress) { resolved in
            guard let resolved else { return }
            addressLine = resolved.addressLine
            city = resolved.city
            country = resolved.country
            zipCode = resolved.zipCode
            message = "Adresa u mbush nga lokacioni aktual."
            messageTone = .success
        }
        .onChange(of: locationHelper.errorMessage) { errorMessage in
            guard let errorMessage, !errorMessage.isEmpty else { return }
            message = errorMessage
            messageTone = .error
        }
    }

    private func hydrateAddress(_ address: TregoAddress?) {
        addressLine = address?.addressLine ?? ""
        city = address?.city ?? ""
        country = address?.country ?? ""
        zipCode = address?.zipCode ?? ""
        phoneNumber = address?.phoneNumber ?? store.user?.phoneNumber ?? ""
    }

    private func loadAddress() async {
        guard store.user != nil else { return }
        isLoading = true
        defer { isLoading = false }
        let address = await store.api.fetchDefaultAddress()
        savedAddress = address
        hydrateAddress(address)
    }

    private func saveAddress() async {
        guard !isSaving else { return }
        guard store.user != nil else { return }
        guard !addressLine.isEmpty, !city.isEmpty, !country.isEmpty, !zipCode.isEmpty, !phoneNumber.isEmpty else {
            message = "Ploteso te gjitha fushat e adreses."
            messageTone = .error
            return
        }

        isSaving = true
        defer { isSaving = false }

        let (response, address) = await store.api.saveDefaultAddress(
            addressLine: addressLine.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            country: country.trimmingCharacters(in: .whitespacesAndNewlines),
            zipCode: zipCode.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        guard response.ok == true, let address else {
            message = response.message ?? "Adresa nuk u ruajt."
            messageTone = .error
            return
        }

        savedAddress = address
        hydrateAddress(address)
        message = response.message ?? "Adresa default u ruajt."
        messageTone = .success
    }
}

private struct TregoResolvedAddress: Equatable {
    let addressLine: String
    let city: String
    let country: String
    let zipCode: String
}

private final class TregoAddressLocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var resolvedAddress: TregoResolvedAddress?
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestCurrentAddress() {
        errorMessage = nil
        resolvedAddress = nil

        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            isLoading = true
            locationManager.requestLocation()
        case .notDetermined:
            isLoading = true
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            isLoading = false
            errorMessage = "Lejo Location Services per te mbushur adresen automatikisht."
        @unknown default:
            isLoading = false
            errorMessage = "Lokacioni nuk eshte i disponueshem tani."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if isLoading {
                manager.requestLocation()
            }
        case .denied, .restricted:
            isLoading = false
            errorMessage = "Lejo Location Services per te mbushur adresen automatikisht."
        case .notDetermined:
            break
        @unknown default:
            isLoading = false
            errorMessage = "Lokacioni nuk eshte i disponueshem tani."
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            isLoading = false
            errorMessage = "Nuk u gjet lokacioni aktual."
            return
        }

        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "sq_AL")) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let placemark = placemarks?.first else {
                    self.errorMessage = "Nuk u gjet adresa nga lokacioni."
                    return
                }

                let street = [placemark.thoroughfare, placemark.subThoroughfare]
                    .compactMap { value in
                        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? nil : trimmed
                    }
                    .joined(separator: " ")

                let locality = [placemark.locality, placemark.subAdministrativeArea]
                    .compactMap { value in
                        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? nil : trimmed
                    }
                    .first ?? ""

                let country = (placemark.country ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let postalCode = (placemark.postalCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                self.resolvedAddress = TregoResolvedAddress(
                    addressLine: street.isEmpty ? "Lokacioni aktual" : street,
                    city: locality,
                    country: country,
                    zipCode: postalCode
                )
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
        errorMessage = error.localizedDescription
    }
}

private struct TregoHistoryScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    @State private var pendingDeleteEntry: TregoViewedHistoryEntry?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if store.viewedHistory.isEmpty {
                    TregoEmptyStateView(
                        title: "Historia eshte bosh",
                        subtitle: "Produktet qe shikon do te dalin ketu sipas dates."
                    )
                } else {
                    ForEach(historySections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(TregoNativeTheme.accent)

                            VStack(spacing: 12) {
                                ForEach(section.entries) { entry in
                                    TregoSavedProductRow(
                                        product: entry.product,
                                        buttonTitle: "Open",
                                        buttonTint: TregoNativeTheme.accent,
                                        onPrimary: { store.selectedProduct = entry.product },
                                        onSecondary: { pendingDeleteEntry = entry },
                                        secondaryTitle: "Remove"
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .padding(.bottom, 90)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Historia")
        .navigationBarTitleDisplayMode(.inline)
        .tregoHideTabBarOnSecondaryPage()
        .alert("Deshironi ta largoni produktin?", isPresented: Binding(
            get: { pendingDeleteEntry != nil },
            set: { if !$0 { pendingDeleteEntry = nil } }
        )) {
            Button("Po, deshiroj ta largoj", role: .destructive) {
                if let entry = pendingDeleteEntry {
                    store.removeViewedHistoryProduct(productID: entry.product.id)
                    store.presentToast("Produkti u largua nga historia.")
                }
                pendingDeleteEntry = nil
            }
            Button("Jo, ktheje produktin", role: .cancel) {
                pendingDeleteEntry = nil
            }
        } message: {
            Text(pendingDeleteEntry?.product.title ?? "")
        }
    }

    private var historySections: [TregoHistorySection] {
        let grouped = Dictionary(grouping: store.viewedHistory) { entry in
            Calendar.current.startOfDay(for: viewedDate(from: entry))
        }

        return grouped.keys.sorted(by: >).map { date in
            TregoHistorySection(
                title: sectionTitle(for: date),
                entries: grouped[date]?.sorted { viewedDate(from: $0) > viewedDate(from: $1) } ?? []
            )
        }
    }

    private func viewedDate(from entry: TregoViewedHistoryEntry) -> Date {
        TregoNativeFormatting.optionalDate(fromStorage: entry.viewedAt) ?? Date()
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Sot"
        }
        if calendar.isDateInYesterday(date) {
            return "Dje"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sq_AL")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct TregoHistorySection {
    let title: String
    let entries: [TregoViewedHistoryEntry]
}

private struct TregoNotificationsScreen: View {
    @ObservedObject var store: TregoNativeAppStore

    @State private var notifications: [TregoNotificationItem] = []
    @State private var unreadCount = 0
    @State private var message = ""
    @State private var messageTone: TregoStatusMessageTone?
    @State private var isLoading = false
    @State private var selectedNotification: TregoNotificationItem?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if store.user != nil {
                    TregoNoticeCard(
                        title: "Njoftimet",
                        subtitle: unreadCount > 0
                            ? "Ke \(unreadCount) njoftime te palexuara. Keto përditësohen nga porositë, mesazhet dhe kthimet."
                            : "Ketu shfaqen perditesimet per porosite, verifikimet, mesazhet dhe kthimet."
                    )

                    if let tone = messageTone, !message.isEmpty {
                        TregoStatusMessageCard(message: message, tone: tone)
                    }

                    if isLoading && notifications.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 30)
                    } else if notifications.isEmpty {
                        TregoEmptyStateView(
                            title: "Ende nuk ka njoftime",
                            subtitle: "Perditesimet per porosite, mesazhet dhe verifikimet do te dalin ketu."
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(notifications) { notification in
                                Button {
                                    selectedNotification = notification
                                } label: {
                                    TregoNotificationCard(notification: notification)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button("Fshij", role: .destructive) {
                                        Task { await deleteNotification(notification) }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    TregoScreenGuestNotice(
                        title: "Kyçu për njoftimet",
                        subtitle: "Pasi të kyçesh, njoftimet e porosive dhe mesazheve do të dalin ketu."
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .padding(.bottom, 90)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Njoftimet")
        .navigationBarTitleDisplayMode(.inline)
        .tregoHideTabBarOnSecondaryPage()
        .task {
            await loadNotifications()
        }
        .refreshable {
            await loadNotifications()
        }
        .sheet(item: $selectedNotification) { notification in
            NavigationView {
                TregoNotificationDetailSheet(
                    notification: notification,
                    onCancel: {
                        selectedNotification = nil
                    },
                    onOpen: {
                        selectedNotification = nil
                        Task { await store.openNotificationItem(notification) }
                    }
                )
            }
            .tregoPopupSheetStyle(height: 340)
        }
    }

    private func loadNotifications() async {
        guard store.user != nil else { return }
        isLoading = true
        defer { isLoading = false }

        let payload = await store.api.fetchNotifications()
        notifications = payload.notifications
        unreadCount = payload.unreadCount
        message = ""
        messageTone = nil

        if payload.unreadCount > 0 {
            let response = await store.api.markNotificationsRead()
            if response.ok == true {
                let readAt = ISO8601DateFormatter().string(from: Date())
                notifications = notifications.map { item in
                    TregoNotificationItem(
                        id: item.id,
                        type: item.type,
                        title: item.title,
                        body: item.body,
                        href: item.href,
                        isRead: true,
                        createdAt: item.createdAt,
                        readAt: item.readAt ?? readAt
                    )
                }
                unreadCount = 0
                await store.refreshNotificationBadgeCount()
            }
        } else {
            await store.refreshNotificationBadgeCount()
        }
    }

    private func deleteNotification(_ notification: TregoNotificationItem) async {
        let response = await store.api.deleteNotification(notificationId: notification.id)
        guard response.ok == true else {
            message = response.message ?? "Njoftimi nuk u fshi."
            messageTone = .error
            return
        }

        notifications.removeAll { $0.id == notification.id }
        unreadCount = notifications.filter { $0.isRead != true }.count
        message = response.message ?? "Njoftimi u fshi."
        messageTone = .success
        await store.refreshNotificationBadgeCount()
    }
}

private struct TregoReturnsScreen: View {
    @ObservedObject var store: TregoNativeAppStore

    @State private var requests: [TregoReturnRequest] = []
    @State private var message = ""
    @State private var messageTone: TregoStatusMessageTone?
    @State private var isLoading = false
    @State private var activeRequestId: Int?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if store.user != nil {
                    TregoNoticeCard(
                        title: "Refund / Returne",
                        subtitle: canManageReturns
                            ? "Ketu mund te shqyrtosh, aprovosh ose rimbursosh kerkesat e kthimit."
                            : "Ketu i sheh te gjitha kerkesat e tua per kthim dhe statusin e tyre."
                    )

                    if let tone = messageTone, !message.isEmpty {
                        TregoStatusMessageCard(message: message, tone: tone)
                    }

                    if isLoading && requests.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 30)
                    } else if requests.isEmpty {
                        TregoEmptyStateView(
                            title: "Ende nuk ka kerkesa",
                            subtitle: "Kerkesat per refund ose returne do te shfaqen ketu."
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(requests) { request in
                                TregoReturnRequestCard(
                                    request: request,
                                    canManage: canManageReturns,
                                    isUpdating: activeRequestId == request.id,
                                    onUpdate: { status in
                                        Task { await updateReturnStatus(request, status: status) }
                                    }
                                )
                            }
                        }
                    }
                } else {
                    TregoScreenGuestNotice(
                        title: "Kyçu për refund / returne",
                        subtitle: "Pasi të kyçesh, mund t'i shohësh kerkesat e kthimit nga kjo faqe."
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .padding(.bottom, 90)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Refund / Returne")
        .navigationBarTitleDisplayMode(.inline)
        .tregoHideTabBarOnSecondaryPage()
        .task {
            await loadRequests()
        }
        .refreshable {
            await loadRequests()
        }
    }

    private var canManageReturns: Bool {
        let role = store.user?.role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return role == "business" || role == "admin"
    }

    private func loadRequests() async {
        guard store.user != nil else { return }
        isLoading = true
        defer { isLoading = false }
        requests = await store.api.fetchReturnRequests()
    }

    private func updateReturnStatus(_ request: TregoReturnRequest, status: String) async {
        guard canManageReturns else { return }
        activeRequestId = request.id
        defer { activeRequestId = nil }

        let response = await store.api.updateReturnRequestStatus(returnRequestId: request.id, status: status)
        guard response.ok == true else {
            message = response.message ?? "Kerkesa nuk u perditesua."
            messageTone = .error
            return
        }

        message = response.message ?? "Kerkesa u perditesua."
        messageTone = .success
        await loadRequests()
    }
}

private struct TregoBusinessHubScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    @State private var isCreateProductPresented = false
    @State private var editingProduct: TregoProduct?
    @State private var isCreatePromotionPresented = false
    @State private var editingPromotion: TregoPromotion?
    @State private var managingOrder: TregoOrderItem?

    private let productGrid = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if store.user?.role != "business" {
                    TregoNoticeCard(
                        title: "Business only",
                        subtitle: "Ky seksion shfaqet kur hyn me llogari biznesi."
                    )
                } else {
                    if store.businessWorkspaceLoading && store.businessProfile == nil {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                    } else {
                        TregoBusinessProfileCard(profile: store.businessProfile, fallbackName: store.user?.businessName)

                        TregoMiniStatsGrid(items: businessSummaryItems)

                        NavigationLink(destination: TregoBusinessSettingsScreen(store: store)) {
                            TregoFeatureLinkRow(
                                title: "Profili & Transporti",
                                subtitle: "Perditeso profilin e biznesit dhe rregullat e dergeses"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: TregoBusinessAnalyticsScreen(store: store)) {
                            TregoFeatureLinkRow(
                                title: "Analytics",
                                subtitle: "Shiko shitjet, vleresimet dhe pulse-in e biznesit"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: TregoManagedOrdersScreen(store: store, mode: .business)) {
                            TregoFeatureLinkRow(
                                title: "Te gjitha porosite",
                                subtitle: "Menaxho statuset dhe tracking per cdo porosi"
                            )
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 10) {
                            Button("Kerko verifikim") {
                                Task { await store.requestBusinessVerification() }
                            }
                            .buttonStyle(TregoSecondaryButtonStyle())

                            Button("Kerko editim") {
                                Task { await store.requestBusinessEditAccess() }
                            }
                            .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.accent))
                        }

                        HStack {
                            TregoSectionHeader(title: "Produktet")
                            Spacer()
                            Button {
                                isCreateProductPresented = true
                            } label: {
                                Label("Shto artikull", systemImage: "plus")
                            }
                            .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.softAccent))
                        }

                        if !store.businessProducts.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(store.businessProducts) { product in
                                    TregoBusinessManagedProductRow(
                                        product: product,
                                        onOpen: { store.selectedProduct = product },
                                        onEdit: { editingProduct = product },
                                        onToggleVisibility: {
                                            Task {
                                                await store.updateBusinessProductVisibility(product, isPublic: !(product.isPublic ?? false))
                                            }
                                        },
                                        onDelete: {
                                            Task {
                                                await store.deleteBusinessProduct(product)
                                            }
                                        }
                                    )
                                }
                            }
                        } else {
                            TregoEmptyStateView(
                                title: "Nuk ka produkte",
                                subtitle: "Shto artikullin e pare te biznesit dhe ai do te shfaqet ketu."
                            )
                        }

                        if !store.businessOrders.isEmpty {
                            HStack {
                                TregoSectionHeader(title: "Porosite e fundit")
                                Spacer()
                            }
                            VStack(spacing: 12) {
                                ForEach(Array(store.businessOrders.prefix(3))) { order in
                                    TregoOrderManagementCard(
                                        order: order,
                                        managerLabel: "Biznes",
                                        onUpdate: { managingOrder = order }
                                    )
                                }
                            }
                        }

                        HStack {
                            TregoSectionHeader(title: "Promocionet")
                            Spacer()
                            Button {
                                isCreatePromotionPresented = true
                            } label: {
                                Label("Shto promocion", systemImage: "ticket.fill")
                            }
                            .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.accent))
                        }

                        if !store.businessPromotions.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(Array(store.businessPromotions.prefix(4)), id: \.stableID) { promotion in
                                    TregoPromotionManagementRow(
                                        promotion: promotion,
                                        onEdit: { editingPromotion = promotion },
                                        onDelete: {
                                            Task {
                                                if let message = await store.deleteBusinessPromotion(promotion) {
                                                    store.globalMessage = message
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                        } else {
                            TregoEmptyStateView(
                                title: "Nuk ka promocione",
                                subtitle: "Krijo kuponin e pare te biznesit dhe monitoroje zbritjet nga iPhone."
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .padding(.bottom, 90)
        }
        .background(TregoNativeTheme.background.ignoresSafeArea())
        .navigationTitle("Business Studio")
        .navigationBarTitleDisplayMode(.inline)
        .tregoHideTabBarOnSecondaryPage()
        .task {
            await store.loadBusinessWorkspace()
        }
        .refreshable {
            await store.loadBusinessWorkspace(force: true)
        }
        .sheet(isPresented: $isCreateProductPresented) {
            NavigationView {
                TregoBusinessProductEditorScreen(store: store, existingProduct: nil)
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $editingProduct) { product in
            NavigationView {
                TregoBusinessProductEditorScreen(store: store, existingProduct: product)
            }
            .navigationViewStyle(.stack)
        }
        .sheet(isPresented: $isCreatePromotionPresented) {
            NavigationView {
                TregoPromotionEditorScreen(store: store, existingPromotion: nil)
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $editingPromotion) { promotion in
            NavigationView {
                TregoPromotionEditorScreen(store: store, existingPromotion: promotion)
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $managingOrder) { order in
            NavigationView {
                TregoOrderStatusEditorScreen(
                    store: store,
                    order: order,
                    title: "Perditeso porosine",
                    onSave: { status, trackingCode, trackingURL in
                        await store.updateBusinessOrderStatus(
                            order,
                            status: status,
                            trackingCode: trackingCode,
                            trackingURL: trackingURL
                        )
                    }
                )
            }
            .navigationViewStyle(.stack)
        }
    }

    private var businessSummaryItems: [TregoMiniStatItem] {
        [
            TregoMiniStatItem(
                label: "Views",
                value: String(store.businessAnalytics?.viewsCount ?? 0),
                icon: "eye"
            ),
            TregoMiniStatItem(
                label: "Wishlist",
                value: String(store.businessAnalytics?.wishlistCount ?? 0),
                icon: "heart"
            ),
            TregoMiniStatItem(
                label: "Cart",
                value: String(store.businessAnalytics?.cartCount ?? 0),
                icon: "cart"
            ),
            TregoMiniStatItem(
                label: "Orders",
                value: String(store.businessProfile?.ordersCount ?? store.businessAnalytics?.ordersCount ?? 0),
                icon: "shippingbox"
            ),
        ]
    }
}

private struct TregoAdminControlScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    @State private var passwordResetUser: TregoAdminUser?
    @State private var isCreateBusinessPresented = false
    @State private var editingBusiness: TregoAdminBusiness?
    @State private var isCreateLaunchAdPresented = false
    @State private var editingLaunchAd: TregoLaunchAd?
    @State private var managingOrder: TregoOrderItem?
    @State private var inspectingBusiness: TregoAdminBusiness?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if store.user?.role != "admin" {
                    TregoNoticeCard(
                        title: "Admin only",
                        subtitle: "Ky seksion hapet vetem per llogarite me rol admin."
                    )
                } else {
                    if store.adminWorkspaceLoading && store.adminUsers.isEmpty && store.adminBusinesses.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                    } else {
                        TregoMiniStatsGrid(items: adminSummaryItems)

                        TregoSectionHeader(title: "Perdoruesit · Demografia")
                        TregoMiniStatsGrid(items: adminGenderItems)

                        TregoSectionHeader(title: "Perdoruesit · Aktiviteti")
                        TregoMiniStatsGrid(items: adminUserHealthItems)

                        TregoSectionHeader(title: "Bizneset · Statusi")
                        TregoMiniStatsGrid(items: adminBusinessStatsItems)

                        TregoSectionHeader(title: "Porosite · Fulfillment")
                        TregoMiniStatsGrid(items: adminOrderStatsItems)

                        TregoSectionHeader(title: "Raportet · Moderimi")
                        TregoMiniStatsGrid(items: adminReportStatsItems)

                        HStack {
                            TregoSectionHeader(title: "Launch Ads")
                            Spacer()
                            Button {
                                isCreateLaunchAdPresented = true
                            } label: {
                                Label("Shto ad", systemImage: "sparkles.rectangle.stack.fill")
                            }
                            .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.softAccent))
                        }

                        if !store.adminLaunchAds.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(store.adminLaunchAds) { launchAd in
                                    TregoLaunchAdManagementRow(
                                        launchAd: launchAd,
                                        onEdit: { editingLaunchAd = launchAd },
                                        onDelete: {
                                            Task {
                                                if let message = await store.deleteAdminLaunchAd(launchAd) {
                                                    store.globalMessage = message
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                        } else {
                            TregoEmptyStateView(
                                title: "Nuk ka launch ads",
                                subtitle: "Krijo ad-in e pare qe del sapo hapet app-i."
                            )
                        }

                        NavigationLink(destination: TregoManagedOrdersScreen(store: store, mode: .admin)) {
                            TregoFeatureLinkRow(
                                title: "Te gjitha porosite",
                                subtitle: "Shiko dhe perditeso te gjitha porosite nga paneli admin"
                            )
                        }
                        .buttonStyle(.plain)

                        if !store.adminUsers.isEmpty {
                            TregoSectionHeader(title: "Users")
                            VStack(spacing: 12) {
                                ForEach(store.adminUsers) { user in
                                    TregoAdminUserManagementRow(
                                        user: user,
                                        onRole: { role in
                                            Task { await store.updateAdminUserRole(user, role: role) }
                                        },
                                        onPassword: {
                                            passwordResetUser = user
                                        },
                                        onDelete: {
                                            Task { await store.deleteAdminUser(user) }
                                        }
                                    )
                                }
                            }
                        }

                        HStack {
                            TregoSectionHeader(title: "Biznese")
                            Spacer()
                            Button {
                                isCreateBusinessPresented = true
                            } label: {
                                Label("Shto biznes", systemImage: "plus")
                            }
                            .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.accent))
                        }

                        if !store.adminBusinesses.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(store.adminBusinesses) { business in
                                    TregoAdminBusinessRow(
                                        business: business,
                                        onOpen: {
                                            inspectingBusiness = business
                                        },
                                        onEdit: {
                                            editingBusiness = business
                                        },
                                        onVerify: {
                                            Task { await store.updateAdminBusinessVerification(business, status: "verified") }
                                        },
                                        onReject: {
                                            Task { await store.updateAdminBusinessVerification(business, status: "rejected") }
                                        },
                                        onUnlockEdit: {
                                            Task { await store.updateAdminBusinessEditAccess(business, status: "approved") }
                                        },
                                        onLockEdit: {
                                            Task { await store.updateAdminBusinessEditAccess(business, status: "locked") }
                                        }
                                    )
                                }
                            }
                        }

                        if !store.adminReports.isEmpty {
                            TregoSectionHeader(title: "Reports")
                            VStack(spacing: 12) {
                                ForEach(Array(store.adminReports.prefix(6))) { report in
                                    TregoAdminReportRow(
                                        report: report,
                                        onReviewing: {
                                            Task { await store.updateAdminReportStatus(report, status: "reviewing") }
                                        },
                                        onResolve: {
                                            Task { await store.updateAdminReportStatus(report, status: "resolved") }
                                        }
                                    )
                                }
                            }
                        }

                        if !store.adminOrders.isEmpty {
                            TregoSectionHeader(title: "Porosite")
                            VStack(spacing: 12) {
                                ForEach(Array(store.adminOrders.prefix(4))) { order in
                                    TregoOrderManagementCard(
                                        order: order,
                                        managerLabel: "Admin",
                                        onUpdate: { managingOrder = order }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .padding(.bottom, 90)
        }
        .background(TregoNativeTheme.background.ignoresSafeArea())
        .navigationTitle("Admin Control")
        .navigationBarTitleDisplayMode(.inline)
        .tregoHideTabBarOnSecondaryPage()
        .task {
            await store.loadAdminWorkspace()
        }
        .refreshable {
            await store.loadAdminWorkspace(force: true)
        }
        .sheet(item: $passwordResetUser) { user in
            NavigationView {
                TregoAdminPasswordResetScreen(store: store, user: user)
            }
            .navigationViewStyle(.stack)
        }
        .sheet(isPresented: $isCreateBusinessPresented) {
            NavigationView {
                TregoAdminBusinessEditorScreen(store: store, existingBusiness: nil)
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $editingBusiness) { business in
            NavigationView {
                TregoAdminBusinessEditorScreen(store: store, existingBusiness: business)
            }
            .navigationViewStyle(.stack)
        }
        .sheet(isPresented: $isCreateLaunchAdPresented) {
            NavigationView {
                TregoLaunchAdEditorScreen(store: store, existingLaunchAd: nil)
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $editingLaunchAd) { launchAd in
            NavigationView {
                TregoLaunchAdEditorScreen(store: store, existingLaunchAd: launchAd)
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $inspectingBusiness) { business in
            NavigationView {
                TregoAdminBusinessDetailScreen(store: store, business: business)
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $managingOrder) { order in
            NavigationView {
                TregoOrderStatusEditorScreen(
                    store: store,
                    order: order,
                    title: "Admin · Porosia",
                    onSave: { status, trackingCode, trackingURL in
                        await store.updateAdminOrderStatus(
                            order,
                            status: status,
                            trackingCode: trackingCode,
                            trackingURL: trackingURL
                        )
                    }
                )
            }
            .navigationViewStyle(.stack)
        }
    }

    private var adminSummaryItems: [TregoMiniStatItem] {
        [
            TregoMiniStatItem(label: "Users", value: String(store.adminUsers.count), icon: "person.2"),
            TregoMiniStatItem(label: "Biznese", value: String(store.adminBusinesses.count), icon: "storefront"),
            TregoMiniStatItem(label: "Reports", value: String(store.adminReports.count), icon: "flag"),
            TregoMiniStatItem(label: "Orders", value: String(store.adminOrders.count), icon: "shippingbox")
        ]
    }

    private var adminGenderItems: [TregoMiniStatItem] {
        [
            TregoMiniStatItem(label: "Meshkuj", value: String(userCount(gender: "mashkull")), icon: "person.fill"),
            TregoMiniStatItem(label: "Femra", value: String(userCount(gender: "femer")), icon: "person.fill.turn.right"),
            TregoMiniStatItem(label: "Pa gjini", value: String(usersWithoutGenderCount), icon: "questionmark.circle"),
            TregoMiniStatItem(label: "Qytete", value: String(distinctUserCitiesCount), icon: "building.2")
        ]
    }

    private var adminUserHealthItems: [TregoMiniStatItem] {
        [
            TregoMiniStatItem(label: "Kliente", value: String(userCount(role: "client") + userCount(role: "user")), icon: "person"),
            TregoMiniStatItem(label: "Biznes", value: String(userCount(role: "business")), icon: "bag"),
            TregoMiniStatItem(label: "Admin", value: String(userCount(role: "admin")), icon: "person.crop.rectangle.stack"),
            TregoMiniStatItem(label: "Email verified", value: String(emailVerifiedUsersCount), icon: "checkmark.seal"),
            TregoMiniStatItem(label: "Me telefon", value: String(usersWithPhoneCount), icon: "phone"),
            TregoMiniStatItem(label: "Me porosi", value: String(usersWithOrdersCount), icon: "cart"),
            TregoMiniStatItem(label: "Me foto", value: String(usersWithProfilePhotoCount), icon: "person.crop.circle.badge.checkmark"),
            TregoMiniStatItem(label: "Kete muaj", value: String(usersJoinedThisMonthCount), icon: "calendar")
        ]
    }

    private var adminBusinessStatsItems: [TregoMiniStatItem] {
        [
            TregoMiniStatItem(label: "Verified", value: String(businessCount(verificationStatus: "verified")), icon: "checkmark.shield"),
            TregoMiniStatItem(label: "Pending", value: String(businessCount(verificationStatus: "pending")), icon: "clock"),
            TregoMiniStatItem(label: "Rejected", value: String(businessCount(verificationStatus: "rejected")), icon: "xmark.shield"),
            TregoMiniStatItem(label: "Unverified", value: String(businessCount(verificationStatus: "unverified")), icon: "shield.lefthalf.filled"),
            TregoMiniStatItem(label: "Edit approved", value: String(businessCount(editAccessStatus: "approved")), icon: "pencil.and.outline"),
            TregoMiniStatItem(label: "Edit pending", value: String(businessCount(editAccessStatus: "pending")), icon: "hourglass"),
            TregoMiniStatItem(label: "Edit locked", value: String(businessCount(editAccessStatus: "locked")), icon: "lock"),
            TregoMiniStatItem(label: "Me logo", value: String(businessesWithLogoCount), icon: "photo")
        ]
    }

    private var adminOrderStatsItems: [TregoMiniStatItem] {
        [
            TregoMiniStatItem(label: "Ne pritje", value: String(orderCount(status: "pending_confirmation")), icon: "clock"),
            TregoMiniStatItem(label: "Konfirmuar", value: String(orderCount(status: "confirmed")), icon: "checkmark.circle"),
            TregoMiniStatItem(label: "Paketuar", value: String(orderCount(status: "packed")), icon: "cube.box"),
            TregoMiniStatItem(label: "Ne dergim", value: String(orderCount(status: "shipped")), icon: "truck.box"),
            TregoMiniStatItem(label: "Dorezuar", value: String(orderCount(status: "delivered")), icon: "shippingbox.fill"),
            TregoMiniStatItem(label: "Anuluar", value: String(orderCount(status: "cancelled")), icon: "xmark.circle"),
            TregoMiniStatItem(label: "Kthyer", value: String(orderCount(status: "returned")), icon: "arrow.uturn.backward.circle"),
            TregoMiniStatItem(label: "COD", value: String(paymentMethodCount("cash_on_delivery")), icon: "banknote")
        ]
    }

    private var adminReportStatsItems: [TregoMiniStatItem] {
        [
            TregoMiniStatItem(label: "Open", value: String(reportCount(status: "open")), icon: "exclamationmark.bubble"),
            TregoMiniStatItem(label: "Reviewing", value: String(reportCount(status: "reviewing")), icon: "eye"),
            TregoMiniStatItem(label: "Resolved", value: String(reportCount(status: "resolved")), icon: "checkmark.circle"),
            TregoMiniStatItem(label: "Dismissed", value: String(reportCount(status: "dismissed")), icon: "xmark.bin"),
            TregoMiniStatItem(label: "Produkte", value: String(reportCount(targetType: "product")), icon: "shippingbox"),
            TregoMiniStatItem(label: "Perdorues", value: String(reportCount(targetType: "user")), icon: "person.crop.circle.badge.exclam"),
            TregoMiniStatItem(label: "Biznese", value: String(reportCount(targetType: "business")), icon: "storefront"),
            TregoMiniStatItem(label: "Porosi", value: String(reportCount(targetType: "order")), icon: "bag.badge.question")
        ]
    }

    private var usersWithoutGenderCount: Int {
        store.adminUsers.count - userCount(gender: "mashkull") - userCount(gender: "femer")
    }

    private var distinctUserCitiesCount: Int {
        Set(
            store.adminUsers.compactMap {
                let city = normalized($0.city)
                return city.isEmpty ? nil : city
            }
        ).count
    }

    private var emailVerifiedUsersCount: Int {
        store.adminUsers.filter { $0.isEmailVerified == true }.count
    }

    private var usersWithPhoneCount: Int {
        store.adminUsers.filter { !normalized($0.phoneNumber).isEmpty }.count
    }

    private var usersWithOrdersCount: Int {
        store.adminUsers.filter { ($0.ordersCount ?? 0) > 0 }.count
    }

    private var usersWithProfilePhotoCount: Int {
        store.adminUsers.filter { !normalized($0.profileImagePath).isEmpty }.count
    }

    private var usersJoinedThisMonthCount: Int {
        let calendar = Calendar.current
        let now = Date()
        return store.adminUsers.filter { user in
            guard let createdAt = TregoNativeFormatting.optionalDate(fromStorage: user.createdAt) else {
                return false
            }
            return calendar.isDate(createdAt, equalTo: now, toGranularity: .month)
                && calendar.isDate(createdAt, equalTo: now, toGranularity: .year)
        }.count
    }

    private var businessesWithLogoCount: Int {
        store.adminBusinesses.filter { !normalized($0.logoPath).isEmpty }.count
    }

    private func userCount(gender: String) -> Int {
        store.adminUsers.filter { normalized($0.gender) == gender }.count
    }

    private func userCount(role: String) -> Int {
        store.adminUsers.filter { normalized($0.role) == role }.count
    }

    private func businessCount(verificationStatus: String) -> Int {
        store.adminBusinesses.filter { normalized($0.verificationStatus) == verificationStatus }.count
    }

    private func businessCount(editAccessStatus: String) -> Int {
        store.adminBusinesses.filter { normalized($0.profileEditAccessStatus) == editAccessStatus }.count
    }

    private func orderCount(status: String) -> Int {
        store.adminOrders.filter { normalized($0.fulfillmentStatus ?? $0.status) == status }.count
    }

    private func paymentMethodCount(_ method: String) -> Int {
        store.adminOrders.filter { normalized($0.paymentMethod) == method }.count
    }

    private func reportCount(status: String) -> Int {
        store.adminReports.filter { normalized($0.status) == status }.count
    }

    private func reportCount(targetType: String) -> Int {
        store.adminReports.filter { normalized($0.targetType) == targetType }.count
    }

    private func normalized(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }
}

private enum TregoManagedOrdersMode {
    case business
    case admin

    var title: String {
        switch self {
        case .business: return "Porosite e biznesit"
        case .admin: return "Porosite e adminit"
        }
    }
}

private struct TregoBusinessSettingsScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    @State private var profileDraft: TregoBusinessProfileDraft
    @State private var shippingDraft: TregoBusinessShippingDraft
    @State private var selectedUpload: TregoImageSearchUpload?
    @State private var pickerSource: TregoImagePickerSource?
    @State private var showsImageDialog = false
    @State private var statusMessage = ""
    @State private var statusTone: TregoStatusMessageTone = .info
    @State private var isSavingProfile = false
    @State private var isSavingShipping = false

    init(store: TregoNativeAppStore) {
        self.store = store
        let profile = store.businessProfile
        _profileDraft = State(initialValue: TregoBusinessProfileDraft(profile: profile))
        _shippingDraft = State(initialValue: TregoBusinessShippingDraft(settings: profile?.shippingSettings))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                TregoNoticeCard(
                    title: "Profili & transporti",
                    subtitle: "Ruaj te dhenat kryesore te biznesit dhe konfiguro dergesat sipas rregullave te tua."
                )

                if !statusMessage.isEmpty {
                    TregoStatusMessageCard(message: statusMessage, tone: statusTone)
                }

                TregoProductImageEditorCard(
                    title: "Logoja e biznesit",
                    subtitle: "Perditeso logon kryesore qe shfaqet ne profilin publik te biznesit.",
                    imagePath: profileDraft.businessLogoPath,
                    upload: selectedUpload,
                    onChoosePhoto: { showsImageDialog = true },
                    onRemovePhoto: {
                        selectedUpload = nil
                        profileDraft.businessLogoPath = ""
                    }
                )

                TregoSectionHeader(title: "Profili")
                TregoInputCard(title: "Emri i biznesit", text: $profileDraft.businessName, placeholder: "Tregio Store", textContentType: .organizationName, disableAutocorrection: false)
                TregoMultilineInputCard(title: "Pershkrimi", text: $profileDraft.businessDescription, placeholder: "Pershkruaj biznesin dhe produktet kryesore")
                TregoInputCard(title: "Numri i biznesit", text: $profileDraft.businessNumber, placeholder: "BK-1020", autocapitalization: .characters)
                TregoInputCard(title: "Telefoni", text: $profileDraft.phoneNumber, keyboardType: .phonePad, placeholder: "+383 44 123 456", autocapitalization: .never, textContentType: .telephoneNumber)
                TregoInputCard(title: "Qyteti", text: $profileDraft.city, placeholder: "Prishtine", textContentType: .addressCity, disableAutocorrection: false)
                TregoInputCard(title: "Adresa", text: $profileDraft.addressLine, placeholder: "Rr. Nena Tereze, nr. 12", textContentType: .fullStreetAddress, disableAutocorrection: false)

                Button {
                    Task { await saveProfile() }
                } label: {
                    if isSavingProfile {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Ruaj profilin").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(TregoPrimaryButtonStyle())

                TregoSectionHeader(title: "Transporti")
                Toggle(isOn: $shippingDraft.standardEnabled) {
                    Text("Lejo dergese standard")
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                if shippingDraft.standardEnabled {
                    TregoInputCard(title: "Cmimi standard", text: $shippingDraft.standardFeeText, keyboardType: .decimalPad, placeholder: "2.50", autocapitalization: .never)
                    TregoInputCard(title: "ETA standard", text: $shippingDraft.standardEta, placeholder: "2-3 dite")
                }

                Toggle(isOn: $shippingDraft.expressEnabled) {
                    Text("Lejo fast delivery")
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                if shippingDraft.expressEnabled {
                    TregoInputCard(title: "Cmimi express", text: $shippingDraft.expressFeeText, keyboardType: .decimalPad, placeholder: "4.90", autocapitalization: .never)
                    TregoInputCard(title: "ETA express", text: $shippingDraft.expressEta, placeholder: "Brenda dites")
                }

                Toggle(isOn: $shippingDraft.pickupEnabled) {
                    Text("Lejo pickup te biznesi")
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                if shippingDraft.pickupEnabled {
                    TregoInputCard(title: "Adresa e pickup", text: $shippingDraft.pickupAddress, placeholder: "Adresa e biznesit")
                    TregoInputCard(title: "Orari i pickup", text: $shippingDraft.pickupHours, placeholder: "09:00 - 18:00")
                    TregoInputCard(title: "Linku i maps", text: $shippingDraft.pickupMapURL, keyboardType: .URL, placeholder: "https://maps.google.com/...", autocapitalization: .never)
                    TregoInputCard(title: "ETA pickup", text: $shippingDraft.pickupEta, placeholder: "Gati sot")
                }

                HStack(spacing: 12) {
                    TregoInputCard(title: "Pragu 50% transport", text: $shippingDraft.halfOffThresholdText, keyboardType: .decimalPad, placeholder: "30.00", autocapitalization: .never)
                    TregoInputCard(title: "Pragu falas", text: $shippingDraft.freeShippingThresholdText, keyboardType: .decimalPad, placeholder: "60.00", autocapitalization: .never)
                }

                TregoSectionHeader(title: "Surcharge sipas qytetit")
                ForEach($shippingDraft.cityRates) { $cityRate in
                    HStack(spacing: 10) {
                        TregoInputCard(title: "Qyteti", text: $cityRate.city, placeholder: "Prizren")
                        TregoInputCard(title: "Shtesa", text: $cityRate.surchargeText, keyboardType: .decimalPad, placeholder: "1.20", autocapitalization: .never)
                    }
                }

                Button("Shto qytet me surcharge") {
                    shippingDraft.cityRates.append(.init(city: "", surchargeText: ""))
                }
                .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.softAccent))

                Button {
                    Task { await saveShipping() }
                } label: {
                    if isSavingShipping {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Ruaj transportin").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(TregoPrimaryButtonStyle(tint: TregoNativeTheme.softAccent))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Profili & transporti")
        .navigationBarTitleDisplayMode(.inline)
        .tregoHideTabBarOnSecondaryPage()
        .confirmationDialog("Logoja e biznesit", isPresented: $showsImageDialog) {
            Button("Take photo") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    pickerSource = .camera
                } else {
                    statusTone = .error
                    statusMessage = "Kamera nuk eshte e disponueshme tani."
                }
            }
            Button("Choose from library") {
                pickerSource = .photoLibrary
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $pickerSource) { source in
            TregoImagePicker(source: source) { upload in
                selectedUpload = upload
            }
        }
        .task {
            await store.loadBusinessWorkspace(force: true)
            profileDraft = TregoBusinessProfileDraft(profile: store.businessProfile)
            shippingDraft = TregoBusinessShippingDraft(settings: store.businessProfile?.shippingSettings)
        }
    }

    private func saveProfile() async {
        isSavingProfile = true
        defer { isSavingProfile = false }

        if let selectedUpload {
            let (uploadResponse, uploaded) = await store.api.uploadProductImages([selectedUpload])
            guard uploadResponse.ok == true, let uploaded else {
                statusTone = .error
                statusMessage = uploadResponse.message ?? "Logoja nuk u ngarkua."
                return
            }
            profileDraft.businessLogoPath = uploaded.paths.first ?? ""
        }

        if let failure = await store.updateBusinessProfile(payload: profileDraft.payload()) {
            statusTone = .error
            statusMessage = failure
            return
        }
        statusMessage = ""
        selectedUpload = nil
    }

    private func saveShipping() async {
        isSavingShipping = true
        defer { isSavingShipping = false }

        if let failure = await store.saveBusinessShippingSettings(payload: shippingDraft.payload()) {
            statusTone = .error
            statusMessage = failure
            return
        }
        statusMessage = ""
    }
}

private struct TregoBusinessAnalyticsScreen: View {
    @ObservedObject var store: TregoNativeAppStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                TregoNoticeCard(
                    title: "Analytics",
                    subtitle: "Shiko performancen e biznesit, shitjet dhe sinjalet kryesore te marketplace-it."
                )

                TregoMiniStatsGrid(items: analyticsItems)

                if !store.businessPromotions.isEmpty {
                    TregoSectionHeader(title: "Promocionet aktive")
                    VStack(spacing: 12) {
                        ForEach(store.businessPromotions.prefix(6), id: \.stableID) { promotion in
                            TregoPromotionRow(promotion: promotion)
                        }
                    }
                }

                if !store.businessOrders.isEmpty {
                    TregoSectionHeader(title: "Porosite e fundit")
                    VStack(spacing: 12) {
                        ForEach(store.businessOrders.prefix(6)) { order in
                            TregoOrderCard(order: order)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .tregoHideTabBarOnSecondaryPage()
        .task {
            await store.loadBusinessWorkspace(force: true)
        }
    }

    private var analyticsItems: [TregoMiniStatItem] {
        [
            .init(label: "Produkte", value: String(store.businessAnalytics?.totalProducts ?? 0), icon: "shippingbox"),
            .init(label: "Publike", value: String(store.businessAnalytics?.publicProducts ?? 0), icon: "eye"),
            .init(label: "Stok total", value: String(store.businessAnalytics?.totalStock ?? 0), icon: "archivebox"),
            .init(label: "Njesi shitura", value: String(store.businessAnalytics?.unitsSold ?? 0), icon: "chart.line.uptrend.xyaxis"),
            .init(label: "Gross sales", value: TregoFormatting.price(store.businessAnalytics?.grossSales ?? 0), icon: "eurosign.circle"),
            .init(label: "Fitimi", value: TregoFormatting.price(store.businessAnalytics?.sellerEarnings ?? 0), icon: "banknote"),
            .init(label: "Reviews", value: String(store.businessAnalytics?.reviewCount ?? 0), icon: "star"),
            .init(label: "Mesatarja", value: String(format: "%.1f", store.businessAnalytics?.averageRating ?? 0), icon: "star.fill"),
            .init(label: "Kthime", value: String(store.businessAnalytics?.totalReturns ?? 0), icon: "arrow.uturn.backward"),
            .init(label: "Promo aktive", value: String(store.businessAnalytics?.activePromotions ?? 0), icon: "ticket.fill"),
            .init(label: "Wishlist", value: String(store.businessAnalytics?.wishlistCount ?? 0), icon: "heart"),
            .init(label: "Share", value: String(store.businessAnalytics?.shareCount ?? 0), icon: "square.and.arrow.up"),
        ]
    }
}

private struct TregoManagedOrdersScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    let mode: TregoManagedOrdersMode
    @State private var managingOrder: TregoOrderItem?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if orders.isEmpty {
                    TregoEmptyStateView(
                        title: "Nuk ka porosi",
                        subtitle: "Kur te vijne porosite, ato do te shfaqen ketu per menaxhim."
                    )
                } else {
                    ForEach(orders) { order in
                        TregoOrderManagementCard(
                            order: order,
                            managerLabel: mode == .business ? "Biznes" : "Admin",
                            onUpdate: { managingOrder = order }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .tregoHideTabBarOnSecondaryPage()
        .task { await reload() }
        .refreshable { await reload() }
        .sheet(item: $managingOrder) { order in
            NavigationView {
                TregoOrderStatusEditorScreen(
                    store: store,
                    order: order,
                    title: mode == .business ? "Perditeso porosine" : "Admin · Porosia",
                    onSave: { status, trackingCode, trackingURL in
                        if mode == .business {
                            return await store.updateBusinessOrderStatus(order, status: status, trackingCode: trackingCode, trackingURL: trackingURL)
                        }
                        return await store.updateAdminOrderStatus(order, status: status, trackingCode: trackingCode, trackingURL: trackingURL)
                    }
                )
            }
            .navigationViewStyle(.stack)
        }
    }

    private var orders: [TregoOrderItem] {
        mode == .business ? store.businessOrders : store.adminOrders
    }

    private func reload() async {
        if mode == .business {
            await store.loadBusinessWorkspace(force: true)
        } else {
            await store.loadAdminWorkspace(force: true)
        }
    }
}

private struct TregoAdminBusinessDetailScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    let business: TregoAdminBusiness
    @State private var isEditing = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                TregoNoticeCard(
                    title: business.businessName ?? "Detajet e biznesit",
                    subtitle: "Shiko verifikimin, edit access dhe rregullat e transportit te biznesit."
                )

                TregoAdminBusinessRow(
                    business: business,
                    onOpen: {},
                    onEdit: { isEditing = true },
                    onVerify: { Task { await store.updateAdminBusinessVerification(business, status: "verified") } },
                    onReject: { Task { await store.updateAdminBusinessVerification(business, status: "rejected") } },
                    onUnlockEdit: { Task { await store.updateAdminBusinessEditAccess(business, status: "approved") } },
                    onLockEdit: { Task { await store.updateAdminBusinessEditAccess(business, status: "locked") } }
                )

                TregoSectionHeader(title: "Detajet")
                TregoInfoTile(title: "Pronari", value: business.ownerName ?? "-")
                TregoInfoTile(title: "Email", value: business.ownerEmail ?? "-")
                TregoInfoTile(title: "Numri i biznesit", value: business.businessNumber ?? "-")
                TregoInfoTile(title: "Telefoni", value: business.phoneNumber ?? "-")
                TregoInfoTile(title: "Qyteti", value: business.city ?? "-")
                TregoInfoTile(title: "Adresa", value: business.addressLine ?? "-")

                if let description = business.businessDescription, !description.isEmpty {
                    TregoInfoTile(title: "Pershkrimi", value: description)
                }

                if let notes = business.verificationNotes, !notes.isEmpty {
                    TregoInfoTile(title: "Shenime verifikimi", value: notes)
                }

                if let notes = business.profileEditNotes, !notes.isEmpty {
                    TregoInfoTile(title: "Shenime editimi", value: notes)
                }

                if let shipping = business.shippingSettings {
                    TregoSectionHeader(title: "Transporti")
                    TregoBusinessShippingSummaryCard(settings: shipping)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Detajet e biznesit")
        .navigationBarTitleDisplayMode(.inline)
        .tregoHideTabBarOnSecondaryPage()
        .sheet(isPresented: $isEditing) {
            NavigationView {
                TregoAdminBusinessEditorScreen(store: store, existingBusiness: business)
            }
            .navigationViewStyle(.stack)
        }
    }
}

private struct TregoOrdersScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    @State private var returnOrder: TregoOrderItem?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if store.ordersLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else if store.orders.isEmpty {
                    TregoEmptyStateView(
                        title: "Nuk ka porosi",
                        subtitle: "Porosite e tua do te shfaqen ketu."
                    )
                } else {
                    ForEach(store.orders) { order in
                        TregoCustomerOrderCard(
                            order: order,
                            onReturn: canRequestReturn(for: order) ? { returnOrder = order } : nil
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .padding(.bottom, 90)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Orders")
        .navigationBarTitleDisplayMode(.inline)
        .tregoHideTabBarOnSecondaryPage()
        .task {
            await store.loadOrders()
        }
        .sheet(item: $returnOrder) { order in
            NavigationView {
                TregoReturnRequestComposerScreen(store: store, order: order)
            }
            .navigationViewStyle(.stack)
        }
    }

    private func canRequestReturn(for order: TregoOrderItem) -> Bool {
        let status = (order.fulfillmentStatus ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let returnStatus = (order.returnRequestStatus ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return (status == "delivered" || status == "returned") && !["requested", "approved", "received"].contains(returnStatus)
    }
}

private struct TregoHairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.primary.opacity(0.08),
                        Color.primary.opacity(0.14),
                        Color.primary.opacity(0.08),
                        Color.clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
    }
}

private struct TregoMessagesScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    @State private var searchText = ""
    @State private var isOpeningSupport = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if store.conversationsLoading && filteredConversations.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else if filteredConversations.isEmpty {
                    TregoEmptyStateView(
                        title: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nuk ka biseda" : "Nuk u gjet bisede",
                        subtitle: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Bisedat me bizneset do te shfaqen ketu."
                            : "Provo me emer biznesi ose me tekstin e mesazhit."
                    )
                } else {
                    ForEach(filteredConversations) { conversation in
                        NavigationLink(destination: TregoConversationScreen(store: store, conversation: conversation)) {
                            TregoConversationRow(conversation: conversation)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Fshij", role: .destructive) {
                                Task {
                                    if let message = await store.deleteConversation(conversation) {
                                        store.globalMessage = message
                                        await store.loadConversations()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 90)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .tregoHideTabBarOnSecondaryPage()
        .safeAreaInset(edge: .top, spacing: 0) {
            TregoMessagesSearchBar(text: $searchText)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(TregoNativeTheme.systemBackground)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 10) {
                    Button {
                        Task { await openSupportConversation() }
                    } label: {
                        Image(systemName: "headphones")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(TregoNativeTheme.accent)
                            .frame(width: 34, height: 34)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Customer Support")

                    NavigationLink(destination: TregoNotificationsScreen(store: store)) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(TregoNativeTheme.accent)
                            .frame(width: 34, height: 34)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Notification Center")
                }
            }
        }
        .task {
            await store.loadConversations()
        }
    }

    private var filteredConversations: [TregoConversation] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            return store.conversations
        }

        return store.conversations.filter { conversation in
            let haystack = [
                conversation.counterpartName ?? "",
                conversation.businessName ?? "",
                conversation.clientName ?? "",
                conversation.lastMessagePreview ?? "",
            ]
            .joined(separator: " ")
            .lowercased()

            return haystack.contains(trimmed)
        }
    }

    private func openSupportConversation() async {
        guard !isOpeningSupport else { return }
        isOpeningSupport = true
        defer { isOpeningSupport = false }
        await store.startSupportConversation()
    }
}

private struct TregoPinnedSupportCard: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    TregoNativeTheme.accent.opacity(0.96),
                                    Color(red: 0.99, green: 0.67, blue: 0.26),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: "headphones")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Customer Support")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.primary)

                        Text("Pinned")
                            .font(.system(size: 10, weight: .black))
                            .textCase(.uppercase)
                            .foregroundStyle(TregoNativeTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.72), in: Capsule())
                    }

                    Text("Pyetje per porosite, kthimet ose problemet? Hape support-in direkt nga ketu.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.07 : 0.94),
                        Color.orange.opacity(colorScheme == .dark ? 0.1 : 0.14),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.54), lineWidth: 0.8)
            }
            .shadow(color: TregoNativeTheme.accent.opacity(colorScheme == .dark ? 0.2 : 0.12), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
    }
}

private struct TregoMessagesShortcutButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.42), lineWidth: 0.7)
        }
    }
}

private struct TregoMessagesSearchBar: View {
    @Binding var text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Kerko ne mesazhe", text: $text)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)

            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.8), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.34), lineWidth: 0.8)
        }
    }
}

private struct TregoChatAttachmentPreview: View {
    let attachment: TregoAttachmentUpload
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(TregoNativeTheme.accent)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(attachment.filename)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Text(attachment.mimeType)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.34), lineWidth: 0.8)
        }
    }

    private var iconName: String {
        if attachment.mimeType.lowercased().hasPrefix("image/") {
            return "photo.fill"
        }
        if attachment.mimeType.lowercased().hasPrefix("video/") {
            return "play.rectangle.fill"
        }
        return "doc.fill"
    }
}

private struct TregoMessageEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TregoSectionHeader(title: "Edito mesazhin")

            TextEditor(text: $text)
                .font(.system(size: 16, weight: .medium))
                .frame(minHeight: 140)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 24)
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Edito")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Ruaj") {
                    onSave()
                    dismiss()
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private struct TregoConversationScreen: View {
    private static let bottomAnchorID = "trego-conversation-bottom-anchor"

    @Environment(\.openURL) private var openURL
    @ObservedObject var store: TregoNativeAppStore
    let conversation: TregoConversation
    let initialDraft: String?

    @State private var loadedConversation: TregoConversation?
    @State private var messages: [TregoChatMessage] = []
    @State private var draft = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var selectedAttachment: TregoAttachmentUpload?
    @State private var showsAttachmentComposer = false
    @State private var mediaPickerSource: TregoImagePickerSource?
    @State private var showsDocumentPicker = false
    @State private var showsLinkComposer = false
    @State private var linkDraft = ""
    @State private var editingMessage: TregoChatMessage?
    @State private var editDraft = ""
    @State private var hasAppliedInitialDraft = false
    @State private var conversationScrollProxy: ScrollViewProxy?
    @State private var openedBusinessSelection: TregoBusinessSelection?
    @FocusState private var isDraftFocused: Bool

    init(
        store: TregoNativeAppStore,
        conversation: TregoConversation,
        initialDraft: String? = nil
    ) {
        self.store = store
        self.conversation = conversation
        self.initialDraft = initialDraft
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && messages.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                TregoMessageBubble(
                                    message: message,
                                    businessName: activeConversation.businessName,
                                    businessProfileId: activeConversation.businessProfileId,
                                    onOpenBusiness: { businessId in
                                        openedBusinessSelection = TregoBusinessSelection(id: businessId)
                                    },
                                    onEdit: {
                                        guard canEditMessage(message) else { return }
                                        editingMessage = message
                                        editDraft = message.body ?? ""
                                    },
                                    onDelete: {
                                        guard canDeleteMessage(message) else { return }
                                        Task { await deleteMessage(message) }
                                    },
                                    onOpenURL: { url in
                                        openURL(url)
                                    }
                                )
                                .id(message.id)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(TregoNativeFormatting.readableChatSwipeTimestamp(message.createdAt)) {}
                                        .tint(Color.black.opacity(0.58))

                                    if canEditMessage(message) {
                                        Button("Edito") {
                                            editingMessage = message
                                            editDraft = message.body ?? ""
                                        }
                                        .tint(TregoNativeTheme.softAccent)
                                    }

                                    if canDeleteMessage(message) {
                                        Button("Fshij", role: .destructive) {
                                            Task { await deleteMessage(message) }
                                        }
                                    }
                                }
                            }

                            Color.clear
                                .frame(height: 1)
                                .id(Self.bottomAnchorID)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                        .padding(.bottom, 18)
                    }
                    .onChange(of: messages) { _ in
                        scrollToLatest(using: proxy)
                    }
                    .onChange(of: isDraftFocused) { isFocused in
                        guard isFocused else { return }
                        scrollToLatest(using: proxy)
                    }
                    .onAppear {
                        conversationScrollProxy = proxy
                        scrollToLatest(using: proxy, animated: false)
                    }
                }
                .tregoInteractiveKeyboardDismiss()
            }

            if let selectedAttachment {
                TregoChatAttachmentPreview(
                    attachment: selectedAttachment,
                    onRemove: {
                        self.selectedAttachment = nil
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }

            HStack(alignment: .bottom, spacing: 12) {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        showsAttachmentComposer.toggle()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(TregoNativeTheme.primaryText)
                        .frame(width: 48, height: 48)
                        .tregoGlassCircleBackground()
                }
                .buttonStyle(.plain)
                .overlay(alignment: .topLeading) {
                    if showsAttachmentComposer {
                        VStack(alignment: .leading, spacing: 8) {
                            attachmentComposerButton(title: "Shto link", systemImage: "link") {
                                showsAttachmentComposer = false
                                showsLinkComposer = true
                            }

                            attachmentComposerButton(title: "Foto ose video", systemImage: "photo.on.rectangle") {
                                showsAttachmentComposer = false
                                mediaPickerSource = .photoLibrary
                            }

                            attachmentComposerButton(title: "File", systemImage: "doc") {
                                showsAttachmentComposer = false
                                showsDocumentPicker = true
                            }
                        }
                        .padding(10)
                        .tregoGlassRectBackground(cornerRadius: 22)
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                        }
                        .offset(x: 0, y: -182)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                    }
                }

                TextField("Shkruaj mesazhin", text: $draft)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .submitLabel(.send)
                    .focused($isDraftFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .foregroundStyle(TregoNativeTheme.primaryText)
                    .tregoGlassRectBackground(cornerRadius: 24)
                    .onTapGesture {
                        showsAttachmentComposer = false
                        isDraftFocused = true
                        if let proxy = conversationScrollProxy {
                            scrollToLatest(using: proxy)
                        }
                    }

                Button {
                    showsAttachmentComposer = false
                    Task { await sendMessage() }
                } label: {
                    if isSending {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 52, height: 52)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                    }
                }
                .buttonStyle(.plain)
                .background {
                    ZStack {
                        Circle()
                            .fill(TregoNativeTheme.accent.opacity(canSendMessage ? 0.92 : 0.68))
                        TregoGlassCircleBackground()
                            .opacity(canSendMessage ? 0.28 : 0.18)
                    }
                }
                .scaleEffect(isSending ? 0.98 : 1)
                .disabled(!canSendMessage)
                .opacity(canSendMessage ? 1 : 0.55)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .background(TregoBusinessPushLink(store: store, selection: $openedBusinessSelection))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tregoHideTabBarOnSecondaryPage()
        .tregoTapOutsideKeyboardDismiss()
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let businessId = activeConversation.businessProfileId {
                    Button {
                        openedBusinessSelection = TregoBusinessSelection(id: businessId)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "building.2.crop.circle")
                                .font(.system(size: 14, weight: .bold))
                            Text(conversationHeaderTitle)
                                .font(.system(size: 14, weight: .bold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(TregoNativeTheme.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .tregoGlassCapsuleBackground()
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "building.2.crop.circle")
                            .font(.system(size: 14, weight: .bold))
                        Text(conversationHeaderTitle)
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(TregoNativeTheme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .tregoGlassCapsuleBackground()
                }
            }
        }
        .alert("Shto link", isPresented: $showsLinkComposer) {
            TextField("https://shembull.com", text: $linkDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            Button("Shto") {
                appendLinkToDraft()
            }
            Button("Cancel", role: .cancel) {
                linkDraft = ""
            }
        } message: {
            Text("Linku do te futet ne draft dhe mund ta dergosh bashke me tekst ose vetem si link.")
        }
        .sheet(item: $editingMessage) { _ in
            NavigationView {
                TregoMessageEditorSheet(
                    text: $editDraft,
                    onCancel: {
                        editingMessage = nil
                        editDraft = ""
                    },
                    onSave: {
                        Task { await saveEditedMessage() }
                    }
                )
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $mediaPickerSource) { source in
            TregoMediaPicker(source: source) { upload in
                selectedAttachment = upload
            }
        }
                .sheet(isPresented: $showsDocumentPicker) {
            TregoDocumentPicker { upload in
                selectedAttachment = upload
            }
        }
        .onAppear {
            applyInitialDraftIfNeeded()
        }
        .task {
            await loadConversation()
        }
    }

    private var activeConversation: TregoConversation {
        loadedConversation ?? conversation
    }

    private var conversationHeaderTitle: String {
        activeConversation.businessName ?? activeConversation.counterpartName ?? "Biseda"
    }

    private func loadConversation() async {
        isLoading = true
        defer { isLoading = false }
        guard let detail = await store.api.fetchConversationDetail(id: conversation.id) else {
            return
        }
        loadedConversation = detail.conversation
        messages = detail.messages
        await store.loadConversations()
    }

    private func sendMessage() async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || selectedAttachment != nil else {
            return
        }
        guard !isSending else { return }

        let attachment = selectedAttachment
        let pendingMessage = makePendingMessage(body: trimmed, attachment: attachment)
        draft = ""
        selectedAttachment = nil
        messages.append(pendingMessage)

        isSending = true
        defer { isSending = false }

        let (response, message, updatedConversation) = await store.api.sendChatMessage(
            conversationId: conversation.id,
            body: trimmed,
            attachment: attachment
        )
        guard response.ok == true, let message else {
            removeMessage(withId: pendingMessage.id)
            draft = trimmed
            selectedAttachment = attachment
            store.globalMessage = response.message ?? "Mesazhi nuk u dergua."
            return
        }

        if let updatedConversation {
            loadedConversation = updatedConversation
        }
        replaceMessage(message, replacingId: pendingMessage.id)
        await store.loadConversations()
    }

    private var canSendMessage: Bool {
        !isSending && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedAttachment != nil)
    }

    private func canEditMessage(_ message: TregoChatMessage) -> Bool {
        message.isOwn == true
            && (message.deletedAt ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !(message.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func canDeleteMessage(_ message: TregoChatMessage) -> Bool {
        message.isOwn == true
            && (message.deletedAt ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveEditedMessage() async {
        guard let editingMessage else { return }
        let trimmed = editDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            store.globalMessage = "Shkruaj tekstin e mesazhit."
            return
        }

        let (response, updatedMessage) = await store.api.updateChatMessage(messageId: editingMessage.id, body: trimmed)
        guard response.ok == true, let updatedMessage else {
            store.globalMessage = response.message ?? "Mesazhi nuk u perditesua."
            return
        }

        replaceMessage(updatedMessage)
        self.editingMessage = nil
        editDraft = ""
        await store.loadConversations()
    }

    private func deleteMessage(_ message: TregoChatMessage) async {
        let (response, updatedMessage) = await store.api.deleteChatMessage(messageId: message.id)
        guard response.ok == true else {
            store.globalMessage = response.message ?? "Mesazhi nuk u fshi."
            return
        }

        if let updatedMessage {
            replaceMessage(updatedMessage)
        }
        await store.loadConversations()
    }

    private func replaceMessage(_ updatedMessage: TregoChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == updatedMessage.id }) {
            messages[index] = updatedMessage
        } else {
            messages.append(updatedMessage)
        }
    }

    private func replaceMessage(_ updatedMessage: TregoChatMessage, replacingId originalId: Int) {
        if let index = messages.firstIndex(where: { $0.id == originalId }) {
            messages[index] = updatedMessage
        } else {
            replaceMessage(updatedMessage)
        }
    }

    private func removeMessage(withId id: Int) {
        messages.removeAll { $0.id == id }
    }

    private func makePendingMessage(body: String, attachment: TregoAttachmentUpload?) -> TregoChatMessage {
        TregoChatMessage(
            id: -Int(Date().timeIntervalSince1970 * 1000),
            conversationId: conversation.id,
            senderUserId: store.user?.id ?? 0,
            recipientUserId: nil,
            body: body.isEmpty ? nil : body,
            attachmentPath: nil,
            attachmentContentType: attachment?.mimeType,
            attachmentFileName: attachment?.filename,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            editedAt: nil,
            deletedAt: nil,
            readAt: nil,
            senderName: store.user?.fullName,
            senderRole: store.user?.role,
            isOwn: true,
            localDeliveryState: .sending
        )
    }

    private func appendLinkToDraft() {
        var normalized = linkDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        if !normalized.lowercased().hasPrefix("http://") && !normalized.lowercased().hasPrefix("https://") {
            normalized = "https://\(normalized)"
        }

        if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft = normalized
        } else {
            draft += draft.hasSuffix(" ") ? normalized : " \(normalized)"
        }

        linkDraft = ""
    }

    private func applyInitialDraftIfNeeded() {
        guard !hasAppliedInitialDraft else { return }
        hasAppliedInitialDraft = true

        let normalizedDraft = (initialDraft ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedDraft.isEmpty else { return }
        guard draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        draft = normalizedDraft
    }

    @ViewBuilder
    private func attachmentComposerButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(TregoNativeTheme.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(minWidth: 156, alignment: .leading)
            .tregoGlassRectBackground(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    private func scrollToLatest(using proxy: ScrollViewProxy, animated: Bool = true) {
        let scrollAction = {
            proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        }
        if animated {
            withAnimation(.easeOut(duration: 0.22)) {
                scrollAction()
            }
        } else {
            scrollAction()
        }
    }
}

private struct TregoProductDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TregoNativeAppStore
    let product: TregoProduct

    @State private var loadedProduct: TregoProduct?
    @State private var recommendationSections: [TregoRecommendationSection] = []
    @State private var reviews: [TregoProductReview] = []
    @State private var isLoading = false
    @State private var openedConversation: TregoConversation?
    @State private var openedConversationDraft = ""
    @State private var openedBusinessSelection: TregoBusinessSelection?
    @State private var isReviewComposerPresented = false
    @State private var isReportComposerPresented = false
    @State private var shareItems: [Any] = []
    @State private var isShareSheetPresented = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .bottom) {
                    TregoRemoteImage(imagePath: activeProduct.imageGallery?.first ?? activeProduct.imagePath)
                        .frame(height: 348)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

                    HStack {
                        Button {
                            Task { await store.toggleWishlist(for: activeProduct) }
                        } label: {
                            Image(systemName: store.isWishlisted(productId: activeProduct.id) ? "heart.fill" : "heart")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(store.isWishlisted(productId: activeProduct.id) ? Color.red : Color.primary)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.34), lineWidth: 0.7)
                                }
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 0)

                        Button {
                            Task { await store.addToCart(product: activeProduct) }
                        } label: {
                            Image(systemName: "cart.badge.plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(TregoNativeTheme.accent)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.34), lineWidth: 0.7)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(activeProduct.title)
                        .font(.system(size: 28, weight: .bold))
                    if let businessName = activeProduct.businessName, !businessName.isEmpty {
                        Button {
                            if let businessId = activeProduct.businessProfileId {
                                openedBusinessSelection = TregoBusinessSelection(id: businessId)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "storefront")
                                    .font(.system(size: 13, weight: .bold))
                                Text(businessName)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    HStack(spacing: 8) {
                        Text(TregoFormatting.price(activeProduct.price ?? 0))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.orange.opacity(0.96))
                        if let compareAt = activeProduct.compareAtPrice, compareAt > (activeProduct.price ?? 0) {
                            TregoComparePriceText(
                                value: TregoFormatting.price(compareAt),
                                font: .system(size: 14, weight: .semibold)
                            )
                        }
                    }

                    HStack(spacing: 12) {
                        Text("\(activeProduct.buyersCount ?? 0) shitje")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        TregoCompactRatingSummary(rating: activeProduct.averageRating ?? 0)
                    }
                }

                if let description = activeProduct.description, !description.isEmpty {
                    TregoSectionHeader(title: "Pershkrimi")
                    Text(description)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .tregoGlassRectBackground(cornerRadius: 28)
                }

                TregoSectionHeader(title: "Reviews")
                if isLoading && reviews.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if reviews.isEmpty {
                    TregoEmptyStateView(
                        title: "Nuk ka reviews",
                        subtitle: "Reviews do te dalin ketu sapo perdoruesit te shkruajne per produktin."
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(reviews) { review in
                            TregoReviewCard(review: review)
                        }
                    }
                }

                ForEach(displayRecommendationSections) { section in
                    TregoSectionHeader(title: section.title)
                    if let subtitle = section.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: recommendedGrid, spacing: 14) {
                        ForEach(section.products) { suggestedProduct in
                            TregoProductCard(
                                product: suggestedProduct,
                                isWishlisted: store.isWishlisted(productId: suggestedProduct.id),
                                onTap: { store.selectedProduct = suggestedProduct },
                                onOpenBusiness: {
                                    if let businessId = suggestedProduct.businessProfileId {
                                        openedBusinessSelection = TregoBusinessSelection(id: businessId)
                                    }
                                },
                                onWishlist: {
                                    Task { await store.toggleWishlist(for: suggestedProduct) }
                                },
                                onAddToCart: {
                                    Task { await store.addToCart(product: suggestedProduct) }
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 18)
        }
        .background(TregoNativeTheme.background.ignoresSafeArea())
        .background(TregoBusinessPushLink(store: store, selection: $openedBusinessSelection))
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer(minLength: 0)
                TregoProductStickyActionBar(
                    isWishlisted: store.isWishlisted(productId: activeProduct.id),
                    canMessage: activeProduct.businessProfileId != nil,
                    onWishlist: {
                        Task { await store.toggleWishlist(for: activeProduct) }
                    },
                    onMessage: {
                        Task { await openBusinessConversation() }
                    },
                    onAddToCart: {
                        Task { await store.addToCart(product: activeProduct) }
                    }
                )
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
        .navigationTitle("Produkti")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task { await presentShareSheet() }
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        Task {
                            guard await store.ensureAuthenticatedSession(route: .login) else { return }
                            isReportComposerPresented = true
                        }
                    } label: {
                        Label("Raporto produktin", systemImage: "flag.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
            }
        }
        .sheet(item: $openedConversation) { conversation in
            NavigationView {
                TregoConversationScreen(
                    store: store,
                    conversation: conversation,
                    initialDraft: openedConversationDraft
                )
            }
            .navigationViewStyle(.stack)
        }
        .sheet(isPresented: $isShareSheetPresented) {
            TregoActivitySheet(items: shareItems)
        }
        .sheet(isPresented: $isReviewComposerPresented) {
            NavigationView {
                TregoReviewComposerScreen(store: store, product: activeProduct) {
                    await loadProduct()
                }
            }
            .navigationViewStyle(.stack)
        }
        .sheet(isPresented: $isReportComposerPresented) {
            NavigationView {
                TregoReportComposerScreen(
                    store: store,
                    targetType: "product",
                    targetId: activeProduct.id,
                    targetLabel: activeProduct.title,
                    businessUserId: activeProduct.createdByUserId
                )
            }
            .navigationViewStyle(.stack)
        }
        .task {
            await store.loadHomeIfNeeded()
            await loadProduct()
        }
    }

    private var activeProduct: TregoProduct {
        loadedProduct ?? product
    }

    private var recommendedGrid: [GridItem] {
        [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    }

    private var suggestedProducts: [TregoProduct] {
        var seen = Set<Int>([activeProduct.id])
        let recent = store.recentlyViewedProducts.filter {
            guard !seen.contains($0.id) else { return false }
            seen.insert($0.id)
            return true
        }
        let fallback = store.homeProducts.filter {
            guard !seen.contains($0.id) else { return false }
            seen.insert($0.id)
            return true
        }
        return Array((recent + fallback).prefix(4))
    }

    private var suggestedSectionTitle: String {
        store.recentlyViewedProducts.contains(where: { $0.id != activeProduct.id }) ? "Te shikuara me heret" : "Produkte te tjera"
    }

    private var displayRecommendationSections: [TregoRecommendationSection] {
        if !recommendationSections.isEmpty {
            return recommendationSections
        }

        guard !suggestedProducts.isEmpty else { return [] }
        return [
            TregoRecommendationSection(
                key: "fallback-suggested-products",
                title: suggestedSectionTitle,
                subtitle: "Fallback bazuar ne produktet qe useri ka pare me heret.",
                products: suggestedProducts
            )
        ]
    }

    private func loadProduct() async {
        isLoading = true
        async let detail: TregoProduct? = store.api.fetchProductDetail(id: product.id)
        async let loadedReviews: [TregoProductReview] = store.api.fetchProductReviews(id: product.id)
        async let loadedRecommendations: [TregoRecommendationSection] = store.api.fetchProductRecommendations(id: product.id, limit: 4)
        loadedProduct = await detail
        reviews = await loadedReviews
        recommendationSections = await loadedRecommendations
        store.trackViewedProduct(loadedProduct ?? product)
        isLoading = false
    }

    private func openBusinessConversation() async {
        guard let businessId = activeProduct.businessProfileId else { return }
        guard await store.ensureAuthenticatedSessionOrPrompt(
            message: "Per te derguar mesazh biznesit duhet te kyqeni ose te krijoni llogari."
        ) else { return }

        let (response, conversation) = await store.api.openBusinessConversation(businessId: businessId)
        guard response.ok == true, let conversation else {
            store.globalMessage = response.message ?? "Biseda nuk u hap."
            return
        }
        openedConversationDraft = buildProductConversationDraft(for: activeProduct)
        openedConversation = conversation
    }

    private func presentShareSheet() async {
        let response = await store.api.trackProductShare(productId: activeProduct.id)
        if response.ok != true, let message = response.message, !message.isEmpty {
            store.globalMessage = message
        }

        let shareURL = buildShareURL(for: activeProduct.id)
        shareItems = [activeProduct.title, shareURL]
        isShareSheetPresented = true
    }

    private func buildShareURL(for productId: Int) -> URL {
        let baseURL = TregoAPIConfiguration.load().baseURL
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = "/produkti"
        components?.queryItems = [URLQueryItem(name: "id", value: String(productId))]
        return components?.url ?? URL(string: "https://www.tregos.store/produkti?id=\(productId)")!
    }

    private func buildProductConversationDraft(for product: TregoProduct) -> String {
        let shareURL = buildShareURL(for: product.id).absoluteString
        let normalizedArticle = (product.articleNumber ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let productLabel = normalizedArticle.isEmpty
            ? "\"\(product.title)\""
            : "\"\(product.title)\" (SKU: \(normalizedArticle))"
        return "Pershendetje, jam i interesuar per produktin \(productLabel): \(shareURL)"
    }
}

private struct TregoReviewComposerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TregoNativeAppStore
    let product: TregoProduct
    let onSaved: () async -> Void

    @State private var rating = 5
    @State private var title = ""
    @State private var reviewBody = ""
    @State private var statusMessage = ""
    @State private var statusTone: TregoStatusMessageTone = .info
    @State private var isSubmitting = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                TregoNoticeCard(
                    title: "Shkruaj review",
                    subtitle: "Ndaj pervojen tende per produktin dhe ndihmo bleresit e tjere."
                )

                if !statusMessage.isEmpty {
                    TregoStatusMessageCard(message: statusMessage, tone: statusTone)
                }

                TregoInfoTile(title: "Produkti", value: product.title)

                TregoReviewRatingPicker(rating: $rating)
                TregoInputCard(title: "Titulli", text: $title, placeholder: "Si ishte produkti?")
                TregoMultilineInputCard(title: "Pershkrimi", text: $reviewBody, placeholder: "Shkruaj detajet e review-it")

                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Dergo review").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(TregoPrimaryButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private func submit() async {
        guard store.user != nil else {
            store.requireAuthentication(defaultRoute: .login)
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }

        let response = await store.api.createProductReview(
            productId: product.id,
            rating: rating,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: reviewBody.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard response.ok == true else {
            statusTone = .error
            statusMessage = response.message ?? "Review nuk u ruajt."
            return
        }
        store.presentToast(response.message ?? "Review u ruajt.")
        await onSaved()
        dismiss()
    }
}

private struct TregoReportComposerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TregoNativeAppStore
    let targetType: String
    let targetId: Int
    let targetLabel: String
    let businessUserId: Int?

    @State private var reason = ""
    @State private var details = ""
    @State private var statusMessage = ""
    @State private var statusTone: TregoStatusMessageTone = .info
    @State private var isSubmitting = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                TregoNoticeCard(
                    title: "Raporto",
                    subtitle: "Na tregoni arsyen e raportimit dhe ne do ta shqyrtojme."
                )

                if !statusMessage.isEmpty {
                    TregoStatusMessageCard(message: statusMessage, tone: statusTone)
                }

                TregoInfoTile(title: "Objekti", value: targetLabel)
                TregoInputCard(title: "Arsyeja", text: $reason, placeholder: "P.sh. informacion i pasakte")
                TregoMultilineInputCard(title: "Detajet", text: $details, placeholder: "Shkruaj me shume detaje nese eshte e nevojshme")

                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Dergo raportimin").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(TregoPrimaryButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Raportim")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private func submit() async {
        guard store.user != nil else {
            store.requireAuthentication(defaultRoute: .login)
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }

        let response = await store.api.createReport(
            targetType: targetType,
            targetId: targetId,
            targetLabel: targetLabel,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            businessUserId: businessUserId
        )
        guard response.ok == true else {
            statusTone = .error
            statusMessage = response.message ?? "Raportimi nuk u dergua."
            return
        }
        store.presentToast(response.message ?? "Raportimi u dergua.")
        dismiss()
    }
}

private struct TregoReturnRequestComposerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TregoNativeAppStore
    let order: TregoOrderItem

    @State private var reason = ""
    @State private var details = ""
    @State private var statusMessage = ""
    @State private var statusTone: TregoStatusMessageTone = .info
    @State private var isSubmitting = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                TregoNoticeCard(
                    title: "Kerkese per kthim",
                    subtitle: "Shkruaj arsyen e kthimit dhe biznesi do ta shqyrtoje kerkesen."
                )

                if !statusMessage.isEmpty {
                    TregoStatusMessageCard(message: statusMessage, tone: statusTone)
                }

                TregoOrderManagementCard(order: order, managerLabel: nil, onUpdate: nil)
                TregoInputCard(title: "Arsyeja", text: $reason, placeholder: "P.sh. produkti nuk pershtatet")
                TregoMultilineInputCard(title: "Detajet", text: $details, placeholder: "Shkruaj cfare ndodhi dhe pse deshiron kthim")

                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Dergo kerkesen").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(TregoPrimaryButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Kthim")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private func submit() async {
        guard store.user != nil else {
            store.requireAuthentication(defaultRoute: .login)
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }

        let response = await store.api.createReturnRequest(
            orderItemId: order.id,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard response.ok == true else {
            statusTone = .error
            statusMessage = response.message ?? "Kerkesa nuk u dergua."
            return
        }
        store.presentToast(response.message ?? "Kerkesa u dergua.")
        await store.loadOrders()
        dismiss()
    }
}

private struct TregoPublicBusinessScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    let selection: TregoBusinessSelection

    @State private var business: TregoPublicBusinessProfile?
    @State private var products: [TregoProduct] = []
    @State private var selectedProduct: TregoProduct?
    @State private var openedConversation: TregoConversation?
    @State private var isLoading = false
    @State private var isFollowUpdating = false
    @State private var feedbackMessage = ""
    @State private var feedbackTone: TregoStatusMessageTone = .info

    private let grid = [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                if isLoading && business == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else if let business {
                    TregoPublicBusinessHeroCard(business: business)

                    if !feedbackMessage.isEmpty {
                        TregoStatusMessageCard(message: feedbackMessage, tone: feedbackTone)
                    }

                    HStack(spacing: 12) {
                        Button {
                            Task { await toggleFollow() }
                        } label: {
                            if isFollowUpdating {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label(business.isFollowed == true ? "Following" : "Follow", systemImage: business.isFollowed == true ? "checkmark.circle.fill" : "plus.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(TregoPrimaryButtonStyle(tint: business.isFollowed == true ? TregoNativeTheme.softAccent : TregoNativeTheme.accent))

                        Button {
                            Task { await openConversation() }
                        } label: {
                            Label("Mesazh", systemImage: "message.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(TregoPrimaryButtonStyle())
                    }

                    TregoBusinessStatsRow(items: businessStats(for: business))

                    TregoSectionHeader(title: "Produktet e dyqanit")

                    if products.isEmpty {
                        TregoEmptyStateView(
                            title: "Ky dyqan ende nuk ka produkte",
                            subtitle: "Produktet publike do te shfaqen ketu sapo biznesi te publikoje katalogun."
                        )
                    } else {
                        LazyVGrid(columns: grid, spacing: 18) {
                            ForEach(products) { product in
                                TregoProductCard(
                                    product: product,
                                    isWishlisted: store.isWishlisted(productId: product.id),
                                    onTap: { selectedProduct = product },
                                    onOpenBusiness: {},
                                    onWishlist: {
                                        Task { await store.toggleWishlist(for: product) }
                                    },
                                    onAddToCart: {
                                        Task { await store.addToCart(product: product) }
                                    }
                                )
                            }
                        }
                    }
                } else {
                    TregoEmptyStateView(
                        title: "Dyqani nuk u gjet",
                        subtitle: "Ky profil biznesi nuk eshte i disponueshem ose nuk mund te ngarkohet tani."
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 36)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Dyqani")
        .navigationBarTitleDisplayMode(.inline)
        .tregoHideTabBarOnSecondaryPage()
        .sheet(item: $selectedProduct) { product in
            NavigationView {
                TregoProductDetailView(store: store, product: product)
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $openedConversation) { conversation in
            NavigationView {
                TregoConversationScreen(store: store, conversation: conversation)
            }
            .navigationViewStyle(.stack)
        }
        .task {
            await loadBusiness()
        }
    }

    private func loadBusiness() async {
        isLoading = true
        async let businessTask: TregoPublicBusinessProfile? = store.api.fetchPublicBusinessProfile(id: selection.id)
        async let productsTask = store.api.fetchPublicBusinessProductsPageResult(id: selection.id)
        business = await businessTask
        let productsResult = await productsTask
        if productsResult.didSucceed {
            products = productsResult.page.items
        } else if !products.isEmpty {
            feedbackTone = .error
            feedbackMessage = productsResult.message ?? "Produktet aktuale u ruajten. Rifreskimi deshtoi."
        }
        isLoading = false
    }

    private func toggleFollow() async {
        guard await store.ensureAuthenticatedSession(route: .login) else { return }
        isFollowUpdating = true
        defer { isFollowUpdating = false }

        let (response, updatedBusiness) = await store.api.toggleBusinessFollow(businessId: selection.id)
        if let updatedBusiness {
            business = updatedBusiness
            store.publicBusinesses = store.publicBusinesses.map { current in
                current.id == updatedBusiness.id ? updatedBusiness : current
            }
        }
        feedbackTone = response.ok == true ? .success : .error
        feedbackMessage = response.message ?? (response.ok == true ? "Dyqani u perditesua." : "Veprimi deshtoi.")
    }

    private func openConversation() async {
        guard await store.ensureAuthenticatedSessionOrPrompt(
            message: "Per te derguar mesazh biznesit duhet te kyqeni ose te krijoni llogari."
        ) else { return }

        let (response, conversation) = await store.api.openBusinessConversation(businessId: selection.id)
        guard response.ok == true, let conversation else {
            feedbackTone = .error
            feedbackMessage = response.message ?? "Biseda nuk u hap."
            return
        }
        openedConversation = conversation
    }

    private func businessStats(for business: TregoPublicBusinessProfile) -> [TregoMiniStatItem] {
        [
            TregoMiniStatItem(label: "Followers", value: String(business.followersCount ?? 0), icon: "person.2.fill"),
            TregoMiniStatItem(label: "Produkte", value: String(business.productsCount ?? 0), icon: "bag.fill"),
            TregoMiniStatItem(label: "Rating", value: business.sellerRating.map { String(format: "%.1f", $0) } ?? "-", icon: "star.fill"),
            TregoMiniStatItem(label: "Reviews", value: String(business.sellerReviewCount ?? 0), icon: "text.bubble.fill"),
        ]
    }
}

private struct TregoCheckoutScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TregoNativeAppStore
    let cartItems: [TregoCartItem]

    @State private var addressLine = ""
    @State private var city = ""
    @State private var country = "Kosove"
    @State private var zipCode = ""
    @State private var phoneNumber = ""
    @State private var promoCode = ""
    @State private var selectedDeliveryMethod = "standard"
    @State private var selectedPaymentMethod = "cash"
    @State private var pricing: TregoCheckoutPricing?
    @State private var isPreparing = false
    @State private var isRefreshingPricing = false
    @State private var isPlacingOrder = false
    @State private var hasPrepared = false
    @State private var stripeSession: TregoStripeCheckoutSession?
    @State private var statusMessage = ""
    @State private var statusTone: TregoStatusMessageTone = .info
    @State private var showsExitConfirmation = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                TregoNoticeCard(
                    title: "Checkout",
                    subtitle: "Ploteso adresen, zgjidh menyren e dergeses dhe konfirmo porosine direkt nga iPhone."
                )

                if !statusMessage.isEmpty {
                    TregoStatusMessageCard(message: statusMessage, tone: statusTone)
                }

                if isPreparing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    TregoSectionHeader(title: "Adresa e dergeses")
                    TregoInputCard(title: "Adresa", text: $addressLine, placeholder: "Rruga, numri, hyrja", textContentType: .fullStreetAddress, disableAutocorrection: false)
                    TregoInputCard(title: "Qyteti", text: $city, placeholder: "Shkruaj qytetin", textContentType: .addressCity, disableAutocorrection: false)
                    TregoInputCard(title: "Shteti", text: $country, placeholder: "Shkruaj shtetin", textContentType: .countryName, disableAutocorrection: false)
                    TregoInputCard(title: "Zip code", text: $zipCode, placeholder: "Shkruaj zip code", textContentType: .postalCode)
                    TregoInputCard(title: "Numri i telefonit", text: $phoneNumber, keyboardType: .phonePad, placeholder: "+383 44 123 456", autocapitalization: .never, textContentType: .telephoneNumber)

                    Button {
                        Task { await refreshPricing() }
                    } label: {
                        if isRefreshingPricing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Perditeso permbledhjen")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(TregoSecondaryButtonStyle())

                    TregoSectionHeader(title: "Dergesa")
                    if deliveryOptions.isEmpty {
                        TregoNoticeCard(
                            title: "Opsionet po ngarkohen",
                            subtitle: "Sapo adresa te jete gati, do te shfaqen metodat e dergeses."
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(deliveryOptions) { option in
                                Button {
                                    selectedDeliveryMethod = option.value
                                } label: {
                                    TregoDeliveryOptionCard(
                                        option: option,
                                        isSelected: selectedDeliveryMethod == option.value
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    TregoSectionHeader(title: "Pagesa")
                    VStack(spacing: 12) {
                        Button {
                            selectedPaymentMethod = "cash"
                            stripeSession = nil
                        } label: {
                            TregoPaymentOptionCard(
                                title: "Cash on delivery",
                                subtitle: "Pagese ne dorezim ose te biznesi",
                                systemImage: "banknote.fill",
                                isSelected: selectedPaymentMethod == "cash",
                                isEnabled: true,
                                badge: nil
                            )
                        }
                        .buttonStyle(.plain)

                        TregoApplePayOptionCard(
                            isSelected: selectedPaymentMethod == "apple-pay",
                            isAvailable: applePayAvailable
                        ) {
                            selectedPaymentMethod = "apple-pay"
                            stripeSession = nil
                            statusTone = applePayAvailable ? .info : .error
                            statusMessage = applePayAvailable
                                ? "Apple Pay UI u shtua. Pagesa reale do te lidhet me backend ne hapin e ardhshem."
                                : "Apple Pay nuk eshte i disponueshem ne kete pajisje ose ne Wallet."
                        }

                        Button {
                            selectedPaymentMethod = "card-online"
                        } label: {
                            TregoPaymentOptionCard(
                                title: "Card online",
                                subtitle: "Hap Stripe checkout dhe konfirmo pagesen pasi te perfundosh",
                                systemImage: "creditcard.fill",
                                isSelected: selectedPaymentMethod == "card-online",
                                isEnabled: true,
                                badge: "Stripe"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    TregoSectionHeader(title: "Kodi promocional")
                    HStack(spacing: 12) {
                        TregoInputCard(title: "Promo code", text: $promoCode, placeholder: "Shkruaj kodin")
                        Button("Apliko") {
                            Task { await refreshPricing() }
                        }
                        .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.accent))
                        .padding(.top, 26)
                    }

                    TregoSectionHeader(title: "Permbledhja")
                    TregoCheckoutSummaryCard(
                        pricing: pricing,
                        fallbackSubtotal: cartSubtotal,
                        cartItemsCount: cartItems.count
                    )

                    if stripeSession != nil {
                        Button {
                            Task { await confirmStripePayment() }
                        } label: {
                            if isPlacingOrder {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("Konfirmo pagesen me Stripe", systemImage: "checkmark.shield.fill")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(TregoSecondaryButtonStyle())
                    }

                    Button {
                        Task { await placeOrder() }
                    } label: {
                        if isPlacingOrder {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Konfirmo porosine", systemImage: "checkmark.seal.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(TregoPrimaryButtonStyle())
                    .disabled(isPlacingOrder || isRefreshingPricing || cartItems.isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 36)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .tregoHideTabBarOnSecondaryPage()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    showsExitConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
        }
        .alert("A jeni te sigurt qe doni te largoheni?", isPresented: $showsExitConfirmation) {
            Button("Jo, dua te blej", role: .cancel) {}
            Button("Po, dua te largohem", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("Nese largoheni tani, checkout-i do te mbyllet.")
        }
        .sheet(item: $stripeSession) { session in
            TregoSafariSheet(urlString: session.checkoutURL)
        }
        .task {
            guard !hasPrepared else { return }
            hasPrepared = true
            await prepareCheckout()
        }
        .onChange(of: selectedDeliveryMethod) { _ in
            guard hasPrepared, !isPreparing else { return }
            Task { await refreshPricing() }
        }
    }

    private var cartLineIds: [Int] {
        cartItems.map(\.id)
    }

    private var cartSubtotal: Double {
        cartItems.reduce(0.0) { partial, item in
            partial + (Double(item.quantity ?? 1) * (item.price ?? 0))
        }
    }

    private var deliveryOptions: [TregoDeliveryMethodOption] {
        pricing?.availableDeliveryMethods ?? []
    }

    private var applePayAvailable: Bool {
        PKPaymentAuthorizationController.canMakePayments(usingNetworks: [.visa, .masterCard, .amex])
    }

    private var checkoutDraft: TregoCheckoutDraft {
        TregoCheckoutDraft(
            addressLine: addressLine.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            country: country.trimmingCharacters(in: .whitespacesAndNewlines),
            zipCode: zipCode.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func prepareCheckout() async {
        guard !cartLineIds.isEmpty else { return }
        isPreparing = true
        defer { isPreparing = false }

        async let reserveTask = store.api.reserveCheckout(cartLineIds: cartLineIds)
        async let addressTask = store.api.fetchDefaultAddress()

        let (_, reservePayload) = await reserveTask
        if let address = await addressTask {
            addressLine = address.addressLine ?? ""
            city = address.city ?? ""
            country = address.country?.isEmpty == false ? (address.country ?? "") : "Kosove"
            zipCode = address.zipCode ?? ""
            phoneNumber = address.phoneNumber ?? ""
        } else {
            phoneNumber = store.user?.phoneNumber ?? ""
        }

        if let reserveMessage = reservePayload?.message, !reserveMessage.isEmpty {
            statusTone = .info
            statusMessage = reserveMessage
        }

        await refreshPricing(showSuccessMessage: false)
    }

    private func refreshPricing(showSuccessMessage: Bool = true) async {
        guard !cartLineIds.isEmpty else { return }
        isRefreshingPricing = true
        defer { isRefreshingPricing = false }

        let (response, loadedPricing) = await store.api.fetchCheckoutPricing(
            cartLineIds: cartLineIds,
            draft: checkoutDraft,
            promoCode: promoCode.trimmingCharacters(in: .whitespacesAndNewlines),
            deliveryMethod: selectedDeliveryMethod
        )

        guard response.ok == true, let loadedPricing else {
            statusTone = .error
            statusMessage = response.message ?? "Permbledhja nuk u perditesua."
            return
        }

        pricing = loadedPricing
        if let firstMethod = loadedPricing.availableDeliveryMethods?.first?.value,
           !(loadedPricing.availableDeliveryMethods ?? []).contains(where: { $0.value == selectedDeliveryMethod }) {
            selectedDeliveryMethod = firstMethod
        }

        let summaryMessage = (loadedPricing.message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? loadedPricing.message
            : response.message)

        if let summaryMessage, !summaryMessage.isEmpty, showSuccessMessage {
            statusTone = .success
            statusMessage = summaryMessage
        }
    }

    private func placeOrder() async {
        guard !checkoutDraft.addressLine.isEmpty,
              !checkoutDraft.city.isEmpty,
              !checkoutDraft.country.isEmpty,
              !checkoutDraft.phoneNumber.isEmpty else {
            statusTone = .error
            statusMessage = "Ploteso adresen dhe numrin e telefonit para se ta konfirmosh porosine."
            return
        }

        isPlacingOrder = true
        defer { isPlacingOrder = false }

        if selectedPaymentMethod == "card-online" {
            await startStripeCheckout()
            return
        }

        if selectedPaymentMethod == "apple-pay" {
            statusTone = applePayAvailable ? .info : .error
            statusMessage = applePayAvailable
                ? "Apple Pay eshte shtuar si opsion native ne checkout. Per pagesen reale duhet lidhur merchant/backend processing."
                : "Apple Pay nuk eshte i disponueshem ne kete pajisje ose ne Wallet."
            return
        }

        let response = await store.api.createOrder(
            cartLineIds: cartLineIds,
            draft: checkoutDraft,
            paymentMethod: selectedPaymentMethod,
            promoCode: promoCode.trimmingCharacters(in: .whitespacesAndNewlines),
            deliveryMethod: selectedDeliveryMethod
        )

        guard response.ok == true else {
            statusTone = .error
            statusMessage = response.message ?? "Porosia nuk u dergua."
            return
        }

        await store.loadCart()
        await store.loadOrders()
        store.presentToast(response.message ?? "Porosia u dergua me sukses.")
        dismiss()
    }

    private func startStripeCheckout() async {
        let (response, checkoutSession) = await store.api.createStripeCheckoutSession(
            cartLineIds: cartLineIds,
            draft: checkoutDraft,
            promoCode: promoCode.trimmingCharacters(in: .whitespacesAndNewlines),
            deliveryMethod: selectedDeliveryMethod
        )

        guard response.ok == true, let checkoutSession else {
            statusTone = .error
            statusMessage = response.message ?? "Stripe checkout nuk u hap."
            return
        }

        pricing = checkoutSession.pricing ?? pricing
        stripeSession = checkoutSession
        statusTone = .info
        statusMessage = checkoutSession.message ?? "Perfundo pagesen ne Stripe dhe pastaj kthehu per ta konfirmuar."
    }

    private func confirmStripePayment() async {
        guard let stripeSession else {
            statusTone = .error
            statusMessage = "Sesioni Stripe mungon."
            return
        }

        isPlacingOrder = true
        defer { isPlacingOrder = false }

        let response = await store.api.confirmStripeCheckoutSession(sessionId: stripeSession.sessionId)
        guard response.ok == true else {
            statusTone = .error
            statusMessage = response.message ?? "Pagesa ende nuk eshte konfirmuar."
            return
        }

        await store.loadCart()
        await store.loadOrders()
        store.presentToast(response.message ?? "Pagesa u konfirmua dhe porosia u dergua.")
        dismiss()
    }
}

private struct TregoAdminPasswordResetScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TregoNativeAppStore
    let user: TregoAdminUser

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var message = ""
    @State private var tone: TregoStatusMessageTone = .info
    @State private var isSaving = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                TregoNoticeCard(
                    title: "Ndrysho fjalekalimin",
                    subtitle: "Vendos nje fjalekalim te ri per \(user.fullName ?? user.email ?? "perdoruesin")."
                )

                if !message.isEmpty {
                    TregoStatusMessageCard(message: message, tone: tone)
                }

                TregoSecureInputCard(title: "Fjalekalimi i ri", text: $newPassword, textContentType: .newPassword, submitLabel: .next)
                TregoSecureInputCard(title: "Konfirmo fjalekalimin", text: $confirmPassword, textContentType: .newPassword, submitLabel: .done)

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Ruaj fjalekalimin")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(TregoPrimaryButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Reset password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private func save() async {
        guard !newPassword.isEmpty, !confirmPassword.isEmpty else {
            tone = .error
            message = "Ploteso te dy fushat."
            return
        }
        guard newPassword == confirmPassword else {
            tone = .error
            message = "Konfirmimi i fjalekalimit nuk perputhet."
            confirmPassword = ""
            return
        }
        isSaving = true
        defer { isSaving = false }

        if let error = await store.setAdminUserPassword(user, newPassword: newPassword) {
            tone = .error
            message = error
            return
        }

        dismiss()
    }
}

private struct TregoBusinessProductEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TregoNativeAppStore
    let existingProduct: TregoProduct?

    @State private var draft: TregoProductFormDraft
    @State private var selectedUpload: TregoImageSearchUpload?
    @State private var pickerSource: TregoImagePickerSource?
    @State private var showsImageDialog = false
    @State private var statusMessage = ""
    @State private var statusTone: TregoStatusMessageTone = .info
    @State private var isSaving = false

    init(store: TregoNativeAppStore, existingProduct: TregoProduct?) {
        self.store = store
        self.existingProduct = existingProduct
        _draft = State(initialValue: TregoProductFormDraft(product: existingProduct))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                TregoNoticeCard(
                    title: existingProduct == nil ? "Shto artikull" : "Edito artikullin",
                    subtitle: "Ruaj produktin me foto, kategori, cmim dhe stok direkt nga iPhone."
                )

                if !statusMessage.isEmpty {
                    TregoStatusMessageCard(message: statusMessage, tone: statusTone)
                }

                TregoProductImageEditorCard(
                    title: "Fotoja e produktit",
                    subtitle: "Ngarko te pakten nje foto kryesore per artikullin.",
                    imagePath: draft.imagePaths.first ?? "",
                    upload: selectedUpload,
                    onChoosePhoto: { showsImageDialog = true },
                    onRemovePhoto: {
                        selectedUpload = nil
                        draft.imagePaths = []
                    }
                )

                TregoSectionHeader(title: "Detajet bazë")
                TregoInputCard(title: "Kodi i artikullit", text: $draft.articleNumber, placeholder: "10025")
                TregoInputCard(title: "Titulli", text: $draft.title, placeholder: "Shkruaj titullin")
                TregoMultilineInputCard(title: "Pershkrimi", text: $draft.description, placeholder: "Pershkruaj produktin")

                TregoSelectionValueCard(
                    title: "Seksioni",
                    subtitle: "Ku do te shfaqet produkti",
                    currentValue: TregoNativeProductCatalog.sectionLabel(for: draft.pageSection),
                    options: TregoNativeProductCatalog.sectionOptions
                ) { draft.pageSection = $0 }

                if TregoNativeProductCatalog.sectionSupportsAudience(draft.pageSection) {
                    TregoSelectionValueCard(
                        title: "Audience",
                        subtitle: "Nenkategoria e seksionit",
                        currentValue: TregoNativeProductCatalog.audienceLabel(section: draft.pageSection, audience: draft.audience),
                        options: TregoNativeProductCatalog.audienceOptions(for: draft.pageSection)
                    ) { draft.audience = $0 }
                }

                TregoSelectionValueCard(
                    title: "Lloji i produktit",
                    subtitle: "Tipi i artikullit",
                    currentValue: TregoNativeProductCatalog.productTypeLabel(for: draft.productType),
                    options: TregoNativeProductCatalog.productTypeOptions(section: draft.pageSection, audience: draft.audience)
                ) { draft.productType = $0 }

                TregoSectionHeader(title: "Cmimi")
                TregoInputCard(title: "Cmimi aktual", text: $draft.priceText, keyboardType: .decimalPad, placeholder: "19.90", autocapitalization: .never)
                Toggle(isOn: $draft.saleEnabled) {
                    Text("Ky produkt eshte ne zbritje")
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                if draft.saleEnabled {
                    TregoInputCard(title: "Cmimi para zbritjes", text: $draft.compareAtPriceText, keyboardType: .decimalPad, placeholder: "29.90", autocapitalization: .never)
                    TregoDateInputCard(title: "Zbritja vlen deri me", date: $draft.saleEndDate)
                }

                TregoSectionHeader(title: "Stoku dhe varianti")
                TregoInputCard(title: "Stoku", text: $draft.stockQuantityText, keyboardType: .numberPad, placeholder: "12", autocapitalization: .never)

                if TregoNativeProductCatalog.requiresSize(section: draft.pageSection) {
                    TregoSelectionValueCard(
                        title: "Madhesia",
                        subtitle: "Zgjidh madhesine baze",
                        currentValue: draft.size.isEmpty ? "Zgjidh madhesine" : draft.size,
                        options: TregoNativeProductCatalog.sizeOptions
                    ) { draft.size = $0 }
                }

                TregoSelectionValueCard(
                    title: "Ngjyra",
                    subtitle: "Ngjyra kryesore e artikullit",
                    currentValue: TregoNativeProductCatalog.colorLabel(for: draft.color),
                    options: TregoNativeProductCatalog.colorOptions
                ) { draft.color = $0 }

                if TregoNativeProductCatalog.supportsPackageAmount(section: draft.pageSection) {
                    TregoInputCard(title: "Sasia", text: $draft.packageAmountValueText, keyboardType: .decimalPad, placeholder: "250", autocapitalization: .never)
                    TregoSelectionValueCard(
                        title: "Njesia",
                        subtitle: "ml ose L",
                        currentValue: draft.packageAmountUnit.isEmpty ? "Zgjidh njesine" : draft.packageAmountUnit.uppercased(),
                        options: TregoNativeProductCatalog.amountUnitOptions
                    ) { draft.packageAmountUnit = $0 }
                }

                Toggle(isOn: $draft.isPublic) {
                    Text("Shfaqe publikisht ne marketplace")
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(existingProduct == nil ? "Ruaj artikullin" : "Perditeso artikullin")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(TregoPrimaryButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle(existingProduct == nil ? "Shto artikull" : "Edito artikullin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .confirmationDialog("Foto e produktit", isPresented: $showsImageDialog) {
            Button("Take photo") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    pickerSource = .camera
                } else {
                    statusTone = .error
                    statusMessage = "Kamera nuk eshte e disponueshme tani."
                }
            }
            Button("Choose from library") {
                pickerSource = .photoLibrary
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $pickerSource) { source in
            TregoImagePicker(source: source) { upload in
                selectedUpload = upload
            }
        }
        .onChange(of: draft.pageSection) { newValue in
            draft.syncForSectionChange(newValue)
        }
        .onChange(of: draft.audience) { _ in
            draft.syncForSectionChange(draft.pageSection)
        }
    }

    private func save() async {
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusTone = .error
            statusMessage = "Shkruaj titullin e produktit."
            return
        }

        isSaving = true
        defer { isSaving = false }

        if let selectedUpload {
            let (uploadResponse, uploaded) = await store.api.uploadProductImages([selectedUpload])
            guard uploadResponse.ok == true, let uploaded else {
                statusTone = .error
                statusMessage = uploadResponse.message ?? "Fotoja nuk u ngarkua."
                return
            }
            draft.imagePaths = uploaded.paths
        }

        let payload = draft.backendPayload()
        let responseAndProduct: (TregoStatusResponse, TregoProduct?)
        if let existingProduct {
            responseAndProduct = await store.api.updateProduct(productId: existingProduct.id, payload: payload)
        } else {
            responseAndProduct = await store.api.createProduct(payload: payload)
        }

        let response = responseAndProduct.0
        guard response.ok == true, let savedProduct = responseAndProduct.1 else {
            statusTone = .error
            statusMessage = response.message ?? "Produkti nuk u ruajt."
            return
        }

        if draft.isPublic != (savedProduct.isPublic ?? false) {
            _ = await store.api.updateProductPublicVisibility(productId: savedProduct.id, isPublic: draft.isPublic)
        }

        await store.loadBusinessWorkspace(force: true)
        store.presentToast(response.message ?? (existingProduct == nil ? "Artikulli u ruajt me sukses." : "Artikulli u perditesua me sukses."))
        dismiss()
    }
}

private struct TregoPromotionEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TregoNativeAppStore
    let existingPromotion: TregoPromotion?

    @State private var draft: TregoPromotionFormDraft
    @State private var statusMessage = ""
    @State private var statusTone: TregoStatusMessageTone = .info
    @State private var isSaving = false

    init(store: TregoNativeAppStore, existingPromotion: TregoPromotion?) {
        self.store = store
        self.existingPromotion = existingPromotion
        _draft = State(initialValue: TregoPromotionFormDraft(promotion: existingPromotion))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                TregoNoticeCard(
                    title: existingPromotion == nil ? "Shto promocion" : "Edito promocionin",
                    subtitle: "Krijo kupona dhe zbritje per biznesin pa dalë nga iPhone."
                )

                if !statusMessage.isEmpty {
                    TregoStatusMessageCard(message: statusMessage, tone: statusTone)
                }

                TregoSectionHeader(title: "Detajet")
                TregoInputCard(title: "Kodi i kuponit", text: $draft.code, placeholder: "SALE25", autocapitalization: .characters)
                TregoInputCard(title: "Titulli", text: $draft.title, placeholder: "Weekend sale")
                TregoMultilineInputCard(title: "Pershkrimi", text: $draft.description, placeholder: "Pershkruaj ofertën dhe kushtet kryesore")

                TregoSelectionValueCard(
                    title: "Lloji i zbritjes",
                    subtitle: "Perqindje ose vlerë fikse",
                    currentValue: draft.discountTypeLabel,
                    options: TregoPromotionFormDraft.discountTypeOptions
                ) { draft.discountType = $0 }

                TregoInputCard(
                    title: draft.discountType == "percent" ? "Zbritja ne %" : "Zbritja ne €",
                    text: $draft.discountValueText,
                    keyboardType: .decimalPad,
                    placeholder: draft.discountType == "percent" ? "15" : "5.00",
                    autocapitalization: .never
                )

                HStack(spacing: 12) {
                    TregoInputCard(
                        title: "Minimumi i porosise",
                        text: $draft.minimumSubtotalText,
                        keyboardType: .decimalPad,
                        placeholder: "20.00",
                        autocapitalization: .never
                    )
                    TregoInputCard(
                        title: "Limit total",
                        text: $draft.usageLimitText,
                        keyboardType: .numberPad,
                        placeholder: "0 = pa limit",
                        autocapitalization: .never
                    )
                }

                TregoInputCard(
                    title: "Per user",
                    text: $draft.perUserLimitText,
                    keyboardType: .numberPad,
                    placeholder: "1",
                    autocapitalization: .never
                )

                TregoSectionHeader(title: "Targetimi")
                TregoSelectionValueCard(
                    title: "Seksioni",
                    subtitle: "Ne cilin seksion aplikohet oferta",
                    currentValue: draft.sectionLabel,
                    options: TregoPromotionFormDraft.sectionOptions
                ) { draft.pageSection = $0 }

                if TregoNativeProductCatalog.sectionSupportsAudience(draft.pageSection) {
                    TregoSelectionValueCard(
                        title: "Audience",
                        subtitle: "Zgjidh nenkategorine e ofertes",
                        currentValue: draft.audienceLabel,
                        options: [("", "Te gjitha")] + TregoNativeProductCatalog.audienceOptions(for: draft.pageSection)
                    ) { draft.audience = $0 }
                }

                Toggle(isOn: $draft.isActive) {
                    Text("Promocioni eshte aktiv")
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                Toggle(isOn: $draft.hasStartDate) {
                    Text("Ka date nisjeje")
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                if draft.hasStartDate {
                    TregoDateInputCard(title: "Nis me", date: $draft.startsAt)
                }

                Toggle(isOn: $draft.hasEndDate) {
                    Text("Ka date perfundimi")
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                if draft.hasEndDate {
                    TregoDateInputCard(title: "Mbaron me", date: $draft.endsAt)
                }

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(existingPromotion == nil ? "Ruaj promocionin" : "Perditeso promocionin")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(TregoPrimaryButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle(existingPromotion == nil ? "Shto promocion" : "Edito promocionin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .onChange(of: draft.pageSection) { newValue in
            draft.syncForSectionChange(newValue)
        }
        .onChange(of: draft.audience) { _ in
            draft.syncForSectionChange(draft.pageSection)
        }
    }

    private func save() async {
        guard !draft.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusTone = .error
            statusMessage = "Shkruaj kodin e kuponit."
            return
        }

        isSaving = true
        defer { isSaving = false }

        if let message = await store.saveBusinessPromotion(payload: draft.backendPayload()) {
            statusTone = .error
            statusMessage = message
            return
        }

        dismiss()
    }
}

private struct TregoLaunchAdEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TregoNativeAppStore
    let existingLaunchAd: TregoLaunchAd?

    @State private var draft: TregoLaunchAdFormDraft
    @State private var selectedUpload: TregoImageSearchUpload?
    @State private var pickerSource: TregoImagePickerSource?
    @State private var showsImageDialog = false
    @State private var statusMessage = ""
    @State private var statusTone: TregoStatusMessageTone = .info
    @State private var isSaving = false

    init(store: TregoNativeAppStore, existingLaunchAd: TregoLaunchAd?) {
        self.store = store
        self.existingLaunchAd = existingLaunchAd
        _draft = State(initialValue: TregoLaunchAdFormDraft(launchAd: existingLaunchAd))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                TregoNoticeCard(
                    title: existingLaunchAd == nil ? "Shto launch ad" : "Edito launch ad",
                    subtitle: "Menaxho popup-in qe hapet ne start te app-it direkt nga paneli admin."
                )

                if !statusMessage.isEmpty {
                    TregoStatusMessageCard(message: statusMessage, tone: statusTone)
                }

                TregoProductImageEditorCard(
                    title: "Fotoja e launch ad",
                    subtitle: "Kjo foto shfaqet ne popup-in fillestar te app-it.",
                    imagePath: draft.imagePath,
                    upload: selectedUpload,
                    onChoosePhoto: { showsImageDialog = true },
                    onRemovePhoto: {
                        selectedUpload = nil
                        draft.imagePath = ""
                    }
                )

                TregoSectionHeader(title: "Permbajtja")
                TregoInputCard(title: "Badge", text: $draft.badge, placeholder: "Spring Sale", disableAutocorrection: false)
                TregoInputCard(title: "Titulli", text: $draft.title, placeholder: "Fresh looks this week", disableAutocorrection: false)
                TregoMultilineInputCard(title: "Pershkrimi", text: $draft.subtitle, placeholder: "Shpjego shkurt cfare oferte po del ne hyrje.")
                TregoInputCard(title: "Teksti i butonit", text: $draft.ctaLabel, placeholder: "Shop now", disableAutocorrection: false)
                TregoInputCard(
                    title: "Renditja",
                    text: $draft.sortOrderText,
                    keyboardType: .numberPad,
                    placeholder: "0",
                    autocapitalization: .never
                )

                Toggle(isOn: $draft.isActive) {
                    Text("Launch ad eshte aktiv")
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                Toggle(isOn: $draft.hasStartDate) {
                    Text("Ka date nisjeje")
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                if draft.hasStartDate {
                    TregoDateInputCard(title: "Nis me", date: $draft.startsAt)
                }

                Toggle(isOn: $draft.hasEndDate) {
                    Text("Ka date perfundimi")
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                if draft.hasEndDate {
                    TregoDateInputCard(title: "Mbaron me", date: $draft.endsAt)
                }

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(existingLaunchAd == nil ? "Ruaj launch ad" : "Perditeso launch ad")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(TregoPrimaryButtonStyle(tint: TregoNativeTheme.softAccent))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle(existingLaunchAd == nil ? "Shto launch ad" : "Edito launch ad")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .confirmationDialog("Fotoja e launch ad", isPresented: $showsImageDialog) {
            Button("Take photo") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    pickerSource = .camera
                } else {
                    statusTone = .error
                    statusMessage = "Kamera nuk eshte e disponueshme tani."
                }
            }
            Button("Choose from library") {
                pickerSource = .photoLibrary
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $pickerSource) { source in
            TregoImagePicker(source: source) { upload in
                selectedUpload = upload
            }
        }
    }

    private func save() async {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            statusTone = .error
            statusMessage = "Shkruaj titullin e launch ad."
            return
        }

        isSaving = true
        defer { isSaving = false }

        if let selectedUpload {
            let (uploadResponse, uploaded) = await store.api.uploadProductImages([selectedUpload])
            guard uploadResponse.ok == true, let uploaded else {
                statusTone = .error
                statusMessage = uploadResponse.message ?? "Fotoja nuk u ngarkua."
                return
            }
            draft.imagePath = uploaded.paths.first ?? ""
        }

        guard !draft.imagePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusTone = .error
            statusMessage = "Ngarko nje foto per launch ad."
            return
        }

        if let message = await store.saveAdminLaunchAd(payload: draft.backendPayload(existingId: existingLaunchAd?.id)) {
            statusTone = .error
            statusMessage = message
            return
        }

        dismiss()
    }
}

private struct TregoOrderStatusEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TregoNativeAppStore
    let order: TregoOrderItem
    let title: String
    let onSave: (String, String, String) async -> String?

    @State private var draft: TregoOrderStatusDraft
    @State private var statusMessage = ""
    @State private var statusTone: TregoStatusMessageTone = .info
    @State private var isSaving = false

    init(
        store: TregoNativeAppStore,
        order: TregoOrderItem,
        title: String,
        onSave: @escaping (String, String, String) async -> String?
    ) {
        self.store = store
        self.order = order
        self.title = title
        self.onSave = onSave
        _draft = State(initialValue: TregoOrderStatusDraft(order: order))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                TregoNoticeCard(
                    title: title,
                    subtitle: "Perditeso statusin, tracking code dhe linkun e transportit ne nje vend."
                )

                if !statusMessage.isEmpty {
                    TregoStatusMessageCard(message: statusMessage, tone: statusTone)
                }

                TregoOrderManagementCard(order: order, managerLabel: nil, onUpdate: nil)

                TregoSelectionValueCard(
                    title: "Statusi i ri",
                    subtitle: "Kalimi i ardhshëm i lejuar per kete artikull",
                    currentValue: TregoNativeFormatting.fulfillmentStatusLabel(draft.nextStatus),
                    options: draft.availableStatuses
                ) { draft.nextStatus = $0 }

                if draft.showsTrackingFields {
                    TregoInputCard(
                        title: "Tracking code",
                        text: $draft.trackingCode,
                        placeholder: "TRK-204998",
                        autocapitalization: .characters
                    )
                    TregoInputCard(
                        title: "Tracking link",
                        text: $draft.trackingURL,
                        keyboardType: .URL,
                        placeholder: "https://posta.com/track/...",
                        autocapitalization: .never
                    )
                }

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Ruaj statusin")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(TregoPrimaryButtonStyle())
                .disabled(draft.nextStatus.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Statusi i porosise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private func save() async {
        guard !draft.nextStatus.isEmpty else {
            statusTone = .error
            statusMessage = "Zgjidh statusin e ri."
            return
        }

        isSaving = true
        defer { isSaving = false }

        if let message = await onSave(
            draft.nextStatus,
            draft.trackingCode.trimmingCharacters(in: .whitespacesAndNewlines),
            draft.trackingURL.trimmingCharacters(in: .whitespacesAndNewlines)
        ) {
            statusTone = .error
            statusMessage = message
            return
        }

        dismiss()
    }
}

private struct TregoAdminBusinessEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TregoNativeAppStore
    let existingBusiness: TregoAdminBusiness?

    @State private var draft: TregoAdminBusinessFormDraft
    @State private var selectedUpload: TregoImageSearchUpload?
    @State private var pickerSource: TregoImagePickerSource?
    @State private var showsImageDialog = false
    @State private var statusMessage = ""
    @State private var statusTone: TregoStatusMessageTone = .info
    @State private var isSaving = false

    init(store: TregoNativeAppStore, existingBusiness: TregoAdminBusiness?) {
        self.store = store
        self.existingBusiness = existingBusiness
        _draft = State(initialValue: TregoAdminBusinessFormDraft(business: existingBusiness))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                TregoNoticeCard(
                    title: existingBusiness == nil ? "Krijo biznes" : "Edito biznesin",
                    subtitle: "Menaxho te dhenat baze te biznesit nga paneli i adminit."
                )

                if !statusMessage.isEmpty {
                    TregoStatusMessageCard(message: statusMessage, tone: statusTone)
                }

                if existingBusiness != nil {
                    TregoProductImageEditorCard(
                        title: "Logoja e biznesit",
                        subtitle: "Perditeso logon qe perdor ky biznes ne marketplace.",
                        imagePath: draft.businessLogoPath,
                        upload: selectedUpload,
                        onChoosePhoto: { showsImageDialog = true },
                        onRemovePhoto: {
                            selectedUpload = nil
                            draft.businessLogoPath = ""
                        }
                    )
                }

                TregoSectionHeader(title: "Pronari")

                if existingBusiness == nil {
                    TregoInputCard(title: "Emri dhe mbiemri", text: $draft.fullName, placeholder: "Ardit Berisha", textContentType: .name, disableAutocorrection: false)
                    TregoInputCard(title: "Email", text: $draft.email, keyboardType: .emailAddress, placeholder: "biznesi@email.com", autocapitalization: .never, textContentType: .emailAddress)
                    TregoSecureInputCard(title: "Fjalekalimi", text: $draft.password, textContentType: .newPassword)
                } else {
                    TregoInfoTile(title: "Pronari", value: draft.fullName.isEmpty ? (existingBusiness?.ownerName ?? "-") : draft.fullName)
                    TregoInfoTile(title: "Email", value: draft.email.isEmpty ? (existingBusiness?.ownerEmail ?? "-") : draft.email)
                }

                TregoSectionHeader(title: "Profili i biznesit")
                TregoInputCard(title: "Emri i biznesit", text: $draft.businessName, placeholder: "Tregio Store", textContentType: .organizationName, disableAutocorrection: false)
                TregoMultilineInputCard(title: "Pershkrimi", text: $draft.businessDescription, placeholder: "Pershkruaj biznesin dhe cfare shet.")
                TregoInputCard(title: "Numri i biznesit", text: $draft.businessNumber, placeholder: "BK-2026-01", autocapitalization: .characters)
                TregoInputCard(title: "Telefoni", text: $draft.phoneNumber, keyboardType: .phonePad, placeholder: "+383 44 123 456", autocapitalization: .never, textContentType: .telephoneNumber)
                TregoInputCard(title: "Qyteti", text: $draft.city, placeholder: "Prishtine", textContentType: .addressCity, disableAutocorrection: false)
                TregoInputCard(title: "Adresa", text: $draft.addressLine, placeholder: "Rr. Nena Tereze, nr. 12", textContentType: .fullStreetAddress, disableAutocorrection: false)

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(existingBusiness == nil ? "Krijo biznesin" : "Ruaj perditesimet")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(TregoPrimaryButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle(existingBusiness == nil ? "Shto biznes" : "Edito biznesin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .confirmationDialog("Logoja e biznesit", isPresented: $showsImageDialog) {
            Button("Take photo") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    pickerSource = .camera
                } else {
                    statusTone = .error
                    statusMessage = "Kamera nuk eshte e disponueshme tani."
                }
            }
            Button("Choose from library") {
                pickerSource = .photoLibrary
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $pickerSource) { source in
            TregoImagePicker(source: source) { upload in
                selectedUpload = upload
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        if let selectedUpload {
            let (uploadResponse, uploaded) = await store.api.uploadProductImages([selectedUpload])
            guard uploadResponse.ok == true, let uploaded else {
                statusTone = .error
                statusMessage = uploadResponse.message ?? "Logoja nuk u ngarkua."
                return
            }
            draft.businessLogoPath = uploaded.paths.first ?? ""
        }

        let failureMessage: String?
        if let existingBusiness {
            failureMessage = await store.updateAdminBusiness(existingBusiness, payload: draft.updatePayload())
        } else {
            failureMessage = await store.createAdminBusiness(payload: draft.createPayload())
        }

        if let failureMessage {
            statusTone = .error
            statusMessage = failureMessage
            return
        }

        dismiss()
    }
}

private struct TregoAuthSheetView: View {
    @ObservedObject var store: TregoNativeAppStore
    let route: TregoAuthRoute

    var body: some View {
        Group {
            switch activeRoute {
            case .login:
                TregoLoginView(store: store)
            case .signup:
                TregoSignupView(store: store)
            case .forgotPassword:
                TregoForgotPasswordView(store: store)
            case .verifyEmail:
                TregoVerifyEmailView(store: store)
            }
        }
        .id(activeRoute.id)
        .onAppear {
            TregoNativeKeyboard.removeLegacyTapOutsideDismissRecognizers()
        }
    }

    private var activeRoute: TregoAuthRoute {
        store.authRoute ?? route
    }
}

private enum TregoNativeKeyboard {
    private static let legacyTapOutsideGestureName = "trego.tapOutsideKeyboardDismiss"

    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    static func removeLegacyTapOutsideDismissRecognizers() {
        DispatchQueue.main.async {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .forEach { window in
                    removeLegacyTapOutsideDismissRecognizers(from: window)
                }
        }
    }

    private static func removeLegacyTapOutsideDismissRecognizers(from view: UIView) {
        if let recognizers = view.gestureRecognizers {
            recognizers
                .filter { $0.name == legacyTapOutsideGestureName }
                .forEach { recognizer in
                    view.removeGestureRecognizer(recognizer)
                }
        }

        for subview in view.subviews {
            removeLegacyTapOutsideDismissRecognizers(from: subview)
        }
    }
}

private struct TregoInteractiveKeyboardDismissModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollDismissesKeyboard(.interactively)
        } else {
            content
        }
    }
}

private struct TregoTapOutsideKeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

private struct TregoTapOutsideKeyboardDismissView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false

        DispatchQueue.main.async {
            guard let hostView = view.superview else { return }
            let gestureName = "trego.tapOutsideKeyboardDismiss"
            let alreadyInstalled = hostView.gestureRecognizers?.contains(where: { $0.name == gestureName }) == true
            guard !alreadyInstalled else { return }

            let recognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = context.coordinator
            recognizer.name = gestureName
            hostView.addGestureRecognizer(recognizer)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        @objc func handleTap() {
            TregoNativeKeyboard.dismiss()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var current: UIView? = touch.view
            while let view = current {
                if view is UIControl || view is UITextField || view is UITextView {
                    return false
                }
                current = view.superview
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

private extension View {
    func tregoInteractiveKeyboardDismiss() -> some View {
        modifier(TregoInteractiveKeyboardDismissModifier())
    }

    func tregoTapOutsideKeyboardDismiss() -> some View {
        modifier(TregoTapOutsideKeyboardDismissModifier())
    }
}

private struct TregoAuthSheetCard<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.07 : 0.98),
                    TregoNativeTheme.cardSurface.opacity(colorScheme == .dark ? 0.96 : 0.94),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.52), lineWidth: 0.9)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.34),
                            .clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.08), radius: 24, y: 16)
        .shadow(color: TregoNativeTheme.accent.opacity(colorScheme == .dark ? 0.12 : 0.08), radius: 10, y: 4)
    }
}

private struct TregoLoginView: View {
    @ObservedObject var store: TregoNativeAppStore
    @State private var identifier = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isSubmitting = false
    @State private var failedAttempts = 0
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case identifier
        case password
    }

    var body: some View {
        ScrollView {
            TregoAuthSheetCard {
                HStack {
                    Spacer()
                    TregoAuthSupportButton {
                        store.globalMessage = "Customer Support eshte nen construction."
                    }
                }

                Spacer(minLength: 34)

                TregoAuthHeader(title: "Kyçuni", subtitle: "Hyni ne llogarine tuaj.")

                TextField("Email ose telefoni", text: $identifier)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.default)
                    .textContentType(.username)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .identifier)
                    .onSubmit {
                        focusedField = .password
                    }
                    .onChange(of: identifier) { _ in
                        clearFieldValidationState()
                    }

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.go)
                    .focused($focusedField, equals: .password)
                    .onSubmit {
                        Task { await submit() }
                    }
                    .onChange(of: password) { _ in
                        clearFieldValidationState()
                    }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                }

                if failedAttempts > 0 {
                    Button("Keni harruar fjalekalimin?") {
                        store.authRoute = .forgotPassword
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(TregoNativeTheme.accent)
                }

                Button {
                    Task {
                        await submit()
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Log in")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(TregoNativeTheme.accent)

                HStack(spacing: 6) {
                    Text("Nuk keni llogari akoma?")
                        .foregroundStyle(.secondary)
                    Button("Sign up") {
                        store.authRoute = .signup
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 14, weight: .medium))

                TregoAuthSocialButtonsGroup(store: store)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .padding(.bottom, 16)
        }
        .background(TregoNativeTheme.background.ignoresSafeArea())
        .tregoInteractiveKeyboardDismiss()
        .onAppear {
            if identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !store.pendingEmailVerificationEmail.isEmpty {
                identifier = store.pendingEmailVerificationEmail
            }
        }
    }

    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        let message = await store.login(identifier: identifier.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        if let message {
            handleLoginFailure(message)
        } else {
            failedAttempts = 0
            errorMessage = ""
        }
    }

    private func clearFieldValidationState() {
        if errorMessage.contains("Ploteso") || errorMessage.contains("email") || errorMessage.contains("telefon") {
            errorMessage = ""
        }
    }

    private func handleLoginFailure(_ message: String) {
        let normalized = message.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if normalized.contains("fjalekalim") {
            failedAttempts += 1
            password = ""
            errorMessage = ""
        } else {
            errorMessage = message
        }
    }
}

private struct TregoSignupView: View {
    @ObservedObject var store: TregoNativeAppStore
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var birthDate = TregoNativeFormatting.defaultBirthDate
    @State private var gender = "femer"
    @State private var errorMessage = ""
    @State private var isSubmitting = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case firstName
        case lastName
        case email
        case phoneNumber
        case password
    }

    var body: some View {
        ScrollView {
            TregoAuthSheetCard {
                HStack {
                    Spacer()
                    TregoAuthSupportButton {
                        store.globalMessage = "Customer Support eshte nen construction."
                    }
                }

                Spacer(minLength: 34)

                TregoAuthHeader(title: "Regjistrohuni", subtitle: "Krijoni llogarine.")

                TextField("Emri", text: $firstName)
                    .textContentType(.givenName)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .firstName)
                    .onSubmit {
                        focusedField = .lastName
                    }
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)

                TextField("Mbiemri", text: $lastName)
                    .textContentType(.familyName)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .lastName)
                    .onSubmit {
                        focusedField = .email
                    }
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    .onSubmit {
                        focusedField = .phoneNumber
                    }
                    .textFieldStyle(.roundedBorder)

                TextField("Numri i telefonit", text: $phoneNumber, prompt: Text("+383 44 123 456"))
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .phoneNumber)
                    .onSubmit {
                        focusedField = .password
                    }
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .password)
                    .onSubmit {
                        Task { await submit() }
                    }
                    .textFieldStyle(.roundedBorder)

                TregoBirthDateGenderRow(
                    birthDate: $birthDate,
                    gender: $gender
                )

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                }

                Button {
                    Task {
                        await submit()
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create account")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(TregoNativeTheme.accent)

                HStack(spacing: 6) {
                    Text("Keni llogari tashme?")
                        .foregroundStyle(.secondary)
                    Button("Log in") {
                        store.authRoute = .login
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 14, weight: .medium))

                TregoAuthSocialButtonsGroup(store: store)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .padding(.bottom, 16)
        }
        .background(TregoNativeTheme.background.ignoresSafeArea())
        .tregoInteractiveKeyboardDismiss()
    }

    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let fullName = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        errorMessage = await store.register(
            fullName: fullName,
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            birthDate: TregoNativeFormatting.storageDateString(from: birthDate),
            gender: gender
        ) ?? ""
    }
}

private struct TregoVerifyEmailView: View {
    @ObservedObject var store: TregoNativeAppStore
    @State private var email = ""
    @State private var code = ""
    @State private var statusMessage = ""
    @State private var isSubmitting = false
    @State private var isResending = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email
        case code
    }

    var body: some View {
        ScrollView {
            TregoAuthSheetCard {
                TregoAuthHeader(
                    title: "Verifiko Email-in",
                    subtitle: "Vendos kodin qe erdhi me email dhe vazhdo te kyqesh."
                )

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    .onSubmit {
                        focusedField = .code
                    }
                    .textFieldStyle(.roundedBorder)

                TextField("Kodi i verifikimit", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .submitLabel(.go)
                    .focused($focusedField, equals: .code)
                    .textFieldStyle(.roundedBorder)

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(statusMessageContainsError ? .red : TregoNativeTheme.accent)
                }

                Button {
                    Task { await submitVerification() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Verifiko email-in")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(TregoNativeTheme.accent)

                Button {
                    Task { await resendCode() }
                } label: {
                    if isResending {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Dergo kod te ri")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .tint(TregoNativeTheme.softAccent)

                Button("Back to log in") {
                    store.pendingEmailVerificationMessage = nil
                    store.authRoute = .login
                    store.accountAuthRoute = .login
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .padding(.bottom, 16)
        }
        .background(TregoNativeTheme.background.ignoresSafeArea())
        .tregoInteractiveKeyboardDismiss()
        .onAppear {
            syncFromStore()
        }
    }

    private var statusMessageContainsError: Bool {
        let normalized = statusMessage.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return normalized.contains("nuk") || normalized.contains("gabim") || normalized.contains("skaduar")
    }

    private func syncFromStore() {
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !store.pendingEmailVerificationEmail.isEmpty {
            email = store.pendingEmailVerificationEmail
        }
        if statusMessage.isEmpty, let pending = store.pendingEmailVerificationMessage, !pending.isEmpty {
            statusMessage = pending
        }
    }

    private func submitVerification() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if let message = await store.verifyEmail(email: trimmedEmail, code: trimmedCode) {
            statusMessage = message
        } else {
            statusMessage = ""
        }
    }

    private func resendCode() async {
        guard !isResending else { return }
        isResending = true
        defer { isResending = false }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let message = await store.resendEmailVerification(email: trimmedEmail) {
            statusMessage = message
        } else {
            statusMessage = store.pendingEmailVerificationMessage ?? "Kodi i verifikimit u dergua me sukses."
        }
    }
}

private struct TregoForgotPasswordView: View {
    @ObservedObject var store: TregoNativeAppStore
    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var hasRequestedCode = false
    @State private var errorMessage = ""
    @State private var isSubmitting = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email
        case code
        case newPassword
        case confirmPassword
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TregoAuthHeader(title: "RESET", subtitle: "Kerkoni kodin dhe vendosni fjalekalimin e ri.")

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .submitLabel(hasRequestedCode ? .next : .go)
                    .focused($focusedField, equals: .email)
                    .onSubmit {
                        if hasRequestedCode {
                            focusedField = .code
                        } else {
                            Task { await submit() }
                        }
                    }
                    .textFieldStyle(.roundedBorder)

                if hasRequestedCode {
                    TextField("Code", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .code)
                        .onSubmit {
                            focusedField = .newPassword
                        }
                        .textFieldStyle(.roundedBorder)

                    SecureField("New password", text: $newPassword)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .newPassword)
                        .onSubmit {
                            focusedField = .confirmPassword
                        }
                        .textFieldStyle(.roundedBorder)

                    SecureField("Confirm password", text: $confirmPassword)
                        .submitLabel(.go)
                        .focused($focusedField, equals: .confirmPassword)
                        .onSubmit {
                            Task { await submit() }
                        }
                        .textFieldStyle(.roundedBorder)
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(hasRequestedCode ? "Reset password" : "Send reset code")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(TregoNativeTheme.accent)

                Button("Back to log in") {
                    store.authRoute = .login
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(24)
            .padding(.bottom, 16)
        }
        .background(TregoNativeTheme.background.ignoresSafeArea())
        .tregoInteractiveKeyboardDismiss()
    }

    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        if hasRequestedCode {
            errorMessage = await store.confirmPasswordReset(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                code: code.trimmingCharacters(in: .whitespacesAndNewlines),
                newPassword: newPassword,
                confirmPassword: confirmPassword
            ) ?? ""
        } else {
            errorMessage = await store.requestPasswordReset(email: email.trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
            if errorMessage.isEmpty {
                hasRequestedCode = true
            }
        }
    }
}

private struct TregoAccountLoginPromptView: View {
    @ObservedObject var store: TregoNativeAppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var mode: AuthMode = .login
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var identifier = ""
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var birthDate = TregoNativeFormatting.defaultBirthDate
    @State private var gender = "femer"
    @State private var errorMessage = ""
    @State private var isSubmitting = false
    @State private var failedAttempts = 0
    @State private var passwordPrompt = "Password"
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case firstName
        case lastName
        case identifier
        case phoneNumber
        case password
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 10) {
                Text(mode == .login ? "Kyçuni" : "Regjistrohuni")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.92))
                    .frame(maxWidth: .infinity, alignment: .center)

                TregoHairlineDivider()
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                if mode == .signup {
                    authTextField(
                        text: $firstName,
                        prompt: "Emri",
                        textContentType: .givenName,
                        autocapitalization: .words,
                        disableAutocorrection: false,
                        focusedField: $focusedField,
                        equals: .firstName,
                        submitLabel: .next,
                        onSubmit: {
                            focusedField = .lastName
                        }
                    )

                    authTextField(
                        text: $lastName,
                        prompt: "Mbiemri",
                        textContentType: .familyName,
                        autocapitalization: .words,
                        disableAutocorrection: false,
                        focusedField: $focusedField,
                        equals: .lastName,
                        submitLabel: .next,
                        onSubmit: {
                            focusedField = .identifier
                        }
                    )
                }

                authTextField(
                    text: $identifier,
                    prompt: mode == .login ? "Email ose telefoni" : "Email",
                    keyboardType: mode == .login ? .default : .emailAddress,
                    textContentType: mode == .login ? .username : .emailAddress,
                    focusedField: $focusedField,
                    equals: .identifier,
                    submitLabel: .next,
                    onSubmit: {
                        if mode == .signup {
                            focusedField = .phoneNumber
                        } else {
                            focusedField = .password
                        }
                    }
                )

                if mode == .signup {
                    authTextField(
                        text: $phoneNumber,
                        prompt: "Numri i telefonit",
                        keyboardType: .phonePad,
                        textContentType: .telephoneNumber,
                        autocapitalization: .never,
                        focusedField: $focusedField,
                        equals: .phoneNumber,
                        submitLabel: .next,
                        onSubmit: {
                            focusedField = .password
                        }
                    )
                }

                authSecureField(
                    text: $password,
                    prompt: passwordPrompt,
                    textContentType: mode == .login ? .password : .newPassword,
                    highlighted: failedAttempts > 0 && password.isEmpty,
                    focusedField: $focusedField,
                    equals: .password,
                    submitLabel: .go,
                    onSubmit: {
                        Task { await submit() }
                    }
                )

                if mode == .signup {
                    TregoBirthDateGenderRow(
                        birthDate: $birthDate,
                        gender: $gender
                    )
                }
            }
            .onChange(of: password) { newValue in
                if !newValue.isEmpty && passwordPrompt != "Password" {
                    passwordPrompt = "Password"
                }
                clearFieldValidationState()
            }
            .onChange(of: identifier) { _ in
                clearFieldValidationState()
                if mode == .login {
                    failedAttempts = 0
                }
            }
            .onChange(of: firstName) { _ in
                if mode == .signup { clearFieldValidationState() }
            }
            .onChange(of: lastName) { _ in
                if mode == .signup { clearFieldValidationState() }
            }
            .onChange(of: phoneNumber) { _ in
                if mode == .signup { clearFieldValidationState() }
            }
            .onChange(of: birthDate) { _ in
                if mode == .signup { clearFieldValidationState() }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red)
            }

            if mode == .login && failedAttempts > 0 {
                Button("Keni harruar fjalëkalimin?") {
                    store.authRoute = .forgotPassword
                }
                .buttonStyle(.plain)
                .foregroundStyle(TregoNativeTheme.accent)
            }

            Button {
                Task { await submit() }
            } label: {
                HStack {
                    Spacer()
                    if isSubmitting {
                        ProgressView()
                            .tint(TregoNativeTheme.accent)
                    } else {
                        Text(mode == .login ? "Log in" : "Sign up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(colorScheme == .dark ? Color.orange.opacity(0.98) : TregoNativeTheme.accent)
                    }
                    Spacer()
                }
                .frame(height: 54)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(primaryButtonTint)
                        .allowsHitTesting(false)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(primaryButtonStroke, lineWidth: 0.95)
                        .allowsHitTesting(false)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Text(mode == .login ? "Nuk keni llogari akoma?" : "Keni llogari tashmë?")
                    .foregroundStyle(.secondary)

                Button(mode == .login ? "Sign up" : "Log in") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        mode = mode == .login ? .signup : .login
                        store.accountAuthRoute = mode == .login ? .login : .signup
                        errorMessage = ""
                        failedAttempts = 0
                        passwordPrompt = "Password"
                        password = ""
                        focusedField = mode == .signup ? .firstName : .identifier
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(colorScheme == .dark ? Color.orange.opacity(0.94) : TregoNativeTheme.accent)
            }
            .font(.system(size: 14, weight: .medium))

            TregoAuthSocialButtonsGroup(store: store)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.96),
                    TregoNativeTheme.cardSurface.opacity(colorScheme == .dark ? 0.96 : 0.9),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(cardStrokeColor, lineWidth: 0.9)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.28),
                            .clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.1), radius: 22, y: 14)
        .shadow(color: TregoNativeTheme.accent.opacity(colorScheme == .dark ? 0.12 : 0.08), radius: 12, y: 4)
        .onAppear {
            TregoNativeKeyboard.removeLegacyTapOutsideDismissRecognizers()
            syncModeFromStore()
        }
        .onChange(of: store.accountAuthRoute) { _ in
            syncModeFromStore()
        }
    }

    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        if mode == .login {
            let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedIdentifier.isEmpty, !password.isEmpty else {
                errorMessage = "Ploteso email ose telefon dhe password."
                passwordPrompt = "Password"
                return
            }

            let message = await store.login(
                identifier: trimmedIdentifier,
                password: password
            )
            if let message {
                handleLoginFailure(message)
            } else {
                failedAttempts = 0
                passwordPrompt = "Password"
                errorMessage = ""
            }
            return
        }

        let fullName = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        errorMessage = await store.register(
            fullName: fullName,
            email: identifier.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            birthDate: TregoNativeFormatting.storageDateString(from: birthDate),
            gender: gender
        ) ?? ""
    }

    private func clearFieldValidationState() {
        if errorMessage.contains("Ploteso") || errorMessage.contains("email") || errorMessage.contains("telefon") {
            errorMessage = ""
        }
    }

    private func handleLoginFailure(_ message: String) {
        let normalized = message.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if normalized.contains("fjalekalim") {
            failedAttempts += 1
            password = ""
            passwordPrompt = "Fjalëkalimi nuk është i saktë"
            errorMessage = ""
        } else {
            errorMessage = message
        }
    }

    private func syncModeFromStore() {
        let requestedMode: AuthMode = store.accountAuthRoute == .signup ? .signup : .login
        guard mode != requestedMode else { return }
        mode = requestedMode
        errorMessage = ""
        failedAttempts = 0
        passwordPrompt = "Password"
        password = ""
        focusedField = requestedMode == .signup ? .firstName : .identifier
    }

    private func authTextField(
        text: Binding<String>,
        prompt: String,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .never,
        disableAutocorrection: Bool = true,
        focusedField: FocusState<Field?>.Binding,
        equals: Field,
        submitLabel: SubmitLabel = .done,
        onSubmit: @escaping () -> Void = {}
    ) -> some View {
        HStack(spacing: 0) {
            TextField("", text: text, prompt: Text(prompt).foregroundColor(.secondary))
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(disableAutocorrection)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .submitLabel(submitLabel)
                .focused(focusedField, equals: equals)
                .onSubmit(onSubmit)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(colorScheme == .dark ? 0.96 : 0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(fieldStrokeColor, lineWidth: 0.9)
                .allowsHitTesting(false)
        }
    }

    private func authSecureField(
        text: Binding<String>,
        prompt: String,
        textContentType: UITextContentType?,
        highlighted: Bool,
        focusedField: FocusState<Field?>.Binding,
        equals: Field,
        submitLabel: SubmitLabel = .go,
        onSubmit: @escaping () -> Void = {}
    ) -> some View {
        HStack(spacing: 0) {
            SecureField("", text: text, prompt: Text(prompt).foregroundColor(highlighted ? .red.opacity(0.82) : .secondary))
                .textContentType(textContentType)
                .submitLabel(submitLabel)
                .focused(focusedField, equals: equals)
                .onSubmit(onSubmit)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(colorScheme == .dark ? 0.96 : 0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(highlighted ? Color.red.opacity(0.06) : .clear)
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(highlighted ? Color.red.opacity(0.36) : fieldStrokeColor, lineWidth: 0.9)
                .allowsHitTesting(false)
        }
    }

    private var fieldStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.52)
    }

    private var primaryButtonTint: Color {
        colorScheme == .dark ? Color.orange.opacity(0.18) : TregoNativeTheme.accent.opacity(0.16)
    }

    private var primaryButtonStroke: Color {
        colorScheme == .dark ? Color.orange.opacity(0.34) : TregoNativeTheme.accent.opacity(0.34)
    }

    private var cardStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color.white.opacity(0.46)
    }

    private enum AuthMode {
        case login
        case signup
    }
}

private struct TregoTopTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 24, weight: .bold))
            .lineSpacing(0)
            .foregroundStyle(Color.primary.opacity(0.9))
    }
}

private struct TregoSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 19, weight: .bold))
            .lineSpacing(0)
            .foregroundStyle(Color.primary.opacity(0.9))
    }
}

private struct TregoSettingsSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.0)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
            .tregoGlassRectBackground(cornerRadius: 28)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
            }
        }
    }
}

private struct TregoAccountDetailRow: View {
    let title: String
    let value: String
    let systemImage: String
    let helper: String

    private var trimmedValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasValue: Bool {
        !trimmedValue.isEmpty
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(TregoNativeTheme.accent)
                .frame(width: 36, height: 36)
                .tregoGlassCircleBackground()

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(hasValue ? trimmedValue : "Nuk eshte shtuar ende")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(hasValue ? TregoNativeTheme.primaryText : TregoNativeTheme.secondaryText)
                    .lineLimit(3)
                Text(helper)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(TregoNativeTheme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}

private struct TregoVisualSearchIcon: View {
    let symbolName: String

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.22, green: 0.82, blue: 0.84),
                        Color(red: 0.29, green: 0.56, blue: 0.98),
                        Color(red: 0.56, green: 0.45, blue: 0.98),
                        Color(red: 0.94, green: 0.48, blue: 0.77),
                        Color(red: 0.99, green: 0.73, blue: 0.38),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: Color(red: 0.29, green: 0.56, blue: 0.98).opacity(0.12), radius: 6, y: 2)
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
    }
}

private struct TregoAuthSocialButtonsGroup: View {
    @ObservedObject var store: TregoNativeAppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Capsule()
                    .fill(separatorColor)
                    .frame(height: 1)
                Text("Vazhdo me")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                Capsule()
                    .fill(separatorColor)
                    .frame(height: 1)
            }

            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            TregoAuthSocialActionButton(title: "Continue with Google", action: handleGoogleTap) {
                ZStack {
                    Circle()
                        .fill(googleBadgeFill)
                        .frame(width: 28, height: 28)
                    Text("G")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(googleBadgeText)
                }
            }

            TregoAuthSocialActionButton(title: "Continue with Facebook", action: handleFacebookTap) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.09, green: 0.39, blue: 0.88))
                        .frame(width: 28, height: 28)
                    Text("f")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.white)
                        .offset(y: 1)
                }
            }
        }
    }

    private var separatorColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.42)
    }

    private var googleBadgeFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color.white
    }

    private var googleBadgeText: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : Color(red: 0.24, green: 0.45, blue: 0.92)
    }

    private func handleGoogleTap() {
        store.globalMessage = "Google login UI u shtua, por backend-i ende nuk ka social auth endpoint per Google."
    }

    private func handleFacebookTap() {
        store.globalMessage = "Facebook login UI u shtua, por backend-i ende nuk ka social auth endpoint per Facebook."
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success:
            store.globalMessage = "Apple ID u verifikua, por backend-i ende nuk ka social auth endpoint per Apple Sign In."
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            store.globalMessage = error.localizedDescription
        }
    }
}

private struct TregoAuthSocialActionButton<Badge: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let action: () -> Void
    @ViewBuilder let badge: () -> Badge

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                badge()

                Text(title)
                    .font(.system(size: 15, weight: .semibold))

                Spacer()
            }
            .foregroundStyle(Color.primary.opacity(colorScheme == .dark ? 0.94 : 0.84))
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(fieldStrokeColor, lineWidth: 0.9)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
    }

    private var fieldStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.52)
    }
}

private struct TregoGuestCardView: View {
    let title: String
    let subtitle: String
    let primaryTitle: String
    let secondaryTitle: String
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button(action: onPrimary) {
                    Text(primaryTitle)
                        .frame(maxWidth: .infinity)
                }
                    .buttonStyle(TregoPrimaryButtonStyle())
                Button(action: onSecondary) {
                    Text(secondaryTitle)
                        .frame(maxWidth: .infinity)
                }
                    .buttonStyle(TregoSecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(.white.opacity(0.45), lineWidth: 0.8)
        }
        .padding(.top, 80)
    }
}

private struct TregoAuthenticationPromptOverlay: View {
    let prompt: TregoAuthenticationPrompt
    let onLogin: () -> Void
    let onSignup: () -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.black.opacity(colorScheme == .dark ? 0.48 : 0.22)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 18) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(TregoNativeTheme.accent)

                VStack(spacing: 8) {
                    Text(prompt.title)
                        .font(.system(size: 24, weight: .bold))
                        .multilineTextAlignment(.center)

                    Text(prompt.message)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                TregoHairlineDivider()

                HStack(spacing: 12) {
                    Button(action: onLogin) {
                        Text("Login")
                            .frame(maxWidth: .infinity)
                    }
                        .buttonStyle(TregoPrimaryButtonStyle())

                    Button(action: onSignup) {
                        Text("Sign up")
                            .frame(maxWidth: .infinity)
                    }
                        .buttonStyle(TregoSecondaryButtonStyle())
                }
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 22)
            .padding(.vertical, 26)
            .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.42), lineWidth: 0.85)
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct TregoAuthSupportButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "headphones")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(TregoNativeTheme.accent)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Customer Support")
    }
}

private struct TregoUserCard: View {
    let user: TregoSessionUser
    let isUploadingPhoto: Bool
    let onTakePhoto: () -> Void
    let onChooseFromLibrary: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
            HStack(spacing: 16) {
            ZStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    TregoNativeTheme.accent,
                                    TregoNativeTheme.softAccent,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    if let url = TregoAPIClient.imageURL(from: user.profileImagePath) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Image(systemName: "person.fill")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    if isUploadingPhoto {
                        Circle()
                            .fill(.black.opacity(0.2))
                        ProgressView()
                            .tint(.white)
                    }
                }
                .frame(width: 86, height: 86)
                .clipShape(Circle())

                Menu {
                    Button("Take photo", action: onTakePhoto)
                    Button("Choose from library", action: onChooseFromLibrary)
                } label: {
                    ZStack {
                        Circle()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.95) : Color.white)
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TregoNativeTheme.accent)
                    }
                    .frame(width: 30, height: 30)
                    .overlay {
                        Circle()
                            .strokeBorder(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.8), lineWidth: 0.8)
                    }
                    .shadow(color: TregoNativeTheme.accent.opacity(0.18), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .offset(x: 28, y: -28)
            }
            .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName ?? "Perdoruesi")
                    .font(.system(size: 20, weight: .bold))
                Text(user.email ?? "")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .tregoGlassRectBackground(cornerRadius: 30)
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(colorScheme == .dark ? .white.opacity(0.14) : .white.opacity(0.44), lineWidth: 0.8)
        }
    }

}

private struct TregoFeatureGridCard: View {
    let title: String
    let subtitle: String
    let icon: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(iconBackgroundColor)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(iconForegroundColor)
                    .shadow(color: iconForegroundColor.opacity(0.28), radius: 5, y: 2)
            }
            .frame(width: 32, height: 32)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 84, maxHeight: .infinity, alignment: .topLeading)
        .padding(9)
        .contentShape(Rectangle())
        .tregoGlassRectBackground(cornerRadius: 24)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.85)
        }
    }

    private var iconBackgroundColor: Color {
        let palette = iconPalette
        return colorScheme == .dark ? palette.darkBackground : palette.lightBackground
    }

    private var iconForegroundColor: Color {
        let palette = iconPalette
        return colorScheme == .dark ? palette.darkForeground : palette.lightForeground
    }

    private var iconPalette: (lightBackground: Color, lightForeground: Color, darkBackground: Color, darkForeground: Color) {
        if icon.contains("gear") || icon.contains("lock") {
            return (
                Color(red: 0.92, green: 0.94, blue: 1.0),
                Color(red: 0.28, green: 0.42, blue: 0.92),
                Color(red: 0.16, green: 0.22, blue: 0.36),
                Color(red: 0.68, green: 0.82, blue: 1.0)
            )
        }
        if icon.contains("shippingbox") || icon.contains("location") {
            return (
                Color(red: 0.92, green: 0.98, blue: 0.93),
                Color(red: 0.14, green: 0.62, blue: 0.28),
                Color(red: 0.12, green: 0.28, blue: 0.18),
                Color(red: 0.56, green: 0.92, blue: 0.64)
            )
        }
        if icon.contains("bell") || icon.contains("bubble") {
            return (
                Color(red: 1.0, green: 0.95, blue: 0.9),
                Color(red: 0.93, green: 0.5, blue: 0.14),
                Color(red: 0.34, green: 0.22, blue: 0.12),
                Color(red: 1.0, green: 0.8, blue: 0.48)
            )
        }
        if icon.contains("person") || icon.contains("key") {
            return (
                Color(red: 0.98, green: 0.92, blue: 0.95),
                Color(red: 0.82, green: 0.22, blue: 0.44),
                Color(red: 0.34, green: 0.12, blue: 0.2),
                Color(red: 1.0, green: 0.64, blue: 0.8)
            )
        }
        return (
            Color(red: 0.87, green: 0.93, blue: 1.0).opacity(0.92),
            Color(red: 0.24, green: 0.47, blue: 0.88),
            Color(red: 0.2, green: 0.28, blue: 0.4).opacity(0.78),
            Color(red: 0.66, green: 0.82, blue: 1.0)
        )
    }
}

private struct TregoFeatureLinkRow: View {
    let title: String
    let subtitle: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TregoNativeTheme.primaryText)
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TregoNativeTheme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(TregoNativeTheme.accentStrong)
        }
        .padding(18)
        .tregoGlassRectBackground(cornerRadius: 28)
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.85)
        }
    }
}

private struct TregoNoticeCard: View {
    let title: String
    let subtitle: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .tregoGlassRectBackground(cornerRadius: 28)
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.8)
        }
    }
}

private enum TregoStatusMessageTone {
    case success
    case error
    case info
}

private struct TregoStatusMessageCard: View {
    let message: String
    let tone: TregoStatusMessageTone
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .bold))
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .tregoGlassRectBackground(cornerRadius: 22)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(fillColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(strokeColor, lineWidth: 0.9)
        }
    }

    private var iconName: String {
        switch tone {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var foregroundColor: Color {
        switch tone {
        case .success:
            return colorScheme == .dark ? Color.green.opacity(0.92) : Color.green.opacity(0.82)
        case .error:
            return colorScheme == .dark ? Color.red.opacity(0.92) : Color.red.opacity(0.82)
        case .info:
            return colorScheme == .dark ? Color.blue.opacity(0.92) : Color.blue.opacity(0.8)
        }
    }

    private var fillColor: Color {
        switch tone {
        case .success: return Color.green.opacity(colorScheme == .dark ? 0.1 : 0.08)
        case .error: return Color.red.opacity(colorScheme == .dark ? 0.1 : 0.07)
        case .info: return Color.blue.opacity(colorScheme == .dark ? 0.1 : 0.07)
        }
    }

    private var strokeColor: Color {
        switch tone {
        case .success: return Color.green.opacity(colorScheme == .dark ? 0.3 : 0.22)
        case .error: return Color.red.opacity(colorScheme == .dark ? 0.32 : 0.22)
        case .info: return Color.blue.opacity(colorScheme == .dark ? 0.3 : 0.22)
        }
    }
}

private struct TregoPublicBusinessHeroCard: View {
    let business: TregoPublicBusinessProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Group {
                    if let url = TregoAPIClient.imageURL(from: business.logoPath) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                TregoBusinessAvatarView(name: business.businessName ?? "Tregio")
                            }
                        }
                    } else {
                        TregoBusinessAvatarView(name: business.businessName ?? "Tregio")
                    }
                }
                .frame(width: 76, height: 76)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(business.businessName ?? "Business")
                        .font(.system(size: 22, weight: .bold))
                    Text(business.businessDescription?.isEmpty == false ? (business.businessDescription ?? "") : "Ky eshte profili publik i biznesit ne TREGIO.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }

            HStack(spacing: 8) {
                if let status = business.verificationStatus, !status.isEmpty {
                    TregoMetaPill(text: status.capitalized)
                }
                if let city = business.city, !city.isEmpty {
                    TregoMetaPill(text: city)
                }
                if let phone = business.phoneNumber, !phone.isEmpty {
                    TregoMetaPill(text: phone)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.42), lineWidth: 0.8)
        }
    }
}

private struct TregoBusinessSellerCard: View {
    let businessName: String
    let location: String
    let actionTitle: String
    let secondaryTitle: String
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                TregoAvatarView(name: businessName)
                    .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(businessName)
                        .font(.system(size: 17, weight: .bold))
                    if !location.isEmpty {
                        Text(location)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button(actionTitle, action: onPrimary)
                    .buttonStyle(TregoSecondaryButtonStyle())
                Button(secondaryTitle, action: onSecondary)
                    .buttonStyle(TregoPrimaryButtonStyle())
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.42), lineWidth: 0.8)
        }
    }
}

private struct TregoPublicBusinessExplorerCard: View {
    let business: TregoPublicBusinessProfile
    let previewProducts: [TregoProduct]
    let isPreviewLoading: Bool
    let onOpen: () -> Void
    let onFollow: () -> Void
    let onMessage: () -> Void
    let onOpenProduct: (TregoProduct) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button(action: onOpen) {
                    HStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            Group {
                                if let logoPath = business.logoPath, !logoPath.isEmpty {
                                    TregoRemoteImage(imagePath: logoPath)
                                } else {
                                    TregoBusinessAvatarView(name: business.businessName ?? "Tregio")
                                }
                            }
                            .frame(width: 58, height: 58)
                            .clipShape(Circle())

                            if let badgeSymbol = verificationBadgeSymbol {
                                Image(systemName: badgeSymbol)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(verificationBadgeForeground)
                                    .frame(width: 22, height: 22)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .overlay {
                                        Circle()
                                            .strokeBorder(.white.opacity(0.4), lineWidth: 0.6)
                                    }
                                    .offset(x: 3, y: 3)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(business.businessName ?? "Biznes pa emer")
                                .font(.system(size: 17, weight: .bold))
                                .lineLimit(2)

                            if let city = business.city?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty {
                                Text(city)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Button(action: onMessage) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(TregoNativeTheme.accent, in: Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(TregoNativeTheme.accent.opacity(0.22), lineWidth: 0.8)
                            }
                    }
                    .buttonStyle(.plain)

                    if business.isFollowed == true {
                        Button("Following", action: onFollow)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 10)
                            .background(TregoNativeTheme.softAccent, in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(TregoNativeTheme.softAccent.opacity(0.24), lineWidth: 0.8)
                            }
                            .buttonStyle(.plain)
                    } else {
                        Button("Follow", action: onFollow)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 10)
                            .background(TregoNativeTheme.accent, in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(TregoNativeTheme.accent.opacity(0.24), lineWidth: 0.8)
                            }
                            .buttonStyle(.plain)
                    }
                }
            }

            if isPreviewLoading && previewProducts.isEmpty {
                TregoBusinessPreviewRailSkeleton()
            } else if !previewProducts.isEmpty {
                TregoAutoSlidingRail(
                    products: previewProducts,
                    itemWidth: 148,
                    itemSpacing: 12,
                    railHeight: 184
                ) { product in
                    TregoBusinessPreviewProductCard(
                        product: product,
                        onTap: { onOpenProduct(product) }
                    )
                    .frame(width: 148)
                }
            }
        }
        .padding(16)
        .tregoGlassRectBackground(cornerRadius: 28)
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.38), lineWidth: 0.8)
        }
    }

    private var verificationBadgeSymbol: String? {
        switch (business.verificationStatus ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "verified":
            return "checkmark.seal.fill"
        case "pending":
            return "clock.badge.checkmark.fill"
        case "rejected":
            return "xmark.seal.fill"
        default:
            return nil
        }
    }

    private var verificationBadgeForeground: Color {
        switch (business.verificationStatus ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "verified":
            return Color.green.opacity(0.94)
        case "pending":
            return Color.orange.opacity(0.94)
        case "rejected":
            return Color.red.opacity(0.94)
        default:
            return TregoNativeTheme.accent
        }
    }

    private var buttonStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.38)
    }

    private var messageIconColor: Color {
        colorScheme == .dark ? Color.orange.opacity(0.92) : TregoNativeTheme.softAccent
    }

    private var followFillColor: Color {
        colorScheme == .dark ? TregoNativeTheme.softAccent.opacity(0.26) : TregoNativeTheme.softAccent.opacity(0.18)
    }

    private var followBorderColor: Color {
        colorScheme == .dark ? TregoNativeTheme.softAccent.opacity(0.34) : TregoNativeTheme.softAccent.opacity(0.24)
    }

    private var followTextColor: Color {
        colorScheme == .dark ? Color.orange.opacity(0.95) : TregoNativeTheme.softAccent
    }

    private var followingTextColor: Color {
        colorScheme == .dark ? Color.primary.opacity(0.92) : Color.primary.opacity(0.82)
    }
}

private struct TregoBusinessAvatarView: View {
    let name: String

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        TregoNativeTheme.accent,
                        TregoNativeTheme.softAccent,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text(initials)
                        .font(.system(size: 12, weight: .black))
                        .tracking(0.4)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
            }
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
            }
    }

    private var initials: String {
        let bits = name
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
        return bits.isEmpty ? "TG" : bits.joined()
    }
}

private struct TregoBusinessPreviewProductCard: View {
    let product: TregoProduct
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                TregoRemoteImage(imagePath: product.imagePath)
                    .frame(height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                Text(product.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TregoNativeTheme.primaryText)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Text(TregoFormatting.price(product.price ?? 0))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(TregoNativeTheme.accent)
                    Spacer(minLength: 0)
                    TregoCompactRatingSummary(rating: product.averageRating ?? 0)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
            .padding(12)
            .tregoGlassRectBackground(cornerRadius: 24)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.42), lineWidth: 0.9)
            }
            .shadow(color: TregoNativeTheme.accent.opacity(0.08), radius: 10, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct TregoScreenGuestNotice: View {
    let title: String
    let subtitle: String

    var body: some View {
        TregoEmptyStateView(title: title, subtitle: subtitle)
            .padding(.top, 24)
    }
}

private struct TregoDeliveryOptionCard: View {
    let option: TregoDeliveryMethodOption
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(isSelected ? TregoNativeTheme.accent : Color.primary.opacity(0.72))
                .frame(width: 40, height: 40)
                .tregoGlassCircleBackground()

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(option.label ?? option.value.capitalized)
                        .font(.system(size: 16, weight: .semibold))
                    if let badge = option.badge, !badge.isEmpty {
                        TregoMetaPill(text: badge)
                    }
                }
                if let description = option.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text(TregoFormatting.price(option.shippingAmount ?? 0))
                        .font(.system(size: 13, weight: .bold))
                    if let eta = option.estimatedDeliveryText, !eta.isEmpty {
                        Text(eta)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isSelected ? TregoNativeTheme.accent : .secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(
                    isSelected
                    ? TregoNativeTheme.accent.opacity(colorScheme == .dark ? 0.42 : 0.3)
                    : Color.white.opacity(colorScheme == .dark ? 0.12 : 0.42),
                    lineWidth: 0.9
                )
        }
    }

    private var iconName: String {
        switch option.value {
        case "express": return "bolt.fill"
        case "pickup": return "storefront.fill"
        default: return "shippingbox.fill"
        }
    }
}

private struct TregoPaymentOptionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let isEnabled: Bool
    let badge: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isEnabled ? TregoNativeTheme.accent : Color.secondary)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                    if let badge, !badge.isEmpty {
                        TregoMetaPill(text: badge)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isSelected ? TregoNativeTheme.accent : .secondary)
        }
        .opacity(isEnabled ? 1 : 0.78)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(
                    isSelected
                    ? TregoNativeTheme.accent.opacity(colorScheme == .dark ? 0.42 : 0.3)
                    : Color.white.opacity(colorScheme == .dark ? 0.12 : 0.42),
                    lineWidth: 0.9
                )
        }
    }
}

private struct TregoApplePayOptionCard: View {
    let isSelected: Bool
    let isAvailable: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                TregoNativeApplePayButton(isEnabled: isAvailable, onTap: onTap)
                    .frame(width: 160, height: 34)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Pay")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primary)

                    Text(isAvailable
                         ? "Opsion native ne iPhone. Lidhja e pageses reale vjen me backend wiring."
                         : "Aktualisht nuk eshte aktiv ne kete pajisje ose ne Wallet.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? TregoNativeTheme.accent : .secondary)
            }
            .opacity(isAvailable ? 1 : 0.8)
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(
                        isSelected
                        ? TregoNativeTheme.accent.opacity(colorScheme == .dark ? 0.42 : 0.3)
                        : Color.white.opacity(colorScheme == .dark ? 0.12 : 0.42),
                        lineWidth: 0.9
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

private struct TregoNativeApplePayButton: UIViewRepresentable {
    let isEnabled: Bool
    let onTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: .automatic)
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleTap), for: .touchUpInside)
        button.isEnabled = isEnabled
        button.alpha = isEnabled ? 1 : 0.72
        return button
    }

    func updateUIView(_ uiView: PKPaymentButton, context: Context) {
        uiView.isEnabled = isEnabled
        uiView.alpha = isEnabled ? 1 : 0.72
    }

    final class Coordinator: NSObject {
        let onTap: () -> Void

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }

        @objc func handleTap() {
            onTap()
        }
    }
}

private struct TregoCheckoutSummaryCard: View {
    let pricing: TregoCheckoutPricing?
    let fallbackSubtotal: Double
    let cartItemsCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TregoCheckoutSummaryRow(label: "Artikuj", value: "\(cartItemsCount)")
            TregoCheckoutSummaryRow(label: "Nentotali", value: TregoFormatting.price(pricing?.subtotal ?? fallbackSubtotal))
            TregoCheckoutSummaryRow(label: "Zbritja", value: TregoFormatting.price(pricing?.discountAmount ?? 0))
            TregoCheckoutSummaryRow(label: "Transporti", value: TregoFormatting.price(pricing?.shippingAmount ?? 0))

            if let deliveryLabel = pricing?.deliveryLabel, !deliveryLabel.isEmpty {
                TregoCheckoutSummaryRow(label: "Dergesa", value: deliveryLabel)
            }

            if let eta = pricing?.estimatedDeliveryText, !eta.isEmpty {
                TregoCheckoutSummaryRow(label: "Afati", value: eta)
            }

            if let shippingRuleMessage = pricing?.shippingRuleMessage, !shippingRuleMessage.isEmpty {
                Text(shippingRuleMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            Divider()

            TregoCheckoutSummaryRow(
                label: "Totali",
                value: TregoFormatting.price(pricing?.total ?? fallbackSubtotal + (pricing?.shippingAmount ?? 0) - (pricing?.discountAmount ?? 0)),
                emphasized: true
            )

            if let notice = pricing?.deliveryNotice, !notice.isEmpty {
                Text(notice)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.42), lineWidth: 0.8)
        }
    }
}

private struct TregoCheckoutSummaryRow: View {
    let label: String
    let value: String
    var emphasized = false

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: emphasized ? 16 : 14, weight: emphasized ? .bold : .medium))
                .foregroundStyle(emphasized ? Color.primary.opacity(0.9) : .secondary)
            Spacer()
            Text(value)
                .font(.system(size: emphasized ? 18 : 14, weight: emphasized ? .bold : .semibold))
                .foregroundStyle(Color.primary.opacity(0.9))
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct TregoInfoTile: View {
    let title: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.88))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .tregoGlassRectBackground(cornerRadius: 22)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.8)
        }
    }
}

private struct TregoBusinessShippingSummaryCard: View {
    let settings: TregoBusinessShippingSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if settings.standardEnabled == true {
                    TregoMetaPill(text: "Standard")
                }
                if settings.expressEnabled == true {
                    TregoMetaPill(text: "Express")
                }
                if settings.pickupEnabled == true {
                    TregoMetaPill(text: "Pickup")
                }
            }

            TregoCheckoutSummaryRow(label: "Fee standard", value: TregoFormatting.price(settings.standardFee ?? 0))
            TregoCheckoutSummaryRow(label: "Fee express", value: TregoFormatting.price(settings.expressFee ?? 0))
            TregoCheckoutSummaryRow(label: "Pragu 50%", value: TregoFormatting.price(settings.halfOffThreshold ?? 0))
            TregoCheckoutSummaryRow(label: "Pragu falas", value: TregoFormatting.price(settings.freeShippingThreshold ?? 0))

            if let pickupAddress = settings.pickupAddress, !pickupAddress.isEmpty {
                TregoInfoTile(title: "Pickup address", value: pickupAddress)
            }
            if let pickupHours = settings.pickupHours, !pickupHours.isEmpty {
                TregoInfoTile(title: "Pickup hours", value: pickupHours)
            }

            if let cityRates = settings.cityRates, !cityRates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Qytetet me surcharge")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                    ForEach(cityRates) { rate in
                        TregoCheckoutSummaryRow(
                            label: rate.city,
                            value: TregoFormatting.price(rate.surcharge ?? 0)
                        )
                    }
                }
            }
        }
        .padding(18)
        .tregoGlassRectBackground(cornerRadius: 28)
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.42), lineWidth: 0.8)
        }
    }
}

private struct TregoProfileImageEditorCard: View {
    let title: String
    let subtitle: String
    let imagePath: String
    let upload: TregoImageSearchUpload?
    let onChoosePhoto: () -> Void
    let onRemovePhoto: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var canRemovePhoto: Bool {
        upload != nil || !imagePath.isEmpty
    }

    var body: some View {
        HStack(spacing: 16) {
            preview
                .frame(width: 86, height: 86)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Button("Zgjidh foton", action: onChoosePhoto)
                        .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.softAccent))

                    if canRemovePhoto {
                        Button("Hiqe foton", action: onRemovePhoto)
                            .buttonStyle(TregoMiniOutlineButtonStyle())
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.8)
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let upload, let image = UIImage(data: upload.data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if !imagePath.isEmpty {
            TregoRemoteImage(imagePath: imagePath)
        } else {
            TregoAvatarView(name: title)
        }
    }
}

private struct TregoProductImageEditorCard: View {
    let title: String
    let subtitle: String
    let imagePath: String
    let upload: TregoImageSearchUpload?
    let onChoosePhoto: () -> Void
    let onRemovePhoto: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            preview
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Button("Zgjidh foton", action: onChoosePhoto)
                        .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.softAccent))

                    if upload != nil || !imagePath.isEmpty {
                        Button("Hiqe", action: onRemovePhoto)
                            .buttonStyle(TregoMiniOutlineButtonStyle())
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.8)
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let upload, let image = UIImage(data: upload.data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            TregoRemoteImage(imagePath: imagePath)
        }
    }
}

private struct TregoDateInputCard: View {
    let title: String
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TregoBirthDateGenderRow: View {
    @Binding var birthDate: Date
    @Binding var gender: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            TregoDateInputCard(title: "Data e lindjes", date: $birthDate)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            TregoGenderPicker(selected: $gender)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

private struct TregoNotificationCard: View {
    let notification: TregoNotificationItem
    @Environment(\.colorScheme) private var colorScheme

    private var visualStyle: TregoNotificationVisualStyle {
        TregoNotificationVisualStyle(notification: notification)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                visualStyle.tint.opacity(0.96),
                                visualStyle.tint.opacity(0.68),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: visualStyle.symbolName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(notification.title?.isEmpty == false ? (notification.title ?? "") : "Njoftim")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(TregoNativeTheme.primaryText)
                            .lineLimit(2)

                        if let body = notification.body, !body.isEmpty {
                            Text(body)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(TregoNativeTheme.secondaryText)
                                .lineLimit(3)
                        }
                    }

                    Spacer(minLength: 0)

                    if notification.isRead != true {
                        Circle()
                            .fill(TregoNativeTheme.accent)
                            .frame(width: 9, height: 9)
                            .padding(.top, 6)
                    }
                }

                HStack(spacing: 8) {
                    Text(visualStyle.typeLabel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(visualStyle.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(visualStyle.tint.opacity(colorScheme == .dark ? 0.18 : 0.12), in: Capsule())

                    Text(TregoNativeFormatting.readableDateTime(notification.createdAt))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .tregoGlassRectBackground(cornerRadius: 26)
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.8)
        }
        .shadow(color: visualStyle.tint.opacity(colorScheme == .dark ? 0.12 : 0.08), radius: 12, y: 6)
    }
}

private struct TregoNotificationDetailSheet: View {
    let notification: TregoNotificationItem
    let onCancel: () -> Void
    let onOpen: () -> Void

    private var visualStyle: TregoNotificationVisualStyle {
        TregoNotificationVisualStyle(notification: notification)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        visualStyle.tint.opacity(0.96),
                                        visualStyle.tint.opacity(0.68),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Image(systemName: visualStyle.symbolName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(notification.title?.isEmpty == false ? (notification.title ?? "") : "Njoftim")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(TregoNativeTheme.primaryText)
                        HStack(spacing: 8) {
                            Text(visualStyle.typeLabel)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(visualStyle.tint)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(visualStyle.tint.opacity(0.12), in: Capsule())
                            Text(TregoNativeFormatting.readableDateTime(notification.createdAt))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let body = notification.body, !body.isEmpty {
                    Text(body)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(TregoNativeTheme.secondaryText)
                        .lineSpacing(3)
                }
            }
            .padding(18)
            .tregoGlassRectBackground(cornerRadius: 28)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(TregoSecondaryButtonStyle())
                Button("Shiko me shume", action: onOpen)
                    .buttonStyle(TregoPrimaryButtonStyle())
            }
        }
        .padding(18)
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Njoftimi")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TregoNotificationVisualStyle {
    let typeLabel: String
    let symbolName: String
    let tint: Color

    init(notification: TregoNotificationItem) {
        let normalizedType = (notification.type ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalizedType {
        case "message":
            typeLabel = "Mesazh"
            symbolName = "message.fill"
            tint = Color(red: 0.18, green: 0.58, blue: 0.98)
        case "order":
            typeLabel = "Porosi"
            symbolName = "bag.fill"
            tint = TregoNativeTheme.accent
        case "return":
            typeLabel = "Kthim"
            symbolName = "arrow.uturn.backward.circle.fill"
            tint = Color(red: 0.94, green: 0.42, blue: 0.22)
        case "verification":
            typeLabel = "Verifikim"
            symbolName = "checkmark.seal.fill"
            tint = Color(red: 0.16, green: 0.72, blue: 0.44)
        case "promotion":
            typeLabel = "Promo"
            symbolName = "sparkles"
            tint = Color(red: 0.84, green: 0.46, blue: 0.98)
        default:
            typeLabel = "Njoftim"
            symbolName = notification.isRead == true ? "bell.fill" : "bell.badge.fill"
            tint = TregoNativeTheme.accent
        }
    }
}

private struct TregoReturnRequestCard: View {
    let request: TregoReturnRequest
    let canManage: Bool
    let isUpdating: Bool
    let onUpdate: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                TregoRemoteImage(imagePath: request.productImagePath)
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(request.productTitle?.isEmpty == false ? (request.productTitle ?? "") : "Produkt")
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(2)
                    Text(TregoNativeFormatting.returnStatusLabel(request.status))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(TregoNativeTheme.accent)
                    Text(TregoNativeFormatting.readableDate(request.createdAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            TregoInfoTile(title: "Arsyeja", value: request.reason?.isEmpty == false ? (request.reason ?? "") : "-")

            if let details = request.details, !details.isEmpty {
                TregoInfoTile(title: "Detajet", value: details)
            }

            if let notes = request.resolutionNotes, !notes.isEmpty {
                TregoInfoTile(title: "Vendimi", value: notes)
            }

            if canManage {
                if isUpdating {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                } else {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Button("Aprovo") { onUpdate("approved") }
                                .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.softAccent))
                            Button("Pranuar") { onUpdate("received") }
                                .buttonStyle(TregoMiniOutlineButtonStyle())
                        }
                        HStack(spacing: 10) {
                            Button("Rimburso") { onUpdate("refunded") }
                                .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.accent))
                            Button("Refuzo") { onUpdate("rejected") }
                                .buttonStyle(TregoMiniOutlineButtonStyle())
                        }
                    }
                }
            }
        }
        .padding(16)
        .tregoGlassRectBackground(cornerRadius: 28)
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.8)
        }
    }
}

private struct TregoSettingsSelectionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let currentValue: String
    let options: [(String, String)]
    let onSelect: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TregoNativeTheme.accentStrong)
                .frame(width: 40, height: 40)
                .background(TregoNativeTheme.accentBadgeSurface, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TregoNativeTheme.primaryText)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TregoNativeTheme.secondaryText)
            }

            Spacer()

            Menu {
                ForEach(options, id: \.0) { option in
                    Button(option.1) {
                        onSelect(option.0)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(currentValue)
                        .font(.system(size: 13, weight: .bold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(TregoNativeTheme.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .tregoGlassCapsuleBackground()
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.8)
        }
    }
}

private struct TregoMiniStatItem: Identifiable {
    let label: String
    let value: String
    let icon: String

    var id: String { label }
}

private struct TregoBusinessStatsRow: View {
    let items: [TregoMiniStatItem]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: item.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(TregoNativeTheme.accent)
                        Text(item.value)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Text(item.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}

private struct TregoMiniStatsGrid: View {
    let items: [TregoMiniStatItem]

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: item.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TregoNativeTheme.accent)
                    Text(item.value)
                        .font(.system(size: 20, weight: .bold))
                    Text(item.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }
}

private struct TregoBusinessProfileCard: View {
    let profile: TregoBusinessProfile?
    let fallbackName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Group {
                    if let url = TregoAPIClient.imageURL(from: profile?.logoPath) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                TregoAvatarView(name: profile?.businessName ?? fallbackName ?? "Tregio")
                            }
                        }
                    } else {
                        TregoAvatarView(name: profile?.businessName ?? fallbackName ?? "Tregio")
                    }
                }
                .frame(width: 62, height: 62)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile?.businessName ?? fallbackName ?? "Business Studio")
                        .font(.system(size: 20, weight: .bold))
                    Text(profile?.businessDescription ?? "Menaxho produktet, porosite dhe profilin e biznesit nga iPhone.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            HStack(spacing: 8) {
                TregoMetaPill(text: profile?.verificationStatus?.capitalized ?? "Locked")
                if let city = profile?.city, !city.isEmpty {
                    TregoMetaPill(text: city)
                }
                if let rating = profile?.sellerRating, rating > 0 {
                    TregoMetaPill(text: String(format: "%.1f ★", rating))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.4), lineWidth: 0.8)
        }
    }
}

private struct TregoPromotionRow: View {
    let promotion: TregoPromotion

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(TregoNativeTheme.accent)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.8), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(promotion.code ?? promotion.title ?? "Promotion")
                    .font(.system(size: 16, weight: .semibold))
                Text(promotion.description ?? "Pa pershkrim shtese.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            TregoMetaPill(text: promotion.isActive == true ? "Active" : "Paused")
        }
        .padding(16)
        .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

private struct TregoPromotionManagementRow: View {
    let promotion: TregoPromotion
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TregoPromotionRow(promotion: promotion)

            HStack(spacing: 8) {
                TregoMetaPill(text: promotion.discountType == "fixed" ? "€\(Int((promotion.discountValue ?? 0).rounded()))" : "\(Int((promotion.discountValue ?? 0).rounded()))%")
                if let start = promotion.startsAt, !start.isEmpty {
                    TregoMetaPill(text: TregoNativeFormatting.readableDate(start))
                }
                if let end = promotion.endsAt, !end.isEmpty {
                    TregoMetaPill(text: "Deri \(TregoNativeFormatting.readableDate(end))")
                }
            }

            HStack(spacing: 10) {
                Button("Edito", action: onEdit)
                    .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.softAccent))
                Button("Fshij", action: onDelete)
                    .buttonStyle(TregoMiniOutlineButtonStyle())
            }
        }
        .padding(16)
        .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

private struct TregoLaunchAdManagementRow: View {
    let launchAd: TregoLaunchAd
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                TregoRemoteImage(imagePath: launchAd.imagePath)
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(primaryBadge)
                        .font(.system(size: 11, weight: .black))
                        .textCase(.uppercase)
                        .foregroundStyle(TregoNativeTheme.accent)

                    Text(launchAd.title ?? "Launch ad")
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(2)

                    Text(launchAd.subtitle ?? "Pa pershkrim shtese.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                TregoMetaPill(text: launchAd.isActive == true ? "Active" : "Paused")
                TregoMetaPill(text: "#\(launchAd.sortOrder ?? 0)")
                if let startsAt = launchAd.startsAt, !startsAt.isEmpty {
                    TregoMetaPill(text: "Nga \(TregoNativeFormatting.readableDate(startsAt))")
                }
                if let endsAt = launchAd.endsAt, !endsAt.isEmpty {
                    TregoMetaPill(text: "Deri \(TregoNativeFormatting.readableDate(endsAt))")
                }
            }

            HStack(spacing: 10) {
                Button("Edito", action: onEdit)
                    .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.softAccent))
                Button("Fshij", action: onDelete)
                    .buttonStyle(TregoMiniOutlineButtonStyle())
            }
        }
        .padding(16)
        .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var primaryBadge: String {
        let trimmed = launchAd.badge?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "TREGIO Promo" : trimmed
    }
}

private struct TregoAdminUserRow: View {
    let user: TregoAdminUser

    var body: some View {
        HStack(spacing: 12) {
            TregoAvatarView(name: user.fullName ?? user.email ?? "User")
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName ?? "Pa emer")
                    .font(.system(size: 16, weight: .semibold))
                Text(user.email ?? "-")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    if let genderLabel = genderLabel {
                        TregoMetaPill(text: genderLabel)
                    }
                    if let orders = user.ordersCount, orders > 0 {
                        TregoMetaPill(text: "\(orders) porosi")
                    }
                    if user.isEmailVerified == true {
                        TregoMetaPill(text: "Verified")
                    }
                }
            }

            Spacer()

            TregoMetaPill(text: user.role?.capitalized ?? "Client")
        }
        .padding(16)
        .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var genderLabel: String? {
        switch (user.gender ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "mashkull", "male":
            return "Mashkull"
        case "femer", "female":
            return "Femer"
        default:
            return nil
        }
    }
}

private struct TregoAdminUserManagementRow: View {
    let user: TregoAdminUser
    let onRole: (String) -> Void
    let onPassword: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TregoAdminUserRow(user: user)

            HStack(spacing: 10) {
                Menu {
                    Button("Client") { onRole("client") }
                    Button("Business") { onRole("business") }
                    Button("Admin") { onRole("admin") }
                } label: {
                    Label("Ndrysho rolin", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(TregoMiniOutlineButtonStyle())

                Button("Fjalekalim", action: onPassword)
                    .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.softAccent))

                Button("Fshij", action: onDelete)
                    .buttonStyle(TregoMiniOutlineButtonStyle())
            }
        }
        .padding(16)
        .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

private struct TregoAdminBusinessRow: View {
    let business: TregoAdminBusiness
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onVerify: () -> Void
    let onReject: () -> Void
    let onUnlockEdit: () -> Void
    let onLockEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(business.businessName ?? "Biznes pa emer")
                        .font(.system(size: 17, weight: .semibold))
                    Text("\(business.ownerName ?? "-") · \(business.ownerEmail ?? "-")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                TregoMetaPill(text: business.verificationStatus?.capitalized ?? "Locked")
            }

            HStack(spacing: 8) {
                TregoMetaPill(text: "\(business.productsCount ?? 0) produkte")
                TregoMetaPill(text: "\(business.ordersCount ?? 0) porosi")
                if let city = business.city, !city.isEmpty {
                    TregoMetaPill(text: city)
                }
            }

            HStack(spacing: 10) {
                Button("Verifiko", action: onVerify)
                    .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.softAccent))
                Button("Refuzo", action: onReject)
                    .buttonStyle(TregoMiniOutlineButtonStyle())
            }

            HStack(spacing: 10) {
                Button("Detaje", action: onOpen)
                    .buttonStyle(TregoMiniOutlineButtonStyle())
                Button("Edito", action: onEdit)
                    .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.softAccent))
                Button("Lejo editim", action: onUnlockEdit)
                    .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.accent))
                Button("Mbyll editimin", action: onLockEdit)
                    .buttonStyle(TregoMiniOutlineButtonStyle())
            }
        }
        .padding(16)
        .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

private struct TregoAdminReportRow: View {
    let report: TregoAdminReport
    let onReviewing: () -> Void
    let onResolve: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.targetLabel ?? "Objekt i raportuar")
                        .font(.system(size: 16, weight: .semibold))
                    Text(report.reason ?? report.targetType ?? "Report")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                TregoMetaPill(text: report.status?.capitalized ?? "Open")
            }

            if let details = report.details, !details.isEmpty {
                Text(details)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.78))
            }

            HStack(spacing: 10) {
                Button("Reviewing", action: onReviewing)
                    .buttonStyle(TregoMiniOutlineButtonStyle())
                Button("Resolved", action: onResolve)
                    .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.accent))
            }
        }
        .padding(16)
        .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

private struct TregoMetaPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.primary.opacity(0.76))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.76), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.34), lineWidth: 0.7)
            }
    }
}

private struct TregoSavedProductRow: View {
    let product: TregoProduct
    let buttonTitle: String
    let buttonTint: Color
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    let secondaryTitle: String

    var body: some View {
        HStack(spacing: 14) {
            TregoRemoteImage(imagePath: product.imagePath)
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(product.title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                Text(TregoFormatting.price(product.price ?? 0))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(buttonTint)
                HStack(spacing: 10) {
                    Button(buttonTitle, action: onPrimary)
                        .buttonStyle(TregoMiniButtonStyle(tint: buttonTint))
                    Button(secondaryTitle, action: onSecondary)
                        .buttonStyle(TregoMiniOutlineButtonStyle())
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .tregoGlassRectBackground(cornerRadius: 28)
    }
}

private struct TregoBusinessManagedProductRow: View {
    let product: TregoProduct
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onToggleVisibility: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            TregoRemoteImage(imagePath: product.imagePath)
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(product.title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)

                Text(TregoFormatting.price(product.price ?? 0))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TregoNativeTheme.accent)

                HStack(spacing: 8) {
                    TregoMetaPill(text: product.isPublic == true ? "Publik" : "Privat")
                    if let stockQuantity = product.stockQuantity {
                        TregoMetaPill(text: "Stok \(stockQuantity)")
                    }
                }

                HStack(spacing: 8) {
                    Button("Hape", action: onOpen)
                        .buttonStyle(TregoMiniOutlineButtonStyle())
                    Button("Edito", action: onEdit)
                        .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.softAccent))
                    Button(product.isPublic == true ? "Fsheh" : "Publiko", action: onToggleVisibility)
                        .buttonStyle(TregoMiniOutlineButtonStyle())
                    Button("Fshij", action: onDelete)
                        .buttonStyle(TregoMiniOutlineButtonStyle())
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct TregoCustomerOrderCard: View {
    let order: TregoOrderItem
    let onReturn: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TregoOrderCard(order: order)

            if let trackingCode = order.trackingCode, !trackingCode.isEmpty {
                TregoInfoTile(title: "Tracking", value: trackingCode)
            }

            if let onReturn {
                Button("Kerko kthim", action: onReturn)
                    .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.accent))
            }
        }
        .padding(16)
        .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct TregoOrderManagementCard: View {
    let order: TregoOrderItem
    let managerLabel: String?
    let onUpdate: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                TregoRemoteImage(imagePath: order.imagePath)
                    .frame(width: 82, height: 82)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(order.title?.isEmpty == false ? (order.title ?? "") : "Artikull porosie")
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(2)
                    Text(TregoFormatting.price(order.totalPrice ?? order.totalAmount ?? 0))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(TregoNativeTheme.accent)
                    Text(TregoNativeFormatting.fulfillmentStatusLabel(order.fulfillmentStatus ?? order.status))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                    if let managerLabel, !managerLabel.isEmpty {
                        Text(managerLabel)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(TregoNativeTheme.softAccent)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                if let delivery = order.deliveryLabel, !delivery.isEmpty {
                    TregoMetaPill(text: delivery)
                }
                if let payment = order.paymentMethod, !payment.isEmpty {
                    TregoMetaPill(text: payment.capitalized)
                }
                if let quantity = order.quantity, quantity > 0 {
                    TregoMetaPill(text: "x\(quantity)")
                }
            }

            if let customer = order.customerName, !customer.isEmpty {
                TregoInfoTile(title: "Klienti", value: customer)
            }

            if let address = order.addressLine, !address.isEmpty {
                TregoInfoTile(title: "Adresa", value: [address, order.city, order.country].compactMap { value in
                    guard let value, !value.isEmpty else { return nil }
                    return value
                }.joined(separator: ", "))
            }

            if let trackingCode = order.trackingCode, !trackingCode.isEmpty {
                TregoInfoTile(title: "Tracking", value: trackingCode)
            }

            if let onUpdate {
                Button("Perditeso statusin", action: onUpdate)
                    .buttonStyle(TregoPrimaryButtonStyle(tint: TregoNativeTheme.softAccent))
            }
        }
        .padding(16)
        .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct TregoCartRow: View {
    let item: TregoCartItem
    let isSelected: Bool
    let isUpdatingQuantity: Bool
    let onToggleSelection: () -> Void
    let onDecreaseQuantity: () -> Void
    let onIncreaseQuantity: () -> Void
    let onRemove: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggleSelection) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isSelected ? TregoNativeTheme.accent : .secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            TregoRemoteImage(imagePath: item.imagePath)
                .frame(width: 78, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)

                if let variantLabel = item.variantLabel, !variantLabel.isEmpty {
                    Text(variantLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(TregoFormatting.price(item.price ?? 0))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(TregoNativeTheme.accent)

                    if let compareAt = item.compareAtPrice, compareAt > (item.price ?? 0) {
                        TregoComparePriceText(
                            value: TregoFormatting.price(compareAt),
                            font: .system(size: 11, weight: .semibold)
                        )
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 6) {
                        Button(action: onDecreaseQuantity) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 24, height: 24)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled((item.quantity ?? 1) <= 1 || isUpdatingQuantity)
                        .opacity(((item.quantity ?? 1) <= 1 || isUpdatingQuantity) ? 0.45 : 1)

                        if isUpdatingQuantity {
                            ProgressView()
                                .frame(width: 22, height: 22)
                        } else {
                            Text("\(item.quantity ?? 1)")
                                .font(.system(size: 12, weight: .bold))
                                .frame(minWidth: 16)
                        }

                        Button(action: onIncreaseQuantity) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 24, height: 24)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isUpdatingQuantity)
                        .opacity(isUpdatingQuantity ? 0.45 : 1)
                    }
                }

                if savingsAmount > 0 {
                    Text("Kursen \(TregoFormatting.price(savingsAmount))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.green.opacity(0.92))
                }
            }

            Spacer(minLength: 0)

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .bold))
                .foregroundStyle(colorScheme == .dark ? Color.red.opacity(0.94) : Color.red.opacity(0.82))
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.red.opacity(colorScheme == .dark ? 0.3 : 0.2), lineWidth: 0.8)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var savingsAmount: Double {
        max(0, ((item.compareAtPrice ?? 0) - (item.price ?? 0)) * Double(item.quantity ?? 1))
    }
}

private struct TregoCartStickySummaryCard<CheckoutDestination: View>: View {
    let selectedItemsCount: Int
    let subtotal: Double
    let itemSavings: Double
    let checkoutDiscount: Double
    let shippingAmount: Double
    let totalAmount: Double
    let isLoading: Bool
    let isCheckoutEnabled: Bool
    let checkoutDestination: CheckoutDestination

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Totali")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(TregoFormatting.price(totalAmount))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(TregoNativeTheme.accent)
                }

                Spacer(minLength: 0)

                if savedAmount > 0 {
                    Text("Saved \(TregoFormatting.price(savedAmount))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.green.opacity(0.94))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.green.opacity(0.16), lineWidth: 0.8)
                        }
                }
            }

            VStack(spacing: 6) {
                TregoCheckoutSummaryRow(label: "Produktet", value: "\(selectedItemsCount)")
                if subtotal > 0 {
                    TregoCheckoutSummaryRow(label: "Nentotali", value: TregoFormatting.price(subtotal))
                }
                if savedAmount > 0 {
                    TregoCheckoutSummaryRow(label: "Kursimi", value: TregoFormatting.price(itemSavings + checkoutDiscount))
                }
                TregoCheckoutSummaryRow(label: "Transporti", value: TregoFormatting.price(shippingAmount))
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }

            NavigationLink(destination: checkoutDestination) {
                Label(isCheckoutEnabled ? "Vazhdo ne checkout" : "Selekto produkte", systemImage: "creditcard.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TregoPrimaryButtonStyle())
            .disabled(!isCheckoutEnabled)
            .opacity(isCheckoutEnabled ? 1 : 0.55)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.42), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
    }

    private var savedAmount: Double {
        itemSavings + checkoutDiscount
    }
}

private struct TregoOrderCard: View {
    let order: TregoOrderItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("#\(order.id)")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                Text(TregoNativeFormatting.fulfillmentStatusLabel(order.fulfillmentStatus ?? order.status))
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(TregoNativeTheme.softAccent, in: Capsule())
                    .foregroundStyle(.white)
            }

            Text(TregoFormatting.price(order.totalPrice ?? order.totalAmount ?? 0))
                .font(.system(size: 22, weight: .bold))

            if let delivery = order.deliveryLabel, !delivery.isEmpty {
                Text(delivery)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let eta = order.estimatedDeliveryText, !eta.isEmpty {
                Text(eta)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .tregoGlassRectBackground(cornerRadius: 28)
    }
}

private struct TregoConversationRow: View {
    let conversation: TregoConversation

    var body: some View {
        HStack(spacing: 14) {
            TregoAvatarView(name: conversation.counterpartName ?? conversation.businessName ?? "T")
                .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.counterpartName ?? conversation.businessName ?? "Conversation")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TregoNativeTheme.primaryText)
                Text(conversation.lastMessagePreview ?? "Nuk ka mesazh ende")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TregoNativeTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                if let timestamp = conversation.lastMessageAt, !timestamp.isEmpty {
                    Text(TregoNativeFormatting.readableMessageTime(timestamp))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TregoNativeTheme.secondaryText)
                }

                if let unread = conversation.unreadCount, unread > 0 {
                    Text(String(unread))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(TregoNativeTheme.accent, in: Circle())
                }
            }
        }
        .padding(14)
        .tregoGlassRectBackground(cornerRadius: 28)
    }
}

private struct TregoMessageBubble: View {
    let message: TregoChatMessage
    let businessName: String?
    let businessProfileId: Int?
    let onOpenBusiness: (Int) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onOpenURL: (URL) -> Void

    var body: some View {
        HStack {
            if message.isOwn == true {
                Spacer(minLength: 48)
            }

            VStack(alignment: .leading, spacing: 6) {
                if message.isOwn != true {
                    if let sender = message.senderName, !sender.isEmpty {
                        Text(sender)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    } else if let businessName, !businessName.isEmpty {
                        Text(businessName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                if isDeleted {
                    if #available(iOS 16.0, *) {
                        Text("Ky mesazh u fshi.")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        // Fallback on earlier versions
                    };if #available(iOS 16.0, *) {
                        Text("Ky mesazh u fshi.")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        // Fallback on earlier versions
                    }
                } else {
                    if let attachmentURL {
                        if isImageAttachment {
                            Button {
                                onOpenURL(attachmentURL)
                            } label: {
                                TregoRemoteImage(imagePath: message.attachmentPath)
                                    .frame(width: 220, height: 168)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                onOpenURL(attachmentURL)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: attachmentSymbolName)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(TregoNativeTheme.accent)
                                        .frame(width: 38, height: 38)
                                        .background(Color.white.opacity(0.32), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(message.attachmentFileName ?? (isVideoAttachment ? "Video" : "File"))
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text(isVideoAttachment ? "Hape videon" : "Hape file-in")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer(minLength: 0)
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let body = visibleBody, !body.isEmpty {
                        Text(body)
                            .font(.system(size: 15, weight: .medium))
                    }

                    if let detectedURL, shouldShowLinkButton {
                        Button {
                            onOpenURL(detectedURL)
                        } label: {
                            Label("Hape linkun", systemImage: "link")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(TregoNativeTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 8) {
                    if message.isOwn == true {
                        Text(deliveryStatusLabel)
                    }
                    if !isDeleted && !(message.editedAt ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Edited")
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(messageBubbleBackground)
            .contextMenu {
                if canEditFromContextMenu {
                    Button("Edito") {
                        onEdit()
                    }
                }
                if canDeleteFromContextMenu {
                    Button("Fshij", role: .destructive) {
                        onDelete()
                    }
                }
            }

            if message.isOwn != true {
                Spacer(minLength: 48)
            }
        }
    }

    @ViewBuilder
    private var messageBubbleBackground: some View {
        let bubbleShape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        if message.isOwn == true {
            bubbleShape
                .fill(
                    LinearGradient(
                        colors: [
                            TregoNativeTheme.accent.opacity(0.22),
                            TregoNativeTheme.accent.opacity(0.1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            bubbleShape
                .fill(TregoNativeTheme.cardFill)
        }
    }

    private var visibleBody: String? {
        let trimmed = (message.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var isDeleted: Bool {
        !(message.deletedAt ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var attachmentURL: URL? {
        TregoAPIClient.imageURL(from: message.attachmentPath)
    }

    private var isImageAttachment: Bool {
        (message.attachmentContentType ?? "").lowercased().hasPrefix("image/")
    }

    private var isVideoAttachment: Bool {
        (message.attachmentContentType ?? "").lowercased().hasPrefix("video/")
    }

    private var attachmentSymbolName: String {
        if isVideoAttachment {
            return "play.rectangle.fill"
        }
        return "doc.fill"
    }

    private var detectedURL: URL? {
        guard let body = visibleBody else { return nil }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(location: 0, length: body.utf16.count)
        return detector.firstMatch(in: body, options: [], range: range)?.url
    }

    private var shouldShowLinkButton: Bool {
        detectedURL != nil && attachmentURL == nil
    }

    private var canEditFromContextMenu: Bool {
        message.isOwn == true
            && !isDeleted
            && !(message.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canDeleteFromContextMenu: Bool {
        message.isOwn == true && !isDeleted
    }

    private var deliveryStatusLabel: String {
        if message.localDeliveryState == .sending {
            return "Sending"
        }
        return (message.readAt ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Sent" : "Seen"
    }
}

private struct TregoReviewCard: View {
    let review: TregoProductReview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(review.authorName ?? "Perdorues")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(String(review.rating ?? 0))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(TregoNativeTheme.accent)
            }
            if let title = review.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
            }
            if let body = review.body, !body.isEmpty {
                Text(body)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tregoGlassRectBackground(cornerRadius: 24)
    }
}

private struct TregoReviewRatingPicker: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    rating = value
                } label: {
                    Image(systemName: value <= rating ? "star.fill" : "star")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(value <= rating ? TregoNativeTheme.accent : .secondary)
                        .frame(width: 40, height: 40)
                        .tregoGlassCircleBackground()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct TregoProductCard: View {
    let product: TregoProduct
    let isWishlisted: Bool
    let onTap: () -> Void
    let onOpenBusiness: () -> Void
    let onWishlist: () -> Void
    let onAddToCart: () -> Void

    private let imageHeight: CGFloat = 126
    private let titleHeight: CGFloat = 34
    private let businessHeight: CGFloat = 16
    private let metaHeight: CGFloat = 16
    private let cardHeight: CGFloat = 232
    private let imageCornerRadius: CGFloat = 12
    private let cardCornerRadius: CGFloat = TregoNativeTheme.cardRadius
    private let iconButtonSize: CGFloat = 30
    private let iconSize: CGFloat = 12.5
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .top) {
                Button(action: onTap) {
                    TregoRemoteImage(
                        imagePath: product.imagePath,
                        targetSize: CGSize(width: 320, height: imageHeight * 2)
                    )
                        .frame(height: imageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)

                HStack {
                    Button(action: onWishlist) {
                        Image(systemName: isWishlisted ? "heart.fill" : "heart")
                            .font(.system(size: iconSize, weight: .bold))
                            .foregroundStyle(isWishlisted ? Color.red : Color.primary)
                            .frame(width: iconButtonSize, height: iconButtonSize)
                            .background(TregoNativeTheme.cardSurface, in: Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(TregoNativeTheme.border, lineWidth: 0.8)
                            }
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    Button(action: onAddToCart) {
                        Image(systemName: "cart.badge.plus")
                            .font(.system(size: iconSize, weight: .bold))
                            .foregroundStyle(TregoNativeTheme.accent)
                            .frame(width: iconButtonSize, height: iconButtonSize)
                            .background(TregoNativeTheme.cardSurface, in: Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(TregoNativeTheme.border, lineWidth: 0.8)
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if isSaleProduct {
                        Text("Sale")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red, in: Capsule())
                    }

                    Text(product.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, minHeight: titleHeight, alignment: .topLeading)

                if let businessName = product.businessName, !businessName.isEmpty, product.businessProfileId != nil {
                    Button(action: onOpenBusiness) {
                        Text(businessName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .frame(height: businessHeight, alignment: .leading)
                } else {
                    Color.clear
                        .frame(height: businessHeight)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(TregoFormatting.price(product.price ?? 0))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(TregoNativeTheme.accent)
                    if let compareAt = product.compareAtPrice, compareAt > (product.price ?? 0) {
                        TregoComparePriceText(
                            value: TregoFormatting.price(compareAt),
                            font: .system(size: 12, weight: .semibold)
                        )
                    }
                }

                HStack(spacing: 8) {
                    Text("\(product.buyersCount ?? 0) shitje")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 12)

                    TregoCompactRatingSummary(rating: product.averageRating ?? 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: metaHeight + 14, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .topLeading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(TregoNativeTheme.cardSurface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .strokeBorder(TregoNativeTheme.border, lineWidth: 0.9)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.0 : 0.04), radius: 4, y: 2)
    }

    private var isSaleProduct: Bool {
        let price = product.price ?? 0
        let compareAt = product.compareAtPrice ?? 0
        return compareAt > price && price > 0
    }
}

private struct TregoProductStickyActionBar: View {
    let isWishlisted: Bool
    let canMessage: Bool
    let onWishlist: () -> Void
    let onMessage: () -> Void
    let onAddToCart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onWishlist) {
                Image(systemName: isWishlisted ? "heart.fill" : "heart")
                    .font(.system(size: 19, weight: .bold))
                    .frame(width: 50, height: 50)
            }
            .buttonStyle(TregoMiniIconButtonStyle())

            Button(action: onMessage) {
                Image(systemName: "message.fill")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 50, height: 50)
            }
            .buttonStyle(TregoMiniIconButtonStyle())
            .disabled(!canMessage)
            .opacity(canMessage ? 1 : 0.45)

            Button(action: onAddToCart) {
                Label("Add to cart", systemImage: "cart.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TregoPrimaryButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 380)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.34), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.1), radius: 16, y: 8)
    }
}

private enum TregoHomeCollectionKind: String, Identifiable {
    case trending
    case sale
    case forYou

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trending:
            return "Trending"
        case .sale:
            return "Sale"
        case .forYou:
            return "For You"
        }
    }
}

private enum TregoHomeRailCardStyle {
    case standard
    case metricsOnly
}

private struct TregoHomeRailSection: View {
    let title: String
    let tint: Color
    let products: [TregoProduct]
    let cardStyle: TregoHomeRailCardStyle
    let onViewAll: () -> Void
    let onOpenProduct: (TregoProduct) -> Void
    let onOpenBusiness: (TregoProduct) -> Void
    let isWishlisted: (TregoProduct) -> Bool
    let onWishlist: (TregoProduct) -> Void
    let onAddToCart: (TregoProduct) -> Void
    var viewportHorizontalInset: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
                Spacer()
                Button(action: onViewAll) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, viewportHorizontalInset)

            TregoAutoSlidingRail(
                products: products,
                itemWidth: cardWidth,
                itemSpacing: cardSpacing,
                railHeight: railHeight
            ) { product in
                TregoHomeRailProductCard(
                    product: product,
                    tint: tint,
                    style: cardStyle,
                    isWishlisted: isWishlisted(product),
                    onTap: { onOpenProduct(product) },
                    onOpenBusiness: { onOpenBusiness(product) },
                    onWishlist: { onWishlist(product) },
                    onAddToCart: { onAddToCart(product) }
                )
                .frame(width: cardWidth)
            }
        }
        .padding(.horizontal, -viewportHorizontalInset)
    }

    private var cardWidth: CGFloat {
        cardStyle == .metricsOnly ? 154 : 172
    }

    private var cardSpacing: CGFloat {
        cardStyle == .metricsOnly ? 10 : 12
    }

    private var railHeight: CGFloat {
        cardStyle == .metricsOnly ? 196 : 272
    }
}

private struct TregoAutoSlidingRail<CardContent: View>: View {
    let products: [TregoProduct]
    let itemWidth: CGFloat
    let itemSpacing: CGFloat
    let railHeight: CGFloat
    @ViewBuilder let card: (TregoProduct) -> CardContent

    @State private var animationStartDate = Date()
    @State private var pauseDate: Date?
    @State private var pausedOffset: CGFloat = 0
    @GestureState private var dragState = TregoRailDragState.inactive
    @State private var resumeTask: Task<Void, Never>?

    private let pointsPerSecond: CGFloat = 26
    private let horizontalActivationDistance: CGFloat = 16
    private let horizontalDominanceRatio: CGFloat = 1.35

    var body: some View {
        if products.isEmpty {
            EmptyView()
        } else {
            GeometryReader { geometry in
                let cycleWidth = CGFloat(products.count) * (itemWidth + itemSpacing)

                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: pauseDate != nil)) { context in
                    let offset = resolvedOffset(at: context.date, cycleWidth: cycleWidth)

                    HStack(spacing: itemSpacing) {
                        ForEach(Array(products.enumerated()), id: \.offset) { index, product in
                            card(product)
                                .id("primary-\(index)-\(product.id)")
                        }
                        ForEach(Array(products.enumerated()), id: \.offset) { index, product in
                            card(product)
                                .id("duplicate-\(index)-\(product.id)")
                        }
                    }
                    .offset(x: offset + dragState.translationX)
                    .frame(width: geometry.size.width, alignment: .leading)
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: horizontalActivationDistance)
                        .onChanged { value in
                            guard qualifiesForHorizontalRailDrag(value.translation) else { return }
                            pauseAutoScroll()
                        }
                        .updating($dragState) { value, state, _ in
                            state = railDragState(for: value.translation)
                        }
                        .onEnded { value in
                            guard qualifiesForHorizontalRailDrag(value.translation) else { return }
                            finalizeDrag(with: value.translation.width, cycleWidth: cycleWidth)
                            scheduleResume()
                        }
                )
            }
            .frame(height: railHeight)
            .clipped()
            .onDisappear {
                resumeTask?.cancel()
            }
        }
    }

    private func resolvedOffset(at date: Date, cycleWidth: CGFloat) -> CGFloat {
        guard cycleWidth > 0 else { return 0 }
        guard pauseDate == nil else { return pausedOffset }

        let elapsed = CGFloat(date.timeIntervalSince(animationStartDate))
        let distance = elapsed * pointsPerSecond
        let normalized = distance.truncatingRemainder(dividingBy: cycleWidth)
        return -normalized
    }

    private func pauseAutoScroll() {
        guard pauseDate == nil else { return }
        let now = Date()
        let cycleWidth = CGFloat(products.count) * (itemWidth + itemSpacing)
        pausedOffset = resolvedOffset(at: now, cycleWidth: cycleWidth)
        pauseDate = now
        resumeTask?.cancel()
    }

    private func scheduleResume() {
        resumeTask?.cancel()
        resumeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            guard let pauseDate else { return }
            let pausedDuration = Date().timeIntervalSince(pauseDate)
            animationStartDate = animationStartDate.addingTimeInterval(pausedDuration)
            self.pauseDate = nil
        }
    }

    private func finalizeDrag(with translation: CGFloat, cycleWidth: CGFloat) {
        guard cycleWidth > 0 else { return }
        let adjusted = pausedOffset + translation
        pausedOffset = normalizedOffset(adjusted, cycleWidth: cycleWidth)
    }

    private func normalizedOffset(_ value: CGFloat, cycleWidth: CGFloat) -> CGFloat {
        guard cycleWidth > 0 else { return value }
        var normalized = value.truncatingRemainder(dividingBy: cycleWidth)
        if normalized > 0 {
            normalized -= cycleWidth
        }
        return normalized
    }

    private func railDragState(for translation: CGSize) -> TregoRailDragState {
        guard qualifiesForHorizontalRailDrag(translation) else {
            return .inactive
        }

        return .active(translationX: translation.width)
    }

    private func qualifiesForHorizontalRailDrag(_ translation: CGSize) -> Bool {
        let horizontalDistance = abs(translation.width)
        let verticalDistance = abs(translation.height)
        guard horizontalDistance >= horizontalActivationDistance else {
            return false
        }
        return horizontalDistance > verticalDistance * horizontalDominanceRatio
    }
}

private enum TregoRailDragState {
    case inactive
    case active(translationX: CGFloat)

    var translationX: CGFloat {
        switch self {
        case .inactive:
            return 0
        case .active(let translationX):
            return translationX
        }
    }
}

private struct TregoHomeRailProductCard: View {
    let product: TregoProduct
    let tint: Color
    let style: TregoHomeRailCardStyle
    let isWishlisted: Bool
    let onTap: () -> Void
    let onOpenBusiness: () -> Void
    let onWishlist: () -> Void
    let onAddToCart: () -> Void

    private let imageCornerRadius: CGFloat = 20
    private let cardCornerRadius: CGFloat = 22
    private let iconButtonSize: CGFloat = 30
    private let iconSize: CGFloat = 12.5
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: verticalSpacing) {
            ZStack(alignment: .top) {
                Button(action: onTap) {
                    TregoRemoteImage(imagePath: product.imagePath)
                        .frame(height: imageHeight)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: imageCornerRadius, style: .continuous)
                                .fill(Color.white.opacity(colorScheme == .dark ? 0.92 : 1))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)

                HStack {
                    Button(action: onAddToCart) {
                        Image(systemName: "cart.badge.plus")
                            .font(.system(size: iconSize, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .frame(width: iconButtonSize, height: iconButtonSize)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.34), lineWidth: 0.6)
                            }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: onWishlist) {
                        Image(systemName: isWishlisted ? "heart.fill" : "heart")
                            .font(.system(size: iconSize, weight: .bold))
                            .foregroundStyle(isWishlisted ? Color.red : Color.primary)
                            .frame(width: iconButtonSize, height: iconButtonSize)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.34), lineWidth: 0.6)
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(9)
            }

            if style == .metricsOnly {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Text(TregoFormatting.price(product.price ?? 0))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(tint)
                        if let compareAt = product.compareAtPrice, compareAt > (product.price ?? 0) {
                            TregoComparePriceText(
                                value: TregoFormatting.price(compareAt),
                                font: .system(size: 10, weight: .semibold)
                            )
                        }
                    }

                    HStack(spacing: 6) {
                        Text("\(product.buyersCount ?? 0) shitje")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TregoCompactRatingSummary(rating: product.averageRating ?? 0)
                    }
                }
            } else {
                Text(product.title)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)

                if let businessName = product.businessName, !businessName.isEmpty, product.businessProfileId != nil {
                    Button(action: onOpenBusiness) {
                        Text(businessName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(height: 16)
                }

                HStack(spacing: 6) {
                    Text(TregoFormatting.price(product.price ?? 0))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(tint)
                    if let compareAt = product.compareAtPrice, compareAt > (product.price ?? 0) {
                        TregoComparePriceText(
                            value: TregoFormatting.price(compareAt),
                            font: .system(size: 11, weight: .semibold)
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .topLeading)
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(tint.opacity(style == .metricsOnly ? 0.07 : 0.04))
        )
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(Color.white.opacity(style == .metricsOnly ? 0 : standardCardBaseOpacity))
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.42), lineWidth: 0.7)
        }
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .clipped()
    }

    private var imageHeight: CGFloat {
        style == .metricsOnly ? 116 : 132
    }

    private var cardHeight: CGFloat {
        style == .metricsOnly ? 170 : 224
    }

    private var cardPadding: CGFloat {
        style == .metricsOnly ? 10 : 12
    }

    private var verticalSpacing: CGFloat {
        style == .metricsOnly ? 6 : 8
    }

    private var standardCardBaseOpacity: Double {
        colorScheme == .dark ? 0.14 : 0.92
    }
}

private struct TregoCompactRatingSummary: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: starSymbol(for: index))
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Color(red: 0.98, green: 0.78, blue: 0.16))
            }

            Text(String(format: "%.1f", max(0, rating)))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 0.98, green: 0.78, blue: 0.16))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func starSymbol(for index: Int) -> String {
        let threshold = Double(index) + 1
        if rating >= threshold {
            return "star.fill"
        }
        if rating >= threshold - 0.5 {
            return "star.leadinghalf.filled"
        }
        return "star"
    }
}

private struct TregoHomeCollectionScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    let title: String
    let products: [TregoProduct]
    @State private var openedBusinessSelection: TregoBusinessSelection?

    private let grid = [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if products.isEmpty {
                    TregoEmptyStateView(
                        title: "Nuk ka produkte",
                        subtitle: "Kur te kete produkte ne kete kategori, do te shfaqen ketu."
                    )
                } else {
                    LazyVGrid(columns: grid, spacing: 18) {
                        ForEach(products) { product in
                            TregoProductCard(
                                product: product,
                                isWishlisted: store.isWishlisted(productId: product.id),
                                onTap: { store.selectedProduct = product },
                                onOpenBusiness: {
                                    if let businessId = product.businessProfileId {
                                        openedBusinessSelection = TregoBusinessSelection(id: businessId)
                                    }
                                },
                                onWishlist: {
                                    Task { await store.toggleWishlist(for: product) }
                                },
                                onAddToCart: {
                                    Task { await store.addToCart(product: product) }
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .padding(.bottom, 36)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .background(TregoBusinessPushLink(store: store, selection: $openedBusinessSelection))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TregoPromoCardItem: Identifiable {
    enum Kind {
        case trending
        case sale
        case featured
    }

    let kind: Kind
    let product: TregoProduct

    var id: String {
        "\(kind == .trending ? "trending" : "sale")-\(product.id)"
    }
}

private struct TregoComparePriceText: View {
    let value: String
    let font: Font

    var body: some View {
        Text(value)
            .font(font)
            .foregroundStyle(.secondary)
            .overlay(alignment: .center) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(height: 1)
            }
    }
}

private struct TregoPromoCard: View {
    let card: TregoPromoCardItem
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(cardTitle)
                        .font(.system(size: 12, weight: .heavy))
                        .textCase(.uppercase)
                    Spacer(minLength: 0)
                    Image(systemName: cardIconName)
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(cardForeground)

                TregoRemoteImage(imagePath: card.product.imagePath)
                    .frame(height: 116)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Text(card.product.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)

                Text(TregoFormatting.price(card.product.price ?? 0))
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .tregoGlassRectBackground(cornerRadius: 28)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(cardTint)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(cardStroke, lineWidth: 0.9)
            }
        }
        .buttonStyle(.plain)
    }

    private var cardTint: Color {
        switch card.kind {
        case .trending:
            return Color.red.opacity(colorScheme == .dark ? 0.16 : 0.12)
        case .sale:
            return Color.orange.opacity(colorScheme == .dark ? 0.18 : 0.14)
        case .featured:
            return Color.orange.opacity(colorScheme == .dark ? 0.22 : 0.18)
        }
    }

    private var cardStroke: Color {
        switch card.kind {
        case .trending:
            return Color.red.opacity(colorScheme == .dark ? 0.34 : 0.24)
        case .sale:
            return Color.orange.opacity(colorScheme == .dark ? 0.34 : 0.24)
        case .featured:
            return Color.orange.opacity(colorScheme == .dark ? 0.4 : 0.3)
        }
    }

    private var cardTitle: String {
        switch card.kind {
        case .trending:
            return "Trending"
        case .sale:
            return "Sale"
        case .featured:
            return "Featured"
        }
    }

    private var cardIconName: String {
        switch card.kind {
        case .trending:
            return "chart.line.uptrend.xyaxis"
        case .sale:
            return "tag.fill"
        case .featured:
            return "sparkles"
        }
    }

    private var cardForeground: Color {
        switch card.kind {
        case .trending:
            return Color.red.opacity(0.9)
        case .sale, .featured:
            return TregoNativeTheme.accent
        }
    }
}

private struct TregoGlassRectBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

private struct TregoGlassCapsuleBackground: View {
    var body: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(in: .capsule)
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
        }
    }
}

private struct TregoGlassCircleBackground: View {
    var body: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(in: .circle)
        } else {
            Circle()
                .fill(.ultraThinMaterial)
        }
    }
}

private extension View {
    func tregoGlassRectBackground(cornerRadius: CGFloat) -> some View {
        background {
            TregoGlassRectBackground(cornerRadius: cornerRadius)
        }
    }

    func tregoGlassCapsuleBackground() -> some View {
        background {
            TregoGlassCapsuleBackground()
        }
    }

    func tregoGlassCircleBackground() -> some View {
        background {
            TregoGlassCircleBackground()
        }
    }

    @ViewBuilder
    func tregoPopupSheetStyle(height: CGFloat) -> some View {
        if #available(iOS 16.0, *) {
            self
                .presentationDetents([.height(height), .medium])
                .presentationDragIndicator(.visible)
        } else {
            self
        }
    }

    @ViewBuilder
    func tregoPresentationDragIndicatorVisible() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDragIndicator(.visible)
        } else {
            self
        }
    }

    @ViewBuilder
    func tregoCompatibleForeground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            self.foregroundStyle(color)
        } else {
            self.foregroundColor(color)
        }
    }
}

private struct TregoAuthHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 34, weight: .black))
                .frame(maxWidth: .infinity, alignment: .center)
            Text(subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            TregoHairlineDivider()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TregoInputCard: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var placeholder: String = ""
    var autocapitalization: TextInputAutocapitalization = .words
    var textContentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .done
    var disableAutocorrection: Bool = true
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            TextField(placeholder.isEmpty ? title : placeholder, text: $text)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(disableAutocorrection)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .submitLabel(submitLabel)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .tregoGlassRectBackground(cornerRadius: 22)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.8)
                }
        }
    }
}

private struct TregoMultilineInputCard: View {
    let title: String
    @Binding var text: String
    var placeholder: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                TregoGlassRectBackground(cornerRadius: 22)

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                }

                multilineEditor
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.8)
            }
        }
    }

    @ViewBuilder
    private var multilineEditor: some View {
        if #available(iOS 16.0, *) {
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: 132)
                .background(Color.clear)
        } else {
            TextEditor(text: $text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: 132)
                .background(Color.clear)
        }
    }
}

private struct TregoSecureInputCard: View {
    let title: String
    @Binding var text: String
    var textContentType: UITextContentType? = .password
    var submitLabel: SubmitLabel = .done
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            SecureField(title, text: $text)
                .textContentType(textContentType)
                .submitLabel(submitLabel)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .tregoGlassRectBackground(cornerRadius: 22)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.8)
                }
        }
    }
}

private struct TregoSelectionValueCard: View {
    let title: String
    let subtitle: String
    let currentValue: String
    let options: [(String, String)]
    let onSelect: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                ForEach(options, id: \.0) { option in
                    Button(option.1) { onSelect(option.0) }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(currentValue)
                        .font(.system(size: 13, weight: .bold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Color.primary.opacity(0.82))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .tregoGlassRectBackground(cornerRadius: 28)
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.8)
        }
    }
}

private struct TregoGenderPicker: View {
    @Binding var selected: String

    private let options = [
        ("femer", "Femer"),
        ("mashkull", "Mashkull"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gjinia")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            Picker("Gjinia", selection: $selected) {
                ForEach(options, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TregoEmptyStateView: View {
    let title: String
    let subtitle: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
            Text(subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .tregoGlassRectBackground(cornerRadius: 32)
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.8)
        }
    }
}

private struct TregoWishlistEmptyCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.red)

            Text("Nuk ka produkte")
                .font(.system(size: 22, weight: .bold))

            Text("Ruaj produkte nga Home ose Search dhe do te dalin ketu.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.8)
        }
    }
}

private struct TregoCartEmptyCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(TregoNativeTheme.accent)

            Text("Nuk ka produkte")
                .font(.system(size: 22, weight: .bold))

            Text("Shto produkte nga Home ose Search dhe do te dalin ketu.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.8)
        }
    }
}

private struct TregoToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(TregoNativeTheme.accent, in: Capsule())
            .shadow(color: .black.opacity(0.14), radius: 10, y: 6)
    }
}

private struct TregoSkeletonBlock: View {
    var cornerRadius: CGFloat = 18
    var width: CGFloat? = nil
    var height: CGFloat
    @State private var isAnimating = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        skeletonBase.opacity(isAnimating ? 0.68 : 0.94),
                        skeletonHighlight.opacity(isAnimating ? 0.94 : 0.7),
                        skeletonBase.opacity(isAnimating ? 0.68 : 0.94),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }

    private var skeletonBase: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    private var skeletonHighlight: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.12)
    }
}

private struct TregoProductCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TregoSkeletonBlock(cornerRadius: 18, height: 136)

            TregoSkeletonBlock(cornerRadius: 8, height: 14)
            TregoSkeletonBlock(cornerRadius: 8, width: 92, height: 11)
            TregoSkeletonBlock(cornerRadius: 8, width: 78, height: 14)
            TregoSkeletonBlock(cornerRadius: 8, width: 116, height: 11)
        }
        .padding(12)
        .tregoGlassRectBackground(cornerRadius: 20)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 0.7)
        }
    }
}

private struct TregoHomeRailSkeletonSection: View {
    let title: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(tint)

                Spacer(minLength: 0)

                TregoSkeletonBlock(cornerRadius: 18, width: 34, height: 34)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 8) {
                            TregoSkeletonBlock(cornerRadius: 20, height: 116)
                            TregoSkeletonBlock(cornerRadius: 8, width: 82, height: 14)
                            TregoSkeletonBlock(cornerRadius: 8, width: 126, height: 11)
                        }
                        .frame(width: 172)
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(.white.opacity(0.28), lineWidth: 0.7)
                        }
                    }
                }
            }
        }
    }
}

private struct TregoBusinessPreviewRailSkeleton: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        TregoSkeletonBlock(cornerRadius: 18, height: 108)
                        TregoSkeletonBlock(cornerRadius: 8, width: 96, height: 12)
                        TregoSkeletonBlock(cornerRadius: 8, width: 72, height: 11)
                    }
                    .frame(width: 148)
                }
            }
        }
        .frame(height: 156)
    }
}

private struct TregoBusinessExplorerCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                TregoSkeletonBlock(cornerRadius: 29, width: 58, height: 58)

                VStack(alignment: .leading, spacing: 6) {
                    TregoSkeletonBlock(cornerRadius: 8, width: 148, height: 15)
                    TregoSkeletonBlock(cornerRadius: 8, width: 84, height: 12)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    TregoSkeletonBlock(cornerRadius: 18, width: 36, height: 36)
                    TregoSkeletonBlock(cornerRadius: 18, width: 76, height: 36)
                }
            }

            TregoBusinessPreviewRailSkeleton()
        }
        .padding(16)
        .tregoGlassRectBackground(cornerRadius: 28)
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 0.8)
        }
    }
}

private struct TregoRemoteImageRequest: Hashable {
    let url: URL
    let pixelWidth: Int
    let pixelHeight: Int

    var cacheKey: NSString {
        "\(url.absoluteString)|\(pixelWidth)x\(pixelHeight)" as NSString
    }
}

private final class TregoRemoteImageMemoryCache {
    static let shared: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 220
        cache.totalCostLimit = 96 * 1024 * 1024
        return cache
    }()

    private init() {}
}

private actor TregoRemoteImagePipeline {
    static let shared = TregoRemoteImagePipeline()

    private var inFlightTasks: [TregoRemoteImageRequest: Task<UIImage?, Never>] = [:]

    func image(for request: TregoRemoteImageRequest) async -> UIImage? {
        if let cached = TregoRemoteImageMemoryCache.shared.object(forKey: request.cacheKey) {
            return cached
        }

        if let task = inFlightTasks[request] {
            return await task.value
        }

        let task = Task<UIImage?, Never> {
            let urlRequest = URLRequest(url: request.url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
            if let cachedResponse = URLCache.shared.cachedResponse(for: urlRequest),
               let cachedImage = Self.downsampledImage(from: cachedResponse.data, for: request)
            {
                TregoRemoteImageMemoryCache.shared.setObject(cachedImage, forKey: request.cacheKey, cost: cachedResponse.data.count)
                return cachedImage
            }

            do {
                let (data, response) = try await URLSession.shared.data(for: urlRequest)
                guard !Task.isCancelled else { return nil }
                guard let image = Self.downsampledImage(from: data, for: request) else { return nil }
                URLCache.shared.storeCachedResponse(CachedURLResponse(response: response, data: data), for: urlRequest)
                TregoRemoteImageMemoryCache.shared.setObject(image, forKey: request.cacheKey, cost: data.count)
                return image
            } catch {
                return nil
            }
        }

        inFlightTasks[request] = task
        let image = await task.value
        inFlightTasks[request] = nil
        return image
    }

    private static func downsampledImage(from data: Data, for request: TregoRemoteImageRequest) -> UIImage? {
        let maxDimension = max(request.pixelWidth, request.pixelHeight, 64)
        let options = [
            kCGImageSourceShouldCache: false,
        ] as CFDictionary

        guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
            return nil
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

@MainActor
private final class TregoRemoteImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isLoading = false

    private var task: Task<Void, Never>?
    private var currentRequest: TregoRemoteImageRequest?

    func load(imagePath: String?, targetSize: CGSize, scale: CGFloat) {
        let resolvedScale = max(scale, 1)
        let pixelWidth = max(Int(targetSize.width * resolvedScale), 64)
        let pixelHeight = max(Int(targetSize.height * resolvedScale), 64)
        let url = TregoAPIClient.imageURL(from: imagePath)
        let request = url.map { TregoRemoteImageRequest(url: $0, pixelWidth: pixelWidth, pixelHeight: pixelHeight) }

        if currentRequest == request && (image != nil || isLoading) {
            return
        }

        task?.cancel()
        currentRequest = request
        image = nil
        isLoading = false

        guard let request else { return }

        if let cached = TregoRemoteImageMemoryCache.shared.object(forKey: request.cacheKey) {
            image = cached
            return
        }

        isLoading = true
        task = Task { [weak self] in
            guard let self else { return }
            let fetchedImage = await TregoRemoteImagePipeline.shared.image(for: request)
            guard !Task.isCancelled, currentRequest == request else { return }
            image = fetchedImage
            isLoading = false
        }
    }

    func cancel() {
        task?.cancel()
        isLoading = false
    }

    deinit {
        task?.cancel()
    }
}

private struct TregoRemoteImage: View {
    let imagePath: String?
    var targetSize: CGSize = CGSize(width: 320, height: 320)

    @Environment(\.displayScale) private var displayScale
    @StateObject private var loader = TregoRemoteImageLoader()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)

            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFill()
            } else if loader.isLoading {
                TregoSkeletonBlock(cornerRadius: 24, height: 120)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.26))
            }
        }
        .clipped()
        .task(id: taskIdentifier) {
            loader.load(imagePath: imagePath, targetSize: targetSize, scale: displayScale)
        }
        .onDisappear {
            loader.cancel()
        }
    }

    private var taskIdentifier: String {
        "\(imagePath ?? "none")-\(Int(targetSize.width))x\(Int(targetSize.height))-\(displayScale)"
    }
}

private struct TregoAvatarView: View {
    let name: String

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: avatarGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Text(initials)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
            }
    }

    private var initials: String {
        let bits = name
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
        return bits.isEmpty ? "T" : bits.joined()
    }

    private var avatarGradientColors: [Color] {
        let palette: [[Color]] = [
            [Color(red: 0.98, green: 0.5, blue: 0.22), Color(red: 0.92, green: 0.28, blue: 0.28)],
            [Color(red: 0.22, green: 0.58, blue: 0.98), Color(red: 0.32, green: 0.36, blue: 0.95)],
            [Color(red: 0.18, green: 0.72, blue: 0.54), Color(red: 0.08, green: 0.56, blue: 0.36)],
            [Color(red: 0.74, green: 0.38, blue: 0.96), Color(red: 0.47, green: 0.24, blue: 0.88)],
        ]
        let value = abs(name.unicodeScalars.reduce(Int(0)) { partialResult, scalar in
            partialResult + Int(scalar.value)
        })
        return palette[Int(value) % palette.count]
    }
}

private struct TregoGlassSearchBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    @StateObject private var speechRecognizer = TregoSpeechRecognizer()
    @State private var pickerSource: TregoImagePickerSource?
    @State private var showsImageDialog = false
    @State private var alertState: TregoSearchBarAlert?

    let placeholder: String
    let onSubmit: () -> Void
    let onImagePicked: (TregoImageSearchUpload) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .onSubmit(onSubmit)
                .font(.system(size: 17, weight: .semibold))

            HStack(spacing: 8) {
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            text = ""
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(.white.opacity(colorScheme == .dark ? 0.12 : 0.74)))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showsImageDialog = true
                } label: {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .tregoGlassCircleBackground()
                }
                .buttonStyle(.plain)

                Button(action: handleMicTap) {
                    Image(systemName: "mic")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(Color.primary.opacity(0.7))
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(
            LinearGradient(
                colors: [
                    .white.opacity(colorScheme == .dark ? 0.12 : 0.86),
                    .white.opacity(colorScheme == .dark ? 0.06 : 0.62),
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(colorScheme == .dark ? 0.14 : 0.6), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.14 : 0.05), radius: 14, y: 6)
        .confirmationDialog("Image search", isPresented: $showsImageDialog) {
            Button("Take photo") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    pickerSource = .camera
                } else {
                    alertState = .cameraUnavailable
                }
            }
            Button("Choose from library") {
                pickerSource = .photoLibrary
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: isCameraPickerPresented) {
            TregoImagePicker(source: .camera) { upload in
                onImagePicked(upload)
            }
        }
        .sheet(isPresented: isPhotoLibraryPickerPresented) {
            TregoImagePicker(source: .photoLibrary) { upload in
                onImagePicked(upload)
            }
        }
        .alert(item: $alertState) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .onDisappear {
            speechRecognizer.stop()
        }
    }

    private func handleMicTap() {
        if speechRecognizer.isRecording {
            speechRecognizer.stop()
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                onSubmit()
            }
            return
        }

        Task {
            let started = await speechRecognizer.start { transcript, isFinal in
                text = transcript
                if isFinal && !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onSubmit()
                }
            }

            if !started {
                alertState = speechRecognizer.authorizationDenied ? .microphonePermission : .speechUnavailable
            }
        }
    }

    private var isCameraPickerPresented: Binding<Bool> {
        Binding(
            get: { pickerSource == .camera },
            set: { newValue in
                if !newValue, pickerSource == .camera {
                    pickerSource = nil
                }
            }
        )
    }

    private var isPhotoLibraryPickerPresented: Binding<Bool> {
        Binding(
            get: { pickerSource == .photoLibrary },
            set: { newValue in
                if !newValue, pickerSource == .photoLibrary {
                    pickerSource = nil
                }
            }
        )
    }
}

private enum TregoSearchBarAlert: String, Identifiable {
    case microphonePermission
    case speechUnavailable
    case cameraUnavailable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .microphonePermission:
            return "Microphone access needed"
        case .speechUnavailable:
            return "Voice search unavailable"
        case .cameraUnavailable:
            return "Camera unavailable"
        }
    }

    var message: String {
        switch self {
        case .microphonePermission:
            return "Lejo aksesin per mikrofonin dhe speech recognition ne Settings."
        case .speechUnavailable:
            return "Voice search nuk eshte aktiv ne kete pajisje tani."
        case .cameraUnavailable:
            return "Kamera nuk eshte e disponueshme tani. Zgjidh nje foto nga library."
        }
    }
}

private enum TregoImagePickerSource: String, Identifiable {
    case camera
    case photoLibrary

    var id: String { rawValue }

    var uiKitSourceType: UIImagePickerController.SourceType {
        switch self {
        case .camera:
            return .camera
        case .photoLibrary:
            return .photoLibrary
        }
    }
}

private struct TregoPromotionFormDraft {
    static let discountTypeOptions: [(String, String)] = [
        ("percent", "Perqindje"),
        ("fixed", "Vlere fikse"),
    ]

    static let sectionOptions: [(String, String)] = [
        ("", "Gjithe marketplace"),
    ] + TregoNativeProductCatalog.sectionOptions

    var code: String
    var title: String
    var description: String
    var discountType: String
    var discountValueText: String
    var minimumSubtotalText: String
    var usageLimitText: String
    var perUserLimitText: String
    var isActive: Bool
    var pageSection: String
    var audience: String
    var hasStartDate: Bool
    var startsAt: Date
    var hasEndDate: Bool
    var endsAt: Date

    init(promotion: TregoPromotion?) {
        code = promotion?.code ?? ""
        title = promotion?.title ?? ""
        description = promotion?.description ?? ""
        discountType = promotion?.discountType ?? "percent"
        discountValueText = promotion.flatMap { $0.discountValue.map { String(format: "%.2f", $0) } } ?? ""
        minimumSubtotalText = promotion.flatMap { $0.minimumSubtotal.map { String(format: "%.2f", $0) } } ?? ""
        usageLimitText = promotion.flatMap { $0.usageLimit.map(String.init) } ?? ""
        perUserLimitText = promotion.flatMap { $0.perUserLimit.map(String.init) } ?? "1"
        isActive = promotion?.isActive ?? true
        pageSection = TregoNativeProductCatalog.section(for: promotion?.category ?? promotion?.pageSection ?? "")
        audience = TregoNativeProductCatalog.audience(for: promotion?.category ?? "")
        let defaultStart = Date()
        let defaultEnd = Date().addingTimeInterval(60 * 60 * 24 * 7)
        startsAt = TregoNativeFormatting.optionalDate(fromStorage: promotion?.startsAt) ?? defaultStart
        endsAt = TregoNativeFormatting.optionalDate(fromStorage: promotion?.endsAt) ?? defaultEnd
        hasStartDate = !(promotion?.startsAt ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        hasEndDate = !(promotion?.endsAt ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        syncForSectionChange(pageSection)
    }

    var discountTypeLabel: String {
        Self.discountTypeOptions.first(where: { $0.0 == discountType })?.1 ?? "Perqindje"
    }

    var sectionLabel: String {
        pageSection.isEmpty ? "Gjithe marketplace" : TregoNativeProductCatalog.sectionLabel(for: pageSection)
    }

    var audienceLabel: String {
        if audience.isEmpty {
            return "Te gjitha"
        }
        return TregoNativeProductCatalog.audienceLabel(section: pageSection, audience: audience)
    }

    mutating func syncForSectionChange(_ newSection: String) {
        if newSection.isEmpty {
            audience = ""
            return
        }
        if !TregoNativeProductCatalog.sectionSupportsAudience(newSection) {
            audience = ""
        } else if !TregoNativeProductCatalog.audienceOptions(for: newSection).contains(where: { $0.0 == audience }) {
            audience = ""
        }
    }

    func backendPayload() -> [String: Any] {
        let normalizedPageSection = pageSection.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = normalizedPageSection.isEmpty
            ? ""
            : TregoNativeProductCatalog.category(for: normalizedPageSection, audience: audience)

        return [
            "code": code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "description": description.trimmingCharacters(in: .whitespacesAndNewlines),
            "discountType": discountType,
            "discountValue": discountValueText.trimmingCharacters(in: .whitespacesAndNewlines),
            "minimumSubtotal": minimumSubtotalText.trimmingCharacters(in: .whitespacesAndNewlines),
            "usageLimit": usageLimitText.trimmingCharacters(in: .whitespacesAndNewlines),
            "perUserLimit": perUserLimitText.trimmingCharacters(in: .whitespacesAndNewlines),
            "isActive": isActive,
            "pageSection": normalizedPageSection,
            "category": category,
            "startsAt": hasStartDate ? TregoNativeFormatting.storageDateString(from: startsAt) : "",
            "endsAt": hasEndDate ? TregoNativeFormatting.storageDateString(from: endsAt) : "",
        ]
    }
}

private struct TregoLaunchAdFormDraft {
    var badge: String
    var title: String
    var subtitle: String
    var imagePath: String
    var ctaLabel: String
    var sortOrderText: String
    var isActive: Bool
    var hasStartDate: Bool
    var startsAt: Date
    var hasEndDate: Bool
    var endsAt: Date

    init(launchAd: TregoLaunchAd?) {
        let defaultStart = Date()
        let defaultEnd = Date().addingTimeInterval(60 * 60 * 24 * 7)

        badge = launchAd?.badge ?? ""
        title = launchAd?.title ?? ""
        subtitle = launchAd?.subtitle ?? ""
        imagePath = launchAd?.imagePath ?? ""
        ctaLabel = launchAd?.ctaLabel?.isEmpty == false ? (launchAd?.ctaLabel ?? "") : "Shop now"
        sortOrderText = launchAd.flatMap { $0.sortOrder.map(String.init) } ?? "0"
        isActive = launchAd?.isActive ?? true
        startsAt = TregoNativeFormatting.optionalDate(fromStorage: launchAd?.startsAt) ?? defaultStart
        endsAt = TregoNativeFormatting.optionalDate(fromStorage: launchAd?.endsAt) ?? defaultEnd
        hasStartDate = !(launchAd?.startsAt ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        hasEndDate = !(launchAd?.endsAt ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func backendPayload(existingId: Int?) -> [String: Any] {
        var payload: [String: Any] = [
            "badge": badge.trimmingCharacters(in: .whitespacesAndNewlines),
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "subtitle": subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            "imagePath": imagePath.trimmingCharacters(in: .whitespacesAndNewlines),
            "ctaLabel": ctaLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            "sortOrder": sortOrderText.trimmingCharacters(in: .whitespacesAndNewlines),
            "isActive": isActive,
            "startsAt": hasStartDate ? TregoNativeFormatting.storageDateString(from: startsAt) : "",
            "endsAt": hasEndDate ? TregoNativeFormatting.storageDateString(from: endsAt) : "",
        ]
        if let existingId {
            payload["launchAdId"] = existingId
        }
        return payload
    }
}

private struct TregoOrderStatusDraft {
    let currentStatus: String
    let availableStatuses: [(String, String)]
    var nextStatus: String
    var trackingCode: String
    var trackingURL: String

    init(order: TregoOrderItem) {
        let current = (order.fulfillmentStatus ?? order.status ?? "pending_confirmation")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        currentStatus = current
        availableStatuses = TregoOrderStatusDraft.allowedStatuses(from: current)
        nextStatus = availableStatuses.first?.0 ?? ""
        trackingCode = order.trackingCode ?? ""
        trackingURL = order.trackingUrl ?? ""
    }

    var showsTrackingFields: Bool {
        nextStatus == "shipped" || nextStatus == "delivered" || !trackingCode.isEmpty || !trackingURL.isEmpty
    }

    private static func allowedStatuses(from current: String) -> [(String, String)] {
        switch current {
        case "pending_confirmation":
            return [("confirmed", "Konfirmo"), ("cancelled", "Anulo")]
        case "confirmed":
            return [("packed", "Paketuar"), ("cancelled", "Anulo")]
        case "packed":
            return [("shipped", "Derguar")]
        case "shipped":
            return [("delivered", "Dorezuar"), ("returned", "Kthyer")]
        case "delivered":
            return [("returned", "Kthyer")]
        default:
            return []
        }
    }
}

private struct TregoProductFormDraft {
    var articleNumber: String
    var title: String
    var description: String
    var pageSection: String
    var audience: String
    var productType: String
    var priceText: String
    var compareAtPriceText: String
    var saleEnabled: Bool
    var saleEndDate: Date
    var stockQuantityText: String
    var size: String
    var color: String
    var packageAmountValueText: String
    var packageAmountUnit: String
    var imagePaths: [String]
    var isPublic: Bool

    init(product: TregoProduct?) {
        let category = product?.category ?? "clothing-men"
        let pageSection = TregoNativeProductCatalog.section(for: category)
        let audience = TregoNativeProductCatalog.audience(for: category)
        let saleEnds = TregoNativeFormatting.optionalDate(fromStorage: product?.saleEndsAt) ?? Date().addingTimeInterval(60 * 60 * 24 * 7)

        articleNumber = product?.articleNumber ?? ""
        title = product?.title ?? ""
        description = product?.description ?? ""
        self.pageSection = pageSection
        self.audience = audience
        productType = product?.productType ?? TregoNativeProductCatalog.productTypeOptions(section: pageSection, audience: audience).first?.0 ?? ""
        priceText = product.flatMap { $0.price.map { String(format: "%.2f", $0) } } ?? ""
        compareAtPriceText = product.flatMap { $0.compareAtPrice.map { String(format: "%.2f", $0) } } ?? ""
        saleEnabled = (product?.compareAtPrice ?? 0) > (product?.price ?? 0)
        saleEndDate = saleEnds
        stockQuantityText = product.flatMap { $0.stockQuantity.map(String.init) } ?? ""
        size = product?.selectedSize?.isEmpty == false ? (product?.selectedSize ?? "") : (product?.size ?? "")
        color = product?.selectedColor?.isEmpty == false ? (product?.selectedColor ?? "") : (product?.color ?? "")
        packageAmountValueText = product.flatMap { $0.packageAmountValue.map { String(format: $0.rounded(.towardZero) == $0 ? "%.0f" : "%.2f", $0) } } ?? ""
        packageAmountUnit = product?.packageAmountUnit ?? ""
        imagePaths = product?.imageGallery?.isEmpty == false ? (product?.imageGallery ?? []) : ((product?.imagePath).flatMap { $0 == nil || $0 == "" ? [] : [$0!] } ?? [])
        isPublic = product?.isPublic ?? false
    }

    mutating func syncForSectionChange(_ newSection: String) {
        if !TregoNativeProductCatalog.sectionSupportsAudience(newSection) {
            audience = ""
        } else if audience.isEmpty {
            audience = TregoNativeProductCatalog.audienceOptions(for: newSection).first?.0 ?? ""
        }

        let validTypes = TregoNativeProductCatalog.productTypeOptions(section: newSection, audience: audience)
        if !validTypes.contains(where: { $0.0 == productType }) {
            productType = validTypes.first?.0 ?? ""
        }

        if !TregoNativeProductCatalog.requiresSize(section: newSection) {
            size = ""
        }
        if !TregoNativeProductCatalog.supportsPackageAmount(section: newSection) {
            packageAmountValueText = ""
            packageAmountUnit = ""
        } else if packageAmountUnit.isEmpty {
            packageAmountUnit = TregoNativeProductCatalog.amountUnitOptions.first?.0 ?? "ml"
        }
    }

    func backendPayload() -> [String: Any] {
        let category = TregoNativeProductCatalog.category(for: pageSection, audience: audience)
        let stockQuantity = Int(stockQuantityText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        let variantInventory: [[String: Any]] = stockQuantity > 0 ? [[
            "size": TregoNativeProductCatalog.requiresSize(section: pageSection) ? size : "",
            "color": color,
            "quantity": stockQuantity,
            "price": "",
            "imagePath": imagePaths.first ?? "",
        ]] : []

        return [
            "articleNumber": articleNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "description": description.trimmingCharacters(in: .whitespacesAndNewlines),
            "pageSection": pageSection,
            "audience": TregoNativeProductCatalog.sectionSupportsAudience(pageSection) ? audience : "",
            "category": category,
            "productType": productType,
            "size": TregoNativeProductCatalog.requiresSize(section: pageSection) ? size : "",
            "color": color,
            "variantInventory": variantInventory,
            "imagePath": imagePaths.first ?? "",
            "imageGallery": imagePaths,
            "price": priceText.trimmingCharacters(in: .whitespacesAndNewlines),
            "compareAtPrice": saleEnabled ? compareAtPriceText.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            "saleEndsAt": saleEnabled ? ISO8601DateFormatter().string(from: saleEndDate) : "",
            "packageAmountValue": TregoNativeProductCatalog.supportsPackageAmount(section: pageSection) ? packageAmountValueText.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            "packageAmountUnit": TregoNativeProductCatalog.supportsPackageAmount(section: pageSection) ? packageAmountUnit : "",
            "stockQuantity": stockQuantityText.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
    }
}

private struct TregoAdminBusinessFormDraft {
    var fullName: String
    var email: String
    var password: String
    var businessName: String
    var businessDescription: String
    var businessNumber: String
    var phoneNumber: String
    var city: String
    var addressLine: String
    var businessLogoPath: String

    init(business: TregoAdminBusiness?) {
        fullName = business?.ownerName ?? ""
        email = business?.ownerEmail ?? ""
        password = ""
        businessName = business?.businessName ?? ""
        businessDescription = business?.businessDescription ?? ""
        businessNumber = business?.businessNumber ?? ""
        phoneNumber = business?.phoneNumber ?? ""
        city = business?.city ?? ""
        addressLine = business?.addressLine ?? ""
        businessLogoPath = business?.logoPath ?? ""
    }

    func createPayload() -> TregoAdminBusinessCreatePayload {
        TregoAdminBusinessCreatePayload(
            fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            businessName: businessName.trimmingCharacters(in: .whitespacesAndNewlines),
            businessDescription: businessDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            businessNumber: businessNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            addressLine: addressLine.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func updatePayload() -> [String: Any] {
        [
            "businessName": businessName.trimmingCharacters(in: .whitespacesAndNewlines),
            "businessDescription": businessDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            "businessNumber": businessNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            "businessLogoPath": businessLogoPath.trimmingCharacters(in: .whitespacesAndNewlines),
            "phoneNumber": phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            "city": city.trimmingCharacters(in: .whitespacesAndNewlines),
            "addressLine": addressLine.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
    }
}

private struct TregoBusinessProfileDraft {
    var businessName: String
    var businessDescription: String
    var businessNumber: String
    var phoneNumber: String
    var city: String
    var addressLine: String
    var businessLogoPath: String

    init(profile: TregoBusinessProfile?) {
        businessName = profile?.businessName ?? ""
        businessDescription = profile?.businessDescription ?? ""
        businessNumber = profile?.businessNumber ?? ""
        phoneNumber = profile?.phoneNumber ?? ""
        city = profile?.city ?? ""
        addressLine = profile?.addressLine ?? ""
        businessLogoPath = profile?.logoPath ?? ""
    }

    func payload() -> [String: Any] {
        [
            "businessName": businessName.trimmingCharacters(in: .whitespacesAndNewlines),
            "businessDescription": businessDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            "businessNumber": businessNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            "businessLogoPath": businessLogoPath.trimmingCharacters(in: .whitespacesAndNewlines),
            "phoneNumber": phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            "city": city.trimmingCharacters(in: .whitespacesAndNewlines),
            "addressLine": addressLine.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
    }
}

private struct TregoEditableCityRate: Identifiable, Equatable {
    let id = UUID()
    var city: String
    var surchargeText: String

    init(city: String, surchargeText: String) {
        self.city = city
        self.surchargeText = surchargeText
    }

    init(rate: TregoBusinessCityRate) {
        city = rate.city
        surchargeText = rate.surcharge.map { String(format: "%.2f", $0) } ?? ""
    }
}

private struct TregoBusinessShippingDraft {
    var standardEnabled: Bool
    var standardFeeText: String
    var standardEta: String
    var expressEnabled: Bool
    var expressFeeText: String
    var expressEta: String
    var pickupEnabled: Bool
    var pickupEta: String
    var pickupAddress: String
    var pickupHours: String
    var pickupMapURL: String
    var halfOffThresholdText: String
    var freeShippingThresholdText: String
    var cityRates: [TregoEditableCityRate]

    init(settings: TregoBusinessShippingSettings?) {
        standardEnabled = settings?.standardEnabled ?? true
        standardFeeText = settings?.standardFee.map { String(format: "%.2f", $0) } ?? "2.50"
        standardEta = settings?.standardEta ?? "2-3 dite"
        expressEnabled = settings?.expressEnabled ?? true
        expressFeeText = settings?.expressFee.map { String(format: "%.2f", $0) } ?? "4.90"
        expressEta = settings?.expressEta ?? "1 dite"
        pickupEnabled = settings?.pickupEnabled ?? false
        pickupEta = settings?.pickupEta ?? "Sot"
        pickupAddress = settings?.pickupAddress ?? ""
        pickupHours = settings?.pickupHours ?? ""
        pickupMapURL = settings?.pickupMapUrl ?? ""
        halfOffThresholdText = settings?.halfOffThreshold.map { String(format: "%.2f", $0) } ?? "0"
        freeShippingThresholdText = settings?.freeShippingThreshold.map { String(format: "%.2f", $0) } ?? "0"
        cityRates = (settings?.cityRates ?? []).map(TregoEditableCityRate.init(rate:))
    }

    func payload() -> [String: Any] {
        [
            "shippingSettings": [
                "standardEnabled": standardEnabled,
                "standardFee": standardFeeText.trimmingCharacters(in: .whitespacesAndNewlines),
                "standardEta": standardEta.trimmingCharacters(in: .whitespacesAndNewlines),
                "expressEnabled": expressEnabled,
                "expressFee": expressFeeText.trimmingCharacters(in: .whitespacesAndNewlines),
                "expressEta": expressEta.trimmingCharacters(in: .whitespacesAndNewlines),
                "pickupEnabled": pickupEnabled,
                "pickupEta": pickupEta.trimmingCharacters(in: .whitespacesAndNewlines),
                "pickupAddress": pickupAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                "pickupHours": pickupHours.trimmingCharacters(in: .whitespacesAndNewlines),
                "pickupMapUrl": pickupMapURL.trimmingCharacters(in: .whitespacesAndNewlines),
                "halfOffThreshold": halfOffThresholdText.trimmingCharacters(in: .whitespacesAndNewlines),
                "freeShippingThreshold": freeShippingThresholdText.trimmingCharacters(in: .whitespacesAndNewlines),
                "cityRates": cityRates
                    .filter { !$0.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .map { rate in
                        [
                            "city": rate.city.trimmingCharacters(in: .whitespacesAndNewlines),
                            "surcharge": rate.surchargeText.trimmingCharacters(in: .whitespacesAndNewlines),
                        ]
                    },
            ]
        ]
    }
}

private struct TregoImagePicker: UIViewControllerRepresentable {
    let source: TregoImagePickerSource
    let onImagePicked: (TregoImageSearchUpload) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = source.uiKitSourceType
        picker.allowsEditing = false
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: TregoImagePicker

        init(parent: TregoImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            defer { parent.dismiss() }

            guard let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.84) else {
                return
            }

            let filename = parent.source == .camera ? "camera-search.jpg" : "library-search.jpg"
            parent.onImagePicked(
                TregoImageSearchUpload(
                    data: data,
                    filename: filename,
                    mimeType: "image/jpeg"
                )
            )
        }
    }
}

private struct TregoMediaPicker: UIViewControllerRepresentable {
    let source: TregoImagePickerSource
    let onMediaPicked: (TregoAttachmentUpload) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = source.uiKitSourceType
        picker.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
        picker.allowsEditing = false
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: TregoMediaPicker

        init(parent: TregoMediaPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            defer { parent.dismiss() }

            if
                let mediaURL = info[.mediaURL] as? URL,
                let data = try? Data(contentsOf: mediaURL)
            {
                let ext = mediaURL.pathExtension.isEmpty ? "mp4" : mediaURL.pathExtension
                let type = UTType(filenameExtension: ext) ?? .movie
                parent.onMediaPicked(
                    TregoAttachmentUpload(
                        data: data,
                        filename: mediaURL.lastPathComponent.isEmpty ? "video.\(ext)" : mediaURL.lastPathComponent,
                        mimeType: type.preferredMIMEType ?? "video/mp4"
                    )
                )
                return
            }

            guard let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.84) else {
                return
            }

            let filename = parent.source == .camera ? "camera-media.jpg" : "library-media.jpg"
            parent.onMediaPicked(
                TregoAttachmentUpload(
                    data: data,
                    filename: filename,
                    mimeType: "image/jpeg"
                )
            )
        }
    }
}

private struct TregoDocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (TregoAttachmentUpload) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.content, .data], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let parent: TregoDocumentPicker

        init(parent: TregoDocumentPicker) {
            self.parent = parent
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            defer { parent.dismiss() }
            guard let url = urls.first else { return }

            let startedAccess = url.startAccessingSecurityScopedResource()
            defer {
                if startedAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            guard let data = try? Data(contentsOf: url) else { return }
            let ext = url.pathExtension
            let type = UTType(filenameExtension: ext)

            parent.onDocumentPicked(
                TregoAttachmentUpload(
                    data: data,
                    filename: url.lastPathComponent.isEmpty ? "attachment" : url.lastPathComponent,
                    mimeType: type?.preferredMIMEType ?? "application/octet-stream"
                )
            )
        }
    }
}

private struct TregoSafariSheet: UIViewControllerRepresentable {
    let urlString: String

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let url = URL(string: urlString) ?? URL(string: "https://www.tregos.store")!
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

private struct TregoActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

@MainActor
private final class TregoSpeechRecognizer: ObservableObject {
    @Published private(set) var isRecording = false
    private(set) var authorizationDenied = false

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "sq-AL")) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func start(onResult: @escaping (String, Bool) -> Void) async -> Bool {
        stop()

        let speechGranted = await requestSpeechAuthorization()
        let microphoneGranted = await requestMicrophoneAuthorization()

        guard speechGranted, microphoneGranted, let recognizer, recognizer.isAvailable else {
            authorizationDenied = !(speechGranted && microphoneGranted)
            return false
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = audioEngine.inputNode
            inputNode.removeTap(onBus: 0)
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }

                if let transcript = result?.bestTranscription.formattedString {
                    Task { @MainActor in
                        onResult(transcript, result?.isFinal ?? false)
                    }
                }

                if result?.isFinal == true || error != nil {
                    Task { @MainActor in
                        self.stop()
                    }
                }
            }
            return true
        } catch {
            stop()
            return false
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
        }
    }

    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

private enum TregoNativeTheme {
    static let accent = Color(red: 1.0, green: 0.435, blue: 0.094)
    static let accentStrong = Color(red: 0.95, green: 0.396, blue: 0.133)
    static let primaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(white: 0.97, alpha: 1)
        : UIColor(red: 0.13, green: 0.15, blue: 0.2, alpha: 1)
    })
    static let secondaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(white: 0.82, alpha: 1)
        : UIColor(red: 0.33, green: 0.37, blue: 0.45, alpha: 1)
    })
    static let accentBadgeSurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(red: 1.0, green: 0.435, blue: 0.094, alpha: 0.24)
        : UIColor(red: 1.0, green: 0.91, blue: 0.82, alpha: 1)
    })
    static let softAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(red: 1.0, green: 0.435, blue: 0.094, alpha: 0.18)
        : UIColor(red: 1.0, green: 0.953, blue: 0.918, alpha: 1)
    })
    static let systemBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor.black
        : UIColor.white
    })
    static let cardSurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.09, green: 0.102, blue: 0.129, alpha: 1)
        : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
    })
    static let mutedSurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.114, green: 0.133, blue: 0.169, alpha: 1)
        : UIColor(red: 0.984, green: 0.984, blue: 0.984, alpha: 1)
    })
    static let border = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(white: 1, alpha: 0.1)
        : UIColor(red: 0.898, green: 0.906, blue: 0.922, alpha: 1)
    })
    static let background = LinearGradient(
        colors: [
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                ? UIColor.black
                : UIColor.white
            }),
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                ? UIColor.black
                : UIColor.white
            }),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let cardFill = AnyShapeStyle(cardSurface)
    static let cardRadius: CGFloat = 16
    static let compactRadius: CGFloat = 12
}

enum TregoNativeProductCatalog {
    static let sections: [(String, String)] = [
        ("clothing", "Veshje"),
        ("cosmetics", "Kozmetika"),
        ("home", "Shtepia"),
        ("sport", "Sport"),
        ("technology", "Teknologji"),
    ]

    static let audiencesBySection: [String: [(String, String, String)]] = [
        "clothing": [
            ("men", "Veshje per meshkuj", "clothing-men"),
            ("women", "Veshje per femra", "clothing-women"),
            ("kids", "Veshje per femije", "clothing-kids"),
            ("babies", "Veshje per beba", "clothing-babies"),
        ],
        "cosmetics": [
            ("men", "Kozmetike per meshkuj", "cosmetics-men"),
            ("women", "Kozmetike per femra", "cosmetics-women"),
        ],
    ]

    static let productTypesByCategory: [String: [(String, String)]] = [
        "clothing-men": [("tshirt","Maice"),("shirt","Kemishe"),("pants","Pantallona"),("jeans","Xhinse"),("shorts","Pantallona te shkurta"),("hoodie","Duks"),("sweater","Pulover"),("jacket","Jakne"),("coat","Pallto"),("tracksuit","Trenerke"),("underwear","Te brendshme"),("pajamas","Pizhame"),("socks","Corape"),("shoes","Kepuce")],
        "clothing-women": [("tshirt","Maice"),("blouse","Bluze"),("pants","Pantallona"),("jeans","Xhinse"),("shorts","Pantallona te shkurta"),("dress","Fustan"),("skirt","Fund"),("hoodie","Duks"),("sweater","Pulover"),("jacket","Jakne"),("coat","Pallto"),("tracksuit","Trenerke"),("underwear","Te brendshme"),("pajamas","Pizhame"),("shoes","Kepuce")],
        "clothing-kids": [("tshirt","Maice"),("pants","Pantallona"),("jeans","Xhinse"),("shorts","Pantallona te shkurta"),("hoodie","Duks"),("sweater","Pulover"),("jacket","Jakne"),("tracksuit","Trenerke"),("pajamas","Pizhame"),("shoes","Kepuce")],
        "clothing-babies": [("bodysuit","Bodysuit"),("onesie","Kompleti per bebe"),("baby-pants","Pantallona per bebe"),("baby-set","Set per bebe"),("baby-pajamas","Pizhame per bebe"),("baby-jacket","Jakne per bebe")],
        "cosmetics-men": [("face-cream","Krem per fytyre"),("body-cream","Krem per trup"),("hand-cream","Krem per duar"),("foot-cream","Krem per kembe"),("hair-cream","Krem per floke"),("shampoo","Shampo"),("conditioner","Balsam"),("shower-gel","Gjel per dush"),("hand-soap","Sapun per duar"),("face-cleanser","Pastrues per fytyre"),("deodorant","Deodorant"),("perfume","Parfum"),("hair-gel","Xhel per floke"),("hair-oil","Vaj per floke"),("toothpaste","Paste dhembesh")],
        "cosmetics-women": [("face-cream","Krem per fytyre"),("body-cream","Krem per trup"),("hand-cream","Krem per duar"),("foot-cream","Krem per kembe"),("hair-cream","Krem per floke"),("shampoo","Shampo"),("conditioner","Balsam"),("shower-gel","Gjel per dush"),("hand-soap","Sapun per duar"),("face-cleanser","Pastrues per fytyre"),("deodorant","Deodorant"),("perfume","Parfum"),("hair-gel","Xhel per floke"),("hair-oil","Vaj per floke"),("makeup","Makeup"),("lipstick","Buzekuq"),("nail-care","Kujdes per thonj")],
        "home": [("table","Tavoline"),("chair","Karrige"),("sofa","Divan"),("bed","Krevat"),("mattress","Dyshek"),("wardrobe","Dollap"),("desk","Tavoline pune"),("shelf","Raft"),("lamp","Llambe"),("carpet","Tepih"),("curtain","Perde"),("mirror","Pasqyre"),("pillow","Jastek"),("blanket","Batanije"),("cookware","Ene kuzhine"),("plate-set","Set pjatash")],
        "sport": [("sneakers","Patika"),("sports-tshirt","Maice sportive"),("leggings","Leggings"),("tracksuit","Trenerke"),("ball","Top"),("racket","Raket"),("dumbbells","Pesha"),("yoga-mat","Yoga mat"),("sports-bag","Cante sportive"),("gloves","Doreza sportive"),("water-bottle","Shishe uji")],
        "technology": [("phone","Telefon"),("laptop","Laptop"),("pc","PC"),("tablet","Tablet"),("headphones","Degjuese"),("speaker","Boks"),("smartwatch","Smartwatch"),("keyboard","Tastiere"),("mouse","Mouse"),("monitor","Monitor"),("charger","Karikues"),("cable","Kabllo"),("power-bank","Power bank"),("router","Router"),("microphone","Mikrofon")],
    ]

    static let colors: [(String, String)] = [
        ("bardhe","Bardhe"),("zeze","Zeze"),("gri","Gri"),("beige","Bezh"),("kafe","Kafe"),("kuqe","Kuqe"),("roze","Roze"),("vjollce","Vjollce"),("blu","Blu"),("gjelber","Gjelber"),("verdhe","Verdhe"),("portokalli","Portokalli"),("argjend","Argjend"),("ari","Ari"),("krem","Krem"),("shume-ngjyra","Shume ngjyra")
    ]

    static let sizeOptions: [(String, String)] = [
        ("XS","XS"),("S","S"),("M","M"),("L","L"),("XL","XL"),("XXL","XXL"),("XXXL","XXXL")
    ]

    static let amountUnitOptions: [(String, String)] = [("ml","ML"),("l","L")]

    static var sectionOptions: [(String, String)] { sections }
    static var colorOptions: [(String, String)] { colors }

    static func sectionLabel(for section: String) -> String {
        sections.first(where: { $0.0 == section })?.1 ?? "Zgjidh seksionin"
    }

    static func sectionSupportsAudience(_ section: String) -> Bool {
        audiencesBySection[section]?.isEmpty == false
    }

    static func audienceOptions(for section: String) -> [(String, String)] {
        (audiencesBySection[section] ?? []).map { ($0.0, $0.1) }
    }

    static func audienceLabel(section: String, audience: String) -> String {
        (audiencesBySection[section] ?? []).first(where: { $0.0 == audience })?.1 ?? "Zgjidh audience"
    }

    static func category(for section: String, audience: String) -> String {
        if let category = (audiencesBySection[section] ?? []).first(where: { $0.0 == audience })?.2 {
            return category
        }
        return section
    }

    static func section(for category: String) -> String {
        if category.hasPrefix("clothing-") { return "clothing" }
        if category.hasPrefix("cosmetics-") { return "cosmetics" }
        return category
    }

    static func audience(for category: String) -> String {
        for (_, audiences) in audiencesBySection {
            if let audience = audiences.first(where: { $0.2 == category })?.0 {
                return audience
            }
        }
        return ""
    }

    static func productTypeOptions(section: String, audience: String) -> [(String, String)] {
        productTypesByCategory[category(for: section, audience: audience)] ?? []
    }

    static func productTypeLabel(for productType: String) -> String {
        for (_, values) in productTypesByCategory {
            if let label = values.first(where: { $0.0 == productType })?.1 {
                return label
            }
        }
        return "Zgjidh llojin"
    }

    static func colorLabel(for color: String) -> String {
        colors.first(where: { $0.0 == color })?.1 ?? "Zgjidh ngjyren"
    }

    static func requiresSize(section: String) -> Bool {
        section == "clothing"
    }

    static func supportsPackageAmount(section: String) -> Bool {
        section == "cosmetics"
    }
}

private enum TregoFormatting {
    static func price(_ value: Double) -> String {
        String(format: "%.2f €", value)
    }
}

private struct TregoPrimaryButtonStyle: ButtonStyle {
    var tint: Color = TregoNativeTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(tint.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct TregoSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color.primary.opacity(0.86))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(TregoNativeTheme.cardSurface.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(TregoNativeTheme.border, lineWidth: 0.8)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct TregoMiniButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(configuration.isPressed ? 0.82 : 1), in: Capsule())
    }
}

private struct TregoMiniOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.primary.opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(TregoNativeTheme.cardSurface.opacity(configuration.isPressed ? 0.72 : 1), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(TregoNativeTheme.border, lineWidth: 0.8)
            }
    }
}

private struct TregoMiniIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.primary.opacity(0.78))
            .background(
                Circle()
                    .fill(TregoNativeTheme.cardSurface.opacity(configuration.isPressed ? 0.72 : 1))
            )
    }
}

private struct TregoCircularAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(TregoNativeTheme.accent.opacity(configuration.isPressed ? 0.82 : 1), in: Circle())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

private struct TregoDangerButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(colorScheme == .dark ? Color.red.opacity(0.95) : Color.red.opacity(0.82))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(TregoNativeTheme.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.red.opacity(configuration.isPressed ? 0.1 : 0.06))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.red.opacity(colorScheme == .dark ? 0.34 : 0.22), lineWidth: 0.9)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

private enum TregoNativeFormatting {
    private static let storageFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let readableFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sq_AL")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let storageDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let isoDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoDateTimeFormatterWithoutFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let readableDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sq_AL")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let messageTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sq_AL")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let defaultBirthDate: Date = storageFormatter.date(from: "2000-01-01") ?? Date()

    static func optionalDate(fromStorage rawValue: String?) -> Date? {
        guard let rawValue, !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        if let date = storageFormatter.date(from: rawValue) {
            return date
        }
        let prefix = String(rawValue.replacingOccurrences(of: "T", with: " ").prefix(10))
        return storageFormatter.date(from: prefix)
    }

    static func date(fromStorage rawValue: String?) -> Date {
        guard let date = optionalDate(fromStorage: rawValue) else {
            return defaultBirthDate
        }
        return date
    }

    static func storageDateString(from date: Date) -> String {
        storageFormatter.string(from: date)
    }

    static func readableDate(_ rawValue: String?) -> String {
        guard let rawValue, !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Sot"
        }

        if let date = storageFormatter.date(from: rawValue) {
            return readableFormatter.string(from: date)
        }

        let trimmed = rawValue.replacingOccurrences(of: "T", with: " ")
        let prefix = String(trimmed.prefix(10))
        if let date = storageFormatter.date(from: prefix) {
            return readableFormatter.string(from: date)
        }

        return rawValue
    }

    static func optionalDateTime(from rawValue: String?) -> Date? {
        guard let rawValue, !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        if let date = isoDateTimeFormatter.date(from: rawValue) {
            return date
        }
        if let date = isoDateTimeFormatterWithoutFraction.date(from: rawValue) {
            return date
        }

        let normalized = rawValue.replacingOccurrences(of: "T", with: " ").replacingOccurrences(of: "Z", with: "")
        if let date = storageDateTimeFormatter.date(from: normalized) {
            return date
        }

        return optionalDate(fromStorage: rawValue)
    }

    static func readableDateTime(_ rawValue: String?) -> String {
        guard let rawValue, !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Pa kohe"
        }
        guard let date = optionalDateTime(from: rawValue) else {
            return rawValue
        }
        return readableDateTimeFormatter.string(from: date)
    }

    static func readableChatSwipeTimestamp(_ rawValue: String?) -> String {
        guard let rawValue, !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Pa kohe"
        }
        guard let date = optionalDateTime(from: rawValue) else {
            return rawValue
        }

        if Date().timeIntervalSince(date) < 86_400 {
            return messageTimeFormatter.string(from: date)
        }

        return readableDateTimeFormatter.string(from: date)
    }

    static func readableMessageTime(_ rawValue: String?) -> String {
        guard let rawValue, !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        guard let date = optionalDateTime(from: rawValue) else {
            return rawValue
        }
        if Calendar.current.isDateInToday(date) {
            return messageTimeFormatter.string(from: date)
        }
        return readableFormatter.string(from: date)
    }

    static func firstName(from fullName: String?) -> String {
        guard let first = fullName?.split(separator: " ").first else { return "" }
        return String(first)
    }

    static func lastName(from fullName: String?) -> String {
        let parts = (fullName ?? "").split(separator: " ")
        guard parts.count > 1 else { return "" }
        return parts.dropFirst().joined(separator: " ")
    }

    static func genderPickerValue(from rawValue: String?) -> String {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "mashkull", "male":
            return "mashkull"
        case "femer", "female":
            return "femer"
        default:
            return "femer"
        }
    }

    static func returnStatusLabel(_ rawValue: String?) -> String {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "requested":
            return "Kerkese e derguar"
        case "approved":
            return "E aprovuar"
        case "received":
            return "Produkti u pranua"
        case "refunded":
            return "E rimbursuar"
        case "rejected":
            return "E refuzuar"
        default:
            return "Ne proces"
        }
    }

    static func fulfillmentStatusLabel(_ rawValue: String?) -> String {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "pending_confirmation":
            return "Ne pritje"
        case "confirmed":
            return "E konfirmuar"
        case "packed":
            return "E paketuar"
        case "shipped":
            return "Ne transport"
        case "delivered":
            return "E dorezuar"
        case "cancelled":
            return "E anuluar"
        case "returned":
            return "E kthyer"
        default:
            return "Ne proces"
        }
    }
}
