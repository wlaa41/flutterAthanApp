/// An athan the user can add from its public source. The recording is not in
/// the app: the phone fetches it once, checks it, and keeps it.
class AthanDownload {
  const AthanDownload({
    required this.id,
    required this.name,
    required this.arabicName,
    required this.place,
    required this.seconds,
    required this.bytes,
    required this.sha256,
    required this.url,
    required this.source,
    this.note,
    this.featured = false,
    this.cutFrom,
    this.cutStart = Duration.zero,
  });

  final String id;
  final String name;
  final String arabicName;
  final String place;

  /// What sets this recording apart, when a line helps the choice.
  final String? note;
  final int seconds;

  /// Size and SHA-256 of the file at [url]. A download that differs is refused.
  final int bytes;
  final String sha256;
  final String url;

  /// Where the recording comes from, shown in the credits.
  final String source;

  /// Athans asked for by name: listed first.
  final bool featured;

  /// A shorter athan made on the phone from another entry's recording: the
  /// part from [cutStart] to the end. [bytes], [sha256] and [url] then
  /// describe that other recording.
  final String? cutFrom;
  final Duration cutStart;

  String get soundId => 'dl_$id';
  String get fileName => 'dl_$id.mp3';

  String get length =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  String get size => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
