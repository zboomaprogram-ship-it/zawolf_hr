class ChatPolicyConfig {
  final bool employeeCanChatWithPeers;
  final bool employeeCanChatWithDirectManager;
  final bool employeeCanChatWithHr;
  final bool employeeCanChatWithIt;
  final bool employeeCanChatWithOtherManagers;
  final bool employeeCanChatWithSuperAdmin;

  const ChatPolicyConfig({
    this.employeeCanChatWithPeers = true,
    this.employeeCanChatWithDirectManager = true,
    this.employeeCanChatWithHr = true,
    this.employeeCanChatWithIt = true,
    this.employeeCanChatWithOtherManagers = false,
    this.employeeCanChatWithSuperAdmin = false,
  });

  factory ChatPolicyConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const ChatPolicyConfig();
    return ChatPolicyConfig(
      employeeCanChatWithPeers:
          data['employeeCanChatWithPeers'] as bool? ?? true,
      employeeCanChatWithDirectManager:
          data['employeeCanChatWithDirectManager'] as bool? ?? true,
      employeeCanChatWithHr: data['employeeCanChatWithHr'] as bool? ?? true,
      employeeCanChatWithIt: data['employeeCanChatWithIt'] as bool? ?? true,
      employeeCanChatWithOtherManagers:
          data['employeeCanChatWithOtherManagers'] as bool? ?? false,
      employeeCanChatWithSuperAdmin:
          data['employeeCanChatWithSuperAdmin'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'employeeCanChatWithPeers': employeeCanChatWithPeers,
    'employeeCanChatWithDirectManager': employeeCanChatWithDirectManager,
    'employeeCanChatWithHr': employeeCanChatWithHr,
    'employeeCanChatWithIt': employeeCanChatWithIt,
    'employeeCanChatWithOtherManagers': employeeCanChatWithOtherManagers,
    'employeeCanChatWithSuperAdmin': employeeCanChatWithSuperAdmin,
  };
}
