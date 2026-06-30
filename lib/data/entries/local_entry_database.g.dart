// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_entry_database.dart';

// ignore_for_file: type=lint
class $EntryRecordsTable extends EntryRecords
    with TableInfo<$EntryRecordsTable, EntryRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntryRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _rawTranscriptMeta = const VerificationMeta(
    'rawTranscript',
  );
  @override
  late final GeneratedColumn<String> rawTranscript = GeneratedColumn<String>(
    'raw_transcript',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cleanedTextMeta = const VerificationMeta(
    'cleanedText',
  );
  @override
  late final GeneratedColumn<String> cleanedText = GeneratedColumn<String>(
    'cleaned_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (type IN (\'draft\', \'saved\'))',
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  @override
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
    'word_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    rawTranscript,
    cleanedText,
    type,
    language,
    createdAt,
    wordCount,
    audioPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('raw_transcript')) {
      context.handle(
        _rawTranscriptMeta,
        rawTranscript.isAcceptableOrUnknown(
          data['raw_transcript']!,
          _rawTranscriptMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rawTranscriptMeta);
    }
    if (data.containsKey('cleaned_text')) {
      context.handle(
        _cleanedTextMeta,
        cleanedText.isAcceptableOrUnknown(
          data['cleaned_text']!,
          _cleanedTextMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    } else if (isInserting) {
      context.missing(_languageMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EntryRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      rawTranscript: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_transcript'],
      )!,
      cleanedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cleaned_text'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_count'],
      )!,
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
    );
  }

  @override
  $EntryRecordsTable createAlias(String alias) {
    return $EntryRecordsTable(attachedDatabase, alias);
  }
}

