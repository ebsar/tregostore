function normalizeUserRole(user) {
  return String(user?.role || "").trim().toLowerCase();
}

export function getAccountDashboardMenuItems(user, activeKey = "") {
  const role = normalizeUserRole(user);

  const itemsByRole = {
    admin: [
      { key: "dashboard", href: "/llogaria", label: "Dashboard", icon: "dashboard" },
      { key: "orders", href: "/admin-porosite", label: "Order History", icon: "orders" },
      { key: "products", href: "/admin-products", label: "Products", icon: "bag" },
      { key: "businesses", href: "/bizneset-e-regjistruara", label: "Businesses", icon: "pin" },
      { key: "wishlist", href: "/wishlist", label: "Wishlist", icon: "heart" },
      { key: "compare", href: "/krahaso", label: "Compare", icon: "compare" },
      { key: "settings", href: "/te-dhenat-personale", label: "Setting", icon: "settings" },
    ],
    business: [
      { key: "dashboard", href: "/llogaria", label: "Dashboard", icon: "dashboard" },
      { key: "orders", href: "/porosite-e-biznesit", label: "Order History", icon: "orders" },
      { key: "business-page", href: "/biznesi-juaj", label: "Business Page", icon: "pin" },
      { key: "cart", href: "/cart", label: "Shopping Cart", icon: "bag" },
      { key: "wishlist", href: "/wishlist", label: "Wishlist", icon: "heart" },
      { key: "compare", href: "/krahaso", label: "Compare", icon: "compare" },
      { key: "address", href: "/adresat", label: "Address", icon: "card" },
      { key: "settings", href: "/te-dhenat-personale", label: "Setting", icon: "settings" },
    ],
    client: [
      { key: "dashboard", href: "/llogaria", label: "Dashboard", icon: "dashboard" },
      { key: "orders", href: "/porosite", label: "Order History", icon: "orders" },
      { key: "track-order", href: "/track-order", label: "Track Order", icon: "pin" },
      { key: "cart", href: "/cart", label: "Shopping Cart", icon: "bag" },
      { key: "wishlist", href: "/wishlist", label: "Wishlist", icon: "heart" },
      { key: "compare", href: "/krahaso", label: "Compare", icon: "compare" },
      { key: "address", href: "/adresat", label: "Address", icon: "card" },
      { key: "history", href: "/kerko", label: "Browsing History", icon: "history" },
      { key: "settings", href: "/te-dhenat-personale", label: "Setting", icon: "settings" },
    ],
  };

  const nextItems = itemsByRole[role] || itemsByRole.client;
  return nextItems.map((item) => ({
    ...item,
    active: item.key === activeKey,
  }));
}
