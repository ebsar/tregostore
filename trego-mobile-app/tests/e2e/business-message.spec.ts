import { expect, test } from "@playwright/test";
import { installMockApi } from "./helpers/mockApi";

test("business message opens conversation for authenticated user", async ({ page }) => {
  await installMockApi(page, {
    authenticated: true,
    businesses: [
      {
        id: 7,
        businessName: "Bureka me mish",
        city: "Prishtine",
        category: "Ushqim",
        isFollowed: false,
      },
    ],
    businessProducts: {
      7: [
        {
          id: 91,
          title: "Byrek klasik",
          price: 3,
          imagePath: "",
        },
      ],
    },
  });

  await page.goto("/tabs/businesses");
  await page.getByTestId("business-message-button").first().click();
  await expect(page).toHaveURL(/\/messages\/9001$/);
});
