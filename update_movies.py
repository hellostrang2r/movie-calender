import argparse
import datetime
import json
import os
import re
import time
from pathlib import Path

import requests
from dotenv import load_dotenv
from requests.exceptions import ReadTimeout

load_dotenv()

KOBIS_KEY = os.getenv("KOBIS_KEY", "").strip()
TMDB_BEARER_TOKEN = os.getenv("TMDB_BEARER_TOKEN", "").strip()

DATA_DIR = Path("data")
MOVIES_FILE = DATA_DIR / "movies.json"
LAST_GENERATED_FILE = DATA_DIR / "last_generated_movies.json"
EXCLUDED_IDS_FILE = DATA_DIR / "excluded_movie_ids.json"
HELD_MOVIES_FILE = DATA_DIR / "held_movies.json"
BLOCKED_KEYWORDS_FILE = Path("blocked_keywords.txt")
MANUAL_MOVIES_FILE = DATA_DIR / "manual_movies.json"

EXCLUDED_GENRE_KEYWORDS = [
    "성인물(에로)",
]

TMDB_API_BASE = "https://api.themoviedb.org/3"
TMDB_IMAGE_BASE = "https://image.tmdb.org/t/p/w500"
KOBIS_TIMEOUT_SECONDS = 60
KOBIS_MAX_RETRIES = 3
UPDATE_WINDOW_DAYS = 90
TMDB_ENRICH_LOG_HEADER_PRINTED = False
TITLE_NOISE_PATTERNS = [
    r"\b4k\s*리마스터\b",
    r"\b4k\b",
    r"\b리마스터\b",
    r"\b감독판\b",
    r"\b확장판\b",
    r"\b특별판\b",
    r"\b특별전\b",
    r"\b기획전\b",
    r"\b재개봉\b",
    r"\b돌비\s*시네마\b",
    r"\bios\b",
    r"\bimax\b",
    r"\bscreenx\b",
]


def load_blocked_keywords():
    if not BLOCKED_KEYWORDS_FILE.exists():
        return []

    with open(BLOCKED_KEYWORDS_FILE, "r", encoding="utf-8") as f:
        return [line.strip() for line in f if line.strip()]


BLOCKED_TITLE_KEYWORDS = load_blocked_keywords()


def redact_secrets(text):
    redacted = str(text)

    for secret in [KOBIS_KEY, TMDB_BEARER_TOKEN]:
        if secret:
            redacted = redacted.replace(secret, "***")

    redacted = re.sub(r"([?&]key=)[^&\s]+", r"\1***", redacted, flags=re.IGNORECASE)
    redacted = re.sub(
        r"(Authorization['\"]?:\s*['\"]?Bearer\s+)[^'\"\s]+",
        r"\1***",
        redacted,
        flags=re.IGNORECASE,
    )
    redacted = re.sub(
        r"(Bearer\s+)[A-Za-z0-9._\-]+",
        r"\1***",
        redacted,
        flags=re.IGNORECASE,
    )

    return redacted


def format_safe_error(error):
    return redact_secrets(f"{type(error).__name__}: {error}")


def get_tmdb_headers():
    if not TMDB_BEARER_TOKEN:
        return None

    return {
        "Authorization": f"Bearer {TMDB_BEARER_TOKEN}",
        "Accept": "application/json",
    }


def normalize_title_for_match(title: str) -> str:
    if not title:
        return ""

    text = title.lower().strip()
    replace_map = {
        "：": ":",
        "–": "-",
        "—": "-",
        "’": "'",
        "‘": "'",
        "“": '"',
        "”": '"',
    }

    for old, new in replace_map.items():
        text = text.replace(old, new)

    return " ".join(text.split())


def extract_release_year(open_dt):
    if not open_dt:
        return None

    try:
        return int(str(open_dt)[:4])
    except Exception:
        return None


def clean_tmdb_search_title(title: str) -> str:
    if not title:
        return ""

    cleaned = title.strip()

    for pattern in TITLE_NOISE_PATTERNS:
        cleaned = re.sub(pattern, " ", cleaned, flags=re.IGNORECASE)

    cleaned = re.sub(r"\([^)]*\)", " ", cleaned)
    cleaned = re.sub(r"\[[^\]]*\]", " ", cleaned)

    if ":" in cleaned:
        cleaned = cleaned.split(":", 1)[0]

    cleaned = re.sub(r"\s+", " ", cleaned).strip(" -:/")
    return cleaned


def build_tmdb_search_queries(movie_name: str):
    candidates = []

    def add_candidate(value):
        value = (value or "").strip()
        if not value:
            return

        normalized = normalize_title_for_match(value)
        if normalized in {normalize_title_for_match(item) for item in candidates}:
            return

        candidates.append(value)

    add_candidate(movie_name)
    add_candidate(clean_tmdb_search_title(movie_name))

    return candidates


