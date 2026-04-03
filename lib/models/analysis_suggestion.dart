enum SuggestionType { missing, mismatch, phantom, insight }

class AnalysisSuggestion {
  final SuggestionType type;
  final String description;
  final String? matchedExpenseId;
  final String? suggestedName;
  final double? suggestedCost;
  final String? suggestedCategory;
  final bool suggestedIsLoan;
  final String confidence;
  bool accepted;

  AnalysisSuggestion({
    required this.type,
    required this.description,
    this.matchedExpenseId,
    this.suggestedName,
    this.suggestedCost,
    this.suggestedCategory,
    this.suggestedIsLoan = false,
    this.confidence = 'low',
    this.accepted = false,
  });

  factory AnalysisSuggestion.fromJson(Map<String, dynamic> json) {
    return AnalysisSuggestion(
      type: _parseType(json['type'] as String),
      description: json['description'] as String,
      matchedExpenseId: json['matched_expense_id'] as String?,
      suggestedName: json['suggested_name'] as String?,
      suggestedCost: (json['suggested_cost'] as num?)?.toDouble(),
      suggestedCategory: json['suggested_category'] as String?,
      suggestedIsLoan: json['suggested_is_loan'] as bool? ?? false,
      confidence: json['confidence'] as String? ?? 'low',
    );
  }

  static SuggestionType _parseType(String type) {
    switch (type) {
      case 'missing':
        return SuggestionType.missing;
      case 'mismatch':
        return SuggestionType.mismatch;
      case 'phantom':
        return SuggestionType.phantom;
      case 'insight':
        return SuggestionType.insight;
      default:
        return SuggestionType.insight;
    }
  }
}
