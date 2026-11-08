import 'exercise_pivot.dart';
import '../../utils/json_parse.dart';

/// Exercise catalog entry. [pivot] is present when loaded via a [Workout] relation.
class Exercise {
  final int id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? videoUrl;
  final String? muscles;
  final String? difficulty;
  final String? category;
  final bool isPublic;
  final int? createdBy;
  final ExercisePivot? pivot;

  const Exercise({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.videoUrl,
    this.muscles,
    this.difficulty,
    this.category,
    this.isPublic = false,
    this.createdBy,
    this.pivot,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    final pivotJson = json['pivot'];

    return Exercise(
      id: asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      imageUrl: json['image_url']?.toString(),
      videoUrl: json['video_url']?.toString(),
      muscles: json['muscles']?.toString(),
      difficulty: json['difficulty']?.toString(),
      category: json['category']?.toString(),
      isPublic: asBool(json['is_public']),
      createdBy: asInt(json['created_by']),
      pivot: pivotJson is Map<String, dynamic>
          ? ExercisePivot.fromJson(pivotJson)
          : null,
    );
  }
}
