import os
import asyncio
from typing import Optional, Dict, Any
from enum import Enum

from dotenv import load_dotenv
from groq import Groq
import google.generativeai as genai

load_dotenv()


class LLMProvider(Enum):
    GROQ = "groq"
    GEMINI = "gemini"


class LLMUnavailable(Exception):
    pass


async def call_llm(prompt: str, provider: Optional[str] = None) -> str:
    """Single-shot text completion. Groq primary, Gemini fallback.
    Optional provider param pins a provider (used by /health checks)."""
    import json as _json

    async def _groq() -> str:
        groq_key = os.getenv("GROQ_API_KEY")
        if not groq_key:
            raise LLMUnavailable("GROQ_API_KEY not set")
        client = Groq(api_key=groq_key)
        response = await asyncio.wait_for(
            asyncio.get_event_loop().run_in_executor(
                None,
                lambda: client.chat.completions.create(
                    model=os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile"),
                    messages=[{"role": "user", "content": prompt}],
                ),
            ),
            timeout=int(os.getenv("LLM_TIMEOUT_S", "8")),
        )
        return response.choices[0].message.content or ""

    async def _gemini() -> str:
        gemini_key = os.getenv("GEMINI_API_KEY")
        if not gemini_key:
            raise LLMUnavailable("GEMINI_API_KEY not set")
        genai.configure(api_key=gemini_key)
        model = genai.GenerativeModel(os.getenv("GEMINI_MODEL", "gemini-2.0-flash"))
        response = await asyncio.wait_for(
            asyncio.get_event_loop().run_in_executor(
                None,
                lambda: model.generate_content(prompt),
            ),
            timeout=int(os.getenv("LLM_TIMEOUT_S", "8")),
        )
        return response.text

    order = [LLMProvider.GROQ, LLMProvider.GEMINI]
    if provider == "groq":
        order = [LLMProvider.GROQ]
    elif provider == "gemini":
        order = [LLMProvider.GEMINI]

    errors = []
    for p in order:
        try:
            if p is LLMProvider.GROQ:
                return await _groq()
            return await _gemini()
        except Exception as e:  # noqa: BLE001 — failover must swallow provider errors
            errors.append(f"{p.value}: {e}")

    raise LLMUnavailable("All LLM providers failed: " + "; ".join(errors))


async def complete_json(system: str, user: str, schema: dict) -> dict:
    """Groq primary, Gemini fallback. Raises LLMUnavailable if both fail."""
    # Try Groq primary
    try:
        groq_key = os.getenv("GROQ_API_KEY")
        if groq_key:
            client = Groq(api_key=groq_key)
            response = await asyncio.wait_for(
                asyncio.get_event_loop().run_in_executor(
                    None,
                    lambda: client.chat.completions.create(
                        model=os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile"),
                        messages=[{"role": "system", "content": system}, {"role": "user", "content": user}],
                        response_format={"type": "json_object"},
                    )
                ),
                timeout=8
            )
            import json
            return json.loads(response.choices[0].message.content)
    except Exception:
        pass

    # Try Gemini fallback
    try:
        gemini_key = os.getenv("GEMINI_API_KEY")
        if gemini_key:
            genai.configure(api_key=gemini_key)
            model = genai.GenerativeModel(os.getenv("GEMINI_MODEL", "gemini-2.0-flash"))
            response = await asyncio.wait_for(
                asyncio.get_event_loop().run_in_executor(
                    None,
                    lambda: model.generate_content(
                        f"{system}\n\n{user}\n\nOutput valid JSON only matching this schema: {schema}"
                    )
                ),
                timeout=8
            )
            import json
            return json.loads(response.text)
    except Exception:
        pass

    raise LLMUnavailable("Both Groq and Gemini LLM providers failed")