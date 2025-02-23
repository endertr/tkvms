class Country {
  final int id;
  final String name;
  final String displayName;

  Country({
    required this.id,
    required this.name,
    required this.displayName,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['Id'],
      name: json['Name'],
      displayName: json['DisplayName'],
    );
  }
}

class City {
  final int id;
  final String name;
  final String displayName;

  City({
    required this.id,
    required this.name,
    required this.displayName,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['Id'],
      name: json['Name'],
      displayName: json['DisplayName'],
    );
  }
}

class District {
  final int id;
  final String name;
  final String displayName;

  District({
    required this.id,
    required this.name,
    required this.displayName,
  });

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      id: json['Id'],
      name: json['Name'],
      displayName: json['DisplayName'],
    );
  }
} 