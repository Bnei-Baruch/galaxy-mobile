// TODO: move to JsonSerializable once we upgrade flutter to null safety.
class StudyMaterial {
  String title;
  String htmlContent;

  StudyMaterial({this.title, this.htmlContent});

  factory StudyMaterial.fromJson(Map<String, dynamic> json) {
    return StudyMaterial(
        title: json['Title'] ?? '',
        htmlContent: json['Description'] ?? '');
  }
}