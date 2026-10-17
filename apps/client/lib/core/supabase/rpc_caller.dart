/// Calls a Postgres RPC; wired to `SupabaseClient.rpc` in DI so data sources
/// stay testable without a client.
typedef RpcCaller =
    Future<Object?> Function(String fn, Map<String, Object?> params);
