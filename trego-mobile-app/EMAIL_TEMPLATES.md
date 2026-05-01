# TREGIO Email Templates

This project now includes reusable HTML email template builders in:

- `src/lib/emailTemplates.ts`

## Included templates

- Client order confirmation
- Business new order notification
- Order status update
- Message received notification

## Example usage

```ts
import {
  renderClientOrderConfirmationEmail,
  renderBusinessOrderNotificationEmail,
  renderOrderStatusUpdateEmail,
  renderMessageReceivedEmail,
} from "./src/lib/emailTemplates";

const html = renderClientOrderConfirmationEmail({
  recipientName: "Arta",
  orderNumber: "10482",
  orderDate: "2026-04-30 21:40",
  paymentMethod: "Card",
  deliveryMethod: "Express",
  shippingAddress: "Rr. Bill Clinton, Prishtine, Kosovo",
  subtotal: "€72.00",
  shippingCost: "€3.00",
  total: "€75.00",
  items: [
    { title: "Sneakers", quantity: 1, unitPrice: "€49.00" },
    { title: "Sport Socks", quantity: 2, unitPrice: "€11.50" },
  ],
});
```

Then pass `html` to your backend email provider (SendGrid, Postmark, SES, Resend, Nodemailer, etc.).

## Notes

- These templates are presentational and event-ready, but this repository does not currently include a backend mailer service.
- Keep all price/date formatting consistent with your backend locale logic before calling template builders.
