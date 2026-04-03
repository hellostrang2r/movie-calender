import requests
import datetime
import json
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

KOBIS_KEY = os.getenv("KOBIS_KEY")

DATA_DIR = Path("data")
MOVIES_FILE = DATA_DIR / "movies.json"
LAST_GENERATED_FILE = DATA_DIR / "last_generated_movies.json"
EXCLUDED_IDS_FILE = DATA_DIR / "excluded_movie_ids.json"
BLOCKED_KEYWORDS_FILE = Path("blocked_keywords.txt")
MANUAL_MOVIES_FILE = DATA_DIR / "manual_movies.json"

EXCLUDED_GENRE_KEYWORDS = [
    "성인물(에로)",
]


def load_blocked_keywords():
    if not BLOCKED_KEYWORDS_FILE.exists():
        return []

    with open(BLOCKED_KEYWORDS_FILE, "r", encoding="utf-8") as f:
        return [line.strip() for line in f if line.strip()]


BLOCKED_TITLE_KEYWORDS = load_blocked_keywords()


def fetch_movie_page(open_start_year, open_end_year, page=1, per_page=100):
    url = "https://www.kobis.or.kr/kobisopenapi/webservice/rest/movie/searchMovieList.json"

    params = {
        "key": KOBIS_KEY.strip(),
        "curPage": page,
        "itemPerPage": per_page,
        "openStartDt": open_start_year,
        "openEndDt": open_end_year,
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
            int(open_dt[6:8]),
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


def normalize_movie(movie, open_dt):
    directors = movie.get("directors", [])

    if directors and isinstance(directors, list):
        director_name = directors[0].get("peopleNm", "정보 없음")
    else:
        director_name = "정보 없음"

    return {
        "movieCd": movie.get("movieCd", ""),
        "movieNm": movie.get("movieNm", ""),
        "openDt": open_dt.strftime("%Y-%m-%d"),
        "genreNm": movie.get("genreNm") or "",
        "nationAlt": movie.get("nationAlt") or "미상",
        "director": director_name,
        "isReRelease": False,
    }


def load_json_list(path: Path):
    if not path.exists():
        return []

    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def save_json_list(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)

    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def movie_key(movie):
    return movie.get("movieCd", "")


def load_excluded_movies(path: Path):
    raw = load_json_list(path)

    excluded_movies = []
    seen_ids = set()

    for item in raw:
        if isinstance(item, str):
            movie_cd = item.strip()
            if movie_cd and movie_cd not in seen_ids:
                excluded_movies.append({
                    "movieCd": movie_cd,
                    "movieNm": "",
                    "openDt": "",
                    "genreNm": "",
                    "nationAlt": "",
                    "director": "",
                })
                seen_ids.add(movie_cd)

        elif isinstance(item, dict):
            movie_cd = item.get("movieCd", "").strip()
            if movie_cd and movie_cd not in seen_ids:
                excluded_movies.append({
                    "movieCd": movie_cd,
                    "movieNm": item.get("movieNm", ""),
                    "openDt": item.get("openDt", ""),
                    "genreNm": item.get("genreNm", ""),
                    "nationAlt": item.get("nationAlt", ""),
                    "director": item.get("director", ""),
                })
                seen_ids.add(movie_cd)

    return excluded_movies


def build_excluded_id_set(excluded_movies):
    return {
        movie.get("movieCd")
        for movie in excluded_movies
        if movie.get("movieCd")
    }


def build_movie_map(movies):
    return {movie_key(movie): movie for movie in movies if movie_key(movie)}


def detect_user_deleted_ids(last_generated_movies, current_movies):
    last_generated_ids = set(
        movie_key(movie) for movie in last_generated_movies if movie_key(movie)
    )
    current_ids = set(
        movie_key(movie) for movie in current_movies if movie_key(movie)
    )

    # 지난번 자동 생성엔 있었는데, 현재 최종 목록엔 없는 것 = 사용자가 삭제한 것
    deleted_ids = last_generated_ids - current_ids
    return deleted_ids


def main():
    start_input = input("시작 날짜 입력 (YYYY-MM-DD): ").strip()

    start_date = datetime.datetime.strptime(start_input, "%Y-%m-%d").date()
    end_date = start_date + datetime.timedelta(days=90)

    print(f"\n조회 범위: {start_date} ~ {end_date}")

    # 기존 파일 로드
    current_movies = load_json_list(MOVIES_FILE)
    last_generated_movies = load_json_list(LAST_GENERATED_FILE)
    manual_movies = load_json_list(MANUAL_MOVIES_FILE)

    excluded_movies = load_json_list(EXCLUDED_IDS_FILE)
    excluded_ids = {
    movie.get("movieCd")
    for movie in excluded_movies
    if isinstance(movie, dict) and movie.get("movieCd")
    }

    # 사용자가 직접 삭제한 영화 자동 감지
    auto_detected_deleted_ids = detect_user_deleted_ids(
    last_generated_movies,
    current_movies,
    )

    if auto_detected_deleted_ids:
        print(f"\n사용자 삭제 감지: {len(auto_detected_deleted_ids)}편")

    existing_excluded_ids = build_excluded_id_set(excluded_movies)

    for movie in last_generated_movies:
        movie_id = movie_key(movie)

        if (
            movie_id in auto_detected_deleted_ids
            and movie_id not in existing_excluded_ids
        ):
            excluded_movies.append({
                "movieCd": movie.get("movieCd", ""),
                "movieNm": movie.get("movieNm", ""),
                "openDt": movie.get("openDt", ""),
                "genreNm": movie.get("genreNm", ""),
                "nationAlt": movie.get("nationAlt", ""),
                "director": movie.get("director", ""),
            })

    excluded_ids = build_excluded_id_set(excluded_movies)

    # KOBIS에서 새 목록 추출
    raw_movies = fetch_all_movies(start_date.year, end_date.year)

    newly_generated_movies = []
    seen_ids = set()

    for movie in raw_movies:
        open_dt = parse_open_date(movie.get("openDt", ""))

        if open_dt is None:
            continue

        if is_adult_movie(movie):
            continue

        if not (start_date <= open_dt <= end_date):
            continue

        normalized = normalize_movie(movie, open_dt)
        movie_cd = movie_key(normalized)

        if not movie_cd:
            continue

        # 사용자가 삭제한 영화는 다시 추가하지 않음
        if movie_cd in excluded_ids:
            continue

        if movie_cd in seen_ids:
            continue

        seen_ids.add(movie_cd)
        newly_generated_movies.append(normalized)

    newly_generated_movies.sort(
        key=lambda x: (x.get("openDt", ""), x.get("movieNm", ""))
    )

    # 현재 최종 목록 기준으로 유지
    current_map = build_movie_map(current_movies)

    added = []
    skipped_existing = []

    for movie in newly_generated_movies:
        movie_cd = movie_key(movie)

        if movie_cd in current_map:
            skipped_existing.append(movie)
            continue

        current_map[movie_cd] = movie
        added.append(movie)
    
    manual_added = []
    manual_skipped = []

    for movie in manual_movies:
        movie_cd = movie_key(movie)

        if not movie_cd:
            continue

        if movie_cd in current_map:
            manual_skipped.append(movie)
            continue

        current_map[movie_cd] = movie
        manual_added.append(movie)

    final_movies = list(current_map.values())
    final_movies.sort(key=lambda x: (x.get("openDt", ""), x.get("movieNm", "")))

    # 저장
    save_json_list(MOVIES_FILE, final_movies)
    save_json_list(LAST_GENERATED_FILE, newly_generated_movies)
    excluded_movies.sort(
    key=lambda x: (x.get("openDt", ""), x.get("movieNm", ""))
    )
    save_json_list(EXCLUDED_IDS_FILE, excluded_movies)

    print("\n=== 업데이트 결과 ===")
    print(f"현재 목록 개수: {len(current_movies)}")
    print(f"새로 추출된 개수: {len(newly_generated_movies)}")
    print(f"새로 추가된 개수: {len(added)}")
    print(f"기존에 있어서 유지된 개수: {len(skipped_existing)}")
    print(f"수동 추가 개수: {len(manual_added)}")
    print(f"자동 제외 목록 개수: {len(excluded_movies)}")
    print(f"최종 저장 개수: {len(final_movies)}")

    if added:
        print("\n[새로 추가된 영화]")
        for movie in added[:20]:
            print(f"- {movie.get('movieNm')} ({movie.get('openDt')})")

    print(f"\n저장 완료 → {MOVIES_FILE}")
    print(f"자동 생성 기준 저장 → {LAST_GENERATED_FILE}")
    print(f"자동 제외 목록 저장 → {EXCLUDED_IDS_FILE}")


if __name__ == "__main__":
    main()