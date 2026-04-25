function normalizeUserRole(user) {
  return String(user?.role || "").trim().toLowerCase();
}

export function getAccountDashboardMenuItems(user, activeKey = "") {
  const role = normalizeUserRole(user);

  const itemsByRole = {
    admin: [
      { key: "dashboard", href: "/llogaria", label: "Overview", icon: "dashboard", group: "Core" },
      { key: "orders", href: "/admin-porosite", label: "Orders", icon: "orders", group: "Core" },
      { key: "products", href: "/admin-products", label: "Add Product", icon: "products", group: "Catalog" },
      { key: "inventory", href: "/admin-products/inventory", label: "Inventory", icon: "stock", group: "Catalog" },
      { key: "businesses", href: "/bizneset-e-regjistruara", label: "Vendors", icon: "pin", group: "Management" },
      { key: "users", href: "/admin-users", label: "Users", icon: "users", group: "Management" },
      { key: "disputes", href: "/admin-disputes", label: "Disputes", icon: "messages", group: "Management" },
      { key: "categories", href: "/admin-categories", label: "Categories", icon: "bag", group: "Operations" },
      { key: "commissions", href: "/admin-commissions", label: "Commissions", icon: "offers", group: "Operations" },
      { key: "payouts", href: "/admin-payouts", label: "Payouts", icon: "shipping", group: "Operations" },
      { key: "settings", href: "/te-dhenat-personale", label: "Settings", icon: "settings", group: "Workspace" },
    ],
    business: [
      { key: "dashboard", href: "/biznesi-juaj?view=analytics", label: "Overview", icon: "dashboard", group: "Core" },
      { key: "orders", href: "/porosite-e-biznesit", label: "Orders", icon: "orders", group: "Core" },
      { key: "inventory", href: "/biznesi-juaj?view=inventory", label: "Products", icon: "products", group: "Inventory" },
      { key: "products", href: "/biznesi-juaj?view=products", label: "Add Product", icon: "bag", group: "Inventory" },
      { key: "stock", href: "/biznesi-juaj?view=stock", label: "Stock", icon: "stock", group: "Inventory" },
      { key: "import", href: "/biznesi-juaj?view=import", label: "Import", icon: "import", group: "Inventory" },
      { key: "offers", href: "/biznesi-juaj?view=offers", label: "Discounts", icon: "offers", group: "Growth" },
      { key: "payouts", href: "/biznesi-juaj?view=payouts", label: "Payouts", icon: "shipping", group: "Growth" },
      { key: "settings", href: "/biznesi-juaj?view=profile", label: "Store Settings", icon: "settings", group: "Store" },
      { key: "support", href: "/mesazhet", label: "Support", icon: "messages", group: "Store" },
    ],
    client: [
      { key: "dashboard", href: "/llogaria", label: "Overview", icon: "dashboard", group: "Core" },
      { key: "orders", href: "/porosite", label: "Orders", icon: "orders", group: "Core" },
      { key: "wishlist", href: "/wishlist", label: "Wishlist", icon: "heart", group: "Core" },
      { key: "address", href: "/adresat", label: "Addresses", icon: "address", group: "Account" },
      { key: "payments", href: "/payments", label: "Payment Methods", icon: "card", group: "Account" },
      { key: "settings", href: "/te-dhenat-personale", label: "Account Settings", icon: "settings", group: "Account" },
      { key: "support", href: "/support", label: "Support / Help", icon: "messages", group: "Help" },
    ],
  };

  const nextItems = itemsByRole[role] || itemsByRole.client;
  return nextItems.map((item) => ({
    ...item,
    active: item.key === activeKey,
  }));
}
