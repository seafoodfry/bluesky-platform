import asyncio
from playwright.async_api import async_playwright, Playwright

from scraper_bluesky.scraper import get_page_title, scrape_posts
from scraper_bluesky.screenshots import take_debug_screenshots


URL = "https://bsky.app/"


async def run(playwright: Playwright):
    chromium = playwright.chromium  # or "firefox" or "webkit".
    browser = await chromium.launch(
        headless=True,
        args=[
            "--disable-blink-features=AutomationControlled",  # Makes it harder to detect automation
            "--window-size=1920,1080",
            "--disable-features=site-per-process",
            "--disable-dev-shm-usage",  # Helps with memory in Docker
            "--disable-gpu",  # Helps in headless mode
            "--lang=en-US,en",  # Set language explicitly
        ],
    )
    # Create context with more realistic browser behavior.
    context = await browser.new_context(
        viewport={"width": 1920, "height": 1080},
        user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        ignore_https_errors=True,
        java_script_enabled=True,
        locale="en-US",
        timezone_id="America/New_York",
        permissions=["geolocation"],  # Some sites need this
        extra_http_headers={
            "Accept-Language": "en-US,en;q=0.9",
        },
    )

    page = await context.new_page()
    await page.goto(URL, wait_until="domcontentloaded")
    await page.wait_for_timeout(3000)  # 3 second delay.

    try:
        # Add more explicit waiting and checks
        print("Navigating to page...")
        response = await page.goto(URL, wait_until="domcontentloaded", timeout=30_000)

        if not response or not response.ok:
            print(
                f"Page load failed with status: {response.status if response else 'No response'}"
            )
            await take_debug_screenshots(page, "failed_load")
            raise Exception("Failed to load page properly")

        print("Waiting for initial render...")
        await page.wait_for_timeout(10_000)

        # Try to ensure JavaScript is loaded
        await page.wait_for_function("() => window.document.readyState === 'complete'")

        # Debug info
        print("Page URL:", page.url)
        print("Document Ready State:", await page.evaluate("document.readyState"))
        print("Checking if JavaScript is enabled:", await page.evaluate("!!window"))

        # Additional check for basic page structure
        body = await page.query_selector("body")
        if not body:
            raise Exception("No body element found")

        # Try to detect any anti-bot measures
        is_blocked = await page.evaluate("""
            () => {
                return document.body.innerText.includes('blocked')
                    || document.body.innerText.includes('captcha')
                    || document.body.innerText.includes('security check');
            }
        """)

        if is_blocked:
            print("Possible anti-bot detection!")
            await take_debug_screenshots(page, "blocked")

        # Scrape the page title.
        await get_page_title(page)

        # Scrape posts.
        await scrape_posts(page)
    except Exception as e:
        print(f"Fatal error in scraping run: {e}")
        if browser:
            await take_debug_screenshots(page, "fatal_error")
        raise

    finally:
        await context.close()
        await browser.close()


async def main():
    async with async_playwright() as playwright:
        await run(playwright)


if __name__ == "__main__":
    asyncio.run(main())
