import asyncio
from playwright.async_api import async_playwright, Playwright

from scraper_bluesky.scraper import get_page_title, scrape_posts



URL = "https://bsky.app/"


async def run(playwright: Playwright):
    chromium = playwright.chromium  # or "firefox" or "webkit".
    browser = await chromium.launch(
        headless=False,
        args=['--disable-blink-features=AutomationControlled']  # Makes it harder to detect automation.
        )
    # Create context with more realistic browser behavior.
    context = await browser.new_context(
        viewport={'width': 1920, 'height': 1080},
        user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    )
    
    page = await context.new_page()
    await page.goto(URL, wait_until="domcontentloaded")
    await page.wait_for_timeout(3000)  # 3 second delay.
    
    try:
        # Scrape the page title.
        await get_page_title(page)

        # Scrape posts.
        await scrape_posts(page)
    except Exception as e:
        print(f"Fatal error in scraping run: {str(e)}")
        if browser:
            # Try to get one final screenshot if possible.
            try:
                pages = await browser.contexts[0].pages
                if pages:
                    await pages[0].screenshot(path="./screenshots/fatal_error.png")
            except:
                print("Could not capture fatal error screenshot")
        raise
        
    finally:
        await context.close()
        await browser.close()


async def main():
    async with async_playwright() as playwright:
        await run(playwright)


if __name__ == "__main__":
    asyncio.run(main())
