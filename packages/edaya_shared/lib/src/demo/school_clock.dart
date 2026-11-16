/// One installed app owns one active school clock. Network timeouts and request
/// identifiers continue to use elapsed/real time.
class SchoolClock {
  static DateTime? sample;
  static DateTime now() => sample ?? DateTime.now();
}
