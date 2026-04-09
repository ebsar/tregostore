import { expect, test } from "@playwright/test";
import { installMockApi } from "./helpers/mockApi";

test("cart checkout completes address to payment flow", async ({ page }) => {
  await installMockApi(page, {
    authenticated: true,
    cartItems: [
      {
        id: 41,
        productId: 5,
        title: "Krem fytyre",
        businessName: "Glow Store",
        price: 24,
        quantity: 1,
      },
    ],
  });

  await page.goto("/tabs/cart");
  await page.getByTestId("cart-checkout-button").click();
  await expect(page).toHaveURL(/\/checkout\/address$/);

  await page.getByTestId("checkout-saved-address-button").click();
  await expect(page).toHaveURL(/\/checkout\/payment$/);

  await page.getByTestId("checkout-payment-submit").click();
  await expect(page).toHaveURL(/\/orders$/);
});
