bool _isEntityEnvelope(Object? value) {
  if (value is! Map) {
    return false;
  }

  final data = value['data'];
  return data is Map;
}

Object? _unwrapEntity(Object? value) {
  if (value is List) {
    return value.map(_unwrapEntity).toList();
  }

  if (value is! Map || !_isEntityEnvelope(value)) {
    return value;
  }

  final data = Map<String, dynamic>.from(value['data'] as Map);
  final merged = <String, dynamic>{};

  for (final entry in data.entries) {
    merged[entry.key] = _unwrapEntity(entry.value);
  }

  for (final entry in value.entries) {
    if (entry.key == 'data') {
      continue;
    }
    merged[entry.key] = _unwrapEntity(entry.value);
  }

  return merged;
}

Map<String, dynamic> unwrapEntityMap(Object? value) {
  final unwrapped = _unwrapEntity(value);
  if (unwrapped is Map<String, dynamic>) {
    return unwrapped;
  }
  if (unwrapped is Map) {
    return Map<String, dynamic>.from(unwrapped);
  }
  throw FormatException('Expected entity map, got $unwrapped');
}

List<Map<String, dynamic>> unwrapEntityList(Object? values) {
  if (values is! List) {
    return const [];
  }

  return values.map((entry) => unwrapEntityMap(entry)).toList();
}

bool isEntityCollectionPath(String path) {
  return RegExp(r'/core/entities/[^/]+/(?:list|one|save)$').hasMatch(path);
}

bool isEntityGetPath(String path) {
  return RegExp(r'/core/entities/[^/]+/[^/]+$').hasMatch(path)
      && !path.endsWith('/list')
      && !path.endsWith('/one')
      && !path.endsWith('/save')
      && !path.endsWith('/count')
      && !path.endsWith('/delete')
      && !path.endsWith('/batch-save')
      && !path.endsWith('/batch-delete');
}

T parseApiResponse<T>(String path, int status, Object? body) {
  if (status == 204) {
    return null as T;
  }

  if (isEntityCollectionPath(path)) {
    if (body is List) {
      return unwrapEntityList(body) as T;
    }
    return unwrapEntityMap(body) as T;
  }

  if (isEntityGetPath(path)) {
    return unwrapEntityMap(body) as T;
  }

  return body as T;
}