def build_tmdb_poster_url(poster_path):
    if not poster_path:
        return None
    return f"{TMDB_IMAGE_BASE}{poster_path}"


def parse_iso_date(date_text):
    if not date_text:
        return None

    try:
        return datetime.date.fromisoformat(date_text[:10])
    except ValueError:
        return None


def fetch_tmdb_movie_details(tmdb_movie_id, language="ko-KR"):
    headers = get_tmdb_headers()
    if not headers or not tmdb_movie_id:
        return None

    try:
        response = requests.get(
            f"{TMDB_API_BASE}/movie/{tmdb_movie_id}",
            headers=headers,
            params={"language": language},
            timeout=10,
        )
        response.raise_for_status()
        return response.json()

    except Exception as e:
        print(
            "[TMDB] 상세 조회 실패: "
            f"movie_id={tmdb_movie_id}, language={language} / {format_safe_error(e)}"
        )
        return None

    finally:
        time.sleep(0.2)


def fetch_tmdb_movie_credits(tmdb_movie_id):
    headers = get_tmdb_headers()
    if not headers or not tmdb_movie_id:
        return None

    try:
        response = requests.get(
            f"{TMDB_API_BASE}/movie/{tmdb_movie_id}/credits",
            headers=headers,
            timeout=10,
        )
        response.raise_for_status()
        return response.json()

    except Exception as e:
        print(
            f"[TMDB] 크레딧 조회 실패: movie_id={tmdb_movie_id} / "
            f"{format_safe_error(e)}"
        )
        return None

    finally:
        time.sleep(0.2)


def fetch_tmdb_overview(tmdb_movie_id):
    details_ko = fetch_tmdb_movie_details(tmdb_movie_id, language="ko-KR")
    overview_ko = (details_ko or {}).get("overview", "").strip()
    if overview_ko:
        return overview_ko

    details_en = fetch_tmdb_movie_details(tmdb_movie_id, language="en-US")
    overview_en = (details_en or {}).get("overview", "").strip()
    if overview_en:
        return overview_en

    return ""


def extract_tmdb_genre_names(details):
    genres = (details or {}).get("genres", [])
    if not isinstance(genres, list):
        return ""

    names = [
        genre.get("name", "").strip()
        for genre in genres
        if isinstance(genre, dict) and genre.get("name")
    ]
    return ",".join(names)


def fetch_tmdb_genres(tmdb_movie_id):
    details_ko = fetch_tmdb_movie_details(tmdb_movie_id, language="ko-KR")
    genres_ko = extract_tmdb_genre_names(details_ko)
    if genres_ko:
        return genres_ko

    details_en = fetch_tmdb_movie_details(tmdb_movie_id, language="en-US")
    return extract_tmdb_genre_names(details_en)


def extract_tmdb_director_names(credits):
    crew = (credits or {}).get("crew", [])
    if not isinstance(crew, list):
        return ""

    names = []
    seen = set()

    for person in crew:
        if not isinstance(person, dict):
            continue

        job = person.get("job", "")
        name = person.get("name", "").strip()
        if job != "Director" or not name or name in seen:
            continue

        names.append(name)
        seen.add(name)

    return ",".join(names)


def fetch_tmdb_directors(tmdb_movie_id):
    credits = fetch_tmdb_movie_credits(tmdb_movie_id)
    return extract_tmdb_director_names(credits)


def is_missing_director(movie):
    director = (movie.get("director") or "").strip()
    return not director or director == "정보 없음"


def score_tmdb_result(item, movie_name, open_dt):
    score = 0

    target_title = normalize_title_for_match(movie_name)
    title_candidates = [
        normalize_title_for_match(item.get("title", "")),
        normalize_title_for_match(item.get("original_title", "")),
    ]

    if target_title in title_candidates:
        score += 100

    for candidate in title_candidates:
        if not candidate:
            continue

        if candidate == target_title:
            score += 50
        elif target_title and target_title in candidate:
            score += 20

    target_year = None
    if open_dt:
        try:
            target_year = int(str(open_dt)[:4])
        except Exception:
            target_year = None

    release_date = item.get("release_date") or ""
    result_year = None
    if release_date:
        try:
            result_year = int(release_date[:4])
        except Exception:
            result_year = None

    if target_year and result_year:
        diff = abs(target_year - result_year)
        if diff == 0:
            score += 30
        elif diff == 1:
            score += 15
        elif diff <= 3:
            score += 5

    if item.get("poster_path"):
        score += 10

    popularity = item.get("popularity") or 0
    try:
        score += min(int(popularity), 20)
    except Exception:
        pass

    return score


