class ExperienceItem {
  final String id;
  final String title;
  final String company;
  final String companyUrl;
  final String location;
  final String startDate;
  final String endDate;
  final bool isCurrent;
  final String description;

  ExperienceItem({
    required this.id,
    required this.title,
    required this.company,
    this.companyUrl = '',
    this.location = '',
    this.startDate = '',
    this.endDate = '',
    this.isCurrent = false,
    this.description = '',
  });

  /// Extracts the domain from companyUrl and generates a high-resolution favicon/logo URL.
  String get companyLogoUrl {
    final clean = companyUrl.trim();
    if (clean.isEmpty) return '';
    try {
      var uriString = clean;
      if (!uriString.startsWith('http://') && !uriString.startsWith('https://')) {
        uriString = 'https://$uriString';
      }
      final uri = Uri.parse(uriString);
      final host = uri.host.isNotEmpty ? uri.host : clean;
      final cleanHost = host.startsWith('www.') ? host.substring(4) : host;
      if (cleanHost.isNotEmpty && cleanHost.contains('.')) {
        return 'https://www.google.com/s2/favicons?domain=$cleanHost&sz=128';
      }
    } catch (_) {}
    return '';
  }

  factory ExperienceItem.fromJson(Map<String, dynamic> json) {
    return ExperienceItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      companyUrl: json['company_url']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      isCurrent: json['is_current'] == true || json['is_current']?.toString() == 'true',
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'company': company,
      'company_url': companyUrl,
      'location': location,
      'start_date': startDate,
      'end_date': endDate,
      'is_current': isCurrent,
      'description': description,
    };
  }

  ExperienceItem copyWith({
    String? id,
    String? title,
    String? company,
    String? companyUrl,
    String? location,
    String? startDate,
    String? endDate,
    bool? isCurrent,
    String? description,
  }) {
    return ExperienceItem(
      id: id ?? this.id,
      title: title ?? this.title,
      company: company ?? this.company,
      companyUrl: companyUrl ?? this.companyUrl,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isCurrent: isCurrent ?? this.isCurrent,
      description: description ?? this.description,
    );
  }
}

class EducationItem {
  final String id;
  final String school;
  final String degree;
  final String fieldOfStudy;
  final String startYear;
  final String endYear;
  final String description;

  EducationItem({
    required this.id,
    required this.school,
    this.degree = '',
    this.fieldOfStudy = '',
    this.startYear = '',
    this.endYear = '',
    this.description = '',
  });

  factory EducationItem.fromJson(Map<String, dynamic> json) {
    return EducationItem(
      id: json['id']?.toString() ?? '',
      school: json['school']?.toString() ?? '',
      degree: json['degree']?.toString() ?? '',
      fieldOfStudy: json['field_of_study']?.toString() ?? '',
      startYear: json['start_year']?.toString() ?? '',
      endYear: json['end_year']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school': school,
      'degree': degree,
      'field_of_study': fieldOfStudy,
      'start_year': startYear,
      'end_year': endYear,
      'description': description,
    };
  }

  EducationItem copyWith({
    String? id,
    String? school,
    String? degree,
    String? fieldOfStudy,
    String? startYear,
    String? endYear,
    String? description,
  }) {
    return EducationItem(
      id: id ?? this.id,
      school: school ?? this.school,
      degree: degree ?? this.degree,
      fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
      startYear: startYear ?? this.startYear,
      endYear: endYear ?? this.endYear,
      description: description ?? this.description,
    );
  }
}
