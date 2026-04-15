import datetime
import json
import os
from pathlib import Path

import requests
from dotenv import load_dotenv

load_dotenv()

KOBIS_KEY = os.getenv("KOBIS_KEY")

OUTPUT_FILE = Path("data/movies.json")
BLOCKED_KEYWORDS_FILE = Path("blocked_keywords.txt")

EXCLUDED_GENRE_KEYWORDS = [
    "성인물(에로)",
]


def load_blocked_keywords():
    if not BLOCKED_KEYWORDS_FILE.exists():
        return []

    with open(BLOCKED_KEYWORDS_FILE, "r", encoding="utf-8") as f:
        return [
            line.strip()
            for line in f
            if line.strip()
        ]


BLOCKED_TITLE_KEYWORDS = load_blocked_keywords()


def fetch_movie_page(open_start_year, open_end_year, page=1, per_page=100):
    url = "https://www.kobis.or.kr/kobisopenapi/webservice/rest/movie/searchMovieList.json"

    params = {
        "key": KOBIS_KEY.strip(),
        "curPage": page,
        "itemPerPage": per_page,
        "openStartDt": open_start_year,
        "openEndDt": open_end_year
    }

    response = requests.get(url, params=params, timeout=30)
    response.raise_for_status()

    data = response.json()

    if "movieListResult" not in data:
        raise Exception(f"KOBIS 오류 응답: {data}")

    return data["movieListResult"]


def fetch_all_movies(open_start_year, open_end_year):
    movies = []
    page = 1

    while True:
        result = fetch_movie_page(open_start_year, open_end_year, page)
        movie_list = result.get("movieList", [])

        if not movie_list:
            break

        movies.extend(movie_list)

        total = int(result.get("totCnt", 0))
        if len(movies) >= total:
            break

        page += 1

    return movies


def parse_open_date(open_dt):
    if not open_dt:
        return None

    if len(open_dt) != 8:
        return None

    try:
        return datetime.date(
            int(open_dt[0:4]),
            int(open_dt[4:6]),
            int(open_dt[6:8])
        )
    except ValueError:
        return None


def is_adult_movie(movie):
    genre = (movie.get("genreNm") or "").strip()
    title = (movie.get("movieNm") or "").strip()

    if any(keyword in genre for keyword in EXCLUDED_GENRE_KEYWORDS):
        return True

    if any(keyword in title for keyword in BLOCKED_TITLE_KEYWORDS):
        return True

    return False


def main():
    start_input = input("시작 날짜 입력 (YYYY-MM-DD): ").strip()

    start_date = datetime.datetime.strptime(
        start_input,
        "%Y-%m-%d"
    ).date()

    end_date = start_date + datetime.timedelta(days=90)

    print(f"\n조회 범위: {start_date} ~ {end_date}")

    movies = fetch_all_movies(start_date.year, end_date.year)

    filtered = []

    for movie in movies:
        open_dt = parse_open_date(movie.get("openDt", ""))

        if open_dt is None:
            continue

        if is_adult_movie(movie):
            continue

        if start_date <= open_dt <= end_date:
            directors = movie.get("directors", [])

            if directors and isinstance(directors, list):
                director_name = directors[0].get("peopleNm", "정보 없음")
            else:
                director_name = "정보 없음"

            filtered.append({
                "movieCd": movie.get("movieCd", ""),
                "movieNm": movie.get("movieNm", ""),
                "openDt": open_dt.strftime("%Y-%m-%d"),
                "genreNm": movie.get("genreNm") or "",
                "nationAlt": movie.get("nationAlt") or "미상",
                "director": director_name,
                "isReRelease": False
            })

    filtered.sort(
        key=lambda x: (x.get("openDt", ""), x.get("movieNm", ""))
    )

    print(f"\n총 {len(filtered)}편")
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(
            filtered,
            f,
            indent=2,
            ensure_ascii=False
        )

    print(f"\n저장 완료 → {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
