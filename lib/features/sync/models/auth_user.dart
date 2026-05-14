/// GitHub 用户信息，从 /api/me 接口返回。
class AuthUser {
  const AuthUser({
    required this.githubId,
    required this.username,
    required this.avatarUrl,
  });

  final int githubId;
  final String username;
  final String avatarUrl;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        githubId: (json['github_id'] as num).toInt(),
        username: json['username'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String? ?? '',
      );

  @override
  String toString() => 'AuthUser($username)';
}
