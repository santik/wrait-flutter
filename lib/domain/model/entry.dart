class Entry {
  const Entry({
    this.id = 0,
    required this.rawTranscript,
    this.cleanedText,
    required this.isDraft,
    required this.language,
    required this.createdAt,
    required this.wordCount,
    this.audioPath,
  });

  final int id;
  final String rawTranscript;
  final String? cleanedText;
  final bool isDraft;
  final String language;
  final int createdAt;
  final int wordCount;
  final String? audioPath;

  Entry copyWith({
    int? id,
    String? rawTranscript,
    String? cleanedText,
    bool clearCleanedText = false,
    bool? isDraft,
    String? language,
    int? createdAt,
    int? wordCount,
    String? audioPath,
    bool clearAudioPath = false,
  }) {
    return Entry(
      id: id ?? this.id,
      rawTranscript: rawTranscript ?? this.rawTranscript,
      cleanedText: clearCleanedText ? null : cleanedText ?? this.cleanedText,
      isDraft: isDraft ?? this.isDraft,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      wordCount: wordCount ?? this.wordCount,
      audioPath: clearAudioPath ? null : audioPath ?? this.audioPath,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Entry &&
            other.id == id &&
            other.rawTranscript == rawTranscript &&
            other.cleanedText == cleanedText &&
            other.isDraft == isDraft &&
            other.language == language &&
            other.createdAt == createdAt &&
            other.wordCount == wordCount &&
            other.audioPath == audioPath);
  }

  @override
  int get hashCode => Object.hash(
    id,
    rawTranscript,
    cleanedText,
    isDraft,
    language,
    createdAt,
    wordCount,
    audioPath,
  );
}
