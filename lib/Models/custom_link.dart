class CustomLink {
  final String id;
  final String name;
  final String url;

  CustomLink({required this.id, required this.name, required this.url});

  factory CustomLink.fromJson(Map<String, dynamic> json) {
    return CustomLink(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      url: json['url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
    };
  }

  CustomLink copyWith({String? id, String? name, String? url}) {
    return CustomLink(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
    );
  }
}
