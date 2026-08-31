import 'package:firebase_auth/firebase_auth.dart';

import 'company_workspace_remote_data_source.dart';

final class FirebaseWorkspaceSession implements WorkspaceSession {
  const FirebaseWorkspaceSession(this._auth);
  final FirebaseAuth _auth;

  @override
  Future<String?> refreshedBearerToken() async => _auth.currentUser == null
      ? null
      : await _auth.currentUser!.getIdToken(true);
}
