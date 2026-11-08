import 'meal_ingredient.dart';
import '../../utils/json_parse.dart';

double _d(dynamic v) => v == null ? 0 : double.tryParse(v.toString()) ?? 0;

/// Meal recipe with macro totals and ingredient breakdown.
class MealDetail {
  final int id;
  final String name;
  final String? imageUrl;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final List<MealIngredient> ingredients;

  const MealDetail({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    this.ingredients = const [],
  });

  factory MealDetail.fromJson(Map<String, dynamic> json) {
    final ingList = json['ingredients'];
    final ingredients = ingList is List
        ? ingList
            .whereType<Map>()
            .map((e) => MealIngredient.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <MealIngredient>[];

    return MealDetail(
      id: asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      imageUrl: json['image_url']?.toString(),
      totalCalories: _d(json['total_calories']),
      totalProtein: _d(json['total_protein']),
      totalCarbs: _d(json['total_carbs']),
      totalFat: _d(json['total_fat']),
      ingredients: ingredients,
    );
  }
}
