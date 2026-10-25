/// Calls a path relative to the api Edge Function.
typedef EdgeCaller =
    Future<Object?> Function(String path, Map<String, Object?> body);

/// GetIt key: EdgeCaller and RpcCaller have the same structural function type.
const edgeCallerInstanceName = 'apiEdgeCaller';
