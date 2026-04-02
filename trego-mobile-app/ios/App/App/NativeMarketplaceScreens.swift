import SwiftUI
import UIKit
import AVFoundation
import Speech
import AuthenticationServices
import SafariServices

struct TregoNativeRootView: View {
    @StateObject private var store = TregoNativeAppStore()
    @State private var tabBarScrollProgress: CGFloat = 0

    var body: some View {
        rootTabs
        .background(TregoNativeTheme.background.ignoresSafeArea())
        .sheet(item: $store.authRoute) { route in
            NavigationView {
                TregoAuthSheetView(store: store, route: route)
            }
            .navigationViewStyle(.stack)
            .tregoPresentationDragIndicatorVisible()
        }
        .sheet(item: $store.selectedProduct) { product in
            NavigationView {
                TregoProductDetailView(store: store, product: product)
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $store.selectedConversation) { conversation in
            NavigationView {
                TregoConversationScreen(store: store, conversation: conversation)
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $store.selectedBusiness) { selection in
            NavigationView {
                TregoPublicBusinessScreen(store: store, selection: selection)
            }
            .navigationViewStyle(.stack)
        }
        .overlay(alignment: .top) {
            if let toast = store.toastMessage {
                TregoToastView(message: toast)
                    .padding(.top, 18)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .alert("TREGO", isPresented: Binding(
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
            await store.bootstrap()
        }
        .onChange(of: store.selectedTab) { newValue in
            if newValue != .home && newValue != .kerko {
                withAnimation(.easeOut(duration: 0.22)) {
                    tabBarScrollProgress = 0
                }
            }
            Task {
                await handleTabChange(for: newValue)
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

            Tab("Wishlist", systemImage: LiquidGlassTab.wishlist.symbolName, value: LiquidGlassTab.wishlist) {
                TregoWishlistScreen(store: store)
            }

            Tab("Cart", systemImage: LiquidGlassTab.cart.symbolName, value: LiquidGlassTab.cart) {
                TregoCartScreen(store: store)
            }

            Tab("Llogaria", systemImage: LiquidGlassTab.llogaria.symbolName, value: LiquidGlassTab.llogaria) {
                TregoAccountScreen(store: store)
            }

            Tab(value: LiquidGlassTab.kerko, role: .search) {
                TregoSearchScreen(store: store, tabBarScrollProgress: $tabBarScrollProgress)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    private var legacyRootTabs: some View {
        TabView(selection: $store.selectedTab) {
            TregoHomeScreen(store: store, tabBarScrollProgress: $tabBarScrollProgress)
                .tabItem {
                    Label("Home", systemImage: LiquidGlassTab.home.symbolName)
                }
                .tag(LiquidGlassTab.home)

            TregoWishlistScreen(store: store)
                .tabItem {
                    Label("Wishlist", systemImage: LiquidGlassTab.wishlist.symbolName)
                }
                .tag(LiquidGlassTab.wishlist)

            TregoCartScreen(store: store)
                .tabItem {
                    Label("Cart", systemImage: LiquidGlassTab.cart.symbolName)
                }
                .tag(LiquidGlassTab.cart)

            TregoAccountScreen(store: store)
                .tabItem {
                    Label("Llogaria", systemImage: LiquidGlassTab.llogaria.symbolName)
                }
                .tag(LiquidGlassTab.llogaria)

            TregoSearchScreen(store: store, tabBarScrollProgress: $tabBarScrollProgress)
                .tabItem {
                    Label("Kerko", systemImage: LiquidGlassTab.kerko.symbolName)
                }
                .tag(LiquidGlassTab.kerko)
        }
    }

    private func handleTabChange(for tab: LiquidGlassTab) async {
        switch tab {
        case .home:
            await store.loadHomeIfNeeded()
        case .kerko:
            await store.performSearch(forceProductsFallback: true)
        case .wishlist:
            await store.loadWishlist()
        case .cart:
            await store.loadCart()
        case .llogaria:
            await store.refreshSession()
        }
    }
}

private struct TregoHomeScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    @Binding var tabBarScrollProgress: CGFloat

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
                    TregoGlassSearchBar(
                        text: $store.searchQuery,
                        placeholder: "Kerko produktet",
                        onSubmit: {
                            Task {
                                await store.openSearch(with: store.searchQuery)
                            }
                        },
                        onImagePicked: { upload in
                            Task {
                                await store.performImageSearch(upload: upload)
                            }
                        }
                    )

                    if !promoCards.isEmpty {
                        HStack(spacing: 14) {
                            ForEach(promoCards) { card in
                                TregoPromoCard(card: card) {
                                    store.selectedProduct = card.product
                                }
                            }
                        }
                    }

                    TregoSectionHeader(title: "Produktet")

                    if store.homeLoading && store.homeProducts.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if store.homeProducts.isEmpty {
                        TregoEmptyStateView(
                            title: "Nuk ka produkte",
                            subtitle: "Produktet do te shfaqen ketu sapo backend-i te ktheje te dhena."
                        )
                    } else {
                        LazyVGrid(columns: grid, spacing: 14) {
                            ForEach(store.homeProducts) { product in
                                TregoProductCard(
                                    product: product,
                                    isWishlisted: store.isWishlisted(productId: product.id),
                                    onTap: { store.selectedProduct = product },
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
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 132)
            }
            .coordinateSpace(name: "trego-home-scroll")
            .onAppear {
                tabBarScrollProgress = 0
            }
            .onPreferenceChange(TregoTabBarScrollPreferenceKey.self) { value in
                let normalized = min(max(value / 240, 0), 1)
                if abs(tabBarScrollProgress - normalized) > 0.01 {
                    tabBarScrollProgress = normalized
                }
            }
            .background(TregoNativeTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }

    private var promoCards: [TregoPromoCardItem] {
        var cards: [TregoPromoCardItem] = []

        if let trending = store.homeProducts.sorted(by: promoScore).first {
            cards.append(TregoPromoCardItem(kind: .trending, product: trending))
        }

        if let sale = store.homeProducts.first(where: { ($0.compareAtPrice ?? 0) > ($0.price ?? 0) }) {
            cards.append(TregoPromoCardItem(kind: .sale, product: sale))
        }

        return cards
    }

    private func promoScore(lhs: TregoProduct, rhs: TregoProduct) -> Bool {
        let leftScore = Double(lhs.buyersCount ?? 0) * 2.5 + Double(lhs.reviewCount ?? 0) + Double(lhs.averageRating ?? 0)
        let rightScore = Double(rhs.buyersCount ?? 0) * 2.5 + Double(rhs.reviewCount ?? 0) + Double(rhs.averageRating ?? 0)
        return leftScore > rightScore
    }
}

private struct TregoSearchScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    @Binding var tabBarScrollProgress: CGFloat

    private let grid = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    @State private var searchTask: Task<Void, Never>?
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

                VStack(alignment: .leading, spacing: 18) {
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

                    if store.searchLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 48)
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
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 132)
            }
            .coordinateSpace(name: "trego-search-scroll")
            .onAppear {
                tabBarScrollProgress = 0
            }
            .onChange(of: store.searchQuery) { newValue in
                guard #available(iOS 26.0, *) else { return }
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 260_000_000)
                    guard !Task.isCancelled else { return }
                    await store.performSearch(forceProductsFallback: true)
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
                    await store.performSearch(forceProductsFallback: true)
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
            .sheet(item: $pickerSource) { source in
                TregoImagePicker(source: source) { upload in
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
                            Image(systemName: resolvedVisualSearchSymbolName)
                                .font(.system(size: 17, weight: .semibold))
                                .offset(y: -5)
                                .frame(width: 34, height: 42, alignment: .top)
                                .contentShape(Rectangle())
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
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    TregoTopTitle(title: "Wishlist")

                    if !store.sessionLoaded || store.wishlistLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                    } else if store.user == nil {
                        TregoGuestCardView(
                            title: "Kycu ose krijo llogari",
                            subtitle: "Ruaj produktet qe i pelqen dhe kthehu te to sa here te duash.",
                            primaryTitle: "Log in",
                            secondaryTitle: "Sign up",
                            onPrimary: { store.requireAuthentication(defaultRoute: .login) },
                            onSecondary: { store.requireAuthentication(defaultRoute: .signup) }
                        )
                    } else if store.wishlist.isEmpty {
                        TregoEmptyStateView(
                            title: "Wishlist eshte bosh",
                            subtitle: "Ruaj produkte nga Home ose Search dhe do te dalin ketu."
                        )
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
            .background(TregoNativeTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                await store.loadWishlist()
            }
        }
        .navigationViewStyle(.stack)
    }
}

private struct TregoCartScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    @State private var isCheckoutPresented = false

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    TregoTopTitle(title: "Cart")

                    if !store.sessionLoaded || store.cartLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                    } else if store.user == nil {
                        TregoGuestCardView(
                            title: "Kycu ose krijo llogari",
                            subtitle: "Ruaj artikujt ne karte dhe vazhdo checkout-in me vone.",
                            primaryTitle: "Log in",
                            secondaryTitle: "Sign up",
                            onPrimary: { store.requireAuthentication(defaultRoute: .login) },
                            onSecondary: { store.requireAuthentication(defaultRoute: .signup) }
                        )
                    } else if store.cart.isEmpty {
                        TregoEmptyStateView(
                            title: "Karta eshte bosh",
                            subtitle: "Shto produkte nga Home ose Search dhe do te dalin ketu."
                        )
                    } else {
                        VStack(spacing: 14) {
                            ForEach(store.cart) { item in
                                TregoCartRow(item: item) {
                                    Task {
                                        await store.removeFromCart(productId: item.productId ?? item.id)
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Totali")
                                .font(.system(size: 15, weight: .semibold))
                            Text(totalText)
                                .font(.system(size: 26, weight: .bold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                        Button {
                            isCheckoutPresented = true
                        } label: {
                            Label("Vazhdo ne checkout", systemImage: "creditcard")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(TregoPrimaryButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 132)
            }
            .background(TregoNativeTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                await store.loadCart()
            }
        }
        .sheet(isPresented: $isCheckoutPresented) {
            NavigationView {
                TregoCheckoutScreen(store: store, cartItems: store.cart)
            }
            .navigationViewStyle(.stack)
        }
        .navigationViewStyle(.stack)
    }

    private var totalText: String {
        let total = store.cart.reduce(0.0) { partial, item in
            partial + (Double(item.quantity ?? 1) * (item.price ?? 0))
        }
        return TregoFormatting.price(total)
    }
}

private struct TregoAccountScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    TregoTopTitle(title: store.user == nil ? "Kyçu" : "Llogaria")

                    if !store.sessionLoaded {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                    } else if let user = store.user {
                        TregoUserCard(user: user)

                        NavigationLink(destination: TregoPersonalDataScreen(store: store)) {
                            TregoFeatureLinkRow(title: "Te dhenat personale", subtitle: "Emri, fotoja, data e lindjes dhe profili")
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: TregoChangePasswordScreen(store: store)) {
                            TregoFeatureLinkRow(title: "Ndrysho fjalekalimin", subtitle: "Perditeso fjalekalimin dhe sigurine e llogarise")
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: TregoAddressesScreen(store: store)) {
                            TregoFeatureLinkRow(title: "Adresat", subtitle: "Ruaj adresen default per porosi dhe dergesa")
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: TregoNotificationsScreen(store: store)) {
                            TregoFeatureLinkRow(title: "Njoftimet", subtitle: "Porosi, mesazhe, verifikime dhe rikthime")
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: TregoReturnsScreen(store: store)) {
                            TregoFeatureLinkRow(title: "Refund / Returne", subtitle: "Shiko dhe menaxho kerkesat e kthimit")
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: TregoAppSettingsScreen(store: store)) {
                            TregoFeatureLinkRow(title: "App settings", subtitle: "Theme, gjuha, valuta dhe privatësia")
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: TregoOrdersScreen(store: store)) {
                            TregoFeatureLinkRow(title: "Orders", subtitle: "Shiko porosite dhe statuset e tyre")
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: TregoMessagesScreen(store: store)) {
                            TregoFeatureLinkRow(title: "Messages", subtitle: "Komuniko me bizneset dhe support")
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: TregoBusinessesExplorerScreen(store: store)) {
                            TregoFeatureLinkRow(title: "Bizneset", subtitle: "Zbulo dyqanet publike, ndiqi ose dergo mesazh")
                        }
                        .buttonStyle(.plain)

                        if user.role == "business" {
                            NavigationLink(destination: TregoBusinessHubScreen(store: store)) {
                                TregoFeatureLinkRow(title: "Business Studio", subtitle: "Produktet, porosite, promocionet dhe pulse i biznesit")
                            }
                            .buttonStyle(.plain)
                        }

                        if user.role == "admin" {
                            NavigationLink(destination: TregoAdminControlScreen(store: store)) {
                                TregoFeatureLinkRow(title: "Admin Control", subtitle: "Users, biznese, raporte dhe porosi")
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            Task { await store.logout() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 15, weight: .bold))
                                Text("Log out")
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
                    } else {
                        TregoAccountLoginPromptView(store: store)

                        NavigationLink(destination: TregoBusinessesExplorerScreen(store: store)) {
                            TregoFeatureLinkRow(title: "Bizneset", subtitle: "Shiko dyqanet publike dhe produktet e tyre")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 132)
            }
            .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                await store.refreshSession()
            }
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationViewStyle(.stack)
    }
}

private struct TregoAppSettingsScreen: View {
    @ObservedObject var store: TregoNativeAppStore

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

                TregoSettingsSelectionCard(
                    title: "Privatesia",
                    subtitle: "Kontrolli i rekomandimeve dhe tracking-ut",
                    icon: "lock.shield",
                    currentValue: label(for: store.appSettings.privacyMode, options: privacyOptions),
                    options: privacyOptions
                ) { store.updateAppPrivacyMode($0) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .padding(.bottom, 90)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("App settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func label(for value: String, options: [(String, String)]) -> String {
        options.first(where: { $0.0 == value })?.1 ?? value.capitalized
    }
}

private struct TregoBusinessesExplorerScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    @State private var searchText = ""

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                TregoNoticeCard(
                    title: "Bizneset",
                    subtitle: "Shfleto dyqanet publike, ndiqi dhe hap profilin e tyre per te pare produktet."
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Kerko biznes")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    TextField("Shkruaj emrin e biznesit ose qytetin", text: $searchText)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(.white.opacity(0.34), lineWidth: 0.8)
                        }
                }

                if store.publicBusinessesLoading && store.publicBusinesses.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if filteredBusinesses.isEmpty {
                    TregoEmptyStateView(
                        title: "Nuk ka biznese",
                        subtitle: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Bizneset publike do te shfaqen ketu sapo te jene aktive."
                            : "Nuk u gjet asnje biznes per kerkimin aktual."
                    )
                } else {
                    ForEach(filteredBusinesses) { business in
                        TregoPublicBusinessExplorerCard(
                            business: business,
                            onOpen: {
                                store.openBusinessProfile(id: business.id)
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
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .padding(.bottom, 90)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Bizneset")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if store.publicBusinesses.isEmpty {
                await store.loadPublicBusinesses()
            }
        }
        .refreshable {
            await store.loadPublicBusinesses(force: true)
        }
    }

    private var filteredBusinesses: [TregoPublicBusinessProfile] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            return store.publicBusinesses
        }

        return store.publicBusinesses.filter { business in
            let haystack = [
                business.businessName ?? "",
                business.businessDescription ?? "",
                business.city ?? "",
            ]
            .joined(separator: " ")
            .lowercased()

            return haystack.contains(trimmed)
        }
    }
}

private struct TregoPersonalDataScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TregoNativeAppStore

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var birthDate = TregoNativeFormatting.defaultBirthDate
    @State private var gender = "female"
    @State private var remoteProfileImagePath = ""
    @State private var selectedPhotoUpload: TregoImageSearchUpload?
    @State private var pickerSource: TregoImagePickerSource?
    @State private var showsPhotoOptions = false
    @State private var saveMessage = ""
    @State private var saveMessageTone: TregoStatusMessageTone?
    @State private var deletePassword = ""
    @State private var deleteMessage = ""
    @State private var deleteMessageTone: TregoStatusMessageTone?
    @State private var isSaving = false
    @State private var isDeleting = false

    private let infoColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if let user = store.user {
                    TregoNoticeCard(
                        title: "Profili yt",
                        subtitle: "Ndrysho foton, emrin, daten e lindjes dhe detajet baze. Ndryshimet ruhen direkt ne llogarine tende."
                    )

                    TregoProfileImageEditorCard(
                        title: user.fullName ?? "Perdoruesi",
                        subtitle: user.email ?? user.phoneNumber ?? "TREGO account",
                        imagePath: remoteProfileImagePath,
                        upload: selectedPhotoUpload,
                        onChoosePhoto: { showsPhotoOptions = true },
                        onRemovePhoto: {
                            selectedPhotoUpload = nil
                        }
                    )

                    LazyVGrid(columns: infoColumns, spacing: 12) {
                        TregoInfoTile(title: "Email", value: user.email ?? "-")
                        TregoInfoTile(title: "Telefoni", value: user.phoneNumber ?? "-")
                    }

                    if let tone = saveMessageTone, !saveMessage.isEmpty {
                        TregoStatusMessageCard(message: saveMessage, tone: tone)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        TregoSectionHeader(title: "Detajet personale")

                        TregoInputCard(title: "Emri", text: $firstName, placeholder: "Shkruaj emrin")
                        TregoInputCard(title: "Mbiemri", text: $lastName, placeholder: "Shkruaj mbiemrin")
                        TregoDateInputCard(title: "Data e lindjes", date: $birthDate)
                        TregoGenderPicker(selected: $gender)

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

                    VStack(alignment: .leading, spacing: 12) {
                        TregoSectionHeader(title: "Danger zone")
                        Text("Per ta fshire llogarine, shkruaj fjalekalimin dhe konfirmo. Ky veprim nuk kthehet prapa.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)

                        TregoSecureInputCard(title: "Konfirmo me fjalekalim", text: $deletePassword)

                        if let tone = deleteMessageTone, !deleteMessage.isEmpty {
                            TregoStatusMessageCard(message: deleteMessage, tone: tone)
                        }

                        Button {
                            Task { await deleteAccount() }
                        } label: {
                            if isDeleting {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Fshi llogarine")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(TregoDangerButtonStyle())
                    }
                } else {
                    TregoScreenGuestNotice(
                        title: "Kyçu për te dhenat personale",
                        subtitle: "Kjo faqe hapet pasi të kycësh llogarinë tende."
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .padding(.bottom, 90)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Te dhenat personale")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Foto e profilit", isPresented: $showsPhotoOptions) {
            Button("Take photo") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    pickerSource = .camera
                } else {
                    store.globalMessage = "Kamera nuk eshte e disponueshme tani."
                }
            }
            Button("Choose from library") {
                pickerSource = .photoLibrary
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $pickerSource) { source in
            TregoImagePicker(source: source) { upload in
                selectedPhotoUpload = upload
            }
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
        await store.refreshSession()
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

                    TregoSecureInputCard(title: "Fjalëkalimi aktual", text: $currentPassword)
                    TregoSecureInputCard(title: "Fjalëkalimi i ri", text: $newPassword)
                    TregoSecureInputCard(title: "Konfirmo fjalëkalimin e ri", text: $confirmPassword)

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
                        TregoInputCard(title: "Adresa e vendbanimit", text: $addressLine, placeholder: "Rruga, numri, hyrja")
                        TregoInputCard(title: "Qyteti", text: $city, placeholder: "Shkruaj qytetin")
                        TregoInputCard(title: "Shteti", text: $country, placeholder: "Shkruaj shtetin")
                        TregoInputCard(title: "Zip code", text: $zipCode, placeholder: "Shkruaj zip code")
                        TregoInputCard(title: "Numri i telefonit", text: $phoneNumber, keyboardType: .phonePad, placeholder: "+383 44 123 456")

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
        .task {
            await loadAddress()
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

private struct TregoNotificationsScreen: View {
    @ObservedObject var store: TregoNativeAppStore

    @State private var notifications: [TregoNotificationItem] = []
    @State private var unreadCount = 0
    @State private var message = ""
    @State private var messageTone: TregoStatusMessageTone?
    @State private var isLoading = false

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
                                TregoNotificationCard(notification: notification) {
                                    notificationAction(for: notification)
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
        .task {
            await loadNotifications()
        }
        .refreshable {
            await loadNotifications()
        }
    }

    @ViewBuilder
    private func notificationAction(for notification: TregoNotificationItem) -> some View {
        let href = (notification.href ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if href.contains("/refund-returne") {
            NavigationLink("Hape", destination: TregoReturnsScreen(store: store))
                .buttonStyle(.plain)
                .foregroundStyle(TregoNativeTheme.accent)
        } else if href.contains("/porosite") {
            NavigationLink("Hape", destination: TregoOrdersScreen(store: store))
                .buttonStyle(.plain)
                .foregroundStyle(TregoNativeTheme.accent)
        } else if href.contains("/mesazhet") {
            NavigationLink("Hape", destination: TregoMessagesScreen(store: store))
                .buttonStyle(.plain)
                .foregroundStyle(TregoNativeTheme.accent)
        } else {
            EmptyView()
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
                let refreshed = await store.api.fetchNotifications()
                notifications = refreshed.notifications
                unreadCount = refreshed.unreadCount
            }
        }
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
                    imagePath: profileDraft.businessLogoPath,
                    upload: selectedUpload,
                    onChoosePhoto: { showsImageDialog = true },
                    onRemovePhoto: {
                        selectedUpload = nil
                        profileDraft.businessLogoPath = ""
                    }
                )

                TregoSectionHeader(title: "Profili")
                TregoInputCard(title: "Emri i biznesit", text: $profileDraft.businessName, placeholder: "Trego Store")
                TregoMultilineInputCard(title: "Pershkrimi", text: $profileDraft.businessDescription, placeholder: "Pershkruaj biznesin dhe produktet kryesore")
                TregoInputCard(title: "Numri i biznesit", text: $profileDraft.businessNumber, placeholder: "BK-1020", autocapitalization: .characters)
                TregoInputCard(title: "Telefoni", text: $profileDraft.phoneNumber, keyboardType: .phonePad, placeholder: "+383 44 123 456", autocapitalization: .never)
                TregoInputCard(title: "Qyteti", text: $profileDraft.city, placeholder: "Prishtine")
                TregoInputCard(title: "Adresa", text: $profileDraft.addressLine, placeholder: "Rr. Nena Tereze, nr. 12")

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

private struct TregoMessagesScreen: View {
    @ObservedObject var store: TregoNativeAppStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if store.conversationsLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else if store.conversations.isEmpty {
                    TregoEmptyStateView(
                        title: "Nuk ka biseda",
                        subtitle: "Bisedat me bizneset do te shfaqen ketu."
                    )
                } else {
                    ForEach(store.conversations) { conversation in
                        NavigationLink(destination: TregoConversationScreen(store: store, conversation: conversation)) {
                            TregoConversationRow(conversation: conversation)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .padding(.bottom, 90)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadConversations()
        }
    }
}

private struct TregoConversationScreen: View {
    @ObservedObject var store: TregoNativeAppStore
    let conversation: TregoConversation

    @State private var loadedConversation: TregoConversation?
    @State private var messages: [TregoChatMessage] = []
    @State private var draft = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && messages.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            TregoMessageBubble(message: message)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 18)
                }
            }

            HStack(spacing: 12) {
                TextField("Shkruaj mesazhin", text: $draft)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                Button {
                    Task {
                        await sendMessage()
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(TregoCircularAccentButtonStyle())
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.001))
        }
        .background(TregoNativeTheme.background.ignoresSafeArea())
        .navigationTitle(loadedConversation?.counterpartName ?? conversation.counterpartName ?? conversation.businessName ?? "Biseda")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadConversation()
        }
    }

    private func loadConversation() async {
        isLoading = true
        defer { isLoading = false }
        guard let detail = await store.api.fetchConversationDetail(id: conversation.id) else {
            return
        }
        loadedConversation = detail.conversation
        messages = detail.messages
    }

    private func sendMessage() async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        if let message = await store.api.sendMessage(conversationId: conversation.id, body: trimmed) {
            draft = ""
            messages.append(message)
        }
    }
}

private struct TregoProductDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TregoNativeAppStore
    let product: TregoProduct

    @State private var loadedProduct: TregoProduct?
    @State private var reviews: [TregoProductReview] = []
    @State private var isLoading = false
    @State private var openedConversation: TregoConversation?
    @State private var openedBusinessSelection: TregoBusinessSelection?
    @State private var isReviewComposerPresented = false
    @State private var isReportComposerPresented = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                TregoRemoteImage(imagePath: activeProduct.imageGallery?.first ?? activeProduct.imagePath)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

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
                        if let compareAt = activeProduct.compareAtPrice, compareAt > (activeProduct.price ?? 0) {
                            TregoComparePriceText(
                                value: TregoFormatting.price(compareAt),
                                font: .system(size: 14, weight: .semibold)
                            )
                        }
                    }
                    if let description = activeProduct.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.78))
                    }
                }

                if let businessName = activeProduct.businessName, !businessName.isEmpty {
                    TregoBusinessSellerCard(
                        businessName: businessName,
                        location: activeProduct.category ?? activeProduct.productType ?? "",
                        actionTitle: "Hape dyqanin",
                        secondaryTitle: "Mesazh",
                        onPrimary: {
                            if let businessId = activeProduct.businessProfileId {
                                openedBusinessSelection = TregoBusinessSelection(id: businessId)
                            }
                        },
                        onSecondary: {
                            Task { await openBusinessConversation() }
                        }
                    )
                }

                HStack(spacing: 12) {
                    Button {
                        Task { await store.toggleWishlist(for: activeProduct) }
                    } label: {
                        Label(store.isWishlisted(productId: activeProduct.id) ? "Saved" : "Wishlist", systemImage: "heart")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TregoSecondaryButtonStyle())

                    Button {
                        Task { await store.addToCart(product: activeProduct) }
                    } label: {
                        Label("Add to cart", systemImage: "cart.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TregoPrimaryButtonStyle())
                }

                HStack(spacing: 12) {
                    Button {
                        guard store.user != nil else {
                            store.requireAuthentication(defaultRoute: .login)
                            return
                        }
                        isReviewComposerPresented = true
                    } label: {
                        Label("Shkruaj review", systemImage: "star.bubble.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TregoSecondaryButtonStyle())

                    Button {
                        guard store.user != nil else {
                            store.requireAuthentication(defaultRoute: .login)
                            return
                        }
                        isReportComposerPresented = true
                    } label: {
                        Label("Raporto", systemImage: "flag.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TregoSecondaryButtonStyle())
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
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .background(TregoNativeTheme.background.ignoresSafeArea())
        .navigationTitle("Produkti")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .sheet(item: $openedBusinessSelection) { selection in
            NavigationView {
                TregoPublicBusinessScreen(store: store, selection: selection)
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $openedConversation) { conversation in
            NavigationView {
                TregoConversationScreen(store: store, conversation: conversation)
            }
            .navigationViewStyle(.stack)
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
            await loadProduct()
        }
    }

    private var activeProduct: TregoProduct {
        loadedProduct ?? product
    }

    private func loadProduct() async {
        isLoading = true
        async let detail: TregoProduct? = store.api.fetchProductDetail(id: product.id)
        async let loadedReviews: [TregoProductReview] = store.api.fetchProductReviews(id: product.id)
        loadedProduct = await detail
        reviews = await loadedReviews
        isLoading = false
    }

    private func openBusinessConversation() async {
        guard let businessId = activeProduct.businessProfileId else { return }
        guard store.user != nil else {
            store.requireAuthentication(defaultRoute: .login)
            return
        }

        let (response, conversation) = await store.api.openBusinessConversation(businessId: businessId)
        guard response.ok == true, let conversation else {
            store.globalMessage = response.message ?? "Biseda nuk u hap."
            return
        }
        openedConversation = conversation
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
    @Environment(\.dismiss) private var dismiss
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

    private let grid = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

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
                        .buttonStyle(TregoSecondaryButtonStyle())

                        Button {
                            Task { await openConversation() }
                        } label: {
                            Label("Mesazh", systemImage: "message.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(TregoPrimaryButtonStyle())
                    }

                    TregoMiniStatsGrid(items: businessStats(for: business))

                    TregoSectionHeader(title: "Produktet e dyqanit")

                    if products.isEmpty {
                        TregoEmptyStateView(
                            title: "Ky dyqan ende nuk ka produkte",
                            subtitle: "Produktet publike do te shfaqen ketu sapo biznesi te publikoje katalogun."
                        )
                    } else {
                        LazyVGrid(columns: grid, spacing: 14) {
                            ForEach(products) { product in
                                TregoProductCard(
                                    product: product,
                                    isWishlisted: store.isWishlisted(productId: product.id),
                                    onTap: { selectedProduct = product },
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
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 36)
        }
        .background(TregoNativeTheme.systemBackground.ignoresSafeArea())
        .navigationTitle("Dyqani")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
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
        async let productsTask: [TregoProduct] = store.api.fetchPublicBusinessProducts(id: selection.id)
        business = await businessTask
        products = await productsTask
        isLoading = false
    }

    private func toggleFollow() async {
        guard store.user != nil else {
            store.requireAuthentication(defaultRoute: .login)
            return
        }
        isFollowUpdating = true
        defer { isFollowUpdating = false }

        let (response, updatedBusiness) = await store.api.toggleBusinessFollow(businessId: selection.id)
        if let updatedBusiness {
            business = updatedBusiness
        }
        feedbackTone = response.ok == true ? .success : .error
        feedbackMessage = response.message ?? (response.ok == true ? "Dyqani u perditesua." : "Veprimi deshtoi.")
    }

    private func openConversation() async {
        guard store.user != nil else {
            store.requireAuthentication(defaultRoute: .login)
            return
        }

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
                    TregoInputCard(title: "Adresa", text: $addressLine, placeholder: "Rruga, numri, hyrja")
                    TregoInputCard(title: "Qyteti", text: $city, placeholder: "Shkruaj qytetin")
                    TregoInputCard(title: "Shteti", text: $country, placeholder: "Shkruaj shtetin")
                    TregoInputCard(title: "Zip code", text: $zipCode, placeholder: "Shkruaj zip code")
                    TregoInputCard(title: "Numri i telefonit", text: $phoneNumber, keyboardType: .phonePad, placeholder: "+383 44 123 456")

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
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
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

                TregoSecureInputCard(title: "Fjalekalimi i ri", text: $newPassword)
                TregoSecureInputCard(title: "Konfirmo fjalekalimin", text: $confirmPassword)

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
                    TregoInputCard(title: "Emri dhe mbiemri", text: $draft.fullName, placeholder: "Ardit Berisha")
                    TregoInputCard(title: "Email", text: $draft.email, keyboardType: .emailAddress, placeholder: "biznesi@email.com", autocapitalization: .never)
                    TregoSecureInputCard(title: "Fjalekalimi", text: $draft.password)
                } else {
                    TregoInfoTile(title: "Pronari", value: draft.fullName.isEmpty ? (existingBusiness?.ownerName ?? "-") : draft.fullName)
                    TregoInfoTile(title: "Email", value: draft.email.isEmpty ? (existingBusiness?.ownerEmail ?? "-") : draft.email)
                }

                TregoSectionHeader(title: "Profili i biznesit")
                TregoInputCard(title: "Emri i biznesit", text: $draft.businessName, placeholder: "Trego Store")
                TregoMultilineInputCard(title: "Pershkrimi", text: $draft.businessDescription, placeholder: "Pershkruaj biznesin dhe cfare shet.")
                TregoInputCard(title: "Numri i biznesit", text: $draft.businessNumber, placeholder: "BK-2026-01", autocapitalization: .characters)
                TregoInputCard(title: "Telefoni", text: $draft.phoneNumber, keyboardType: .phonePad, placeholder: "+383 44 123 456", autocapitalization: .never)
                TregoInputCard(title: "Qyteti", text: $draft.city, placeholder: "Prishtine")
                TregoInputCard(title: "Adresa", text: $draft.addressLine, placeholder: "Rr. Nena Tereze, nr. 12")

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
        switch route {
        case .login:
            TregoLoginView(store: store)
        case .signup:
            TregoSignupView(store: store)
        case .forgotPassword:
            TregoForgotPasswordView(store: store)
        }
    }
}

private struct TregoLoginView: View {
    @ObservedObject var store: TregoNativeAppStore
    @State private var identifier = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isSubmitting = false
    @State private var failedAttempts = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            TregoAuthHeader(title: "LOG IN", subtitle: "Hyni ne llogarine tuaj.")

            TextField("Email ose telefoni", text: $identifier)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(.default)
                .textContentType(.username)
                .textFieldStyle(.roundedBorder)
                .onChange(of: identifier) { _ in
                    clearFieldValidationState()
                }

            SecureField("Password", text: $password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
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
                .foregroundStyle(Color.accentColor)
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

            HStack(spacing: 6) {
                Text("Nuk keni llogari akoma?")
                    .foregroundStyle(.secondary)
                Button("Sign up") {
                    store.authRoute = .signup
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 14, weight: .medium))

            Spacer(minLength: 0)
        }
        .padding(24)
        .background(TregoNativeTheme.background.ignoresSafeArea())
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
    @State private var fullName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var birthDate = ""
    @State private var gender = "female"
    @State private var errorMessage = ""
    @State private var isSubmitting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TregoAuthHeader(title: "SIGN UP", subtitle: "Krijoni llogarine.")

                TextField("Full name", text: $fullName)
                    .textFieldStyle(.roundedBorder)

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textFieldStyle(.roundedBorder)

                TextField("Numri i telefonit", text: $phoneNumber, prompt: Text("+383 44 123 456"))
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
                    .textFieldStyle(.roundedBorder)

                TextField("Birth date", text: $birthDate, prompt: Text("2000-01-01"))
                    .textFieldStyle(.roundedBorder)

                TregoGenderPicker(selected: $gender)

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

                HStack(spacing: 6) {
                    Text("Keni llogari tashme?")
                        .foregroundStyle(.secondary)
                    Button("Log in") {
                        store.authRoute = .login
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 14, weight: .medium))
            }
            .padding(24)
            .padding(.bottom, 40)
        }
        .background(TregoNativeTheme.background.ignoresSafeArea())
    }

    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = await store.register(
            fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            birthDate: birthDate.trimmingCharacters(in: .whitespacesAndNewlines),
            gender: gender
        ) ?? ""
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TregoAuthHeader(title: "RESET", subtitle: "Kerkoni kodin dhe vendosni fjalekalimin e ri.")

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)

                if hasRequestedCode {
                    TextField("Code", text: $code)
                        .textFieldStyle(.roundedBorder)

                    SecureField("New password", text: $newPassword)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Confirm password", text: $confirmPassword)
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

                Button("Back to log in") {
                    store.authRoute = .login
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(24)
            .padding(.bottom, 40)
        }
        .background(TregoNativeTheme.background.ignoresSafeArea())
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
    @State private var fullName = ""
    @State private var identifier = ""
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var birthDate = ""
    @State private var gender = "female"
    @State private var errorMessage = ""
    @State private var isSubmitting = false
    @State private var failedAttempts = 0
    @State private var passwordPrompt = "Password"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                if mode == .signup {
                    authTextField(
                        text: $fullName,
                        prompt: "Full name"
                    )
                }

                authTextField(
                    text: $identifier,
                    prompt: mode == .login ? "Email ose telefoni" : "Email",
                    keyboardType: mode == .login ? .default : .emailAddress,
                    textContentType: mode == .login ? .username : .emailAddress
                )

                if mode == .signup {
                    authTextField(
                        text: $phoneNumber,
                        prompt: "Numri i telefonit",
                        keyboardType: .phonePad,
                        textContentType: .telephoneNumber
                    )
                }

                authSecureField(
                    text: $password,
                    prompt: passwordPrompt,
                    textContentType: mode == .login ? .password : .newPassword,
                    highlighted: failedAttempts > 0 && password.isEmpty
                )

                if mode == .signup {
                    authTextField(
                        text: $birthDate,
                        prompt: "2000-01-01"
                    )

                    TregoGenderPicker(selected: $gender)
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
            .onChange(of: fullName) { _ in
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
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(primaryButtonStroke, lineWidth: 0.95)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Text(mode == .login ? "Nuk keni llogari akoma?" : "Keni llogari tashmë?")
                    .foregroundStyle(.secondary)

                Button(mode == .login ? "Sign up" : "Log in") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        mode = mode == .login ? .signup : .login
                        errorMessage = ""
                        failedAttempts = 0
                        passwordPrompt = "Password"
                        password = ""
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(colorScheme == .dark ? Color.orange.opacity(0.94) : TregoNativeTheme.accent)
            }
            .font(.system(size: 14, weight: .medium))

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

                Button(action: handleGoogleTap) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(googleBadgeFill)
                                .frame(width: 28, height: 28)
                            Text("G")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(googleBadgeText)
                        }

                        Text("Continue with Google")
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
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(cardStrokeColor, lineWidth: 0.9)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.06), radius: 18, y: 10)
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

        errorMessage = await store.register(
            fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: identifier.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            birthDate: birthDate.trimmingCharacters(in: .whitespacesAndNewlines),
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

    private func authTextField(
        text: Binding<String>,
        prompt: String,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil
    ) -> some View {
        HStack(spacing: 0) {
            TextField("", text: text, prompt: Text(prompt).foregroundColor(.secondary))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(colorScheme == .dark ? 0.96 : 0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(fieldStrokeColor, lineWidth: 0.9)
        }
    }

    private func authSecureField(
        text: Binding<String>,
        prompt: String,
        textContentType: UITextContentType?,
        highlighted: Bool
    ) -> some View {
        HStack(spacing: 0) {
            SecureField("", text: text, prompt: Text(prompt).foregroundColor(highlighted ? .red.opacity(0.82) : .secondary))
                .textContentType(textContentType)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(colorScheme == .dark ? 0.96 : 0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(highlighted ? Color.red.opacity(0.06) : .clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(highlighted ? Color.red.opacity(0.36) : fieldStrokeColor, lineWidth: 0.9)
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

    private enum AuthMode {
        case login
        case signup
    }
}

private struct TregoTopTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(Color.primary.opacity(0.9))
    }
}

private struct TregoSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(Color.primary.opacity(0.9))
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
                Button(primaryTitle, action: onPrimary)
                    .buttonStyle(TregoPrimaryButtonStyle())
                Button(secondaryTitle, action: onSecondary)
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

private struct TregoUserCard: View {
    let user: TregoSessionUser
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(TregoNativeTheme.softAccent)
                if let url = TregoAPIClient.imageURL(from: user.profileImagePath) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: "person.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                } else {
                    Text(initials)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 68, height: 68)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName ?? "Perdoruesi")
                    .font(.system(size: 20, weight: .bold))
                Text(user.email ?? "")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                if user.role == "admin" || user.role == "business" {
                    Text(user.role.capitalized)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(TregoNativeTheme.softAccent, in: Capsule())
                        .foregroundStyle(.white)
                }
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

    private var initials: String {
        let words = (user.fullName ?? "")
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
        return words.isEmpty ? "T" : words.joined()
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
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
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
                                TregoAvatarView(name: business.businessName ?? "Trego")
                            }
                        }
                    } else {
                        TregoAvatarView(name: business.businessName ?? "Trego")
                    }
                }
                .frame(width: 76, height: 76)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(business.businessName ?? "Business")
                        .font(.system(size: 22, weight: .bold))
                    Text(business.businessDescription?.isEmpty == false ? (business.businessDescription ?? "") : "Ky eshte profili publik i biznesit ne TREGO.")
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
    let onOpen: () -> Void
    let onFollow: () -> Void
    let onMessage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Group {
                    if let logoPath = business.logoPath, !logoPath.isEmpty {
                        TregoRemoteImage(imagePath: logoPath)
                    } else {
                        TregoAvatarView(name: business.businessName ?? "Biznes")
                    }
                }
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(business.businessName ?? "Biznes pa emer")
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(2)

                    Text([
                        business.city,
                        business.verificationStatus?.capitalized
                    ]
                    .compactMap { value in
                        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                            return nil
                        }
                        return trimmed
                    }
                    .joined(separator: " · "))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            if let description = business.businessDescription, !description.isEmpty {
                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.78))
                    .lineLimit(3)
            }

            HStack(spacing: 8) {
                TregoMetaPill(text: "\(business.productsCount ?? 0) produkte")
                TregoMetaPill(text: "\(business.followersCount ?? 0) followers")
                if let rating = business.sellerRating, rating > 0 {
                    TregoMetaPill(text: String(format: "%.1f", rating))
                }
            }

            HStack(spacing: 10) {
                if business.isFollowed == true {
                    Button("Following", action: onFollow)
                        .buttonStyle(TregoMiniOutlineButtonStyle())
                } else {
                    Button("Follow", action: onFollow)
                        .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.softAccent))
                }
                Button("Hape", action: onOpen)
                    .buttonStyle(TregoMiniOutlineButtonStyle())
                Button("Mesazh", action: onMessage)
                    .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.accent))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.38), lineWidth: 0.8)
        }
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

                    if upload != nil {
                        Button("Anulo foton", action: onRemovePhoto)
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
                Text("Ngarko te pakten nje foto kryesore per artikullin.")
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.8)
                }
        }
    }
}

