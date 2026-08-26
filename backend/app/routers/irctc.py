from fastapi import APIRouter, Query

from app.services.irctc_client import check_pnr, verify_travel_claim

router = APIRouter(prefix="/irctc", tags=["irctc"])


@router.get("/pnr/{pnr}")
async def get_pnr_status(pnr: str):
    """Check IRCTC PNR status.

    Returns live data when IRCTC_ENABLED/IRCTC_API_KEY/IRCTC_API_HOST are set;
    otherwise returns simulated data with 'source': 'simulated'.
    """
    data = await check_pnr(pnr)
    return data


@router.get("/verify-claim")
async def verify_claim(
    pnr: str = Query(..., description="PNR number"),
    claimed_destination: str = Query(
        ..., description="Claimed destination station name"
    ),
):
    """Cross-check a claimed destination against the PNR's actual arrival station."""
    result = await verify_travel_claim(pnr, claimed_destination)
    return result