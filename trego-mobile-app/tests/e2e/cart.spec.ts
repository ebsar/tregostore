import { expect, test } from "@playwright/test";
import { installMockApi } from "./helpers/mockApi";

test("guest cart sends user to signup flow", async ({ page }) => {
  await installMockApi(page, { authenticated: false });

  await page.goto("/tabs/cart");
  await expect(page.getByText("Kyçu per te pare cart")).toBeVisible();
  await page.getByTestId("cart-signup-button").click();
  await expect(page).toHaveURL(/\/signup\?redirect=\/tabs\/cart$/);
});
