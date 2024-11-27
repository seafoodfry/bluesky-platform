import asyncio
from playwright.async_api import async_playwright, Playwright


URL = "https://bsky.app/"


async def run(playwright: Playwright):
    chromium = playwright.chromium  # or "firefox" or "webkit".
    browser = await chromium.launch()
    page = await browser.new_page()
    await page.goto(URL)
    
    # Await the page title method.
    title = await page.title()
    print(title)

    await browser.close()


async def main():
    async with async_playwright() as playwright:
        await run(playwright)


if __name__ == "__main__":
    asyncio.run(main())
