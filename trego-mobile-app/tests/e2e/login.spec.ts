import { expect, test } from "@playwright/test";
import { installMockApi } from "./helpers/mockApi";

test("login routes user back into the app session", async ({ page }) => {
  await installMockApi(page, { authenticated: false });

  await page.goto("/login?redirect=/tabs/account");
  await page.getByTestId("login-identifier").locator("input").fill("test@tregos.store");
  await page.getByTestId("login-password").locator("input").fill("secret123");
  await page.getByTestId("login-submit").click();

  await expect(page).toHaveURL(/\/tabs\/account$/);
  await expect(page.getByText("Trego Test")).toBeVisible();
});
