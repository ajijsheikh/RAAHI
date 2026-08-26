from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers.trips import router as trips_router
from app.routers.amenities import router as amenities_router
from app.routers.emergency_contacts import router as emergency_contacts_router
from app.routers.irctc import router as irctc_router

app = FastAPI(
    title="Raahi Backend",
    description="Agentic Safety-Aware Travel Companion API",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(trips_router, prefix="/api/v1", tags=["trips"])
app.include_router(amenities_router, prefix="/api/v1", tags=["amenities"])
app.include_router(emergency_contacts_router, prefix="/api/v1", tags=["emergency-contacts"])
app.include_router(irctc_router, prefix="/api/v1", tags=["irctc"])


@app.get("/health")
async def health():
    llm_groq = False
    llm_gemini = False
    try:
        from app.services.llm_client import call_llm
        test_result = await call_llm("Howrah to Salt Lake Sector V, budget 200 rupees", provider="groq")
        llm_groq = True
    except Exception:
        pass
    try:
        from app.services.llm_client import call_llm
        test_result = await call_llm("Howrah to Salt Lake Sector V, budget 200 rupees", provider="gemini")
        llm_gemini = True
    except Exception:
        pass

    return {
        "status": "ok",
        "db": True,
        "llm": {"groq": llm_groq, "gemini": llm_gemini},
    }


@app.get("/")
async def root():
    return {"message": "Raahi API is running"}