enum WorkspaceCapability {
  view,
  download,
  comment,
  edit,
  manageContent,
  manageAccess;

  bool implies(WorkspaceCapability requested) {
    if (this == requested) return true;
    return switch (this) {
      WorkspaceCapability.manageAccess => true,
      WorkspaceCapability.manageContent => requested != manageAccess,
      WorkspaceCapability.edit =>
        requested == view ||
            requested == download ||
            requested == comment ||
            requested == edit,
      WorkspaceCapability.comment => requested == view || requested == comment,
      WorkspaceCapability.download =>
        requested == view || requested == download,
      WorkspaceCapability.view => requested == view,
    };
  }

  static WorkspaceCapability? tryParse(String raw) {
    final normalized = raw.trim().toLowerCase();
    return switch (normalized) {
      'view' => view,
      'download' => download,
      'comment' => comment,
      'edit' => edit,
      'manage_content' || 'managecontent' => manageContent,
      'manage_access' || 'manageaccess' => manageAccess,
      _ => null,
    };
  }
}
