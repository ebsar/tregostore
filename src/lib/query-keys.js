export const queryKeys = {
  user: {
    session: () => ["user", "session"],
    profile: () => ["user", "profile"],
  },
  cart: {
    main: () => ["cart"],
  },
  wishlist: {
    main: () => ["wishlist"],
  },
  products: {
    list: (filters) => ["products", "list", { ...filters }],
    detail: (id) => ["products", "detail", id],
    recommendations: (type, id) => ["products", "recommendations", type, id],
  },
  messages: {
    conversations: () => ["messages", "conversations"],
    detail: (id) => ["messages", "conversation", id],
  },
  businesses: {
    public: () => ["businesses", "public"],
    detail: (id) => ["businesses", "detail", id],
  },
};