def get_kr_release_dates(item_id):
    headers = get_tmdb_headers()
    if not headers:
        return []

    try:
        response = requests.get(
            f"{TMDB_API_BASE}/movie/{item_id}/release_dates",
            headers=headers,
            timeout=10,
        )
        response.raise_for_status()
        data = response.json()
    except Exception as e:
        print(
            f"[TMDB] KR 개봉일 조회 실패: movie_id={item_id} / "
            f"{format_safe_error(e)}"
        )
        return []
    finally:
        time.sleep(0.2)

    matched_dates = []

    for country in data.get("results", []):
        if country.get("iso_3166_1") != "KR":
            continue

        for release in country.get("release_dates", []):
            release_date = release.get("release_date")
            if release_date:
                matched_dates.append({
                    "date": release_date[:10],
                    "type": release.get("type"),
                })

    return matched_dates


def validate_tmdb_candidate(item, open_dt):
    target_date = parse_iso_date(open_dt)
    item_id = item.get("id")

    if not target_date or not item_id:
        return True

    kr_release_dates = get_kr_release_dates(item_id)
    if not kr_release_dates:
        return True

    diffs = []
    has_theatrical = False

    for release in kr_release_dates:
        parsed = parse_iso_date(release.get("date"))
        if not parsed:
            continue

        if release.get("type") in (2, 3):
            has_theatrical = True

        diffs.append(abs((parsed - target_date).days))

    if not diffs:
        return True

    closest_diff = min(diffs)

    if has_theatrical and closest_diff > 45:
        return False

    if closest_diff > 120:
        return False

    return True


def search_tmdb_movies(query, open_dt=None):
    headers = get_tmdb_headers()
    if not headers or not query:
        return []

    params = {
        "query": query,
        "language": "ko-KR",
        "region": "KR",
        "include_adult": "false",
    }

    try:
        response = requests.get(
            f"{TMDB_API_BASE}/search/movie",
            headers=headers,
            params=params,
            timeout=10,
        )
        response.raise_for_status()
        data = response.json()
        return data.get("results", [])

    except Exception as e:
        print(f"[TMDB] 검색 실패: {query} / {format_safe_error(e)}")
        return []

    finally:
        time.sleep(0.2)


def discover_tmdb_movies(movie_name, open_dt=None):
    headers = get_tmdb_headers()
    if not headers:
        return []

    params = {
        "language": "ko-KR",
        "region": "KR",
        "include_adult": "false",
        "sort_by": "popularity.desc",
        "with_release_type": "2|3",
    }

    target_date = parse_iso_date(open_dt)
    if target_date:
        window_start = target_date - datetime.timedelta(days=45)
        window_end = target_date + datetime.timedelta(days=45)
        params["release_date.gte"] = window_start.isoformat()
        params["release_date.lte"] = window_end.isoformat()

    try:
        response = requests.get(
            f"{TMDB_API_BASE}/discover/movie",
            headers=headers,
            params=params,
            timeout=10,
        )
        response.raise_for_status()
        data = response.json()
        results = data.get("results", [])
        query_tokens = [
            token
            for token in re.split(r"\s+", normalize_title_for_match(movie_name))
            if token
        ]

        filtered = []
        for item in results:
            haystack = " ".join([
                normalize_title_for_match(item.get("title", "")),
                normalize_title_for_match(item.get("original_title", "")),
            ])

            if not query_tokens:
                filtered.append(item)
                continue

            matched_count = sum(token in haystack for token in query_tokens)
            if matched_count >= max(1, min(2, len(query_tokens))):
                filtered.append(item)

        return filtered

    except Exception as e:
        print(f"[TMDB] discover 실패: {movie_name} / {format_safe_error(e)}")
        return []

    finally:
        time.sleep(0.2)


def choose_best_tmdb_result(results, movie_name, open_dt):
    if not results:
        return None

    scored = []

    for item in results:
        score = score_tmdb_result(item, movie_name, open_dt)
        scored.append((score, item))

    scored.sort(key=lambda pair: pair[0], reverse=True)

    for score, item in scored:
        if score < 35:
            continue

        if validate_tmdb_candidate(item, open_dt):
            return item

    top_score, top_item = scored[0]
    if top_score >= 70:
        return top_item

    return None


def fetch_tmdb_best_match(movie_name, open_dt=None):
    if not get_tmdb_headers():
        return None

    search_queries = build_tmdb_search_queries(movie_name)

    for query in search_queries:
        results = search_tmdb_movies(query, open_dt)
        best = choose_best_tmdb_result(results, movie_name, open_dt)
        if best:
            return best

    discover_results = discover_tmdb_movies(movie_name, open_dt)
    return choose_best_tmdb_result(discover_results, movie_name, open_dt)


