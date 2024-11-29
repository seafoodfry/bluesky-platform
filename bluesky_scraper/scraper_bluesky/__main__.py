import asyncio
import logging
from playwright.async_api import async_playwright, Playwright

from scraper_bluesky.scraper import get_page_title  # , scrape_posts
from scraper_bluesky.scraper_bs4 import scrape_posts as bs4_scrape_posts
from scraper_bluesky.screenshots import take_debug_screenshots

from opentelemetry import trace


# Configure debug logging.
logging.basicConfig(level=logging.DEBUG)

tracer = trace.get_tracer("bluesky")


URL = "https://bsky.app/"


@tracer.start_as_current_span("run")
async def run(playwright: Playwright):
    p_span = trace.get_current_span()

    # Launch the browser.
    with tracer.start_as_current_span("run.launch") as span:
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

    # Create a new context.
    with tracer.start_as_current_span("run.new_context") as span:
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

    with tracer.start_as_current_span("run.wait_until_domcontentloaded") as span:
        await page.goto(URL, wait_until="domcontentloaded")

    await page.wait_for_timeout(1_000)  # 3 second delay.

    try:
        # Add more explicit waiting and checks.
        with tracer.start_as_current_span("run.goto") as span:
            print("Navigating to page...")
            response = await page.goto(
                URL, wait_until="domcontentloaded", timeout=30_000
            )

            if not response or not response.ok:
                print(
                    f"Page load failed with status: {response.status if response else 'No response'}"
                )
                await take_debug_screenshots(page, "failed_load")
                raise Exception("Failed to load page properly")

        print("Waiting for initial render...")
        await page.wait_for_timeout(1_000)

        # Try to ensure JavaScript is loaded.
        with tracer.start_as_current_span("run.wait_for_function") as span:
            await page.wait_for_function(
                "() => window.document.readyState === 'complete'"
            )

            # Debug info.
            readyState = await page.evaluate("document.readyState")
            js_enabled = await page.evaluate("!!window")
            print("Page URL:", page.url)
            print("Document Ready State:", readyState)
            print("Checking if JavaScript is enabled:", js_enabled)
            span.set_attribute("url", page.url)
            span.set_attribute("readyState", readyState)
            span.set_attribute("js_enabled", js_enabled)

        # Additional check for basic page structure.
        with tracer.start_as_current_span("run.body") as span:
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
        p_span.set_attribute("is_blocked", is_blocked)
        if is_blocked:
            print("Possible anti-bot detection!")
            await take_debug_screenshots(page, "blocked")

        # Scrape the page title.
        await get_page_title(page)

        # Scrape posts.
        await bs4_scrape_posts(page)
    except Exception as e:
        print(f"Fatal error in scraping run: {e}")
        if browser:
            await take_debug_screenshots(page, "fatal_error")
        raise

    finally:
        await context.close()
        await browser.close()


@tracer.start_as_current_span("main")
async def main():
    async with async_playwright() as playwright:
        await run(playwright)


if __name__ == "__main__":
    asyncio.run(main())
