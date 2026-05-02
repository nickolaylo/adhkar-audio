// =========================
// UPDATED FULL FILE WITH TODO-NEW (Later today section)
// =========================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter4/views/widgets/task_date_filter_chips.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/prayer.dart';
import '../../models/task.dart';
import '../../viewmodels/prayer_viewmodel.dart';
import '../../viewmodels/task_viewmodel.dart';
import '../edit_task_page.dart';
import 'unified_timeline_row.dart';
import 'timeline_type_filter_chips.dart';
import 'adhkar_card.dart';

// =========================
// TODO-NEW:
// أضفنا widget.selectedDateFilter حتى نتحكم في ما يعرض
// =========================
class PrayerTimelineSection extends StatefulWidget {
  final TaskDateFilter selectedDateFilter;
  final TimelineItemType selectedTimelineType;

  const PrayerTimelineSection({
    super.key,
    required this.selectedDateFilter,
    this.selectedTimelineType = TimelineItemType.all,
  });

  @override
  State<PrayerTimelineSection> createState() => _PrayerTimelineSectionState();
}

class _PrayerTimelineSectionState extends State<PrayerTimelineSection> {
  DateTime _displayedPrayerDate = DateTime.now();

  @override
  void didUpdateWidget(covariant PrayerTimelineSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selectedTimelineType != TimelineItemType.prayers ||
        widget.selectedDateFilter != TaskDateFilter.today) {
      _displayedPrayerDate = DateTime.now();
    }
  }

  void _goToPreviousPrayerDay() {
    setState(() {
      _displayedPrayerDate = _displayedPrayerDate.subtract(
        const Duration(days: 1),
      );
    });
  }

  void _goToNextPrayerDay() {
    setState(() {
      _displayedPrayerDate = _displayedPrayerDate.add(
        const Duration(days: 1),
      );
    });
  }

  void _goToTodayPrayerDay() {
    setState(() {
      _displayedPrayerDate = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TaskViewModel, PrayerViewModel>(
      builder: (context, taskVM, prayerVM, child) {
        // =========================
        // IMPORTANT:
        // إذا كان المستخدم في Tomorrow / Upcoming / Anytime
        // لا نحتاج مواقيت الصلاة ولا Timeline.
        // نعرض فقط List عادية للمهام المناسبة للفلتر.
        // =========================
        if (widget.selectedDateFilter != TaskDateFilter.today) {
          if (widget.selectedTimelineType == TimelineItemType.prayers ||
              widget.selectedTimelineType == TimelineItemType.adhkar) {
            return const _SimpleEmptyState(
              message: "This filter is available for today only.",
            );
          }

          return _buildSimpleFilteredTaskList(taskVM);
        }

        if (prayerVM.isLoading && prayerVM.prayers.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!prayerVM.hasLocation) {
          if (widget.selectedTimelineType == TimelineItemType.prayers ||
              widget.selectedTimelineType == TimelineItemType.adhkar) {
            return const _SimpleEmptyState(
              message: "Choose your prayer location to show this filter.",
            );
          }

          return _buildTodayTasksWithoutPrayerLocation(taskVM);
        }

        if (prayerVM.prayers.isEmpty) {
          return const Center(
            child: Text(
              "No prayer times available today",
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        return FutureBuilder<_AdhkarSettingsSnapshot>(
          future: _loadAdhkarSettings(),
          builder: (context, snapshot) {
            final adhkarSettings =
                snapshot.data ?? const _AdhkarSettingsSnapshot.defaults();

            final blocks = _buildPrayerBlocks(
              prayers: prayerVM.prayers,
              taskVM: taskVM,
              adhkarSettings: adhkarSettings,
              selectedTimelineType: widget.selectedTimelineType,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
              children: [
                if (widget.selectedTimelineType == TimelineItemType.prayers) ...[
                  _PrayerCalendarHeader(
                    locationLabel: prayerVM.locationLabel,
                    displayedDate: _displayedPrayerDate,
                    onPreviousDay: _goToPreviousPrayerDay,
                    onNextDay: _goToNextPrayerDay,
                    onToday: _goToTodayPrayerDay,
                  ),
                  const SizedBox(height: 8),
                ],

                if (blocks.isEmpty)
                  const _EmptyDayMessage(),

                ...blocks,
              ],
            );
          },
        );
      },
    );
  }


  // =========================
  // TODAY WITHOUT PRAYER LOCATION
  // =========================
  // عند أول تثبيت للتطبيق قد لا يكون المستخدم اختار موقعه بعد.
  // في هذه الحالة لا نعرض Timeline لأن مواقيت الصلاة غير متوفرة،
  // لكننا لا نخفي المهام.
  Widget _buildTodayTasksWithoutPrayerLocation(TaskViewModel taskVM) {
    final tasks = taskVM.todayTasks;

    if (tasks.isEmpty) {
      return const _SimpleEmptyState(
        message: "Choose your prayer location to show the prayer timeline.",
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      children: [
        const _LocationNeededMessage(),
        ...tasks.map((task) {
          return _TimelineTaskCard(task: task);
        }),
      ],
    );
  }

  // =========================
  // SIMPLE LIST FOR NON-TODAY FILTERS
  // =========================
  // هذه الدالة مسؤولة عن عرض المهام عندما لا يكون الفلتر Today.
  // لأن Timeline مرتبط بالصلاة ومناسب لليوم فقط.
  Widget _buildSimpleFilteredTaskList(TaskViewModel taskVM) {
    final tasks = _tasksForSelectedFilter(taskVM);

    if (tasks.isEmpty) {
      return _SimpleEmptyState(
        message: _emptyMessageForSelectedFilter(),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      children: tasks.map((task) {
        return _TimelineTaskCard(task: task);
      }).toList(),
    );
  }

  // =========================
  // SELECT TASKS BY FILTER
  // =========================
  List<Task> _tasksForSelectedFilter(TaskViewModel taskVM) {
    switch (widget.selectedDateFilter) {
      case TaskDateFilter.today:
        return taskVM.todayTasks;
      case TaskDateFilter.tomorrow:
        return taskVM.tomorrowTasks;
      case TaskDateFilter.upcoming:
        return taskVM.upcomingTasks;
      case TaskDateFilter.anytime:
        return taskVM.anytimeTasks;
    }
  }

  // =========================
  // EMPTY MESSAGE BY FILTER
  // =========================
  String _emptyMessageForSelectedFilter() {
    switch (widget.selectedDateFilter) {
      case TaskDateFilter.today:
        return "No tasks for today 👀";
      case TaskDateFilter.tomorrow:
        return "No tasks for tomorrow 👀";
      case TaskDateFilter.upcoming:
        return "No upcoming tasks 👀";
      case TaskDateFilter.anytime:
        return "No anytime tasks 👀";
    }
  }

  Future<_AdhkarSettingsSnapshot> _loadAdhkarSettings() async {
    final prefs = await SharedPreferences.getInstance();

    return _AdhkarSettingsSnapshot(
      showAdhkarCards: prefs.getBool('showAdhkarCards') ?? true,
      morningEnabled: prefs.getBool('morningAdhkarEnabled') ?? true,
      eveningEnabled: prefs.getBool('eveningAdhkarEnabled') ?? true,
      sleepEnabled: prefs.getBool('sleepAdhkarEnabled') ?? true,
      morningTiming: prefs.getString('morningAdhkarTiming') ?? 'After Fajr',
      eveningTiming: prefs.getString('eveningAdhkarTiming') ?? 'After Maghrib',
      sleepTiming: prefs.getString('sleepAdhkarTiming') ?? 'After Isha',
    );
  }

  List<Widget> _adhkarCardsForPrayer({
    required PrayerType prayerType,
    required String prayerTime,
    required _AdhkarSettingsSnapshot settings,
    required TimelineItemType selectedTimelineType,
  }) {
    if (!settings.showAdhkarCards) return [];

    final cards = <Widget>[];

    if (settings.morningEnabled &&
        prayerType == PrayerType.fajr &&
        settings.morningTiming == 'After Fajr') {
      cards.add(
        AdhkarCard(
          title: 'Morning adhkar',
          subtitle: 'After Fajr · $prayerTime',
          icon: Icons.wb_sunny_rounded,
          storageKeyPrefix: 'morning_adhkar',
        ),
      );
    }

    if (settings.eveningEnabled &&
        settings.eveningTiming == 'After Asr' &&
        prayerType == PrayerType.asr) {
      cards.add(
        AdhkarCard(
          title: 'Evening adhkar',
          subtitle: 'After Asr · $prayerTime',
          icon: Icons.nights_stay_rounded,
          storageKeyPrefix: 'evening_adhkar',
        ),
      );
    }

    if (settings.eveningEnabled &&
        settings.eveningTiming == 'After Maghrib' &&
        prayerType == PrayerType.maghrib) {
      cards.add(
        AdhkarCard(
          title: 'Evening adhkar',
          subtitle: 'After Maghrib · $prayerTime',
          icon: Icons.nights_stay_rounded,
          storageKeyPrefix: 'evening_adhkar',
        ),
      );
    }

    if (settings.sleepEnabled &&
        prayerType == PrayerType.isha &&
        settings.sleepTiming == 'After Isha') {
      cards.add(
        AdhkarCard(
          title: 'Sleep adhkar',
          subtitle: 'After Isha · $prayerTime',
          icon: Icons.bedtime_rounded,
          storageKeyPrefix: 'sleep_adhkar',
        ),
      );
    }

    return cards;
  }

  List<Widget> _buildPrayerBlocks({
    required List<Prayer> prayers,
    required TaskViewModel taskVM,
    required _AdhkarSettingsSnapshot adhkarSettings,
    required TimelineItemType selectedTimelineType,
  }) {
    final result = <Widget>[];

    final showTasks = selectedTimelineType == TimelineItemType.all ||
        selectedTimelineType == TimelineItemType.tasks;
    final showPrayers = selectedTimelineType == TimelineItemType.all ||
        selectedTimelineType == TimelineItemType.prayers;
    final showAdhkar = selectedTimelineType == TimelineItemType.all ||
        selectedTimelineType == TimelineItemType.adhkar;

    final currentPrayerName = _currentPrayerName(prayers);

    final nextTimelineEvent = _nextTimelineEvent(
      prayers: prayers,
      tasks: taskVM.tasks,
    );

    final nowNormalTask = _nowNormalTask(taskVM.tasks);

    if (showTasks) {
      final beforeFajrTasks = _onlyTodayTasks(
        taskVM.getTimeTasksBeforeFirstPrayer(
          prayers: prayers,
        ),
      );

      if (beforeFajrTasks.isNotEmpty) {
        result.add(
          _TimedTasksSection(
            tasks: beforeFajrTasks,
            nextNormalTask: nextTimelineEvent.task,
            nowNormalTask: nowNormalTask,
          ),
        );
      }
    }

    for (int i = 0; i < PrayerType.values.length; i++) {
      final prayerType = PrayerType.values[i];

      final prayerInfo = _findPrayerInfo(
        prayers: prayers,
        prayerType: prayerType,
      );

      final beforeTasks = showTasks
          ? _onlyTodayTasks(
              taskVM.getTasksForPrayer(
                prayerType,
                TaskRelation.before,
              ),
            )
          : <Task>[];

      final afterTasks = showTasks
          ? _onlyTodayTasks(
              taskVM.getTasksForPrayer(
                prayerType,
                TaskRelation.after,
              ),
            )
          : <Task>[];

      final adhkarCards = showAdhkar
          ? _adhkarCardsForPrayer(
              prayerType: prayerType,
              prayerTime: prayerInfo.time,
              settings: adhkarSettings,
              selectedTimelineType: selectedTimelineType,
            )
          : <Widget>[];

      final shouldShowPrayerBlock = showPrayers ||
          beforeTasks.isNotEmpty ||
          afterTasks.isNotEmpty ||
          adhkarCards.isNotEmpty;

      if (shouldShowPrayerBlock) {
        result.add(
          _PrayerTimelineBlock(
            showPrayerRow: showPrayers,
            prayerName: prayerInfo.name,
            prayerTime: prayerInfo.time,
            beforeTasks: beforeTasks,
            afterTasks: afterTasks,
            afterPrayerCards: adhkarCards,
            isCurrentPrayer: currentPrayerName != null &&
                prayerInfo.name.toLowerCase() == currentPrayerName.toLowerCase(),
            isNextPrayer: nextTimelineEvent.prayerName != null &&
                prayerInfo.name.toLowerCase() ==
                    nextTimelineEvent.prayerName!.toLowerCase(),
          ),
        );
      }

      if (showTasks && i < PrayerType.values.length - 1) {
        final currentPrayer = prayerType;
        final nextPrayer = PrayerType.values[i + 1];

        final timeTasks = _onlyTodayTasks(
          taskVM.getTimeTasksBetweenPrayers(
            currentPrayer: currentPrayer,
            nextPrayer: nextPrayer,
            prayers: prayers,
          ),
        );

        if (timeTasks.isNotEmpty) {
          result.add(
            _TimedTasksSection(
              tasks: timeTasks,
              nextNormalTask: nextTimelineEvent.task,
              nowNormalTask: nowNormalTask,
            ),
          );
        }
      }
    }

    if (showTasks) {
      final afterLastPrayerTasks = _onlyTodayTasks(
        taskVM.getTimeTasksAfterLastPrayer(
          prayers: prayers,
        ),
      );

      if (afterLastPrayerTasks.isNotEmpty) {
        result.add(
          _TimedTasksSection(
            tasks: afterLastPrayerTasks,
            nextNormalTask: nextTimelineEvent.task,
            nowNormalTask: nowNormalTask,
          ),
        );
      }

      final laterTodayTasks = _onlyTodayTasks(
        taskVM.todayTasks.where((task) {
          return task.scheduleType == TaskScheduleType.time &&
              (task.dueHour == null || task.dueMinute == null);
        }).toList(),
      );

      if (laterTodayTasks.isNotEmpty) {
        result.add(
          _LaterTodaySection(tasks: laterTodayTasks),
        );
      }
    }

    return result;
  }

  // =========================
  // TODAY SAFETY FILTER
  // =========================
  // بعض دوال TaskViewModel القديمة ترجع مهام من كل الأيام.
  // لذلك نضيف هنا حماية حتى لا تظهر مهمة الغد في Today.
  List<Task> _onlyTodayTasks(List<Task> tasks) {
    final now = DateTime.now();

    return tasks.where((task) {
      // Prayer كاملة بدون تاريخ = مهمة يومية.
      // لذلك تظهر في Timeline اليوم.
      if (task.scheduleType == TaskScheduleType.prayer &&
          task.linkedPrayer != null &&
          task.relationToPrayer != null &&
          task.dueDate == null) {
        return true;
      }

      if (task.dueDate == null) return false;

      return task.dueDate!.year == now.year &&
          task.dueDate!.month == now.month &&
          task.dueDate!.day == now.day;
    }).toList();
  }


  // =========================
  // NEXT TIMELINE EVENT HELPER
  // =========================
  // هذه الدالة تختار Next واحد فقط في الـ Timeline كله.
  //
  // القاعدة:
  // - ننظر إلى الصلاة القادمة.
  // - ننظر إلى المهمة العادية القادمة.
  // - نختار الأقرب زمنيًا.
  //
  // النتيجة:
  // Next قد يكون صلاة أو مهمة، لكن لا يظهر الاثنان معًا.
  _NextTimelineEvent _nextTimelineEvent({
    required List<Prayer> prayers,
    required List<Task> tasks,
  }) {
    final now = DateTime.now();

    DateTime? bestDateTime;
    String? bestPrayerName;
    Task? bestTask;

    for (final prayer in prayers) {
      final parsedTime = _parsePrayerTime(prayer.time);

      if (parsedTime == null) continue;

      final prayerDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        parsedTime.hour,
        parsedTime.minute,
      );

      if (!prayerDateTime.isAfter(now)) continue;

      if (bestDateTime == null || prayerDateTime.isBefore(bestDateTime)) {
        bestDateTime = prayerDateTime;
        bestPrayerName = prayer.name;
        bestTask = null;
      }
    }

    for (final task in tasks) {
      if (task.isDone) continue;
      if (!task.isTimeScheduled) continue;
      if (!task.hasSpecificTime) continue;
      if (task.dueDate == null) continue;

      final taskDate = task.dueDate!;

      if (!_isSameDay(taskDate, now)) continue;

      final taskDateTime = DateTime(
        taskDate.year,
        taskDate.month,
        taskDate.day,
        task.dueHour!,
        task.dueMinute!,
      );

      if (!taskDateTime.isAfter(now)) continue;

      if (bestDateTime == null || taskDateTime.isBefore(bestDateTime)) {
        bestDateTime = taskDateTime;
        bestPrayerName = null;
        bestTask = task;
      }
    }

    return _NextTimelineEvent(
      prayerName: bestPrayerName,
      task: bestTask,
    );
  }

  // =========================
  // NOW NORMAL TASK HELPER
  // =========================
  // Now Task = أول 5 دقائق بعد وقت المهمة فقط.
  //
  // مثال:
  // مهمة 17:00
  // من 17:00 إلى 17:05 => Now
  //
  // لا نربط هذا بـ Done.
  // Done يبقى فقط نتيجة checkbox.
  Task? _nowNormalTask(List<Task> tasks) {
    final now = DateTime.now();

    Task? nowTask;
    DateTime? nowTaskDateTime;

    for (final task in tasks) {
      if (!task.isTimeScheduled) continue;
      if (!task.hasSpecificTime) continue;
      if (task.dueDate == null) continue;

      final taskDate = task.dueDate!;

      if (!_isSameDay(taskDate, now)) continue;

      final taskDateTime = DateTime(
        taskDate.year,
        taskDate.month,
        taskDate.day,
        task.dueHour!,
        task.dueMinute!,
      );

      final windowEnd = taskDateTime.add(
        const Duration(minutes: 5),
      );

      final isInsideNowWindow =
          !now.isBefore(taskDateTime) && now.isBefore(windowEnd);

      if (!isInsideNowWindow) continue;

      if (nowTaskDateTime == null || taskDateTime.isBefore(nowTaskDateTime)) {
        nowTask = task;
        nowTaskDateTime = taskDateTime;
      }
    }

    return nowTask;
  }

  // مقارنة يومين بدون الساعة.
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // =========================
  // CURRENT PRAYER HELPER
  // =========================
  // Now Prayer = أول 10 دقائق فقط من دخول وقت الصلاة.
  String? _currentPrayerName(List<Prayer> prayers) {
    final now = DateTime.now();

    for (final prayer in prayers) {
      final parsedTime = _parsePrayerTime(prayer.time);

      if (parsedTime == null) continue;

      final prayerDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        parsedTime.hour,
        parsedTime.minute,
      );

      final windowEnd = prayerDateTime.add(
        const Duration(minutes: 10),
      );

      final isInsideNowWindow =
          !now.isBefore(prayerDateTime) && now.isBefore(windowEnd);

      if (isInsideNowWindow) {
        return prayer.name;
      }
    }

    return null;
  }

  // يقرأ وقت الصلاة مثل 13:33 أو 1:33 PM.
  TimeOfDay? _parsePrayerTime(String rawTime) {
    try {
      final value = rawTime.trim();

      if (value.isEmpty) return null;

      final parts = value.split(" ");

      if (parts.length == 2) {
        return _parse12HourTime(parts[0], parts[1]);
      }

      final timePieces = value.split(":");

      if (timePieces.length < 2) return null;

      return TimeOfDay(
        hour: int.parse(timePieces[0]),
        minute: int.parse(timePieces[1]),
      );
    } catch (_) {
      return null;
    }
  }

  TimeOfDay? _parse12HourTime(String timePart, String period) {
    try {
      final timePieces = timePart.split(":");

      if (timePieces.length < 2) return null;

      var hour = int.parse(timePieces[0]);
      final minute = int.parse(timePieces[1]);

      final normalizedPeriod = period.toUpperCase();

      if (normalizedPeriod == "PM" && hour != 12) {
        hour += 12;
      }

      if (normalizedPeriod == "AM" && hour == 12) {
        hour = 0;
      }

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  _PrayerDisplayInfo _findPrayerInfo({
    required List<Prayer> prayers,
    required PrayerType prayerType,
  }) {
    final expectedName = _prayerNameFromType(prayerType);

    final normalMatches = prayers.where((prayer) {
      return prayer.name.toLowerCase() == expectedName.toLowerCase();
    });

    if (normalMatches.isNotEmpty) {
      final prayer = normalMatches.first;

      return _PrayerDisplayInfo(
        name: prayer.name,
        time: prayer.time,
      );
    }

    if (prayerType == PrayerType.dhuhr) {
      final jumuahMatches = prayers.where((prayer) {
        return prayer.name.toLowerCase() == "jumuah";
      });

      if (jumuahMatches.isNotEmpty) {
        final prayer = jumuahMatches.first;

        return _PrayerDisplayInfo(
          name: prayer.name,
          time: prayer.time,
        );
      }
    }

    return _PrayerDisplayInfo(
      name: expectedName,
      time: "",
    );
  }

  String _prayerNameFromType(PrayerType prayerType) {
    switch (prayerType) {
      case PrayerType.fajr:
        return "Fajr";
      case PrayerType.dhuhr:
        return "Dhuhr";
      case PrayerType.asr:
        return "Asr";
      case PrayerType.maghrib:
        return "Maghrib";
      case PrayerType.isha:
        return "Isha";
    }
  }
}


class _PrayerCalendarHeader extends StatelessWidget {
  final String locationLabel;
  final DateTime displayedDate;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onToday;

  const _PrayerCalendarHeader({
    required this.locationLabel,
    required this.displayedDate,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final localizations = MaterialLocalizations.of(context);

    final gregorianDate = localizations.formatFullDate(displayedDate);
    final hijriDate = _approximateHijriDateLabel(displayedDate);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;

        if (velocity < -180) {
          onNextDay();
        } else if (velocity > 180) {
          onPreviousDay();
        }
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              colorScheme.primaryContainer.withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.32 : 0.54,
              ),
              colorScheme.surface,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.22),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onPreviousDay,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: InkWell(
                  onTap: onToday,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 17,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                locationLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                  fontSize: 13,
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          gregorianDate,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 14,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hijriDate,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onNextDay,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _approximateHijriDateLabel(DateTime date) {
    final hijri = _gregorianToApproximateHijri(date);
    return '${hijri.day} ${_hijriMonthName(hijri.month)} ${hijri.year} AH';
  }

  _HijriDate _gregorianToApproximateHijri(DateTime date) {
    final day = date.day;
    final month = date.month;
    final year = date.year;

    final adjustedMonth = month < 3 ? month + 12 : month;
    final adjustedYear = month < 3 ? year - 1 : year;

    final a = adjustedYear ~/ 100;
    final b = 2 - a + (a ~/ 4);

    final julianDay = (365.25 * (adjustedYear + 4716)).floor() +
        (30.6001 * (adjustedMonth + 1)).floor() +
        day +
        b -
        1524;

    final islamicDay = julianDay - 1948440 + 10632;
    final n = ((islamicDay - 1) / 10631).floor();
    final r = islamicDay - 10631 * n + 354;
    final j = (((10985 - r) / 5316).floor()) *
            (((50 * r) / 17719).floor()) +
        ((r / 5670).floor()) *
            (((43 * r) / 15238).floor());
    final f = r -
        (((30 - j) / 15).floor()) *
            (((17719 * j) / 50).floor()) -
        ((j / 16).floor()) *
            (((15238 * j) / 43).floor()) +
        29;

    final hijriMonth = ((24 * f) / 709).floor();
    final hijriDay = f - ((709 * hijriMonth) / 24).floor();
    final hijriYear = 30 * n + j - 30;

    return _HijriDate(day: hijriDay, month: hijriMonth, year: hijriYear);
  }

  String _hijriMonthName(int month) {
    const names = [
      'Muharram',
      'Safar',
      'Rabi al-Awwal',
      'Rabi al-Thani',
      'Jumada al-Awwal',
      'Jumada al-Thani',
      'Rajab',
      'Shaaban',
      'Ramadan',
      'Shawwal',
      'Dhul-Qi’dah',
      'Dhul-Hijjah',
    ];

    if (month < 1 || month > names.length) return 'Hijri';

    return names[month - 1];
  }
}

class _HijriDate {
  final int day;
  final int month;
  final int year;

  const _HijriDate({
    required this.day,
    required this.month,
    required this.year,
  });
}

class _PrayerLocationHeader extends StatelessWidget {
  final String locationLabel;

  const _PrayerLocationHeader({
    required this.locationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              locationLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerTimelineBlock extends StatelessWidget {
  final bool showPrayerRow;
  final String prayerName;
  final String prayerTime;
  final List<Task> beforeTasks;
  final List<Task> afterTasks;
  final List<Widget> afterPrayerCards;
  final bool isCurrentPrayer;
  final bool isNextPrayer;

  const _PrayerTimelineBlock({
    this.showPrayerRow = true,
    required this.prayerName,
    required this.prayerTime,
    required this.beforeTasks,
    required this.afterTasks,
    this.afterPrayerCards = const <Widget>[],
    required this.isCurrentPrayer,
    required this.isNextPrayer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (beforeTasks.isNotEmpty)
          _TaskGroupSection(
            tasks: beforeTasks,
            prayerTimeText: prayerTime,
          ),
        if (showPrayerRow)
          _PrayerRow(
            prayerName: prayerName,
            prayerTime: prayerTime,
            isCurrentPrayer: isCurrentPrayer,
            isNextPrayer: isNextPrayer,
          ),
        ...afterPrayerCards,
        if (afterTasks.isNotEmpty)
          _TaskGroupSection(
            tasks: afterTasks,
            prayerTimeText: prayerTime,
          ),
      ],
    );
  }
}

class _PrayerRow extends StatefulWidget {
  final String prayerName;
  final String prayerTime;
  final bool isCurrentPrayer;
  final bool isNextPrayer;

  const _PrayerRow({
    required this.prayerName,
    required this.prayerTime,
    required this.isCurrentPrayer,
    required this.isNextPrayer,
  });

  @override
  State<_PrayerRow> createState() => _PrayerRowState();
}

class _PrayerRowState extends State<_PrayerRow> {
  static const Duration _autoCompleteDelay = Duration(minutes: 10);

  bool _prayerTrackingEnabled = true;
  bool _isPrayerDone = false;
  bool _isLoadingPrayerStatus = true;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();

    _loadPrayerTrackingAndDoneStatus();
  }

  @override
  void didUpdateWidget(covariant _PrayerRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.prayerName != widget.prayerName ||
        oldWidget.prayerTime != widget.prayerTime) {
      _statusTimer?.cancel();
      _loadPrayerTrackingAndDoneStatus();
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrayerTrackingAndDoneStatus() async {
    final prefs = await SharedPreferences.getInstance();

    final trackingEnabled = prefs.getBool('prayerTrackingEnabled') ?? true;
    final doneKey = _prayerDoneKey(widget.prayerName);
    final manualOverrideKey = _prayerManualOverrideKey(widget.prayerName);

    var isDone = prefs.getBool(doneKey) ?? false;
    final hasManualOverride = prefs.getBool(manualOverrideKey) ?? false;

    if (trackingEnabled && !hasManualOverride && _shouldAutoCompletePrayer()) {
      isDone = true;
      await prefs.setBool(doneKey, true);
    }

    if (!mounted) return;

    setState(() {
      _prayerTrackingEnabled = trackingEnabled;
      _isPrayerDone = isDone;
      _isLoadingPrayerStatus = false;
    });

    _scheduleStatusRefresh();
  }

  void _scheduleStatusRefresh() {
    _statusTimer?.cancel();

    final now = DateTime.now();
    final prayerDateTime = _prayerDateTimeToday();
    if (prayerDateTime == null) return;

    final autoCompleteTime = prayerDateTime.add(_autoCompleteDelay);

    DateTime? nextRefresh;

    if (now.isBefore(prayerDateTime)) {
      nextRefresh = prayerDateTime;
    } else if (now.isBefore(autoCompleteTime)) {
      nextRefresh = autoCompleteTime;
    }

    if (nextRefresh == null) return;

    final delay = nextRefresh.difference(now);

    _statusTimer = Timer(delay, () {
      if (!mounted) return;
      _loadPrayerTrackingAndDoneStatus();
    });
  }

  DateTime? _prayerDateTimeToday() {
    final parsedTime = _parsePrayerTime(widget.prayerTime);

    if (parsedTime == null) return null;

    final now = DateTime.now();

    return DateTime(
      now.year,
      now.month,
      now.day,
      parsedTime.hour,
      parsedTime.minute,
    );
  }

  bool _hasPrayerTimePassed() {
    final prayerDateTime = _prayerDateTimeToday();
    if (prayerDateTime == null) return false;

    return !DateTime.now().isBefore(prayerDateTime);
  }

  bool _shouldAutoCompletePrayer() {
    final prayerDateTime = _prayerDateTimeToday();
    if (prayerDateTime == null) return false;

    final autoCompleteTime = prayerDateTime.add(_autoCompleteDelay);

    return !DateTime.now().isBefore(autoCompleteTime);
  }

  bool _canTogglePrayerDone() {
    if (!_prayerTrackingEnabled) return false;
    if (_isLoadingPrayerStatus) return false;

    return _isPrayerDone || _hasPrayerTimePassed();
  }

  Future<void> _togglePrayerDone() async {
    if (!_canTogglePrayerDone()) return;

    final newValue = !_isPrayerDone;

    setState(() {
      _isPrayerDone = newValue;
    });

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      _prayerDoneKey(widget.prayerName),
      newValue,
    );

    if (_shouldAutoCompletePrayer() && !newValue) {
      await prefs.setBool(
        _prayerManualOverrideKey(widget.prayerName),
        true,
      );
    } else if (newValue) {
      await prefs.remove(
        _prayerManualOverrideKey(widget.prayerName),
      );
    }

    if (mounted) {
      Provider.of<PrayerViewModel>(
        context,
        listen: false,
      ).notifyPrayerTrackingChanged();
    }
  }

  String _prayerDoneKey(String prayerName) {
    final now = DateTime.now();

    final normalizedPrayerName = prayerName
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_');

    final datePart =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return 'prayerDone_${normalizedPrayerName}_$datePart';
  }

  String _prayerManualOverrideKey(String prayerName) {
    final now = DateTime.now();

    final normalizedPrayerName = prayerName
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_');

    final datePart =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return 'prayerManualOverride_${normalizedPrayerName}_$datePart';
  }

  @override
  Widget build(BuildContext context) {
    final prayerVM = Provider.of<PrayerViewModel>(context);

    final prayerType = _prayerTypeFromName(widget.prayerName);

    final isNotificationEnabled = prayerType == null
        ? false
        : prayerVM.isPrayerNotificationEnabled(prayerType);

    final formattedPrayerTime = _formatPrayerTime(
      context: context,
      rawTime: widget.prayerTime,
    );

    final hasPrayerTimePassed = _hasPrayerTimePassed();
    final canTogglePrayerDone = _canTogglePrayerDone();

    final badgeText = _isPrayerDone
        ? null
        : widget.isCurrentPrayer
            ? 'Now'
            : widget.isNextPrayer
                ? 'Next'
                : null;

    final subtitle = hasPrayerTimePassed
        ? 'Prayer time · $formattedPrayerTime'
        : 'Upcoming · $formattedPrayerTime';

    return UnifiedTimelineRow(
      dismissKey: 'prayer_${widget.prayerName}_${widget.prayerTime}',
      title: widget.prayerName,
      subtitle: subtitle,
      isDone: _isPrayerDone,
      canDelete: false,
      badgeText: badgeText,
      showCheckbox: _prayerTrackingEnabled,
      checkboxEnabled: canTogglePrayerDone,
      disabledCheckboxIcon: Icons.hourglass_top_rounded,
      showNotificationIcon: true,
      notificationEnabled: isNotificationEnabled,
      onTap: canTogglePrayerDone ? _togglePrayerDone : null,
      onToggleDone: canTogglePrayerDone ? _togglePrayerDone : null,
      onTapNotification: prayerType == null
          ? null
          : () {
              prayerVM.togglePrayerNotification(prayerType);

              final messenger = ScaffoldMessenger.of(context);

              messenger.clearSnackBars();

              final isEnabled =
                  prayerVM.isPrayerNotificationEnabled(prayerType);

              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    isEnabled
                        ? "${widget.prayerName} notification enabled 🔔"
                        : "${widget.prayerName} notification disabled 🔕",
                  ),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
    );
  }

  String _formatPrayerTime({
    required BuildContext context,
    required String rawTime,
  }) {
    final parsedTime = _parsePrayerTime(rawTime);

    if (parsedTime == null) {
      return rawTime.isEmpty ? "--:--" : rawTime;
    }

    return MaterialLocalizations.of(context).formatTimeOfDay(
      parsedTime,
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
  }

  TimeOfDay? _parsePrayerTime(String rawTime) {
    try {
      final value = rawTime.trim();

      if (value.isEmpty) return null;

      final parts = value.split(" ");

      if (parts.length == 2) {
        return _parse12HourTime(parts[0], parts[1]);
      }

      final timePieces = value.split(":");

      if (timePieces.length < 2) return null;

      final hour = int.parse(timePieces[0]);
      final minute = int.parse(timePieces[1]);

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  TimeOfDay? _parse12HourTime(String timePart, String period) {
    final timePieces = timePart.split(":");

    if (timePieces.length < 2) return null;

    var hour = int.parse(timePieces[0]);
    final minute = int.parse(timePieces[1]);

    final normalizedPeriod = period.toUpperCase();

    if (normalizedPeriod == "PM" && hour != 12) {
      hour += 12;
    }

    if (normalizedPeriod == "AM" && hour == 12) {
      hour = 0;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  PrayerType? _prayerTypeFromName(String prayerName) {
    final value = prayerName.toLowerCase();

    if (value.contains('fajr')) return PrayerType.fajr;
    if (value.contains('dhuhr')) return PrayerType.dhuhr;
    if (value.contains('jumuah')) return PrayerType.dhuhr;
    if (value.contains('asr')) return PrayerType.asr;
    if (value.contains('maghrib')) return PrayerType.maghrib;
    if (value.contains('isha')) return PrayerType.isha;

    return null;
  }
}


class _PrayerStatusBadge extends StatelessWidget {
  final String text;
  final Color borderColor;
  final Color textColor;

  const _PrayerStatusBadge({
    required this.text,
    required this.borderColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: borderColor.withOpacity(0.55),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

class _NotificationBellIcon extends StatelessWidget {
  final bool enabled;

  const _NotificationBellIcon({
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 28,
      height: 28,
      child: Center(
        child: Icon(
          enabled
              ? Icons.notifications_rounded
              : Icons.notifications_off_rounded,
          size: 22,
          color: enabled ? Colors.amber : colorScheme.outline,
        ),
      ),
    );
  }
}

class _TaskGroupSection extends StatelessWidget {
  final List<Task> tasks;
  final String? prayerTimeText;

  const _TaskGroupSection({
    required this.tasks,
    this.prayerTimeText,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: tasks.map((task) {
        return _TimelineTaskCard(
          task: task,
          prayerTimeText: prayerTimeText,
        );
      }).toList(),
    );
  }
}

class _TimedTasksSection extends StatelessWidget {
  final List<Task> tasks;
  final Task? nextNormalTask;
  final Task? nowNormalTask;

  const _TimedTasksSection({
    required this.tasks,
    required this.nextNormalTask,
    required this.nowNormalTask,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: tasks.map((task) {
        return _TimelineTaskCard(
          task: task,
          isNowNormalTask: identical(task, nowNormalTask),
          isNextNormalTask:
          !identical(task, nowNormalTask) && identical(task, nextNormalTask),
        );
      }).toList(),
    );
  }
}

class _TimelineTaskCard extends StatelessWidget {
  final Task task;
  final String? prayerTimeText;
  final bool isNowNormalTask;
  final bool isNextNormalTask;

  const _TimelineTaskCard({
    required this.task,
    this.prayerTimeText,
    this.isNowNormalTask = false,
    this.isNextNormalTask = false,
  });

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<TaskViewModel>(context, listen: false);
    final index = vm.tasks.indexOf(task);

    if (index == -1) {
      return const SizedBox.shrink();
    }

    return UnifiedTimelineRow(
      dismissKey: 'task_${index}_${task.title}_${task.hashCode}',
      title: task.title,
      subtitle: _buildScheduleText(context, task),
      isDone: task.isDone,
      canDelete: true,
      badgeText: _badgeText(),
      showCheckbox: true,
      showNotificationIcon: _canShowNotificationButton(task),
      notificationEnabled: task.hasNotification,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditTaskPage(
              index: index,
              task: task,
            ),
          ),
        );
      },
      onToggleDone: () {
        vm.toggleTask(index);
      },
      onTapNotification: () {
        vm.toggleTaskNotification(index);

        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();

        final isEnabled = vm.tasks[index].hasNotification;

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isEnabled
                  ? "Notification enabled 🔔"
                  : "Notification disabled 🔕",
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onDelete: () {
        vm.deleteTask(index);

        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();

        messenger.showSnackBar(
          SnackBar(
            content: const Text("Task deleted"),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: "Undo",
              onPressed: () {
                vm.restoreLastDeleted();
                messenger.hideCurrentSnackBar();
              },
            ),
          ),
        );

        Future.delayed(const Duration(seconds: 3), () {
          messenger.hideCurrentSnackBar();
        });
      },
    );
  }

  String? _badgeText() {
    if (isNowNormalTask) return 'Now';
    if (isNextNormalTask) return 'Next';
    return null;
  }

  bool _canShowNotificationButton(Task task) {
    if (task.scheduleType == TaskScheduleType.time) {
      return task.dueHour != null && task.dueMinute != null;
    }

    if (task.scheduleType == TaskScheduleType.prayer) {
      return task.linkedPrayer != null && task.relationToPrayer != null;
    }

    return false;
  }

  String _buildScheduleText(BuildContext context, Task task) {
    final repeatText = _repeatText(task);

    if (task.scheduleType == TaskScheduleType.none) {
      return repeatText ?? 'Anytime';
    }

    if (task.scheduleType == TaskScheduleType.prayer) {
      if (task.linkedPrayer == null || task.relationToPrayer == null) {
        return repeatText ?? 'Anytime';
      }

      final prayerName = _prayerLabel(task.linkedPrayer!);
      final relation =
          task.relationToPrayer == TaskRelation.before ? 'Before' : 'After';

      final parts = <String>[
        '$relation $prayerName',
      ];

      if (prayerTimeText != null && prayerTimeText!.trim().isNotEmpty) {
        parts.add(prayerTimeText!.trim());
      }

      if (repeatText != null) {
        parts.add(repeatText);
      }

      return parts.join(' · ');
    }

    if (task.scheduleType == TaskScheduleType.time) {
      final parts = <String>[];

      if (task.dueHour != null && task.dueMinute != null) {
        final formattedTime = MaterialLocalizations.of(context).formatTimeOfDay(
          TimeOfDay(
            hour: task.dueHour!,
            minute: task.dueMinute!,
          ),
          alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
        );

        parts.add(formattedTime);
      }

      if (repeatText != null) {
        parts.add(repeatText);
      }

      return parts.isEmpty ? 'No specific time' : parts.join(' · ');
    }

    return repeatText ?? 'Scheduled';
  }

  String? _repeatText(Task task) {
    if (task.repeatType == RepeatType.everyDay) {
      return 'Daily';
    }

    if (task.scheduleType == TaskScheduleType.prayer &&
        task.dueDate == null &&
        task.linkedPrayer != null &&
        task.relationToPrayer != null) {
      return 'Daily';
    }

    return null;
  }

  String _prayerLabel(PrayerType prayer) {
    switch (prayer) {
      case PrayerType.fajr:
        return 'Fajr';
      case PrayerType.dhuhr:
        return 'Dhuhr';
      case PrayerType.asr:
        return 'Asr';
      case PrayerType.maghrib:
        return 'Maghrib';
      case PrayerType.isha:
        return 'Isha';
    }
  }
}

class _UnscheduledSection extends StatelessWidget {
  final List<Task> tasks;

  const _UnscheduledSection({
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // TODO-NEW:
    // حماية إضافية: حتى لو تم استدعاء هذا القسم بالخطأ وهو فارغ،
    // لن يظهر شيء في الواجهة.
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TODO-NEW:
          // جعلنا عنوان Unscheduled داخل Card مع أيقونة،
          // بدل نص عادي فوق فراغ.
          Row(
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                "Unscheduled",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...tasks.map(
                (task) => _TimelineTaskCard(task: task),
          ),
        ],
      ),
    );
  }
}


class _LocationNeededMessage extends StatelessWidget {
  const _LocationNeededMessage();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Choose your prayer location to show prayer times. Your tasks are still visible.",
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleEmptyState extends StatelessWidget {
  final String message;

  const _SimpleEmptyState({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EmptyDayMessage extends StatelessWidget {
  const _EmptyDayMessage();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Start your day by adding a task ✨",
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdhkarSettingsSnapshot {
  final bool showAdhkarCards;
  final bool morningEnabled;
  final bool eveningEnabled;
  final bool sleepEnabled;
  final String morningTiming;
  final String eveningTiming;
  final String sleepTiming;

  const _AdhkarSettingsSnapshot({
    required this.showAdhkarCards,
    required this.morningEnabled,
    required this.eveningEnabled,
    required this.sleepEnabled,
    required this.morningTiming,
    required this.eveningTiming,
    required this.sleepTiming,
  });

  const _AdhkarSettingsSnapshot.defaults()
      : showAdhkarCards = true,
        morningEnabled = true,
        eveningEnabled = true,
        sleepEnabled = true,
        morningTiming = 'After Fajr',
        eveningTiming = 'After Maghrib',
        sleepTiming = 'After Isha';

  bool get hasVisibleCards {
    return showAdhkarCards &&
        (morningEnabled || eveningEnabled || sleepEnabled);
  }
}

class _NextTimelineEvent {
  final String? prayerName;
  final Task? task;

  const _NextTimelineEvent({
    this.prayerName,
    this.task,
  });
}

class _PrayerDisplayInfo {
  final String name;
  final String time;

  _PrayerDisplayInfo({
    required this.name,
    required this.time,
  });
}

// =========================
// TODO-NEW: Later today UI
// =========================
class _LaterTodaySection extends StatelessWidget {
  final List<Task> tasks;

  const _LaterTodaySection({required this.tasks});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Text(
                "Later today",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...tasks.map((task) => _TimelineTaskCard(task: task)),
        ],
      ),
    );
  }
}