def fetch_tmdb_kr_release_date(tmdb_movie_id):
    release_dates = get_kr_release_dates(tmdb_movie_id)
    if not release_dates:
        return None

    theatrical = []
    others = []

    for item in release_dates:
        date_only = item.get("date")
        release_type = item.get("type")

        if not date_only:
            continue

        if release_type == 3:
            theatrical.append(date_only)
        elif release_type == 2:
            others.append(date_only)
        else:
            others.append(date_only)

    if theatrical:
        return min(theatrical)

    if others:
        return min(others)

    return None


def enrich_movie_with_tmdb(movie):
    global TMDB_ENRICH_LOG_HEADER_PRINTED

    movie_name = movie.get("movieNm", "")
    open_dt = movie.get("openDt")
    poster_added = False
    overview_added = False
    genre_added = False
    director_added = False

    if not movie_name:
        return movie

    best = fetch_tmdb_best_match(movie_name, open_dt)
    if not best:
        return movie

    if not movie.get("posterUrl"):
        poster_url = build_tmdb_poster_url(best.get("poster_path"))
        if poster_url:
            movie["posterUrl"] = poster_url
            poster_added = True

    if not movie.get("overview"):
        tmdb_id = best.get("id")
        if tmdb_id:
            overview = fetch_tmdb_overview(tmdb_id)
            if overview:
                movie["overview"] = overview
                overview_added = True

    if not movie.get("genreNm"):
        tmdb_id = best.get("id")
        if tmdb_id:
            genres = fetch_tmdb_genres(tmdb_id)
            if genres:
                movie["genreNm"] = genres
                genre_added = True

    if is_missing_director(movie):
        tmdb_id = best.get("id")
        if tmdb_id:
            directors = fetch_tmdb_directors(tmdb_id)
            if directors:
                movie["director"] = directors
                director_added = True

    # KOBIS 개봉일이 없을 때만 TMDB 한국 개봉일로 보완
    if not movie.get("openDt"):
        tmdb_id = best.get("id")
        if tmdb_id:
            kr_open_dt = fetch_tmdb_kr_release_date(tmdb_id)
            if kr_open_dt:
                movie["openDt"] = kr_open_dt

    poster_mark = "O" if poster_added else "X"
    overview_mark = "O" if overview_added else "X"
    genre_mark = "O" if genre_added else "X"
    director_mark = "O" if director_added else "X"
    if poster_added or overview_added or genre_added or director_added:
        if not TMDB_ENRICH_LOG_HEADER_PRINTED:
            print("\n[TMDB 보강 로그] 포스터 | 줄거리 | 장르 | 감독 | 영화명")
            TMDB_ENRICH_LOG_HEADER_PRINTED = True
        print(
            f"{poster_mark} | {overview_mark} | {genre_mark} | {director_mark} | {movie_name}"
        )

    return movie


def maybe_enrich_movie_with_tmdb(movie, excluded_ids):
    movie_id = movie_key(movie)
    if movie_id and movie_id in excluded_ids:
        return movie

    if (
        movie.get("posterUrl")
        and movie.get("overview")
        and movie.get("genreNm")
        and not is_missing_director(movie)
    ):
        return movie

    return enrich_movie_with_tmdb(movie)


def fetch_movie_page(open_start_year, open_end_year, page=1, per_page=100):
    if not KOBIS_KEY:
        raise RuntimeError("KOBIS_KEY가 설정되지 않았습니다.")

    url = "https://www.kobis.or.kr/kobisopenapi/webservice/rest/movie/searchMovieList.json"

    params = {
        "key": KOBIS_KEY.strip(),
        "curPage": page,
        "itemPerPage": per_page,
        "openStartDt": open_start_year,
        "openEndDt": open_end_year,
    }

    last_error = None

    for attempt in range(1, KOBIS_MAX_RETRIES + 1):
        try:
            response = requests.get(
                url,
                params=params,
                timeout=KOBIS_TIMEOUT_SECONDS,
            )
            response.raise_for_status()

            data = response.json()

            if "movieListResult" not in data:
                raise Exception(f"KOBIS 오류 응답: {data}")

            return data["movieListResult"]

        except ReadTimeout as e:
            last_error = e
            print(
                f"[KOBIS] 응답 지연: page={page}, 시도 {attempt}/{KOBIS_MAX_RETRIES}"
            )
            if attempt < KOBIS_MAX_RETRIES:
                time.sleep(2)

    raise RuntimeError(
        "KOBIS 응답이 지연되어 조회에 실패했습니다. "
        f"잠시 후 다시 시도해 주세요. ({format_safe_error(last_error)})"
    )


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
        "overview": "",
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


def movie_sort_key(movie):
    return (movie.get("openDt", ""), movie.get("movieNm", ""))


