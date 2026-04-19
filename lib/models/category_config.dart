class CategoryConfig {
  final int year;
  final int categoryId;
  // Index in the clasification array from group 1440 (null = not available)
  final int? clasificationIndex;

  const CategoryConfig({
    required this.year,
    required this.categoryId,
    this.clasificationIndex,
  });

  static const List<CategoryConfig> all = [
    CategoryConfig(year: 2016, categoryId: 10, clasificationIndex: 0),
    CategoryConfig(year: 2017, categoryId: 11, clasificationIndex: 1),
    CategoryConfig(year: 2018, categoryId: 12, clasificationIndex: 2),
    CategoryConfig(year: 2019, categoryId: 99, clasificationIndex: 3),
  ];

  String get label => 'Cat. $year';
  String get categoryLabel => '$year PROMOCIONALES';
}
