# API Payload Types — Workout & Nutrition

> **Educational reference** for the LifeFit mobile app.  
> Describes request/response JSON shapes expected from the Laravel backend.  
> Source of truth: `WorkoutService`, `NutritionService`, and their Dart models.

**Base URL:** `http://{host}:8000/api/`  
**Auth:** All endpoints require `Authorization: Bearer {sanctum_token}`  
**Headers:** `Accept: application/json`

---

## Table of contents

1. [Workout APIs](#workout-apis)
2. [Nutrition APIs](#nutrition-apis)
3. [Shared enums & notes](#shared-enums--notes)
4. [Dart model mapping](#dart-model-mapping)

---

## Workout APIs

Service file: `lib/core/services/workout_service.dart`

---

### 1. GET `/client/today`

Fetches all workouts scheduled for **today** for the authenticated client.

| | |
|---|---|
| **Method** | `GET` |
| **Auth** | Required |
| **Dart method** | `WorkoutService.fetchTodaySchedules()` |
| **Parses as** | `List<TodaySchedule>` from `response.data['data']` |

#### Response — success (200)

```json
{
  "data": [
    {
      "schedule_id": 42,
      "status": "scheduled",
      "workout": {
        "id": 7,
        "name": "Upper Body Push",
        "description": "Chest, shoulders, triceps",
        "estimated_duration": 45,
        "difficulty": "intermediate",
        "type": "strength",
        "exercises": [
          {
            "id": 101,
            "name": "Bench Press",
            "description": "Barbell flat bench press",
            "image_url": "http://127.0.0.1:8000/storage/exercises/bench.jpg",
            "video_url": "https://youtube.com/watch?v=example",
            "muscles": "Chest, Triceps",
            "difficulty": "intermediate",
            "category": "compound",
            "is_public": true,
            "created_by": 3,
            "pivot": {
              "sets": 4,
              "reps": "8-10",
              "set_type": "normal",
              "target_weight": 60.0,
              "intensity_type": "weight",
              "target_percentage": null,
              "target_duration_seconds": null,
              "rpe_target": null,
              "rest_seconds": 90,
              "tempo": "2-0-2",
              "notes": "Control the descent",
              "order": 1
            },
            "created_at": "2026-01-15T10:00:00.000000Z",
            "updated_at": "2026-01-15T10:00:00.000000Z"
          },
          {
            "id": 102,
            "name": "Plank Hold",
            "description": "Core stability hold",
            "image_url": null,
            "video_url": null,
            "muscles": "Core",
            "difficulty": "beginner",
            "category": "isometric",
            "is_public": true,
            "created_by": 3,
            "pivot": {
              "sets": 3,
              "reps": "1",
              "set_type": "normal",
              "target_weight": null,
              "intensity_type": "time",
              "target_percentage": null,
              "target_duration_seconds": 120,
              "rpe_target": null,
              "rest_seconds": 60,
              "tempo": null,
              "notes": null,
              "order": 2
            },
            "created_at": "2026-01-15T10:00:00.000000Z",
            "updated_at": "2026-01-15T10:00:00.000000Z"
          }
        ],
        "created_at": "2026-01-10T08:00:00.000000Z",
        "updated_at": "2026-01-10T08:00:00.000000Z"
      },
      "workout_log": null
    },
    {
      "schedule_id": 43,
      "status": "completed",
      "workout": {
        "id": 8,
        "name": "Leg Day",
        "description": null,
        "estimated_duration": 50,
        "difficulty": "advanced",
        "type": "strength",
        "exercises": []
      },
      "workout_log": {
        "id": 15,
        "schedule_id": 43,
        "status": "pending",
        "trainer_reviewed": false,
        "actual_duration_minutes": 48,
        "target_duration_minutes": 50,
        "notes": "Felt strong today",
        "exercise_logs": [
          {
            "id": 201,
            "exercise_id": 110,
            "set_number": 1,
            "target_reps": 10,
            "actual_reps": 10,
            "target_weight": 80.0,
            "actual_weight": 82.5,
            "intensity_type": "weight",
            "target_percentage": null,
            "actual_percentage": null,
            "target_duration_seconds": null,
            "actual_duration_seconds": null,
            "rpe_target": null,
            "rpe": null,
            "notes": null,
            "created_at": "2026-07-05T08:30:00.000000Z",
            "updated_at": "2026-07-05T08:30:00.000000Z"
          }
        ],
        "created_at": "2026-07-05T08:30:00.000000Z",
        "updated_at": "2026-07-05T08:30:00.000000Z"
      }
    }
  ]
}
```

#### Response — rest day (200, empty list)

```json
{
  "message": "Rest Day! Enjoy your recovery.",
  "data": []
}
```

#### Field reference — `TodaySchedule`

| JSON key | Type | Description |
|----------|------|-------------|
| `schedule_id` | `int` | Program schedule row ID |
| `status` | `string` | `scheduled` \| `completed` \| `missed` |
| `workout` | `object` | Workout template with nested `exercises` |
| `workout_log` | `object\|null` | Existing log if client already logged |

#### Field reference — `exercise.pivot` (prescription)

| JSON key | Type | Description |
|----------|------|-------------|
| `sets` | `int` | Number of sets |
| `reps` | `string` | Target reps (may be range e.g. `"8-10"`) |
| `intensity_type` | `string` | `weight` \| `percentage` \| `rpe` \| `time` |
| `target_weight` | `float\|null` | Target weight in kg |
| `target_percentage` | `int\|null` | % of 1RM |
| `target_duration_seconds` | `int\|null` | Target duration (**seconds** on API) |
| `rpe_target` | `int\|null` | Target RPE 1–10 |
| `rest_seconds` | `int\|null` | Rest between sets in **seconds** |

> **UI note:** The mobile app displays durations and rest in **minutes** using `WorkoutDurationUtils`, but always sends/receives **seconds** to/from the API.

---

### 2. POST `/client/workout-logs`

Saves exercise set logs and marks the schedule as completed.

| | |
|---|---|
| **Method** | `POST` |
| **Auth** | Required |
| **Dart method** | `WorkoutService.saveWorkoutLog()` |
| **Parses as** | `TodaySchedule` via `_scheduleResourceToTodaySchedule()` |

#### Request body

```json
{
  "schedule_id": 42,
  "actual_duration_minutes": 45,
  "notes": "Good session",
  "exercise_logs": [
    {
      "exercise_id": 101,
      "set_number": 1,
      "intensity_type": "weight",
      "target_reps": 10,
      "actual_reps": 10,
      "target_weight": 60.0,
      "actual_weight": 62.5,
      "notes": "Last rep was hard"
    },
    {
      "exercise_id": 101,
      "set_number": 2,
      "intensity_type": "weight",
      "target_reps": 10,
      "actual_reps": 9,
      "target_weight": 60.0,
      "actual_weight": 62.5
    },
    {
      "exercise_id": 102,
      "set_number": 1,
      "intensity_type": "time",
      "target_duration_seconds": 120,
      "actual_duration_seconds": 150,
      "notes": "Held 2.5 minutes"
    },
    {
      "exercise_id": 103,
      "set_number": 1,
      "intensity_type": "percentage",
      "target_reps": 5,
      "actual_reps": 5,
      "target_percentage": 85,
      "actual_percentage": 87
    },
    {
      "exercise_id": 104,
      "set_number": 1,
      "intensity_type": "rpe",
      "target_reps": 8,
      "actual_reps": 8,
      "rpe_target": 8,
      "rpe": 9
    }
  ]
}
```

#### Request field rules

| Field | Required | Notes |
|-------|----------|-------|
| `schedule_id` | ✅ | Must exist in `program_schedule` |
| `exercise_logs` | ✅ | Array, at least one item |
| `exercise_logs.*.exercise_id` | ✅ | Must exist in `exercises` |
| `exercise_logs.*.set_number` | ✅ | 1-based set index |
| `exercise_logs.*.intensity_type` | optional | `weight`, `rpe`, `percentage`, `time` |
| `exercise_logs.*.actual_duration_seconds` | optional | **Seconds** (user enters minutes in UI) |
| `exercise_logs.*.actual_reps` | optional | Nullable for time-based exercises |
| `actual_duration_minutes` | optional | Total workout duration |
| `notes` | optional | Session-level notes |

#### Response — success (200 / 201)

Uses `ScheduleResource` shape. The mobile app maps `log` → `workoutLog`:

```json
{
  "data": {
    "id": 42,
    "assignment_id": 5,
    "program_day_id": 12,
    "scheduled_date": "2026-07-05",
    "status": "completed",
    "workout": {
      "id": 7,
      "name": "Upper Body Push",
      "description": "Chest, shoulders, triceps",
      "estimated_duration": 45,
      "difficulty": "intermediate",
      "type": "strength",
      "exercises": []
    },
    "log": {
      "id": 16,
      "schedule_id": 42,
      "status": "pending",
      "trainer_reviewed": false,
      "actual_duration_minutes": 45,
      "target_duration_minutes": null,
      "notes": "Good session",
      "exercise_logs": [
        {
          "id": 210,
          "exercise_id": 101,
          "set_number": 1,
          "target_reps": 10,
          "actual_reps": 10,
          "target_weight": 60.0,
          "actual_weight": 62.5,
          "intensity_type": "weight",
          "target_percentage": null,
          "actual_percentage": null,
          "target_duration_seconds": null,
          "actual_duration_seconds": null,
          "rpe_target": null,
          "rpe": null,
          "notes": "Last rep was hard",
          "created_at": "2026-07-05T10:00:00.000000Z",
          "updated_at": "2026-07-05T10:00:00.000000Z"
        }
      ],
      "created_at": "2026-07-05T10:00:00.000000Z",
      "updated_at": "2026-07-05T10:00:00.000000Z"
    },
    "completed_at": "2026-07-05T10:00:00.000000Z",
    "notes": null,
    "created_at": "2026-06-01T00:00:00.000000Z",
    "updated_at": "2026-07-05T10:00:00.000000Z"
  }
}
```

> **Important:** After save, the response `workout.exercises` may be **empty**.  
> The app keeps the cached workout tree from `GET /client/today` and only patches `status` + `workoutLog` (see `TodaySchedulesNotifier.saveWorkoutLog`).

#### Response — error (422)

```json
{
  "message": "The schedule id field is required.",
  "errors": {
    "schedule_id": ["The schedule id field is required."]
  }
}
```

---

## Nutrition APIs

Service file: `lib/core/services/nutrition_service.dart`

---

### 3. GET `/client/today-meals`

Fetches today's meal plan with macro targets and any logged intake.

| | |
|---|---|
| **Method** | `GET` |
| **Auth** | Required (active nutritionist subscription) |
| **Dart method** | `NutritionService.fetchTodayMeals()` |
| **Parses as** | `TodayMealsResponse.fromJson(response.data)` |

#### Response — success (200)

```json
{
  "data": [
    {
      "schedule_id": 301,
      "meal_type": "breakfast",
      "meal_order": 1,
      "status": "scheduled",
      "meal": {
        "id": 55,
        "name": "Oatmeal with Berries",
        "image_url": "http://127.0.0.1:8000/storage/meals/oatmeal.jpg",
        "total_calories": 420.0,
        "total_protein": 18.5,
        "total_carbs": 62.0,
        "total_fat": 12.0,
        "ingredients": [
          {
            "food_name": "Oats",
            "image_url": null,
            "category": "grains",
            "amount_g": 80.0,
            "calories": 300.0,
            "protein": 10.0,
            "carbs": 54.0,
            "fat": 6.0
          },
          {
            "food_name": "Blueberries",
            "image_url": "http://127.0.0.1:8000/storage/foods/blueberry.jpg",
            "category": "fruit",
            "amount_g": 100.0,
            "calories": 120.0,
            "protein": 8.5,
            "carbs": 8.0,
            "fat": 6.0
          }
        ]
      },
      "reference_weight_g": 180.0,
      "target_calories": 420.0,
      "target_protein": 18.5,
      "target_carbs": 62.0,
      "target_fat": 12.0,
      "logged": false,
      "actual_weight_grams": null,
      "actual_calories": null,
      "actual_protein": null,
      "actual_carbs": null,
      "actual_fat": null,
      "intake_item_id": null
    },
    {
      "schedule_id": 302,
      "meal_type": "lunch",
      "meal_order": 2,
      "status": "eaten",
      "meal": {
        "id": 56,
        "name": "Grilled Chicken Salad",
        "image_url": null,
        "total_calories": 550.0,
        "total_protein": 45.0,
        "total_carbs": 20.0,
        "total_fat": 28.0,
        "ingredients": []
      },
      "reference_weight_g": 350.0,
      "target_calories": 550.0,
      "target_protein": 45.0,
      "target_carbs": 20.0,
      "target_fat": 28.0,
      "logged": true,
      "actual_weight_grams": 350.0,
      "actual_calories": 550.0,
      "actual_protein": 45.0,
      "actual_carbs": 20.0,
      "actual_fat": 28.0,
      "intake_item_id": 88
    },
    {
      "schedule_id": 303,
      "meal_type": "snack",
      "meal_order": 3,
      "status": "skipped",
      "meal": {
        "id": 57,
        "name": "Protein Shake",
        "image_url": null,
        "total_calories": 200.0,
        "total_protein": 30.0,
        "total_carbs": 8.0,
        "total_fat": 4.0,
        "ingredients": []
      },
      "reference_weight_g": 100.0,
      "target_calories": 200.0,
      "target_protein": 30.0,
      "target_carbs": 8.0,
      "target_fat": 4.0,
      "logged": false,
      "actual_weight_grams": null,
      "actual_calories": null,
      "actual_protein": null,
      "actual_carbs": null,
      "actual_fat": null,
      "intake_item_id": null
    }
  ],
  "intake_log": {
    "id": 44,
    "status": "in_progress",
    "notes": "Drank extra water",
    "nutritionist_reviewed": false
  },
  "plan_name": "Cutting Plan — Week 3",
  "day_notes": "Lower carbs on rest days"
}
```

#### Response — no meals (200)

```json
{
  "message": "No meals scheduled for today.",
  "data": [],
  "intake_log": null
}
```

#### Field reference — `MealSchedule` (each item in `data`)

| JSON key | Type | Description |
|----------|------|-------------|
| `schedule_id` | `int` | Meal plan schedule row ID |
| `meal_type` | `string` | `breakfast` \| `lunch` \| `dinner` \| `snack` |
| `meal_order` | `int` | Display order within the day |
| `status` | `string` | `scheduled` \| `eaten` \| `skipped` |
| `meal` | `object\|null` | Recipe with macros + ingredients |
| `reference_weight_g` | `float` | Full serving weight (sum of ingredients); default 100 |
| `target_*` | `float` | Prescribed macros for the full serving |
| `logged` | `bool` | Whether client logged this meal today |
| `actual_*` | `float\|null` | Logged values (scaled by portion weight) |
| `intake_item_id` | `int\|null` | Daily intake log item ID |

#### Macro scaling formula (server-side)

When logging a custom portion:

```
ratio = actual_weight_grams / reference_weight_g
actual_calories = meal.total_calories × ratio
actual_protein  = meal.total_protein  × ratio
actual_carbs    = meal.total_carbs    × ratio
actual_fat      = meal.total_fat      × ratio
```

---

### 4. POST `/client/intake-logs/single`

Logs or skips **one meal** without affecting others (upsert).

| | |
|---|---|
| **Method** | `POST` |
| **Auth** | Required |
| **Dart method** | `NutritionService.logSingleMeal()` |
| **Used by** | `NutritionNotifier.logMeal()` / `skipMeal()` |

#### Request body — log as eaten

```json
{
  "log_date": "2026-07-05",
  "meal_plan_schedule_id": 301,
  "meal_id": 55,
  "meal_type": "breakfast",
  "actual_weight_grams": 180.0,
  "reference_weight_g": 180.0,
  "skipped": false
}
```

#### Request body — partial portion (half serving)

```json
{
  "log_date": "2026-07-05",
  "meal_plan_schedule_id": 301,
  "meal_id": 55,
  "meal_type": "breakfast",
  "actual_weight_grams": 90.0,
  "reference_weight_g": 180.0,
  "skipped": false
}
```

#### Request body — skip meal

```json
{
  "log_date": "2026-07-05",
  "meal_plan_schedule_id": 303,
  "meal_id": 57,
  "meal_type": "snack",
  "actual_weight_grams": 0,
  "reference_weight_g": 100.0,
  "skipped": true
}
```

#### Request field rules

| Field | Required | Notes |
|-------|----------|-------|
| `log_date` | ✅ | Format `YYYY-MM-DD` |
| `meal_plan_schedule_id` | ✅ | Must belong to client's active plan |
| `meal_id` | ✅ | Must exist in `meals` |
| `meal_type` | optional | Defaults to `breakfast` |
| `actual_weight_grams` | optional | Portion eaten in grams |
| `reference_weight_g` | optional | Full serving weight; default 100 |
| `skipped` | optional | `true` → marks schedule as `skipped` |
| `notes` | optional | Day-level notes on intake log |

#### Response — logged (200)

```json
{
  "message": "Meal logged successfully.",
  "intake_item_id": 89,
  "actual_calories": 420.0,
  "actual_protein": 18.5,
  "actual_carbs": 62.0,
  "actual_fat": 12.0
}
```

#### Response — skipped (200)

```json
{
  "message": "Meal marked as skipped."
}
```

#### Response — no subscription (403)

```json
{
  "message": "Subscription expired or no active subscription found."
}
```

---

### Nutrition endpoints (backend only — not in mobile service yet)

These exist on the API but are **not** wrapped in `NutritionService` yet:

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/client/intake-logs` | Bulk log multiple meals at once |
| `POST` | `/client/intake-logs/notes` | Save day-level notes |

#### Bulk log request mock (`POST /client/intake-logs`)

```json
{
  "log_date": "2026-07-05",
  "items": [
    {
      "meal_plan_schedule_id": 301,
      "meal_id": 55,
      "meal_type": "breakfast",
      "actual_weight_grams": 180.0,
      "reference_weight_g": 180.0,
      "skipped": false
    },
    {
      "meal_plan_schedule_id": 302,
      "meal_id": 56,
      "meal_type": "lunch",
      "actual_weight_grams": 350.0,
      "reference_weight_g": 350.0,
      "skipped": false
    }
  ]
}
```

---

## Shared enums & notes

### Workout — `intensity_type`

| Value | UI inputs | Key payload fields |
|-------|-----------|-------------------|
| `weight` | reps + weight (kg) | `actual_reps`, `actual_weight` |
| `percentage` | reps + % of 1RM | `actual_reps`, `actual_percentage` |
| `rpe` | reps + RPE (1–10) | `actual_reps`, `rpe` |
| `time` | duration (**minutes** in UI) | `actual_duration_seconds` (**seconds** on API) |

### Workout — schedule `status`

| Value | Meaning |
|-------|---------|
| `scheduled` | Not yet done |
| `completed` | Client logged the workout |
| `missed` | Past date, never logged (auto-set by backend) |

### Nutrition — meal `status`

| Value | Arabic label | Meaning |
|-------|--------------|---------|
| `scheduled` | — | Not yet logged |
| `eaten` | — | Client confirmed intake |
| `skipped` | — | Client skipped this meal |

### Nutrition — `meal_type`

| Value | Arabic label |
|-------|--------------|
| `breakfast` | فطور |
| `lunch` | غداء |
| `dinner` | عشاء |
| `snack` | وجبة خفيفة |

---

## Dart model mapping

| API area | Response model | Service |
|----------|---------------|---------|
| Today's workouts | `TodaySchedule` → `Workout` → `Exercise` → `ExercisePivot` | `WorkoutService` |
| Workout log | `WorkoutLog` → `ExerciseLog` | `WorkoutService` |
| Today's meals | `TodayMealsResponse` → `MealSchedule` → `MealDetail` → `MealIngredient` | `NutritionService` |
| Duration display | `WorkoutDurationUtils` | Converts seconds ↔ minutes |

### Key files

```
lib/core/services/workout_service.dart
lib/core/services/nutrition_service.dart
lib/core/models/workout/today_schedule.dart
lib/core/models/workout/workout.dart
lib/core/models/workout/exercise.dart
lib/core/models/workout/exercise_pivot.dart
lib/core/models/workout/workout_log.dart
lib/core/models/workout/exercise_log.dart
lib/core/models/nutrition/today_meals_response.dart
lib/core/models/nutrition/meal_schedule.dart
lib/core/models/nutrition/meal_detail.dart
lib/core/models/nutrition/meal_ingredient.dart
lib/core/utils/workout_duration_utils.dart
```

---

*Last updated from backend controllers: `ScheduleController`, `WorkoutLogController`, `MealLogController` and mobile services as of July 2026.*