def build_excluded_movie_entry(movie):
    return {
        "movieCd": movie.get("movieCd", ""),
        "movieNm": movie.get("movieNm", ""),
        "openDt": movie.get("openDt", ""),
        "genreNm": movie.get("genreNm", ""),
        "nationAlt": movie.get("nationAlt", ""),
        "director": movie.get("director", ""),
        "posterUrl": movie.get("posterUrl", ""),
        "overview": movie.get("overview", ""),
    }


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
                    "overview": "",
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
                    "posterUrl": item.get("posterUrl", ""),
                    "overview": item.get("overview", ""),
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


def merge_movie_metadata(existing_movie, new_movie):
    merged = dict(existing_movie)

    for field in ["posterUrl", "overview", "genreNm"]:
        if not merged.get(field) and new_movie.get(field):
            merged[field] = new_movie.get(field)

    if is_missing_director(merged) and not is_missing_director(new_movie):
        merged["director"] = new_movie.get("director")

    return merged


def merge_movie_record(existing_movie, new_movie):
    if not existing_movie:
        return ensure_movie_optional_fields(dict(new_movie))

    merged = dict(existing_movie)

    for field in ["movieNm", "openDt", "nationAlt"]:
        if not merged.get(field) and new_movie.get(field):
            merged[field] = new_movie.get(field)

    if not merged.get("isReRelease") and new_movie.get("isReRelease") is not None:
        merged["isReRelease"] = new_movie.get("isReRelease")

    merged = merge_movie_metadata(merged, new_movie)
    return ensure_movie_optional_fields(merged)


def ensure_movie_optional_fields(movie):
    normalized = dict(movie)
    normalized.setdefault("overview", "")
    normalized.setdefault("holdReason", "")
    normalized.setdefault("addToMovies", False)
    return normalized


def parse_saved_open_date(open_dt):
    if not open_dt:
        return None

    try:
        return datetime.date.fromisoformat(str(open_dt)[:10])
    except ValueError:
        return None


def is_movie_missing_metadata(movie):
    return any(
        [
            not movie.get("posterUrl"),
            not movie.get("overview"),
            not movie.get("genreNm"),
            is_missing_director(movie),
        ]
    )


def build_hold_reasons(movie):
    reasons = []

    if is_missing_director(movie):
        reasons.append("감독 정보 없음")
    if not movie.get("posterUrl"):
        reasons.append("포스터 없음")
    if not movie.get("overview"):
        reasons.append("줄거리 없음")
    if not movie.get("genreNm"):
        reasons.append("장르 정보 없음")

    return reasons


def annotate_hold_reason(movie):
    normalized = ensure_movie_optional_fields(movie)
    reasons = build_hold_reasons(normalized)
    normalized["holdReason"] = ", ".join(reasons)
    return normalized


def prepare_movie_for_manual_list(movie):
    normalized = ensure_movie_optional_fields(movie)
    manual_movie = dict(normalized)
    manual_movie.pop("holdReason", None)
    manual_movie.pop("addToMovies", None)
    return manual_movie


def should_hold_movie(movie):
    has_title = bool((movie.get("movieNm") or "").strip())
    has_open_date = bool((movie.get("openDt") or "").strip())
    reasons = build_hold_reasons(movie)

    return (
        has_title
        and has_open_date
        and len(reasons) == 4
    )


def sort_movies(movies):
    movies.sort(key=movie_sort_key)
    return movies


def merge_movies_into_list(base_movies, incoming_movies):
    merged_map = build_movie_map(base_movies)

    for movie in incoming_movies:
        movie_cd = movie_key(movie)
        if not movie_cd:
            continue

        existing_movie = merged_map.get(movie_cd)
        merged_map[movie_cd] = merge_movie_record(existing_movie, movie)

    return sort_movies(list(merged_map.values()))


def refresh_held_movies(held_movies, raw_movie_map, excluded_ids):
    still_held = []
    released = []

    for held_movie in held_movies:
        movie = ensure_movie_optional_fields(held_movie)
        movie_cd = movie_key(movie)

        raw_movie = raw_movie_map.get(movie_cd)
        if raw_movie:
            movie = merge_movie_record(movie, raw_movie)

        movie = maybe_enrich_movie_with_tmdb(movie, excluded_ids)

        if movie_cd in excluded_ids or should_hold_movie(movie):
            movie = annotate_hold_reason(movie)
            still_held.append(movie)
        else:
            released.append(movie)

    return sort_movies(still_held), sort_movies(released)


