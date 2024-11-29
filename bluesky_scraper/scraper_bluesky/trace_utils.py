import os
import inspect
from functools import wraps
from opentelemetry import trace
from types import FrameType
from typing import Optional

tracer = trace.get_tracer("bluesky")


def get_span_name(suffix: str = "") -> str:
    """Generate span name from caller's file and function.

    Args:
        suffix: Optional suffix to append to the span name

    Returns:
        Span name in format: filename.function_name[.suffix]
    """
    # Get the caller's frame
    current_frame: Optional[FrameType] = inspect.currentframe()
    if current_frame is None:
        raise RuntimeError("Could not get current frame")

    caller_frame: Optional[FrameType] = current_frame.f_back
    if caller_frame is None:
        raise RuntimeError("Could not get caller frame")

    # Get the caller's filename without .py extension
    filename = os.path.splitext(os.path.basename(caller_frame.f_code.co_filename))[0]

    # Get the caller's function name
    current_func = caller_frame.f_code.co_name

    # Combine parts, adding suffix if provided
    parts = [filename, current_func]
    if suffix:
        parts.append(suffix)

    return ".".join(parts)


def span_name(suffix: str = ""):
    """Decorator that automatically generates span name based on file and function name."""

    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Get filename without .py extension
            filename = os.path.splitext(os.path.basename(func.__code__.co_filename))[0]

            # Build span name
            parts = [filename, func.__name__]
            if suffix:
                parts.append(suffix)
            span_name = ".".join(parts)

            with tracer.start_as_current_span(span_name):
                return await func(*args, **kwargs)

        return wrapper

    return decorator
