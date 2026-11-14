# EDAYA API client

The shared Dart client uses one authenticated transport for school queries, commands and generated entity resources.

Object-returning commands use `SchoolClient.runCommand`. Array-returning commands use `SchoolClient.runListCommand`, for example `record-assessment-results`. The latter returns `List<Map<String, dynamic>>` and preserves the response contract of the batch endpoint. Existing object-returning bindings remain compatible.