def extract_held_movies_from_current_map(current_map, held_movies, forced_include_ids=None):
    held_map = build_movie_map(held_movies)
    forced_include_ids = forced_include_ids or set()

    for movie_cd in list(current_map.keys()):
        if movie_cd in forced_include_ids:
            continue

        movie = ensure_movie_optional_fields(current_map[movie_cd])
        if not should_hold_movie(movie):
            continue

        existing_held_movie = held_map.get(movie_cd)
        held_map[movie_cd] = annotate_hold_reason(
            merge_movie_record(existing_held_movie, movie)
        )
        del current_map[movie_cd]

    return sort_movies(list(held_map.values()))


def split_forced_held_movies(held_movies):
    remaining_held = []
    forced_movies = []

    for held_movie in held_movies:
        movie = ensure_movie_optional_fields(held_movie)
        if movie.get("addToMovies"):
            forced_movies.append(prepare_movie_for_manual_list(movie))
            continue

        remaining_held.append(movie)

    return sort_movies(remaining_held), sort_movies(forced_movies)


def build_raw_movie_map(raw_movies, start_date, end_date):
    raw_map = {}

    for movie in raw_movies:
        open_dt = parse_open_date(movie.get("openDt", ""))
        if not should_include_raw_movie(movie, open_dt, start_date, end_date):
            continue

        normalized = normalize_movie(movie, open_dt)
        movie_cd = movie_key(normalized)
        if movie_cd and movie_cd not in raw_map:
            raw_map[movie_cd] = normalized

    return raw_map


def refresh_existing_movies_in_window(
    current_map,
    raw_movie_map,
    start_date,
    end_date,
    excluded_ids,
):
    refreshed = []

    for movie_cd, existing_movie in current_map.items():
        saved_open_dt = parse_saved_open_date(existing_movie.get("openDt"))
        if not saved_open_dt or not (start_date <= saved_open_dt <= end_date):
            continue

        if not is_movie_missing_metadata(existing_movie):
            continue

        refreshed_movie = dict(existing_movie)
        raw_movie = raw_movie_map.get(movie_cd)
        if raw_movie:
            refreshed_movie = merge_movie_metadata(refreshed_movie, raw_movie)

        refreshed_movie = maybe_enrich_movie_with_tmdb(refreshed_movie, excluded_ids)

        if refreshed_movie != existing_movie:
            current_map[movie_cd] = refreshed_movie
            refreshed.append(refreshed_movie)

    return refreshed


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


def parse_start_date(value):
    return datetime.datetime.strptime(value, "%Y-%m-%d").date()


def resolve_start_date():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--start-date",
        help="조회 시작 날짜 (YYYY-MM-DD). 생략 시 오늘 날짜를 사용합니다.",
    )
    args = parser.parse_args()

    if args.start_date:
        return parse_start_date(args.start_date)

    return datetime.date.today()


def load_update_data():
    return {
        "current_movies": load_json_list(MOVIES_FILE),
        "last_generated_movies": load_json_list(LAST_GENERATED_FILE),
        "manual_movies": load_json_list(MANUAL_MOVIES_FILE),
        "excluded_movies": load_excluded_movies(EXCLUDED_IDS_FILE),
        "held_movies": load_json_list(HELD_MOVIES_FILE),
    }


def enrich_manual_movies(manual_movies, excluded_ids):
    for movie in manual_movies:
        maybe_enrich_movie_with_tmdb(movie, excluded_ids)

    return manual_movies


def add_deleted_movies_to_exclusions(
    excluded_movies,
    last_generated_movies,
    current_movies,
    manual_movies,
):
    auto_detected_deleted_ids = detect_user_deleted_ids(
        last_generated_movies,
        current_movies,
    )

    if not auto_detected_deleted_ids:
        return excluded_movies, auto_detected_deleted_ids

    print(f"\n사용자 삭제 감지: {len(auto_detected_deleted_ids)}편")

    existing_excluded_ids = build_excluded_id_set(excluded_movies)
    manual_ids = {movie_key(m) for m in manual_movies}

    for movie in last_generated_movies:
        movie_id = movie_key(movie)

        if (
            movie_id in auto_detected_deleted_ids
            and movie_id not in existing_excluded_ids
            and movie_id not in manual_ids
        ):
            excluded_movies.append(build_excluded_movie_entry(movie))

    return excluded_movies, auto_detected_deleted_ids


def should_include_raw_movie(movie, open_dt, start_date, end_date):
    if open_dt is None:
        return False

    if is_adult_movie(movie):
        return False

    return start_date <= open_dt <= end_date


