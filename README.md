# movie_calendar

KOBIS 개봉 예정작 데이터를 바탕으로 영화 일정을 보여주는 Flutter 웹 앱입니다. 필요할 때 TMDB 데이터를 함께 사용해 포스터, 줄거리, 장르, 감독 정보를 보강합니다.

## Local Update

영화 데이터 갱신:

```bash
python3 update_movies.py
```

특정 날짜를 기준으로 갱신:

```bash
python3 update_movies.py --start-date 2026-04-27
```

웹 빌드:

```bash
flutter build web --release --base-href /movie-calendar/
```

## Weekly Automation

주간 자동화는 GitHub Actions로 설정되어 있습니다.

- 워크플로 파일: `.github/workflows/weekly_update.yml`
- 실행 시각: 매주 월요일, 금요일 03:00 KST
- 수행 작업: 데이터 갱신, `flutter analyze`, `flutter test`, 웹 빌드, `docs` 갱신, 자동 커밋

필수 GitHub Secrets:

- `KOBIS_KEY`
- `TMDB_BEARER_TOKEN`

수동 실행도 가능합니다. GitHub Actions의 `Weekly Movie Update` 워크플로에서 `Run workflow`를 누르고 필요하면 `start_date`를 넣으면 됩니다.
