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
  final bool question;
  final bool camera;
  final List<String> roles;
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
        roles = json['roles'],
        question = json['question'],
        camera = json['camera'],
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
        'roles': roles,
        'question': question,
        'camera': camera,
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
        'roles: ${this.roles},'
        'question: ${this.question} ,'
        'camera: ${this.camera} ,'
        'group: ${this.group}}';
  }

  String toChatString() {
    return '{\"id\":\"${this.id}\",\"role\":\"user\",\"display\":\"${this.givenName}\"}';
  }
}
