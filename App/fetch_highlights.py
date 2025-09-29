import os, requests
from logger_setup import get_logger

logger = get_logger(__name__)

def fetch_highlights(league, date_str):
    # Replace below URL with the actual RapidAPI endpoint you subscribed to.
    url = os.environ.get("RAPIDAPI_URL", "https://api.sportsdata.io/v3/sports/highlights")  # placeholder
    headers = {
        "X-RapidAPI-Key": os.environ.get("RAPIDAPI_KEY"),
        "X-RapidAPI-Host": os.environ.get("RAPIDAPI_HOST", "")
    }
    params = {"league": league, "date": date_str}
    logger.info("Requesting highlights for %s %s", league, date_str)
    r = requests.get(url, headers=headers, params=params, timeout=30)
    r.raise_for_status()
    return r.json()
