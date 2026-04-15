import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const ReleaseCalendarApp());
}

/// =====================================================
/// UI CONFIG
/// =====================================================

class UIColors {
  // App
  static const Color scaffoldBackground = Color(0xFFF8FAFC);
  static const Color appBarBackground = Color(0xFFFFFFFF);
  static const Color appBarForeground = Color(0xFF111827);

  // Summary
  static const Color summaryBackground = Color(0xFFFFFFFF);
  static const Color summaryDivider = Color(0xFFE5E7EB);

  // Calendar
  static const Color calendarCellBackground = Color(0xFFFFFFFF);
  static const Color calendarCellBorder = Color(0xFFE5E7EB);
  static const Color selectedCellBackground = Color(0xFFDBEAFE);
  static const Color selectedCellBorder = Color(0xFF2563EB);
  static const Color todayCellBackground = Color(0xFFE0F2FE);
  static const Color todayCellBorder = Color(0xFF0284C7);

  // Indicators
  static const Color indicatorDot = Color(0xFF2563EB);
  static const Color indicatorBadgeBackground = Color(0xFF2563EB);
  static const Color indicatorBadgeText = Color(0xFFFFFFFF);

  // Movie card
  static const Color movieCardBackground = Color(0xFFFFFFFF);
  static const Color moviePosterBackground = Color(0xFFF3F4F6);

  // Badge
  static const Color rereleaseBadgeBackground = Color(0xFFFDE68A);
  static const Color rereleaseBadgeText = Color(0xFF92400E);

  // Text
  static const Color titleText = Color(0xFF111827);
  static const Color bodyText = Color(0xFF374151);
  static const Color subText = Color(0xFF6B7280);

  // Divider / icon
  static const Color divider = Color(0xFFE5E7EB);
  static const Color icon = Color(0xFF374151);

  // Button / loading / error
  static const Color primaryButtonBackground = Color(0xFF2563EB);
  static const Color primaryButtonForeground = Color(0xFFFFFFFF);
  static const Color loadingIndicator = Color(0xFF2563EB);
  static const Color errorIcon = Color(0xFFDC2626);
  static const Color errorText = Color(0xFF111827);
}

class UISpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
}

class UISizes {
  static const double cardRadius = 16;
  static const double summaryRadius = 16;
  static const double calendarCellRadius = 16;
  static const double movieCardRadius = 16;
  static const double posterRadius = 10;
  static const double badgeRadius = 999;

  static const double selectedBorderWidth = 1.6;
  static const double normalBorderWidth = 1.0;
  static const double summaryDividerWidth = 1.0;

  static const double movieListHeight = 250;
  static const double compactMovieListRatio = 0.27;
  static const double compactScreenHeightThreshold = 700;

  static const double moviePosterWidth = 42;
  static const double moviePosterHeight = 56;

  static const double movieDotSize = 6;
  static const double movieDotRowHeight = 14;
  static const double movieDotSpacing = 2;

  static const double errorIconSize = 40;
  static const double loadingStrokeWidth = 3;
}

class UIText {
  static const double appBarTitle = 18;
  static const double monthTitle = 22;

  static const double summaryLabel = 14;
  static const double summaryValue = 18;

  static const double weekday = 14;
  static const double dayNumber = 13;
  static const double indicatorBadge = 9;

  static const double selectedDateTitle = 16;
  static const double movieTitle = 15;
  static const double movieMeta = 13;
  static const double movieDirector = 12;
  static const double badge = 12;

  static const double emptyText = 14;
  static const double errorText = 14;
  static const double retryButton = 14;

  static const FontWeight appBarTitleWeight = FontWeight.w700;
  static const FontWeight monthTitleWeight = FontWeight.w700;
  static const FontWeight summaryLabelWeight = FontWeight.w500;
  static const FontWeight summaryValueWeight = FontWeight.w700;
  static const FontWeight weekdayWeight = FontWeight.w700;
  static const FontWeight dayNumberWeight = FontWeight.w700;
  static const FontWeight selectedDateTitleWeight = FontWeight.w700;
  static const FontWeight movieTitleWeight = FontWeight.w700;
  static const FontWeight badgeWeight = FontWeight.w700;
  static const FontWeight indicatorBadgeWeight = FontWeight.bold;
  static const FontWeight retryButtonWeight = FontWeight.w600;
}

class UILayout {
  static const double pageHorizontalPadding = 16;

  static const double monthHeaderLeft = 8;
  static const double monthHeaderTop = 8;
  static const double monthHeaderRight = 8;
  static const double monthHeaderBottom = 4;

