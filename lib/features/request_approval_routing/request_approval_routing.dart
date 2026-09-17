/// Configurable request approval routing feature.
///
/// Provides deterministic, auditable multi-stage approval routes.
library;

export 'domain/entities/approval_stage.dart';
export 'domain/entities/approval_route.dart';
export 'domain/repositories/request_approval_routing_repository.dart';
export 'data/request_approval_routing_repository_impl.dart';
export 'data/request_approval_routing_gateway.dart';
export 'presentation/cubit/request_approval_routing_cubit.dart';
export 'presentation/cubit/request_approval_routing_state.dart';
