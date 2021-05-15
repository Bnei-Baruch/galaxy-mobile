

class User {
  final String id;
  final String sub;
  final String name;
  final String title;
  final bool emailVerified;
  final String email;
  final String preferredUsername;
  final String givenName;
  final String familyName;
  final String group;
  final int rfid;

  User.fromJson(Map<String, dynamic> json)
      : sub = json['sub'],
        id = json['sub'],
        rfid = json['rfid'],
        name = json['name'],
        title = json['title'],
        emailVerified = json['email_verified'],
        email = json['email'],
        preferredUsername = json['preferred_username'],
        givenName = json['given_name'],
        familyName = json['family_name'],
        group = json['group'];

  Map<String, dynamic> toJson() => {
        'sub': sub,
        'id': sub,
        'name': name,
        'title': title,
        'emailVerified': emailVerified,
        'email': email,
        'preferredUsername': preferredUsername,
        'givenName': givenName,
        'familyName': familyName,
        'rfid': rfid,
        'group': group,
      };

  @override
  String toString() {
    return '{sub: ${this.sub}, '
        'name: ${this.name} ,'
        'title: ${this.title} ,'
        'emailVerified: ${this.emailVerified} ,'
        'email: ${this.email} ,'
        'preferredUsername: ${this.preferredUsername} ,'
        'givenName: ${this.givenName} ,'
        'familyName: ${this.familyName} ,'
        'group: ${this.group}}';
  }
}