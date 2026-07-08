import 'package:edaya_api_client/edaya_api_client.dart';

/// Portal actors cannot read every staff workspace entity. Treat optional reads
/// as best-effort enrichment and keep the surrounding screen working.
Future<List<Map<String, dynamic>>> optionalEntityList(
  Future<List<Map<String, dynamic>>> future,
) async {
  try {
    return await future;
  } on ApiError catch (error) {
    if (error.status == 403) {
      return const [];
    }
    rethrow;
  }
}