private struct TregoNotificationCard<Action: View>: View {
    let notification: TregoNotificationItem
    @ViewBuilder let action: () -> Action
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title?.isEmpty == false ? (notification.title ?? "") : "Njoftim")
                        .font(.system(size: 17, weight: .bold))
                    Text(TregoNativeFormatting.readableDate(notification.createdAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if notification.isRead != true {
                    TregoMetaPill(text: "Ri")
                }
            }

            if let body = notification.body, !body.isEmpty {
                Text(body)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.8))
            }

            HStack {
                action()
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(colorScheme == .dark ? .white.opacity(0.12) : .white.opacity(0.42), lineWidth: 0.8)
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
                .foregroundStyle(TregoNativeTheme.accent)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.8), in: Circle())

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
                .foregroundStyle(Color.primary.opacity(0.82))
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
                                TregoAvatarView(name: profile?.businessName ?? fallbackName ?? "Trego")
                            }
                        }
                    } else {
                        TregoAvatarView(name: profile?.businessName ?? fallbackName ?? "Trego")
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
            }

            Spacer()

            TregoMetaPill(text: user.role?.capitalized ?? "Client")
        }
        .padding(16)
        .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
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
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            TregoRemoteImage(imagePath: item.imagePath)
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                Text("Sasia: \(item.quantity ?? 1)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(TregoFormatting.price(item.price ?? 0))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TregoNativeTheme.accent)
            }
            Spacer(minLength: 0)
            Button("Remove", action: onRemove)
                .buttonStyle(TregoMiniOutlineButtonStyle())
        }
        .padding(14)
        .background(TregoNativeTheme.cardFill, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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
                Text(conversation.lastMessagePreview ?? "Nuk ka mesazh ende")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if let unread = conversation.unreadCount, unread > 0 {
                Text(String(unread))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(TregoNativeTheme.accent, in: Circle())
            }
        }
        .padding(14)
        .tregoGlassRectBackground(cornerRadius: 28)
    }
}