class EntryRecord extends DataClass implements Insertable<EntryRecord> {
  final int id;
  final String rawTranscript;
  final String? cleanedText;
  final String type;
  final String language;
  final int createdAt;
  final int wordCount;
  final String? audioPath;
  const EntryRecord({
    required this.id,
    required this.rawTranscript,
    this.cleanedText,
    required this.type,
    required this.language,
    required this.createdAt,
    required this.wordCount,
    this.audioPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['raw_transcript'] = Variable<String>(rawTranscript);
    if (!nullToAbsent || cleanedText != null) {
      map['cleaned_text'] = Variable<String>(cleanedText);
    }
    map['type'] = Variable<String>(type);
    map['language'] = Variable<String>(language);
    map['created_at'] = Variable<int>(createdAt);
    map['word_count'] = Variable<int>(wordCount);
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    return map;
  }

  EntryRecordsCompanion toCompanion(bool nullToAbsent) {
    return EntryRecordsCompanion(
      id: Value(id),
      rawTranscript: Value(rawTranscript),
      cleanedText: cleanedText == null && nullToAbsent
          ? const Value.absent()
          : Value(cleanedText),
      type: Value(type),
      language: Value(language),
      createdAt: Value(createdAt),
      wordCount: Value(wordCount),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
    );
  }

  factory EntryRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryRecord(
      id: serializer.fromJson<int>(json['id']),
      rawTranscript: serializer.fromJson<String>(json['rawTranscript']),
      cleanedText: serializer.fromJson<String?>(json['cleanedText']),
      type: serializer.fromJson<String>(json['type']),
      language: serializer.fromJson<String>(json['language']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      wordCount: serializer.fromJson<int>(json['wordCount']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'rawTranscript': serializer.toJson<String>(rawTranscript),
      'cleanedText': serializer.toJson<String?>(cleanedText),
      'type': serializer.toJson<String>(type),
      'language': serializer.toJson<String>(language),
      'createdAt': serializer.toJson<int>(createdAt),
      'wordCount': serializer.toJson<int>(wordCount),
      'audioPath': serializer.toJson<String?>(audioPath),
    };
  }

  EntryRecord copyWith({
    int? id,
    String? rawTranscript,
    Value<String?> cleanedText = const Value.absent(),
    String? type,
    String? language,
    int? createdAt,
    int? wordCount,
    Value<String?> audioPath = const Value.absent(),
  }) => EntryRecord(
    id: id ?? this.id,
    rawTranscript: rawTranscript ?? this.rawTranscript,
    cleanedText: cleanedText.present ? cleanedText.value : this.cleanedText,
    type: type ?? this.type,
    language: language ?? this.language,
    createdAt: createdAt ?? this.createdAt,
    wordCount: wordCount ?? this.wordCount,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
  );
  EntryRecord copyWithCompanion(EntryRecordsCompanion data) {
    return EntryRecord(
      id: data.id.present ? data.id.value : this.id,
      rawTranscript: data.rawTranscript.present
          ? data.rawTranscript.value
          : this.rawTranscript,
      cleanedText: data.cleanedText.present
          ? data.cleanedText.value
          : this.cleanedText,
      type: data.type.present ? data.type.value : this.type,
      language: data.language.present ? data.language.value : this.language,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryRecord(')
          ..write('id: $id, ')
          ..write('rawTranscript: $rawTranscript, ')
          ..write('cleanedText: $cleanedText, ')
          ..write('type: $type, ')
          ..write('language: $language, ')
          ..write('createdAt: $createdAt, ')
          ..write('wordCount: $wordCount, ')
          ..write('audioPath: $audioPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    rawTranscript,
    cleanedText,
    type,
    language,
    createdAt,
    wordCount,
    audioPath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryRecord &&
          other.id == this.id &&
          other.rawTranscript == this.rawTranscript &&
          other.cleanedText == this.cleanedText &&
          other.type == this.type &&
          other.language == this.language &&
          other.createdAt == this.createdAt &&
          other.wordCount == this.wordCount &&
          other.audioPath == this.audioPath);
}

class EntryRecordsCompanion extends UpdateCompanion<EntryRecord> {
  final Value<int> id;
  final Value<String> rawTranscript;
  final Value<String?> cleanedText;
  final Value<String> type;
  final Value<String> language;
  final Value<int> createdAt;
  final Value<int> wordCount;
  final Value<String?> audioPath;
  const EntryRecordsCompanion({
    this.id = const Value.absent(),
    this.rawTranscript = const Value.absent(),
    this.cleanedText = const Value.absent(),
    this.type = const Value.absent(),
    this.language = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.audioPath = const Value.absent(),
  });
  EntryRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String rawTranscript,
    this.cleanedText = const Value.absent(),
    required String type,
    required String language,
    required int createdAt,
    this.wordCount = const Value.absent(),
    this.audioPath = const Value.absent(),
  }) : rawTranscript = Value(rawTranscript),
       type = Value(type),
       language = Value(language),
       createdAt = Value(createdAt);
  static Insertable<EntryRecord> custom({
    Expression<int>? id,
    Expression<String>? rawTranscript,
    Expression<String>? cleanedText,
    Expression<String>? type,
    Expression<String>? language,
    Expression<int>? createdAt,
    Expression<int>? wordCount,
    Expression<String>? audioPath,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rawTranscript != null) 'raw_transcript': rawTranscript,
      if (cleanedText != null) 'cleaned_text': cleanedText,
      if (type != null) 'type': type,
      if (language != null) 'language': language,
      if (createdAt != null) 'created_at': createdAt,
      if (wordCount != null) 'word_count': wordCount,
      if (audioPath != null) 'audio_path': audioPath,
    });
  }

  EntryRecordsCompanion copyWith({
    Value<int>? id,
    Value<String>? rawTranscript,
    Value<String?>? cleanedText,
    Value<String>? type,
    Value<String>? language,
    Value<int>? createdAt,
    Value<int>? wordCount,
    Value<String?>? audioPath,
  }) {
    return EntryRecordsCompanion(
      id: id ?? this.id,
      rawTranscript: rawTranscript ?? this.rawTranscript,
      cleanedText: cleanedText ?? this.cleanedText,
      type: type ?? this.type,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      wordCount: wordCount ?? this.wordCount,
      audioPath: audioPath ?? this.audioPath,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (rawTranscript.present) {
      map['raw_transcript'] = Variable<String>(rawTranscript.value);
    }
    if (cleanedText.present) {
      map['cleaned_text'] = Variable<String>(cleanedText.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntryRecordsCompanion(')
          ..write('id: $id, ')
          ..write('rawTranscript: $rawTranscript, ')
          ..write('cleanedText: $cleanedText, ')
          ..write('type: $type, ')
          ..write('language: $language, ')
          ..write('createdAt: $createdAt, ')
          ..write('wordCount: $wordCount, ')
          ..write('audioPath: $audioPath')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalEntryDatabase extends GeneratedDatabase {
  _$LocalEntryDatabase(QueryExecutor e) : super(e);
  $LocalEntryDatabaseManager get managers => $LocalEntryDatabaseManager(this);
  late final $EntryRecordsTable entryRecords = $EntryRecordsTable(this);
  late final EntryDao entryDao = EntryDao(this as LocalEntryDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [entryRecords];
}

typedef $$EntryRecordsTableCreateCompanionBuilder =
    EntryRecordsCompanion Function({
      Value<int> id,
      required String rawTranscript,
      Value<String?> cleanedText,
      required String type,
      required String language,
      required int createdAt,
      Value<int> wordCount,
      Value<String?> audioPath,
    });
typedef $$EntryRecordsTableUpdateCompanionBuilder =
    EntryRecordsCompanion Function({
      Value<int> id,
      Value<String> rawTranscript,
      Value<String?> cleanedText,
      Value<String> type,
      Value<String> language,
      Value<int> createdAt,
      Value<int> wordCount,
      Value<String?> audioPath,
    });

class $$EntryRecordsTableFilterComposer
    extends Composer<_$LocalEntryDatabase, $EntryRecordsTable> {
  $$EntryRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawTranscript => $composableBuilder(
    column: $table.rawTranscript,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cleanedText => $composableBuilder(
    column: $table.cleanedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntryRecordsTableOrderingComposer
    extends Composer<_$LocalEntryDatabase, $EntryRecordsTable> {
  $$EntryRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawTranscript => $composableBuilder(
    column: $table.rawTranscript,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cleanedText => $composableBuilder(
    column: $table.cleanedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntryRecordsTableAnnotationComposer
    extends Composer<_$LocalEntryDatabase, $EntryRecordsTable> {
  $$EntryRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get rawTranscript => $composableBuilder(
    column: $table.rawTranscript,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cleanedText => $composableBuilder(
    column: $table.cleanedText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);
}

class $$EntryRecordsTableTableManager
    extends
        RootTableManager<
          _$LocalEntryDatabase,
          $EntryRecordsTable,
          EntryRecord,
          $$EntryRecordsTableFilterComposer,
          $$EntryRecordsTableOrderingComposer,
          $$EntryRecordsTableAnnotationComposer,
          $$EntryRecordsTableCreateCompanionBuilder,
          $$EntryRecordsTableUpdateCompanionBuilder,
          (
            EntryRecord,
            BaseReferences<
              _$LocalEntryDatabase,
              $EntryRecordsTable,
              EntryRecord
            >,
          ),
          EntryRecord,
          PrefetchHooks Function()
        > {
  $$EntryRecordsTableTableManager(
    _$LocalEntryDatabase db,
    $EntryRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntryRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntryRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntryRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> rawTranscript = const Value.absent(),
                Value<String?> cleanedText = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
              }) => EntryRecordsCompanion(
                id: id,
                rawTranscript: rawTranscript,
                cleanedText: cleanedText,
                type: type,
                language: language,
                createdAt: createdAt,
                wordCount: wordCount,
                audioPath: audioPath,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String rawTranscript,
                Value<String?> cleanedText = const Value.absent(),
                required String type,
                required String language,
                required int createdAt,
                Value<int> wordCount = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
              }) => EntryRecordsCompanion.insert(
                id: id,
                rawTranscript: rawTranscript,
                cleanedText: cleanedText,
                type: type,
                language: language,
                createdAt: createdAt,
                wordCount: wordCount,
                audioPath: audioPath,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntryRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalEntryDatabase,
      $EntryRecordsTable,
      EntryRecord,
      $$EntryRecordsTableFilterComposer,
      $$EntryRecordsTableOrderingComposer,
      $$EntryRecordsTableAnnotationComposer,
      $$EntryRecordsTableCreateCompanionBuilder,
      $$EntryRecordsTableUpdateCompanionBuilder,
      (
        EntryRecord,
        BaseReferences<_$LocalEntryDatabase, $EntryRecordsTable, EntryRecord>,
      ),
      EntryRecord,
      PrefetchHooks Function()
    >;

class $LocalEntryDatabaseManager {
  final _$LocalEntryDatabase _db;
  $LocalEntryDatabaseManager(this._db);
  $$EntryRecordsTableTableManager get entryRecords =>
      $$EntryRecordsTableTableManager(_db, _db.entryRecords);
}

mixin _$EntryDaoMixin on DatabaseAccessor<LocalEntryDatabase> {
  $EntryRecordsTable get entryRecords => attachedDatabase.entryRecords;
  EntryDaoManager get managers => EntryDaoManager(this);
}

class EntryDaoManager {
  final _$EntryDaoMixin _db;
  EntryDaoManager(this._db);
  $$EntryRecordsTableTableManager get entryRecords =>
      $$EntryRecordsTableTableManager(_db.attachedDatabase, _db.entryRecords);
}
