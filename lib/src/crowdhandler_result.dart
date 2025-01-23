/// Represents the main result structure from CrowdHandler's /requests API.
/// Typically includes fields like promoted, token, slug, responseID, etc.
class CrowdHandlerResult {
  final int promoted;        // 0 or 1
  final String? token;       // e.g. 'tokXYZ123'
  final String? slug;        // e.g. 'herb-girls'
  final String? responseID;  // used for PUT /responses/:id calls

  CrowdHandlerResult({
    required this.promoted,
    this.token,
    this.slug,
    this.responseID,
  });

  factory CrowdHandlerResult.fromJson(Map<String, dynamic> json) {
    return CrowdHandlerResult(
      promoted: json['promoted'] as int,
      token: json['token'] as String?,
      slug: json['slug'] as String?,
      responseID: json['responseID'] as String?,
    );
  }

  @override
  String toString() {
    return 'CrowdHandlerResult(promoted: $promoted, token: $token, slug: $slug, responseID: $responseID)';
  }
}