def build_newly_generated_movies(
    raw_movies,
    start_date,
    end_date,
    current_map,
    excluded_ids,
):
    newly_generated_movies = []
    newly_held_movies = []
    seen_ids = set()

    for movie in raw_movies:
        open_dt = parse_open_date(movie.get("openDt", ""))

        if not should_include_raw_movie(movie, open_dt, start_date, end_date):
            continue

        normalized = normalize_movie(movie, open_dt)
        existing_movie = current_map.get(movie_key(normalized))
        if (
            existing_movie
            and existing_movie.get("posterUrl")
            and existing_movie.get("overview")
        ):
            normalized = merge_movie_metadata(normalized, existing_movie)
        else:
            normalized = maybe_enrich_movie_with_tmdb(normalized, excluded_ids)

        movie_cd = movie_key(normalized)

        if not movie_cd:
            continue

        # 사용자가 삭제한 영화는 다시 추가하지 않음
        if movie_cd in excluded_ids:
            continue

        if movie_cd in seen_ids:
            continue

        if should_hold_movie(normalized):
            seen_ids.add(movie_cd)
            newly_held_movies.append(annotate_hold_reason(normalized))
            continue

        seen_ids.add(movie_cd)
        newly_generated_movies.append(normalized)

    return sort_movies(newly_generated_movies), sort_movies(newly_held_movies)


def merge_generated_movies(current_map, newly_generated_movies):
    added = []
    skipped_existing = []

    for movie in newly_generated_movies:
        movie_cd = movie_key(movie)

        if movie_cd in current_map:
            current_map[movie_cd] = merge_movie_metadata(
                current_map[movie_cd],
                movie,
            )
            skipped_existing.append(movie)
            continue

        current_map[movie_cd] = movie
        added.append(movie)

    return added, skipped_existing


def merge_manual_movies(current_map, manual_movies):
    manual_added = []
    manual_skipped = []

    for movie in manual_movies:
        movie_cd = movie_key(movie)

        if not movie_cd:
            continue

        if movie_cd in current_map:
            manual_skipped.append(movie)

        existing_movie = current_map.get(movie_cd)
        if existing_movie:
            current_map[movie_cd] = merge_movie_metadata(existing_movie, movie)
        else:
            current_map[movie_cd] = movie
        manual_added.append(movie)

    return manual_added, manual_skipped


def build_final_movies(current_map):
    final_movies = [
        ensure_movie_optional_fields(movie)
        for movie in current_map.values()
    ]
    return sort_movies(final_movies)


def find_duplicate_release_titles(movies):
    grouped = {}

    for movie in movies:
        title = normalize_title_for_match(movie.get("movieNm", ""))
        open_dt = movie.get("openDt", "")
        if not title or not open_dt:
            continue

        grouped.setdefault((open_dt, title), []).append(movie)

    return {
        key: items
        for key, items in grouped.items()
        if len(items) > 1
    }


def print_data_warnings(final_movies):
    duplicate_release_titles = find_duplicate_release_titles(final_movies)
    if not duplicate_release_titles:
        return

    print("\n[확인 필요: 같은 날짜/제목 중복]")
    for (open_dt, _), movies in duplicate_release_titles.items():
        title = movies[0].get("movieNm", "")
        movie_ids = ", ".join(movie_key(movie) for movie in movies)
        print(f"- {title} ({open_dt}) / {movie_ids}")


def save_update_results(
    final_movies,
    newly_generated_movies,
    manual_movies,
    excluded_movies,
    held_movies,
):
    save_json_list(MOVIES_FILE, final_movies)
    save_json_list(LAST_GENERATED_FILE, newly_generated_movies)
    save_json_list(MANUAL_MOVIES_FILE, manual_movies)
    save_json_list(HELD_MOVIES_FILE, held_movies)

    excluded_movies.sort(key=movie_sort_key)
    save_json_list(EXCLUDED_IDS_FILE, excluded_movies)