private struct TregoMessageBubble: View {
    let message: TregoChatMessage

    var body: some View {
        HStack {
            if message.isOwn == true {
                Spacer(minLength: 48)
            }

            VStack(alignment: .leading, spacing: 6) {
                if let sender = message.senderName, !sender.isEmpty {
                    Text(sender)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(message.body ?? "")
                    .font(.system(size: 15, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(messageBubbleBackground)

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
    let onWishlist: () -> Void
    let onAddToCart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onTap) {
                TregoRemoteImage(imagePath: product.imagePath)
                    .frame(height: 158)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .buttonStyle(.plain)

            Text(product.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)

            HStack(spacing: 6) {
                Text(TregoFormatting.price(product.price ?? 0))
                    .font(.system(size: 16, weight: .bold))
                if let compareAt = product.compareAtPrice, compareAt > (product.price ?? 0) {
                    TregoComparePriceText(
                        value: TregoFormatting.price(compareAt),
                        font: .system(size: 12, weight: .semibold)
                    )
                }
            }

            HStack(spacing: 8) {
                Button(action: onWishlist) {
                    Image(systemName: isWishlisted ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(TregoMiniIconButtonStyle())

                Button(action: onAddToCart) {
                    Text("Add")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TregoMiniButtonStyle(tint: TregoNativeTheme.accent))
            }
        }
        .padding(14)
        .tregoGlassRectBackground(cornerRadius: 28)
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.42), lineWidth: 0.7)
        }
    }
}

private struct TregoPromoCardItem: Identifiable {
    enum Kind {
        case trending
        case sale
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

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(card.kind == .trending ? "Trending" : "Sale")
                        .font(.system(size: 12, weight: .heavy))
                        .textCase(.uppercase)
                    Spacer(minLength: 0)
                    Image(systemName: card.kind == .trending ? "chart.line.uptrend.xyaxis" : "tag.fill")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(card.kind == .trending ? Color(red: 0.23, green: 0.27, blue: 0.42) : TregoNativeTheme.accent)

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
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: AnyShapeStyle {
        AnyShapeStyle(.ultraThinMaterial)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 34, weight: .black))
            Text(subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct TregoInputCard: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var placeholder: String = ""
    var autocapitalization: TextInputAutocapitalization = .words
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            TextField(placeholder.isEmpty ? title : placeholder, text: $text)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(true)
                .keyboardType(keyboardType)
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            SecureField(title, text: $text)
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
    @Environment(\.colorScheme) private var colorScheme

    private let options = [
        ("female", "Femer"),
        ("male", "Mashkull"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gjinia")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
            ForEach(options, id: \.0) { option in
                    Button {
                        selected = option.0
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: selected == option.0 ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 15, weight: .bold))
                            Text(option.1)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(selected == option.0 ? TregoNativeTheme.accent : Color.primary.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .tregoGlassRectBackground(cornerRadius: 20)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    selected == option.0
                                        ? TregoNativeTheme.accent.opacity(colorScheme == .dark ? 0.8 : 0.9)
                                        : (colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.42)),
                                    lineWidth: selected == option.0 ? 1.1 : 0.8
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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

private struct TregoRemoteImage: View {
    let imagePath: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.92), Color.white.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            if let url = TregoAPIClient.imageURL(from: imagePath) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        ProgressView()
                    default:
                        Image(systemName: "photo")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.34))
                    }
                }
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.34))
            }
        }
        .clipped()
    }
}

