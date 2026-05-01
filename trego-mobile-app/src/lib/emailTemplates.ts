type OrderLineItem = {
  title: string;
  quantity: number;
  unitPrice: string;
};

type BaseEmailInput = {
  preheader?: string;
  recipientName: string;
  supportEmail?: string;
};

type ClientOrderConfirmationInput = BaseEmailInput & {
  orderNumber: string;
  orderDate: string;
  paymentMethod: string;
  deliveryMethod: string;
  shippingAddress: string;
  subtotal: string;
  shippingCost: string;
  total: string;
  items: OrderLineItem[];
};

type BusinessOrderNotificationInput = BaseEmailInput & {
  businessName: string;
  orderNumber: string;
  buyerName: string;
  orderDate: string;
  total: string;
  items: OrderLineItem[];
};

type OrderStatusUpdateInput = BaseEmailInput & {
  orderNumber: string;
  oldStatus: string;
  newStatus: string;
  statusNote?: string;
  eta?: string;
};

type MessageReceivedInput = BaseEmailInput & {
  senderName: string;
  senderRole: string;
  conversationLabel: string;
  messagePreview: string;
};

function escapeHtml(value: string): string {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function renderItems(items: OrderLineItem[]): string {
  return items
    .map(
      (item) => `
        <tr>
          <td style="padding:10px 0;border-bottom:1px solid #e5e7eb;color:#111827;">${escapeHtml(item.title)}</td>
          <td style="padding:10px 0;border-bottom:1px solid #e5e7eb;color:#6b7280;text-align:center;">${item.quantity}</td>
          <td style="padding:10px 0;border-bottom:1px solid #e5e7eb;color:#111827;text-align:right;">${escapeHtml(item.unitPrice)}</td>
        </tr>
      `,
    )
    .join("");
}

function renderLayout(title: string, preheader: string, body: string): string {
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>${escapeHtml(title)}</title>
  </head>
  <body style="margin:0;padding:0;background:#f3f4f6;font-family:Inter,Segoe UI,Arial,sans-serif;">
    <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">${escapeHtml(preheader)}</div>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f3f4f6;padding:24px 0;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:620px;background:#ffffff;border:1px solid #e5e7eb;border-radius:16px;overflow:hidden;">
            <tr>
              <td style="background:#ff6f18;padding:18px 24px;">
                <div style="font-size:12px;letter-spacing:0.08em;text-transform:uppercase;color:#fff3ea;font-weight:700;">TREGIO</div>
                <div style="font-size:20px;line-height:1.2;font-weight:800;color:#ffffff;margin-top:6px;">${escapeHtml(title)}</div>
              </td>
            </tr>
            <tr>
              <td style="padding:22px 24px;">${body}</td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

export function renderClientOrderConfirmationEmail(input: ClientOrderConfirmationInput): string {
  const supportEmail = input.supportEmail || "support@tregio.com";
  const preheader = input.preheader || `Order #${input.orderNumber} confirmed`;
  const body = `
    <p style="margin:0 0 14px;color:#111827;font-size:15px;">Hi ${escapeHtml(input.recipientName)}, your order has been confirmed.</p>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:0 0 16px;">
      <tr><td style="color:#6b7280;font-size:13px;padding:4px 0;">Order:</td><td style="text-align:right;color:#111827;font-size:13px;font-weight:700;">#${escapeHtml(input.orderNumber)}</td></tr>
      <tr><td style="color:#6b7280;font-size:13px;padding:4px 0;">Date:</td><td style="text-align:right;color:#111827;font-size:13px;">${escapeHtml(input.orderDate)}</td></tr>
      <tr><td style="color:#6b7280;font-size:13px;padding:4px 0;">Payment:</td><td style="text-align:right;color:#111827;font-size:13px;">${escapeHtml(input.paymentMethod)}</td></tr>
      <tr><td style="color:#6b7280;font-size:13px;padding:4px 0;">Delivery:</td><td style="text-align:right;color:#111827;font-size:13px;">${escapeHtml(input.deliveryMethod)}</td></tr>
    </table>
    <div style="background:#f8fafc;border:1px solid #e5e7eb;border-radius:12px;padding:12px;margin:0 0 16px;">
      <div style="font-size:12px;color:#6b7280;font-weight:700;text-transform:uppercase;letter-spacing:0.05em;">Shipping address</div>
      <div style="font-size:14px;color:#111827;margin-top:6px;">${escapeHtml(input.shippingAddress)}</div>
    </div>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:0 0 12px;">
      <thead>
        <tr>
          <th align="left" style="padding:0 0 8px;color:#6b7280;font-size:12px;">Item</th>
          <th align="center" style="padding:0 0 8px;color:#6b7280;font-size:12px;">Qty</th>
          <th align="right" style="padding:0 0 8px;color:#6b7280;font-size:12px;">Price</th>
        </tr>
      </thead>
      <tbody>${renderItems(input.items)}</tbody>
    </table>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:0 0 14px;">
      <tr><td style="padding:4px 0;color:#6b7280;">Subtotal</td><td style="padding:4px 0;text-align:right;color:#111827;">${escapeHtml(input.subtotal)}</td></tr>
      <tr><td style="padding:4px 0;color:#6b7280;">Shipping</td><td style="padding:4px 0;text-align:right;color:#111827;">${escapeHtml(input.shippingCost)}</td></tr>
      <tr><td style="padding:8px 0;color:#111827;font-weight:800;">Total</td><td style="padding:8px 0;text-align:right;color:#ff6f18;font-weight:800;">${escapeHtml(input.total)}</td></tr>
    </table>
    <p style="margin:0;color:#6b7280;font-size:13px;">Need help? Contact us at <a href="mailto:${escapeHtml(supportEmail)}" style="color:#f26522;text-decoration:none;">${escapeHtml(supportEmail)}</a>.</p>
  `;

  return renderLayout(`Order Confirmation #${input.orderNumber}`, preheader, body);
}

export function renderBusinessOrderNotificationEmail(input: BusinessOrderNotificationInput): string {
  const preheader = input.preheader || `New order #${input.orderNumber} received`;
  const body = `
    <p style="margin:0 0 14px;color:#111827;font-size:15px;">Hi ${escapeHtml(input.recipientName)}, you have a new order for ${escapeHtml(input.businessName)}.</p>
    <div style="background:#f8fafc;border:1px solid #e5e7eb;border-radius:12px;padding:12px;margin:0 0 16px;">
      <div style="font-size:14px;color:#111827;"><strong>Order:</strong> #${escapeHtml(input.orderNumber)}</div>
      <div style="font-size:14px;color:#111827;margin-top:4px;"><strong>Buyer:</strong> ${escapeHtml(input.buyerName)}</div>
      <div style="font-size:14px;color:#111827;margin-top:4px;"><strong>Date:</strong> ${escapeHtml(input.orderDate)}</div>
      <div style="font-size:14px;color:#111827;margin-top:4px;"><strong>Total:</strong> ${escapeHtml(input.total)}</div>
    </div>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
      <thead>
        <tr>
          <th align="left" style="padding:0 0 8px;color:#6b7280;font-size:12px;">Item</th>
          <th align="center" style="padding:0 0 8px;color:#6b7280;font-size:12px;">Qty</th>
          <th align="right" style="padding:0 0 8px;color:#6b7280;font-size:12px;">Price</th>
        </tr>
      </thead>
      <tbody>${renderItems(input.items)}</tbody>
    </table>
  `;

  return renderLayout(`New Order #${input.orderNumber}`, preheader, body);
}

export function renderOrderStatusUpdateEmail(input: OrderStatusUpdateInput): string {
  const preheader = input.preheader || `Order #${input.orderNumber} status changed to ${input.newStatus}`;
  const body = `
    <p style="margin:0 0 14px;color:#111827;font-size:15px;">Hi ${escapeHtml(input.recipientName)}, your order status has been updated.</p>
    <div style="background:#fff7ed;border:1px solid #fed7aa;border-radius:12px;padding:12px;margin:0 0 16px;">
      <div style="font-size:14px;color:#111827;"><strong>Order:</strong> #${escapeHtml(input.orderNumber)}</div>
      <div style="font-size:14px;color:#111827;margin-top:4px;"><strong>Previous status:</strong> ${escapeHtml(input.oldStatus)}</div>
      <div style="font-size:14px;color:#111827;margin-top:4px;"><strong>New status:</strong> ${escapeHtml(input.newStatus)}</div>
      ${input.eta ? `<div style="font-size:14px;color:#111827;margin-top:4px;"><strong>ETA:</strong> ${escapeHtml(input.eta)}</div>` : ""}
    </div>
    ${input.statusNote ? `<p style="margin:0 0 12px;color:#374151;font-size:14px;">${escapeHtml(input.statusNote)}</p>` : ""}
    <p style="margin:0;color:#6b7280;font-size:13px;">You can open the app anytime to see full tracking details.</p>
  `;

  return renderLayout(`Order #${input.orderNumber} Status Update`, preheader, body);
}

export function renderMessageReceivedEmail(input: MessageReceivedInput): string {
  const preheader = input.preheader || `New message from ${input.senderName}`;
  const body = `
    <p style="margin:0 0 14px;color:#111827;font-size:15px;">Hi ${escapeHtml(input.recipientName)}, you received a new message.</p>
    <div style="background:#f8fafc;border:1px solid #e5e7eb;border-radius:12px;padding:12px;margin:0 0 16px;">
      <div style="font-size:14px;color:#111827;"><strong>From:</strong> ${escapeHtml(input.senderName)} (${escapeHtml(input.senderRole)})</div>
      <div style="font-size:14px;color:#111827;margin-top:4px;"><strong>Conversation:</strong> ${escapeHtml(input.conversationLabel)}</div>
      <div style="font-size:14px;color:#374151;margin-top:10px;font-style:italic;">"${escapeHtml(input.messagePreview)}"</div>
    </div>
    <p style="margin:0;color:#6b7280;font-size:13px;">Open TREGIO to reply quickly and keep the conversation moving.</p>
  `;

  return renderLayout("New Message Received", preheader, body);
}

