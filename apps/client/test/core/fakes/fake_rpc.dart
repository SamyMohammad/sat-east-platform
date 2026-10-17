/// Records RPC calls; returns [response] or throws [error].
class FakeRpc {
  Object? response;
  Object? error;
  final calls = <(String, Map<String, Object?>)>[];

  Future<Object?> call(String fn, Map<String, Object?> params) async {
    calls.add((fn, params));
    // Tests inject arbitrary exception types.
    // ignore: only_throw_errors
    if (error != null) throw error!;
    return response;
  }
}