private struct TregoAvatarView: View {
    let name: String

    var body: some View {
        Circle()
            .fill(TregoNativeTheme.softAccent)
            .overlay {
                Text(initials)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
    }

    private var initials: String {
        let bits = name
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
        return bits.isEmpty ? "T" : bits.joined()
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
                    Image(systemName: "camera")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 32, height: 32)
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
        .sheet(item: $pickerSource) { source in
            TregoImagePicker(source: source) { upload in
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
    static let accent = Color(red: 0.94, green: 0.45, blue: 0.18)
    static let softAccent = Color(red: 0.32, green: 0.52, blue: 0.98)
    static let systemBackground = Color(uiColor: .systemBackground)
    static let background = LinearGradient(
        colors: [
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1)
                : UIColor(red: 0.97, green: 0.96, blue: 0.95, alpha: 1)
            }),
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.04, green: 0.05, blue: 0.07, alpha: 1)
                : UIColor(red: 0.95, green: 0.94, blue: 0.93, alpha: 1)
            }),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let cardFill = AnyShapeStyle(.ultraThinMaterial)
}

private enum TregoNativeProductCatalog {
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
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(tint.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct TregoSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color.primary.opacity(0.86))
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.white.opacity(configuration.isPressed ? 0.7 : 0.82), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.48), lineWidth: 0.75)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct TregoMiniButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(tint.opacity(configuration.isPressed ? 0.82 : 1), in: Capsule())
    }
}

private struct TregoMiniOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.primary.opacity(0.8))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(configuration.isPressed ? 0.62 : 0.78), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.44), lineWidth: 0.75)
            }
    }
}

private struct TregoMiniIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.primary.opacity(0.78))
            .background(
                Circle()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.66 : 0.82))
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
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(colorScheme == .dark ? Color.red.opacity(0.95) : Color.red.opacity(0.82))
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.red.opacity(configuration.isPressed ? 0.1 : 0.06))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
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
            return "male"
        case "femer", "female":
            return "female"
        case "other", "tjeter":
            return "other"
        default:
            return "female"
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