  static const double weekdayHorizontalPadding = 12;
  static const double calendarHorizontalPadding = 12;
  static const double calendarTopPadding = 8;

  static const double calendarMainAxisSpacing = 8;
  static const double calendarCrossAxisSpacing = 8;

  static const double selectedListLeft = 16;
  static const double selectedListTop = 12;
  static const double selectedListRight = 16;
  static const double selectedListBottom = 16;
}

class UICalendar {
  static const double cellPaddingHorizontal = 4;
  static const double cellPaddingVertical = 5;
  static const double weekdayVerticalPadding = 5;
}

class UIMovieCard {
  static const double padding = 12;
  static const double gapBetweenPosterAndText = 12;
}

class UIBadge {
  static const double horizontalPadding = 8;
  static const double verticalPadding = 4;
}

class UIAdaptive {
  static const bool enableSwipeMonth = true;
}

class UIAnimation {
  static const Duration pageDuration = Duration(milliseconds: 280);
  static const Curve pageCurve = Curves.easeInOut;
}

/// =====================================================
/// APP
/// =====================================================

class ReleaseCalendarApp extends StatelessWidget {
  const ReleaseCalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movie Release Calendar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: UIColors.scaffoldBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: UIColors.appBarBackground,
          foregroundColor: UIColors.appBarForeground,
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: UIColors.appBarForeground,
            fontSize: UIText.appBarTitle,
            fontWeight: UIText.appBarTitleWeight,
          ),
          iconTheme: IconThemeData(color: UIColors.icon),
        ),
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
  final MovieRepository repository = (kDebugMode && !kIsWeb)
      ? LocalMovieRepository()
      : GithubMovieRepository();

  late DateTime focusedMonth;
  late DateTime selectedDate;
  late final PageController _pageController;

  bool isLoading = true;
  String? errorMessage;

  List<Movie> monthMovies = [];
  Map<DateTime, List<Movie>> moviesByDate = {};

  static const int _initialPage = 1200;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    focusedMonth = DateTime(now.year, now.month);
    selectedDate = DateTime(now.year, now.month, now.day);
    _pageController = PageController(initialPage: _initialPage);
    _loadMonth(focusedMonth);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  List<Movie> get selectedMovies {
    return moviesByDate[_normalizeDate(selectedDate)] ?? const [];
  }

  int get releaseCount =>
      monthMovies.where((movie) => !movie.isReRelease).length;
  int get reReleaseCount =>
      monthMovies.where((movie) => movie.isReRelease).length;

  DateTime _monthFromPage(int page) {
    final diff = page - _initialPage;
    return DateTime(focusedMonth.year, focusedMonth.month + diff, 1);
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

      if (!mounted) return;

      setState(() {
        focusedMonth = firstDay;
        monthMovies = movies;
        moviesByDate = grouped;

        final normalizedSelected = _normalizeDate(selectedDate);
        if (normalizedSelected.year != firstDay.year ||
            normalizedSelected.month != firstDay.month) {
          selectedDate = firstDay;
        }

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = '영화 개봉 정보를 불러오지 못했습니다.\n$e';
        isLoading = false;
      });
    }
  }

  void _goToNextMonth() {
    if (!_pageController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pageController.hasClients) return;

      _pageController.nextPage(
        duration: UIAnimation.pageDuration,
        curve: UIAnimation.pageCurve,
      );
    });
  }

  void _goToPreviousMonth() {
    if (!_pageController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pageController.hasClients) return;

      _pageController.previousPage(
        duration: UIAnimation.pageDuration,
        curve: UIAnimation.pageCurve,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final movieListHeight = screenHeight < UISizes.compactScreenHeightThreshold
        ? screenHeight * UISizes.compactMovieListRatio
        : UISizes.movieListHeight;

    return Scaffold(
      appBar: AppBar(title: const Text('영화 개봉 캘린더')),
      body: SafeArea(
        child: Column(
          children: [
            _MonthHeader(
              focusedMonth: focusedMonth,
              onPrevious: _goToPreviousMonth,
              onNext: _goToNextMonth,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: UILayout.pageHorizontalPadding,
              ),
              child: _MonthSummary(
                releaseCount: releaseCount,
                reReleaseCount: reReleaseCount,
              ),
            ),
            const SizedBox(height: UISpacing.s),
            Expanded(
              child: isLoading
                  ? const _LoadingState()
                  : errorMessage != null
                  ? _ErrorState(
                      message: errorMessage!,
                      onRetry: () => _loadMonth(focusedMonth),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: UILayout.weekdayHorizontalPadding,
                          ),
                          child: const _WeekdayHeader(),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              UILayout.calendarHorizontalPadding,
                              UILayout.calendarTopPadding,
                              UILayout.calendarHorizontalPadding,
                              0,
                            ),
                            child: UIAdaptive.enableSwipeMonth
                                ? PageView.builder(
                                    controller: _pageController,
                                    onPageChanged: (page) {
                                      final month = _monthFromPage(page);
                                      _loadMonth(month);
                                    },
                                    itemBuilder: (context, page) {
                                      final month = _monthFromPage(page);
                                      return _CalendarGrid(
                                        focusedMonth: month,
                                        selectedDate: selectedDate,
                                        moviesByDate: moviesByDate,
                                        onDateSelected: (date) {
                                          setState(() {
                                            selectedDate = date;
                                          });
                                        },
                                      );
                                    },
                                  )
                                : _CalendarGrid(
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
                        Container(
                          height: UISizes.summaryDividerWidth,
                          color: UIColors.divider,
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'This product uses the TMDB API but is not endorsed or certified by TMDB.\n데이터 출처: 영화진흥위원회 KOBIS',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: movieListHeight,
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
      padding: const EdgeInsets.fromLTRB(
        UILayout.monthHeaderLeft,
        UILayout.monthHeaderTop,
        UILayout.monthHeaderRight,
        UILayout.monthHeaderBottom,
      ),
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
                style: const TextStyle(
                  color: UIColors.titleText,
                  fontSize: UIText.monthTitle,
                  fontWeight: UIText.monthTitleWeight,
                ),
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
    required this.releaseCount,
    required this.reReleaseCount,
  });

  final int releaseCount;
  final int reReleaseCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: UISpacing.l,
        vertical: UISpacing.s,
      ),
      decoration: BoxDecoration(
        color: UIColors.summaryBackground,
        borderRadius: BorderRadius.circular(UISizes.summaryRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '개봉 $releaseCount편',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),

          Container(width: 1, height: 16, color: Colors.black12),

          const SizedBox(width: 12),

          Text(
            '재개봉 $reReleaseCount편',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  static const List<String> labels = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: labels
          .map(
            (label) => Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: UICalendar.weekdayVerticalPadding,
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: UIColors.bodyText,
                      fontSize: UIText.weekday,
                      fontWeight: UIText.weekdayWeight,
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

  DateTime _normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

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
      physics: const BouncingScrollPhysics(),
      shrinkWrap: true,
      itemCount: cellCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: UILayout.calendarMainAxisSpacing,
        crossAxisSpacing: UILayout.calendarCrossAxisSpacing,
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

        return _DayCell(
          date: date,
          isToday: normalized == today,
          isSelected: normalized == _normalize(selectedDate),
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
    Color backgroundColor = UIColors.calendarCellBackground;
    Color borderColor = UIColors.calendarCellBorder;
    double borderWidth = UISizes.normalBorderWidth;

    if (isSelected) {
      backgroundColor = UIColors.selectedCellBackground;
      borderColor = UIColors.selectedCellBorder;
      borderWidth = UISizes.selectedBorderWidth;
    } else if (isToday) {
      backgroundColor = UIColors.todayCellBackground;
      borderColor = UIColors.todayCellBorder;
      borderWidth = UISizes.selectedBorderWidth;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(UISizes.calendarCellRadius),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(UISizes.calendarCellRadius),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: UICalendar.cellPaddingHorizontal,
            vertical: UICalendar.cellPaddingVertical,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: const TextStyle(
                  color: UIColors.titleText,
                  fontSize: UIText.dayNumber,
                  fontWeight: UIText.dayNumberWeight,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 5),
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
      return const SizedBox(height: UISizes.movieDotRowHeight);
    }

    if (movieCount == 1) {
      return const _DotRow(dotCount: 1);
    }

    if (movieCount == 2) {
      return const _DotRow(dotCount: 2);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: UIColors.indicatorBadgeBackground,
        borderRadius: BorderRadius.circular(UISizes.badgeRadius),
      ),
      child: Text(
        '+$movieCount',
        style: const TextStyle(
          color: UIColors.indicatorBadgeText,
          fontSize: UIText.indicatorBadge,
          fontWeight: UIText.indicatorBadgeWeight,
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
      height: UISizes.movieDotRowHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          dotCount,
          (index) => Container(
            width: UISizes.movieDotSize,
            height: UISizes.movieDotSize,
            margin: const EdgeInsets.symmetric(
              horizontal: UISizes.movieDotSpacing,
            ),
            decoration: const BoxDecoration(
              color: UIColors.indicatorDot,
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
      padding: const EdgeInsets.fromLTRB(
        UILayout.selectedListLeft,
        UILayout.selectedListTop,
        UILayout.selectedListRight,
        UILayout.selectedListBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${selectedDate.year}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.day.toString().padLeft(2, '0')} 개봉',
            style: const TextStyle(
              color: UIColors.titleText,
              fontSize: UIText.selectedDateTitle,
              fontWeight: UIText.selectedDateTitleWeight,
            ),
          ),
          const SizedBox(height: UISpacing.s),
          Expanded(
            child: movies.isEmpty
                ? const Center(
                    child: Text(
                      '이 날짜에 등록된 개봉작이 없습니다.',
                      style: TextStyle(
                        color: UIColors.bodyText,
                        fontSize: UIText.emptyText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: movies.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: UISpacing.s),
                    itemBuilder: (context, index) {
                      return _MovieTile(movie: movies[index]);
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
      padding: const EdgeInsets.all(UIMovieCard.padding),
      decoration: BoxDecoration(
        color: UIColors.movieCardBackground,
        borderRadius: BorderRadius.circular(UISizes.movieCardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: UISizes.moviePosterWidth,
            height: UISizes.moviePosterHeight,
            decoration: BoxDecoration(
              color: UIColors.moviePosterBackground,
              borderRadius: BorderRadius.circular(UISizes.posterRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: movie.posterUrl != null && movie.posterUrl!.isNotEmpty
                ? Image.network(
                    movie.posterUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.movie_outlined, color: UIColors.icon),
                      );
                    },
                  )
                : const Center(
                    child: Icon(Icons.movie_outlined, color: UIColors.icon),
                  ),
          ),
          const SizedBox(width: UIMovieCard.gapBetweenPosterAndText),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.title,
                  style: const TextStyle(
                    color: UIColors.titleText,
                    fontSize: UIText.movieTitle,
                    fontWeight: UIText.movieTitleWeight,
                  ),
                ),
                const SizedBox(height: UISpacing.xs),
                Text(
                  '${movie.genre} · ${movie.nation}',
                  style: const TextStyle(
                    color: UIColors.bodyText,
                    fontSize: UIText.movieMeta,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '감독 ${movie.director}',
                  style: const TextStyle(
                    color: UIColors.subText,
                    fontSize: UIText.movieDirector,
                  ),
                ),
                if (movie.isReRelease) ...[
                  const SizedBox(height: UISpacing.s),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UIBadge.horizontalPadding,
                      vertical: UIBadge.verticalPadding,
                    ),
                    decoration: BoxDecoration(
                      color: UIColors.rereleaseBadgeBackground,
                      borderRadius: BorderRadius.circular(UISizes.badgeRadius),
                    ),
                    child: const Text(
                      '재개봉',
                      style: TextStyle(
                        color: UIColors.rereleaseBadgeText,
                        fontSize: UIText.badge,
                        fontWeight: UIText.badgeWeight,
                      ),
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
        padding: const EdgeInsets.all(UISpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: UISizes.errorIconSize,
              color: UIColors.errorIcon,
            ),
            const SizedBox(height: UISpacing.m),
            Text(
              message,
              style: const TextStyle(
                color: UIColors.errorText,
                fontSize: UIText.errorText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: UISpacing.m),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: UIColors.primaryButtonBackground,
                foregroundColor: UIColors.primaryButtonForeground,
              ),
              onPressed: onRetry,
              child: const Text(
                '다시 시도',
                style: TextStyle(
                  fontSize: UIText.retryButton,
                  fontWeight: UIText.retryButtonWeight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: UISizes.loadingStrokeWidth,
          valueColor: AlwaysStoppedAnimation<Color>(UIColors.loadingIndicator),
        ),
      ),
    );
  }
}

/// =====================================================
/// MODEL / REPOSITORY
/// =====================================================

class Movie {
  const Movie({
    required this.movieCd,
    required this.title,
    required this.openDate,
    required this.genre,
    required this.nation,
    required this.director,
    this.isReRelease = false,
    this.posterUrl,
  });

  final String movieCd;
  final String title;
  final DateTime openDate;
  final String genre;
  final String nation;
  final String director;
  final bool isReRelease;
  final String? posterUrl;
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
        posterUrl: json['posterUrl'] as String?,
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

class LocalMovieRepository implements MovieRepository {
  @override
  Future<List<Movie>> fetchMoviesByMonth(
    DateTime firstDay,
    DateTime lastDay,
  ) async {
    final response = await http.get(
      Uri.parse(
        'http://localhost:8000/data/movies.json?t=${DateTime.now().millisecondsSinceEpoch}',
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('로컬 영화 데이터를 불러오지 못했습니다.');
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
        posterUrl: json['posterUrl'] as String?,
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
