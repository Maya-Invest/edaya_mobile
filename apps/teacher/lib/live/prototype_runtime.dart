/// Distinguishes production Accueil (live Identity + school API) from mock tests.
class PrototypeRuntime {
  const PrototypeRuntime({required this.live});

  final bool live;
}
