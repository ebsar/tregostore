export const queryKeys = {
  user: {
    session: () => ["user", "session"],
  },
  cart: {
    main: () => ["cart"],
  },
  wishlist: {
    main: () => ["wishlist"],
  },
  products: {
    list: (filters?: any) => ["products", "list", filters].filter(Boolean),
    detail: (id: string | number) => ["products", "detail", id],
    recommendations: (type: string, id?: string | number) => ["products", "recommendations", type, id].filter(Boolean),
  },
  messages: {
    conversations: () => ["messages", "conversations"],
    detail: (id: string | number) => ["messages", "conversation", id],
  },
  businesses: {
    public: () => ["businesses", "public"],
    detail: (id: string | number) => ["businesses", "detail", id],
  },
};
