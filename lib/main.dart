import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const ReleaseCalendarApp());
}

class ReleaseCalendarApp extends StatelessWidget {
  const ReleaseCalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movie Release Calendar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        useMaterial3: true,
      ),
      home: const ReleaseCalendarPage(),
    );
  }
}

class ReleaseCalendarPage extends StatefulWidget {
  const ReleaseCalendarPage({super.key});

  @override
  State<ReleaseCalendarPage> createState() => _ReleaseCalendarPageState();
}

class _ReleaseCalendarPageState extends State<ReleaseCalendarPage> {
  final MovieRepository repository = GithubMovieRepository();

  late DateTime focusedMonth;
  late DateTime selectedDate;
  bool isLoading = true;
  String? errorMessage;

  List<Movie> monthMovies = [];
  Map<DateTime, List<Movie>> moviesByDate = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    focusedMonth = DateTime(now.year, now.month);
    selectedDate = DateTime(now.year, now.month, now.day);
    _loadMonth(focusedMonth);
  }

  Future<void> _loadMonth(DateTime month) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0);

      final movies = await repository.fetchMoviesByMonth(firstDay, lastDay);
      final grouped = _groupMoviesByDate(movies);

      setState(() {
        focusedMonth = firstDay;
        monthMovies = movies;
        moviesByDate = grouped;

        final normalizedSelected = _normalizeDate(selectedDate);
        if (normalizedSelected.month != focusedMonth.month ||
            normalizedSelected.year != focusedMonth.year) {
          selectedDate = firstDay;
        }

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = '영화 개봉 정보를 불러오지 못했습니다.\n$e';
        isLoading = false;
      });
    }
  }

  Map<DateTime, List<Movie>> _groupMoviesByDate(List<Movie> movies) {
    final map = <DateTime, List<Movie>>{};
    for (final movie in movies) {
      final key = _normalizeDate(movie.openDate);
      map.putIfAbsent(key, () => []);
      map[key]!.add(movie);
    }

    for (final entry in map.entries) {
      entry.value.sort((a, b) => a.title.compareTo(b.title));
    }

    return map;
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<Movie> get selectedMovies =>
      moviesByDate[_normalizeDate(selectedDate)] ?? const [];

  void _goToPreviousMonth() {
    _loadMonth(DateTime(focusedMonth.year, focusedMonth.month - 1, 1));
  }

  void _goToNextMonth() {
    _loadMonth(DateTime(focusedMonth.year, focusedMonth.month + 1, 1));
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(title: const Text('영화 개봉 캘린더'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            _MonthHeader(
              focusedMonth: focusedMonth,
              onPrevious: _goToPreviousMonth,
              onNext: _goToNextMonth,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _MonthSummary(
                movieCount: monthMovies.length,
                releaseDayCount: moviesByDate.length,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
                  ? _ErrorState(
                      message: errorMessage!,
                      onRetry: () => _loadMonth(focusedMonth),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _WeekdayHeader(),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            child: _CalendarGrid(
                              focusedMonth: focusedMonth,
                              selectedDate: selectedDate,
                              moviesByDate: moviesByDate,
                              onDateSelected: (date) {
                                setState(() {
                                  selectedDate = date;
                                });
                              },
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        SizedBox(
                          height: screenHeight < 700
                              ? screenHeight * 0.22
                              : 220,
                          child: _SelectedDateMovieList(
                            selectedDate: selectedDate,
                            movies: selectedMovies,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.focusedMonth,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime focusedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${focusedMonth.year}년 ${focusedMonth.month}월',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({
    required this.movieCount,
    required this.releaseDayCount,
  });

  final int movieCount;
  final int releaseDayCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(label: '이번 달 개봉작', value: '$movieCount편'),
          ),
          Container(width: 1, height: 36, color: Colors.black12),
          Expanded(
            child: _SummaryItem(label: '개봉일 있는 날짜', value: '$releaseDayCount일'),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final List<String> labels = const ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: labels
          .map(
            (label) => Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.focusedMonth,
    required this.selectedDate,
    required this.moviesByDate,
    required this.onDateSelected,
  });

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final Map<DateTime, List<Movie>> moviesByDate;
  final ValueChanged<DateTime> onDateSelected;

  DateTime _normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth = DateTime(
      focusedMonth.year,
      focusedMonth.month + 1,
      0,
    ).day;
    final leadingEmptyCount = firstDay.weekday % 7;
    final totalCells = leadingEmptyCount + daysInMonth;
    final rowCount = (totalCells / 7).ceil();
    final cellCount = rowCount * 7;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cellCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        if (index < leadingEmptyCount ||
            index >= leadingEmptyCount + daysInMonth) {
          return const SizedBox.shrink();
        }

        final day = index - leadingEmptyCount + 1;
        final date = DateTime(focusedMonth.year, focusedMonth.month, day);
        final normalized = _normalize(date);
        final movieCount = moviesByDate[normalized]?.length ?? 0;

        final today = _normalize(DateTime.now());
        final isToday = normalized == today;
        final isSelected = normalized == _normalize(selectedDate);

        return _DayCell(
          date: date,
          isToday: isToday,
          isSelected: isSelected,
          movieCount: movieCount,
          onTap: () => onDateSelected(date),
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.movieCount,
    required this.onTap,
  });

  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final int movieCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color borderColor = Colors.transparent;
    Color backgroundColor = colorScheme.surface;

    if (isSelected) {
      backgroundColor = colorScheme.primaryContainer;
      borderColor = colorScheme.primary;
    } else if (isToday) {
      backgroundColor = colorScheme.secondaryContainer;
      borderColor = colorScheme.secondary;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: isSelected || isToday ? 1.6 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${date.day}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              _MovieIndicator(movieCount: movieCount),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovieIndicator extends StatelessWidget {
  const _MovieIndicator({required this.movieCount});

  final int movieCount;

  @override
  Widget build(BuildContext context) {
    if (movieCount <= 0) {
      return const SizedBox(height: 14);
    }

    if (movieCount == 1) {
      return const _DotRow(dotCount: 1);
    }

    if (movieCount == 2) {
      return const _DotRow(dotCount: 2);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '+$movieCount',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DotRow extends StatelessWidget {
  const _DotRow({required this.dotCount});

  final int dotCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          dotCount,
          (index) => Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedDateMovieList extends StatelessWidget {
  const _SelectedDateMovieList({
    required this.selectedDate,
    required this.movies,
  });

  final DateTime selectedDate;
  final List<Movie> movies;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${selectedDate.year}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.day.toString().padLeft(2, '0')} 개봉',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: movies.isEmpty
                ? Center(
                    child: Text(
                      '이 날짜에 등록된 개봉작이 없습니다.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView.separated(
                    itemCount: movies.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final movie = movies[index];
                      return _MovieTile(movie: movie);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MovieTile extends StatelessWidget {
  const _MovieTile({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.movie_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${movie.genre} · ${movie.nation}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '감독 ${movie.director}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (movie.isReRelease) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '재개봉',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

class Movie {
  const Movie({
    required this.movieCd,
    required this.title,
    required this.openDate,
    required this.genre,
    required this.nation,
    required this.director,
    this.isReRelease = false,
  });

  final String movieCd;
  final String title;
  final DateTime openDate;
  final String genre;
  final String nation;
  final String director;
  final bool isReRelease;
}

abstract class MovieRepository {
  Future<List<Movie>> fetchMoviesByMonth(DateTime firstDay, DateTime lastDay);
}

class MockMovieRepository implements MovieRepository {
  @override
  Future<List<Movie>> fetchMoviesByMonth(
    DateTime firstDay,
    DateTime lastDay,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final sample = <Movie>[
      Movie(
        movieCd: '20260001',
        title: '봄의 장면',
        openDate: DateTime(firstDay.year, firstDay.month, 2),
        genre: '드라마',
        nation: '한국',
        director: '김다온',
      ),
      Movie(
        movieCd: '20260002',
        title: '문라이트 시티',
        openDate: DateTime(firstDay.year, firstDay.month, 2),
        genre: '로맨스',
        nation: '한국',
        director: '이서현',
      ),
      Movie(
        movieCd: '20260003',
        title: '심연의 항해',
        openDate: DateTime(firstDay.year, firstDay.month, 8),
        genre: '스릴러',
        nation: '미국',
        director: 'Daniel Hart',
      ),
      Movie(
        movieCd: '20260004',
        title: '낮과 밤 사이',
        openDate: DateTime(firstDay.year, firstDay.month, 8),
        genre: '미스터리',
        nation: '한국',
        director: '박예준',
      ),
      Movie(
        movieCd: '20260005',
        title: '소년과 별',
        openDate: DateTime(firstDay.year, firstDay.month, 14),
        genre: '애니메이션',
        nation: '일본',
        director: 'Aoi Tanaka',
      ),
      Movie(
        movieCd: '20260006',
        title: '리와인드 1999',
        openDate: DateTime(firstDay.year, firstDay.month, 18),
        genre: 'SF',
        nation: '영국',
        director: 'Emily Rose',
      ),
      Movie(
        movieCd: '20260007',
        title: '클래식 리마스터',
        openDate: DateTime(firstDay.year, firstDay.month, 18),
        genre: '드라마',
        nation: '프랑스',
        director: 'Jean Moreau',
        isReRelease: true,
      ),
      Movie(
        movieCd: '20260008',
        title: '도시의 초상',
        openDate: DateTime(firstDay.year, firstDay.month, 24),
        genre: '독립영화',
        nation: '한국',
        director: '최민석',
      ),
      Movie(
        movieCd: '20260009',
        title: '한여름의 끝',
        openDate: DateTime(firstDay.year, firstDay.month, 24),
        genre: '멜로',
        nation: '한국',
        director: '정하린',
      ),
      Movie(
        movieCd: '20260010',
        title: '라스트 스테이션',
        openDate: DateTime(firstDay.year, firstDay.month, 24),
        genre: '액션',
        nation: '미국',
        director: 'Chris Nolan Jr.',
      ),
      Movie(
        movieCd: '20260011',
        title: '하늘 아래 우리',
        openDate: DateTime(firstDay.year, firstDay.month, 30),
        genre: '다큐멘터리',
        nation: '한국',
        director: '윤세아',
      ),
    ];

    return sample.where((movie) {
      final d = movie.openDate;
      final afterOrSame = !d.isBefore(
        DateTime(firstDay.year, firstDay.month, firstDay.day),
      );
      final beforeOrSame = !d.isAfter(
        DateTime(lastDay.year, lastDay.month, lastDay.day),
      );
      return afterOrSame && beforeOrSame;
    }).toList();
  }
}

/// KOBIS 연동 시 교체 예시
///
/// 1. 이 Repository를 실제 구현으로 바꿉니다.
/// 2. 앱에서 직접 KOBIS를 호출하지 말고, 중간 백엔드를 두는 것을 권장합니다.
/// 3. 백엔드는 월 범위를 받아 정제된 JSON을 반환하면 됩니다.
///
/// class KobisMovieRepository implements MovieRepository {
///   final Dio dio;
///   KobisMovieRepository(this.dio);
///
///   @override
///   Future<List<Movie>> fetchMoviesByMonth(DateTime firstDay, DateTime lastDay) async {
///     final response = await dio.get(
///       'https://your-backend.example.com/releases',
///       queryParameters: {
///         'startDate': _formatDate(firstDay),
///         'endDate': _formatDate(lastDay),
///       },
///     );
///
///     final list = response.data as List<dynamic>;
///     return list.map((json) => Movie(
///       movieCd: json['movieCd'] as String,
///       title: json['movieNm'] as String,
///       openDate: DateTime.parse(json['openDt'] as String),
///       genre: json['genreNm'] as String? ?? '기타',
///       nation: json['nationAlt'] as String? ?? '미상',
///       director: json['director'] as String? ?? '정보 없음',
///       isReRelease: json['isReRelease'] as bool? ?? false,
///     )).toList();
///   }
/// }
class GithubMovieRepository implements MovieRepository {
  final String url =
      'https://raw.githubusercontent.com/hellostrang2r/movie-calendar/main/data/movies.json';

  @override
  Future<List<Movie>> fetchMoviesByMonth(
    DateTime firstDay,
    DateTime lastDay,
  ) async {
    final response = await http.get(
      Uri.parse('$url?t=${DateTime.now().millisecondsSinceEpoch}'),
    );

    if (response.statusCode != 200) {
      throw Exception('영화 데이터를 불러오지 못했습니다.');
    }

    final List<dynamic> data = jsonDecode(response.body);

    final movies = data.map((json) {
      return Movie(
        movieCd: json['movieCd'] as String,
        title: json['movieNm'] as String,
        openDate: DateTime.parse(json['openDt'] as String),
        genre: json['genreNm'] as String? ?? '기타',
        nation: json['nationAlt'] as String? ?? '미상',
        director: json['director'] as String? ?? '정보 없음',
        isReRelease: json['isReRelease'] as bool? ?? false,
      );
    }).toList();

    return movies.where((movie) {
      final d = movie.openDate;
      final afterOrSame = !d.isBefore(
        DateTime(firstDay.year, firstDay.month, firstDay.day),
      );
      final beforeOrSame = !d.isAfter(
        DateTime(lastDay.year, lastDay.month, lastDay.day),
      );
      return afterOrSame && beforeOrSame;
    }).toList();
  }
}
