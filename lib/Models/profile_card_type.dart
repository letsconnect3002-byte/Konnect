enum ProfileCardType { casual, professional }

class FieldCardAssignment {
  bool casual;
  bool professional;

  FieldCardAssignment({this.casual = false, this.professional = true});

  Map<String, dynamic> toJson() => {'c': casual, 'p': professional};

  factory FieldCardAssignment.fromJson(Map<String, dynamic> json) {
    return FieldCardAssignment(
      casual: json['c'] == true,
      professional: json['p'] != false,
    );
  }

  FieldCardAssignment copyWith({bool? casual, bool? professional}) {
    return FieldCardAssignment(
      casual: casual ?? this.casual,
      professional: professional ?? this.professional,
    );
  }
}

/// Fields that can be assigned to Casual and/or Professional cards.
const List<String> assignableProfileFields = [
  'name',
  'profession',
  'company',
  'email',
  'phoneNumber',
  'bio',
  'avatarUrl',
  'linkedin',
  'twitter',
  'instagram',
];
