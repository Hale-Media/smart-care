class Home {
  final int id;
  final String name;
  final int residentCount;

  const Home({required this.id, required this.name, this.residentCount = 0});

  factory Home.fromJson(Map<String, dynamic> j) => Home(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
        residentCount: (j['resident_count'] as num?)?.toInt() ?? 0,
      );
}