def print_update_summary(
    current_movies,
    newly_generated_movies,
    newly_held_movies,
    refreshed_existing,
    released_held_movies,
    forced_added_movies,
    added,
    skipped_existing,
    manual_added,
    excluded_movies,
    final_movies,
    held_movies,
):
    print("\n=== 업데이트 결과 ===")
    print(f"현재 목록 개수: {len(current_movies)}")
    print(f"새로 추출된 개수: {len(newly_generated_movies)}")
    print(f"새로 보류된 개수: {len(newly_held_movies)}")
    print(f"기존 영화 재보강 개수: {len(refreshed_existing)}")
    print(f"보류 해제 개수: {len(released_held_movies)}")
    print(f"보류 목록에서 추가 요청된 개수: {len(forced_added_movies)}")
    print(f"새로 추가된 개수: {len(added)}")
    print(f"기존에 있어서 유지된 개수: {len(skipped_existing)}")
    print(f"수동 추가 개수: {len(manual_added)}")
    print(f"보류된 개수: {len(held_movies)}")
    print(f"자동 제외 목록 개수: {len(excluded_movies)}")
    print(f"최종 저장 개수: {len(final_movies)}")

    if added:
        print("\n[새로 추가된 영화]")
        for movie in added[:20]:
            poster_mark = " [포스터]" if movie.get("posterUrl") else ""
            print(f"- {movie.get('movieNm')} ({movie.get('openDt')}){poster_mark}")

    if newly_held_movies:
        print("\n[새로 보류된 영화]")
        for movie in newly_held_movies[:20]:
            reason_text = movie.get("holdReason") or "사유 확인 필요"
            print(f"- {movie.get('movieNm')} ({movie.get('openDt')}) - {reason_text}")

    if refreshed_existing:
        print("\n[재보강된 기존 영화]")
        for movie in refreshed_existing[:20]:
            print(f"- {movie.get('movieNm')} ({movie.get('openDt')})")

    if forced_added_movies:
        print("\n[보류 목록에서 추가된 영화]")
        for movie in forced_added_movies[:20]:
            print(f"- {movie.get('movieNm')} ({movie.get('openDt')})")

    if released_held_movies:
        print("\n[보류 해제된 영화]")
        for movie in released_held_movies[:20]:
            print(f"- {movie.get('movieNm')} ({movie.get('openDt')})")

    if held_movies:
        print("\n[보류된 영화]")
        for movie in held_movies[:20]:
            reason_text = movie.get("holdReason") or "사유 확인 필요"
            print(f"- {movie.get('movieNm')} ({movie.get('openDt')}) - {reason_text}")

    print(f"\n저장 완료 → {MOVIES_FILE}")
    print(f"자동 생성 기준 저장 → {LAST_GENERATED_FILE}")
    print(f"자동 제외 목록 저장 → {EXCLUDED_IDS_FILE}")
    print(f"보류 목록 저장 → {HELD_MOVIES_FILE}")


def main():
    start_date = resolve_start_date()
    end_date = start_date + datetime.timedelta(days=UPDATE_WINDOW_DAYS)

    print(f"\n조회 범위: {start_date} ~ {end_date}")

    data = load_update_data()
    current_movies = data["current_movies"]
    last_generated_movies = data["last_generated_movies"]
    manual_movies = data["manual_movies"]
    excluded_movies = data["excluded_movies"]
    held_movies = data["held_movies"]

    excluded_ids = build_excluded_id_set(excluded_movies)
    manual_movies = enrich_manual_movies(manual_movies, excluded_ids)
    save_json_list(MANUAL_MOVIES_FILE, manual_movies)

    excluded_movies, _ = add_deleted_movies_to_exclusions(
        excluded_movies,
        last_generated_movies,
        current_movies,
        manual_movies,
    )

    excluded_ids = build_excluded_id_set(excluded_movies)
    current_map = build_movie_map(current_movies)

    raw_movies = fetch_all_movies(start_date.year, end_date.year)
    raw_movie_map = build_raw_movie_map(raw_movies, start_date, end_date)
    refreshed_existing = refresh_existing_movies_in_window(
        current_map,
        raw_movie_map,
        start_date,
        end_date,
        excluded_ids,
    )
    held_movies, released_held_movies = refresh_held_movies(
        held_movies,
        raw_movie_map,
        excluded_ids,
    )
    held_movies, forced_added_movies = split_forced_held_movies(held_movies)
    forced_include_ids = {
        movie_key(movie) for movie in forced_added_movies if movie_key(movie)
    }
    manual_movies = merge_movies_into_list(manual_movies, forced_added_movies)

    for movie in released_held_movies:
        movie_cd = movie_key(movie)
        existing_movie = current_map.get(movie_cd)
        current_map[movie_cd] = merge_movie_record(existing_movie, movie)

    newly_generated_movies, newly_held_movies = build_newly_generated_movies(
        raw_movies,
        start_date,
        end_date,
        current_map,
        excluded_ids,
    )

    added, skipped_existing = merge_generated_movies(
        current_map,
        newly_generated_movies,
    )
    manual_added, _ = merge_manual_movies(current_map, manual_movies)
    held_movies = merge_movies_into_list(held_movies, newly_held_movies)
    held_movies = extract_held_movies_from_current_map(
        current_map,
        held_movies,
        forced_include_ids,
    )
    final_movies = build_final_movies(current_map)

    print_data_warnings(final_movies)

    save_update_results(
        final_movies,
        newly_generated_movies,
        manual_movies,
        excluded_movies,
        held_movies,
    )

    print_update_summary(
        current_movies,
        newly_generated_movies,
        newly_held_movies,
        refreshed_existing,
        released_held_movies,
        forced_added_movies,
        added,
        skipped_existing,
        manual_added,
        excluded_movies,
        final_movies,
        held_movies,
    )


if __name__ == "__main__":
    main()
