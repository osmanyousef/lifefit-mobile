import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../core/design/fit_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sample data for the workout demo (no API).
//
//   Day  →  Workout (جلسة)  →  Section (muscle group)  →  Exercise  →  Sets
//
// Pictures are bundled in assets/demo/exercises/ (two frames per exercise:
// start and end position). They come from the public-domain
// "free-exercise-db" library. Videos are ordinary YouTube ids.
// In the real screens pictures and videos come from the API.
// ─────────────────────────────────────────────────────────────────────────────

const _imageBase = 'assets/demo/exercises';

/// Keeps a numeric expression left-to-right inside Arabic text (4×10, 40 × 10).
String ltr(String s) => '⁦$s⁩';

String fmtKg(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

enum DemoUnit { reps, seconds, minutes }

class DemoSet {
  DemoSet(this.weight, this.amount);
  double weight;

  /// Reps, seconds or minutes — depends on the exercise's [DemoUnit].
  int amount;
  bool done = false;
}

class DemoExercise {
  DemoExercise({
    required this.name,
    required this.muscles,
    required this.imageId,
    required this.targetSets,
    required this.targetAmount,
    this.targetWeight = 0,
    this.unit = DemoUnit.reps,
    this.videoId,
    this.mainFrame = 0,
    this.tips = const [],
  }) : sets = List.generate(targetSets, (_) => DemoSet(targetWeight, targetAmount));

  final String name;
  final String muscles;
  final String imageId;
  final int targetSets;
  final int targetAmount;

  /// 0 = no weight column (body-weight or cardio exercise).
  final double targetWeight;
  final DemoUnit unit;

  /// YouTube video id, or null when the exercise has pictures only.
  final String? videoId;

  /// Which of the two pictures is the better thumbnail.
  final int mainFrame;
  final List<String> tips;
  final List<DemoSet> sets;

  bool get usesWeight => targetWeight > 0;
  bool get hasVideo => videoId != null;

  /// Picture of the start (0) or end (1) position.
  String image(int frame) => '$_imageBase/${imageId}_$frame.jpg';
  String get thumb => image(mainFrame);

  int get doneCount => sets.where((s) => s.done).length;
  bool get complete => sets.isNotEmpty && doneCount == sets.length;
  double get volume =>
      usesWeight ? sets.where((s) => s.done).fold(0.0, (a, s) => a + s.weight * s.amount) : 0;

  String get unitShort => switch (unit) {
        DemoUnit.reps => '',
        DemoUnit.seconds => 'ث',
        DemoUnit.minutes => 'د',
      };

  /// Column title for the amount.
  String get amountLabel => switch (unit) {
        DemoUnit.reps => 'العدّات',
        DemoUnit.seconds => 'المدة (ث)',
        DemoUnit.minutes => 'المدة (د)',
      };

  /// Row title in the edit sheet.
  String get amountName => switch (unit) {
        DemoUnit.reps => 'العدّات',
        DemoUnit.seconds => 'المدة',
        DemoUnit.minutes => 'المدة',
      };

  String get amountUnitName => switch (unit) {
        DemoUnit.reps => '',
        DemoUnit.seconds => 'ثانية',
        DemoUnit.minutes => 'دقيقة',
      };

  int get amountStep => unit == DemoUnit.seconds ? 5 : 1;

  String amountText(int v) => unit == DemoUnit.reps ? '$v' : '$v $unitShort';

  /// e.g. "4×10 · 40 كجم", "3×45 ث".
  String get targetSummary => usesWeight
      ? '${ltr('$targetSets×$targetAmount')} · ${fmtKg(targetWeight)} كجم'
      : unit == DemoUnit.reps
          ? ltr('$targetSets×$targetAmount')
          : '${ltr('$targetSets×$targetAmount')} $unitShort';

  /// Target shown in each table row, e.g. "40 × 10" or "45 ث".
  String get targetCell => usesWeight ? ltr('${fmtKg(targetWeight)} × $targetAmount') : amountText(targetAmount);
}

class DemoSection {
  DemoSection({required this.title, required this.icon, required this.tone, required this.exercises});

  final String title;
  final IconData icon;
  final FitTone tone;
  final List<DemoExercise> exercises;

  int get doneExercises => exercises.where((e) => e.complete).length;
  bool get complete => doneExercises == exercises.length;
}

class DemoWorkout {
  DemoWorkout({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.kind,
    required this.cover,
    required this.sections,
  });

  final String id;
  final String name;
  final String subtitle;

  /// Short label: قوة / كارديو.
  final String kind;
  final String cover;
  final List<DemoSection> sections;

  /// Set when the user taps "save" on the finish sheet.
  bool saved = false;

  List<DemoExercise> get exercises => [for (final s in sections) ...s.exercises];
  int get totalSets => exercises.fold(0, (a, e) => a + e.sets.length);
  int get doneSets => exercises.fold(0, (a, e) => a + e.doneCount);
  int get doneExercises => exercises.where((e) => e.complete).length;
  double get volume => exercises.fold(0.0, (a, e) => a + e.volume);
  double get progress => totalSets == 0 ? 0 : doneSets / totalSets;
  bool get started => doneSets > 0;
  bool get complete => totalSets > 0 && doneSets == totalSets;
}

/// Holds today's workouts and tells listeners when anything changes.
class DemoDay extends ChangeNotifier {
  DemoDay() : workouts = buildSampleDay();

  List<DemoWorkout> workouts;

  int get totalSets => workouts.fold(0, (a, w) => a + w.totalSets);
  int get doneSets => workouts.fold(0, (a, w) => a + w.doneSets);
  int get totalExercises => workouts.fold(0, (a, w) => a + w.exercises.length);
  int get doneExercises => workouts.fold(0, (a, w) => a + w.doneExercises);
  int get doneWorkouts => workouts.where((w) => w.complete).length;
  double get progress => totalSets == 0 ? 0 : doneSets / totalSets;

  /// Call after changing any set.
  void touch() => notifyListeners();

  void reset() {
    workouts = buildSampleDay();
    notifyListeners();
  }
}

List<DemoWorkout> buildSampleDay() => [
      DemoWorkout(
        id: 'full-day',
        name: 'Full Day',
        subtitle: 'ظهر · صدر',
        kind: 'قوة',
        cover: '$_imageBase/bench_press_1.jpg',
        sections: [
          DemoSection(
            title: 'الظهر',
            icon: FLucideIcons.dumbbell,
            tone: FitTone.brand,
            exercises: [
              DemoExercise(
                name: 'سحب أمامي واسع',
                muscles: 'اللاتس · بايسبس',
                imageId: 'lat_pulldown',
                videoId: 'CAwf7n6Luuc',
                targetSets: 4,
                targetAmount: 12,
                targetWeight: 45,
                mainFrame: 1,
                tips: [
                  'اسحب البار إلى أعلى الصدر وليس خلف الرقبة.',
                  'ابدأ الحركة بإنزال الكتفين ثم اسحب بالمرفقين.',
                  'ارجع ببطء حتى تمتد الذراعان كاملاً.',
                ],
              ),
              DemoExercise(
                name: 'تجديف بالبار منحنياً',
                muscles: 'وسط الظهر · اللاتس',
                imageId: 'barbell_row',
                videoId: 'ZtTwgJTBjOQ',
                targetSets: 4,
                targetAmount: 10,
                targetWeight: 40,
                mainFrame: 1,
                tips: [
                  'حافظ على ظهر مستقيم وانحناء ثابت من الورك.',
                  'اسحب البار نحو أسفل البطن واعصر لوحي الكتف.',
                  'لا تستخدم الاندفاع؛ اختر وزناً تتحكم به.',
                ],
              ),
              DemoExercise(
                name: 'تجديف بالكابل جالساً',
                muscles: 'وسط الظهر',
                imageId: 'cable_row',
                videoId: 'lJoozxC0Rns',
                targetSets: 3,
                targetAmount: 12,
                targetWeight: 35,
                mainFrame: 1,
                tips: [
                  'اجلس بصدر مرفوع وركبتين مثنيتين قليلاً.',
                  'اسحب المقبض نحو البطن دون إرجاع الجذع كثيراً.',
                ],
              ),
            ],
          ),
          DemoSection(
            title: 'الصدر',
            icon: FLucideIcons.flame,
            tone: FitTone.warning,
            exercises: [
              DemoExercise(
                name: 'ضغط البنش بالبار',
                muscles: 'صدر · ترايسبس',
                imageId: 'bench_press',
                videoId: '4Y2ZdHCOXok',
                targetSets: 4,
                targetAmount: 10,
                targetWeight: 60,
                tips: [
                  'ثبّت لوحي الكتف على المقعد والقدمين على الأرض.',
                  'أنزل البار إلى منتصف الصدر بتحكم.',
                  'ادفع للأعلى دون رفع الورك عن المقعد.',
                ],
              ),
              DemoExercise(
                name: 'ضغط مائل بالدمبل',
                muscles: 'أعلى الصدر · أكتاف',
                imageId: 'incline_press',
                videoId: 'oZVCBM9f8Eo',
                targetSets: 3,
                targetAmount: 12,
                targetWeight: 20,
                tips: [
                  'اضبط المقعد على ميل 30 إلى 45 درجة.',
                  'أنزل الدمبلز حتى مستوى الصدر ثم ادفع للأعلى.',
                ],
              ),
              DemoExercise(
                name: 'تفتيح بالدمبل',
                muscles: 'صدر',
                imageId: 'dumbbell_fly',
                videoId: 'Nhvz9EzdJ4U',
                targetSets: 3,
                targetAmount: 15,
                targetWeight: 12,
                tips: [
                  'حافظ على انثناء خفيف وثابت في المرفقين.',
                  'افتح الذراعين حتى تشعر بتمدد الصدر ثم ضمّهما.',
                ],
              ),
            ],
          ),
        ],
      ),
      DemoWorkout(
        id: 'cardio-core',
        name: 'Full Cardio & Core',
        subtitle: 'كارديو · كور',
        kind: 'كارديو',
        cover: '$_imageBase/jump_rope_0.jpg',
        sections: [
          DemoSection(
            title: 'كارديو',
            icon: FLucideIcons.flame,
            tone: FitTone.danger,
            exercises: [
              DemoExercise(
                name: 'جري على السير',
                muscles: 'لياقة · أرجل',
                imageId: 'treadmill',
                targetSets: 1,
                targetAmount: 15,
                unit: DemoUnit.minutes,
                mainFrame: 1,
                tips: [
                  'ابدأ بدقيقتين مشي سريع للإحماء.',
                  'حافظ على وتيرة تستطيع معها الكلام بجمل قصيرة.',
                ],
              ),
              DemoExercise(
                name: 'نط الحبل',
                muscles: 'لياقة · سمانة',
                imageId: 'jump_rope',
                videoId: 'FJmRQ5iTXKE',
                targetSets: 3,
                targetAmount: 60,
                unit: DemoUnit.seconds,
                tips: [
                  'اقفز على مشط القدم بارتفاع بسيط.',
                  'حرّك الحبل بالرسغين لا بالذراعين.',
                ],
              ),
              DemoExercise(
                name: 'متسلق الجبال',
                muscles: 'لياقة · كور',
                imageId: 'mountain_climbers',
                videoId: 'hq_0YlyfqGM',
                targetSets: 3,
                targetAmount: 20,
                tips: [
                  'ابدأ من وضع البلانك واليدان تحت الكتفين.',
                  'بدّل الركبتين نحو الصدر بسرعة مع ثبات الورك.',
                ],
              ),
            ],
          ),
          DemoSection(
            title: 'الكور',
            icon: FLucideIcons.dumbbell,
            tone: FitTone.info,
            exercises: [
              DemoExercise(
                name: 'بلانك',
                muscles: 'بطن · أسفل الظهر',
                imageId: 'plank',
                videoId: 'ASdvN_XEl_c',
                targetSets: 3,
                targetAmount: 45,
                unit: DemoUnit.seconds,
                mainFrame: 1,
                tips: [
                  'اجعل الجسم خطاً مستقيماً من الرأس إلى الكعبين.',
                  'شدّ البطن ولا تدع الورك يهبط.',
                ],
              ),
              DemoExercise(
                name: 'التواء روسي',
                muscles: 'خواصر · بطن',
                imageId: 'russian_twist',
                videoId: 'nhFynCkYtD4',
                targetSets: 3,
                targetAmount: 20,
                tips: [
                  'مِل للخلف قليلاً مع ظهر مستقيم.',
                  'لفّ الجذع كاملاً وليس الذراعين فقط.',
                ],
              ),
              DemoExercise(
                name: 'كرنش',
                muscles: 'بطن',
                imageId: 'crunch',
                videoId: '9T4WQGlKCRk',
                targetSets: 3,
                targetAmount: 20,
                mainFrame: 1,
                tips: [
                  'ارفع الكتفين عن الأرض بعضلات البطن لا بالرقبة.',
                  'انزل ببطء ولا ترتح تماماً بين العدّات.',
                ],
              ),
            ],
          ),
        ],
      ),
    ];
