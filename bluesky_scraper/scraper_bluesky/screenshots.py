from datetime import datetime
from playwright.async_api import Page


async def take_debug_screenshots(page: Page, reason: str = "error") -> None:
    """Take debug screenshots and save HTML."""
    try:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        await page.screenshot(path=f"./screenshots/{reason}_fullpage_{timestamp}.png", full_page=True)
        await page.screenshot(path=f"./screenshots/{reason}_viewport_{timestamp}.png")
        
        html = await page.content()
        with open(f"./screenshots/{reason}_page_{timestamp}.html", "w", encoding="utf-8") as f:
            f.write(html)
            
    except Exception as e:
        print(f"Failed to capture debug screenshots: {e}")
