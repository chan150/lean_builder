import 'package:lean_builder/builder.dart';
import 'package:lean_builder/runner.dart';
import 'package:lean_builder/src/runner/build_utils.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

class _Generator extends Generator {}

BuilderFactory libBuilderFactory([String ext = '.lib.dart']) =>
    (_) => LibraryBuilder(_Generator(), outputExtensions: <String>{ext});

void main() {
  test('Builder Entries should be sorted based on runsBefore', () {
    final List<BuilderEntry> builders = <BuilderEntry>[
      BuilderEntry('b', libBuilderFactory(), runsBefore: <String>{'a'}),
      BuilderEntry('a', libBuilderFactory()),
      BuilderEntry('c', libBuilderFactory(), runsBefore: <String>{'b'}),
    ];
    final List<BuilderEntry> sorted = orderBasedOnRunsBefore(builders);
    expect(sorted[0].key, 'c');
    expect(sorted[1].key, 'b');
    expect(sorted[2].key, 'a');
  });

  test(
    'Builder Entries should be sorted based on runsBefore with multiple dependencies',
    () {
      final List<BuilderEntry> builders = <BuilderEntry>[
        BuilderEntry('a', libBuilderFactory()),
        BuilderEntry('b', libBuilderFactory(), runsBefore: <String>{'a'}),
        BuilderEntry('c', libBuilderFactory(), runsBefore: <String>{'b'}),
        BuilderEntry('d', libBuilderFactory(), runsBefore: <String>{'a', 'c'}),
      ];
      final List<BuilderEntry> sorted = orderBasedOnRunsBefore(builders);
      expect(sorted[0].key, 'd');
      expect(sorted[1].key, 'c');
      expect(sorted[2].key, 'b');
      expect(sorted[3].key, 'a');
    },
  );

  test(
    'Builder Entries should be sorted based on runsBefore with no dependencies',
    () {
      final List<BuilderEntry> builders = <BuilderEntry>[
        BuilderEntry('a', libBuilderFactory()),
        BuilderEntry('b', libBuilderFactory()),
        BuilderEntry('c', libBuilderFactory()),
      ];
      final List<BuilderEntry> sorted = orderBasedOnRunsBefore(builders);
      expect(sorted[0].key, 'a');
      expect(sorted[1].key, 'b');
      expect(sorted[2].key, 'c');
    },
  );

  test(
    'Builder Entries should be sorted based on runsBefore with multiple dependencies',
    () {
      final List<BuilderEntry> builders = <BuilderEntry>[
        BuilderEntry('a', libBuilderFactory()),
        BuilderEntry('b', libBuilderFactory(), runsBefore: <String>{'a'}),
        BuilderEntry('c', libBuilderFactory(), runsBefore: <String>{'b'}),
        BuilderEntry('d', libBuilderFactory(), runsBefore: <String>{'a', 'c'}),
        BuilderEntry('e', libBuilderFactory(), runsBefore: <String>{'d'}),
        BuilderEntry('f', libBuilderFactory(), runsBefore: <String>{'e'}),
        BuilderEntry('g', libBuilderFactory(), runsBefore: <String>{'f'}),
        BuilderEntry('h', libBuilderFactory(), runsBefore: <String>{'g'}),
        BuilderEntry('i', libBuilderFactory(), runsBefore: <String>{'h', 'j'}),
        BuilderEntry('j', libBuilderFactory(), runsBefore: <String>{'x'}),
      ];
      final List<BuilderEntry> sorted = orderBasedOnRunsBefore(builders);
      expect(sorted[0].key, 'i');
      expect(sorted[1].key, 'h');
      expect(sorted[2].key, 'j');
      expect(sorted[3].key, 'g');
      expect(sorted[4].key, 'f');
      expect(sorted[5].key, 'e');
      expect(sorted[6].key, 'd');
      expect(sorted[7].key, 'c');
      expect(sorted[8].key, 'b');
      expect(sorted[9].key, 'a');
    },
  );

  test('Cycle detection in builder dependencies', () {
    final List<BuilderEntry> builders = <BuilderEntry>[
      BuilderEntry('a', libBuilderFactory(), runsBefore: <String>{'b'}),
      BuilderEntry('b', libBuilderFactory(), runsBefore: <String>{'c'}),
      BuilderEntry('c', libBuilderFactory(), runsBefore: <String>{'a'}),
    ];
    expect(() => orderBasedOnRunsBefore(builders), throwsStateError);
  });

  test('Direct cycle detection in builder dependencies', () {
    final List<BuilderEntry> builders = <BuilderEntry>[
      BuilderEntry('a', libBuilderFactory(), runsBefore: <String>{'b'}),
      BuilderEntry('b', libBuilderFactory(), runsBefore: <String>{'a'}),
    ];
    expect(() => orderBasedOnRunsBefore(builders), throwsStateError);
  });

  test('Should build phases based on order', () {
    final List<BuilderEntry> builders = <BuilderEntry>[
      BuilderEntry('c', libBuilderFactory(), runsBefore: <String>{'a'}),
      BuilderEntry('a', libBuilderFactory()),
      BuilderEntry('b', libBuilderFactory()),
    ];
    final List<List<BuilderEntry>> phases = calculateBuilderPhases(builders);
    expect(phases[0][0].key, 'c');
    expect(phases[0][1].key, 'b');
    expect(phases[1][0].key, 'a');
  });

  test('Should force shared part builders into the same phase', () {
    final List<BuilderEntry> builders = <BuilderEntry>[
      BuilderEntry('a', (_) => SharedPartBuilder(<Generator>[_Generator()])),
      BuilderEntry('b', (_) => SharedPartBuilder(<Generator>[_Generator()])),
    ];
    final List<List<BuilderEntry>> phases = calculateBuilderPhases(builders);
    expect(phases.length, 1);
    expect(phases[0][0], isA<CombiningBuilderEntry>());
  });

  test('Should not force shared part builders into the same phase', () {
    final List<BuilderEntry> builders = <BuilderEntry>[
      BuilderEntry('b', libBuilderFactory()),
      BuilderEntry('a', (_) => SharedPartBuilder(<Generator>[_Generator()])),
    ];
    final List<List<BuilderEntry>> phases = calculateBuilderPhases(builders);
    expect(phases.length, 1);
    expect(phases[0][0], isA<BuilderEntryImpl>());
    expect(phases[0][1], isA<CombiningBuilderEntry>());
  });

  test('Should create phases respecting combining builders', () {
    final List<BuilderEntry> builders = <BuilderEntry>[
      BuilderEntry('c', libBuilderFactory(), runsBefore: <String>{'a'}),
      BuilderEntry('a', (_) => SharedPartBuilder(<Generator>[_Generator()])),
      BuilderEntry('d', (_) => SharedPartBuilder(<Generator>[_Generator()])),
      BuilderEntry('b', (_) => SharedPartBuilder(<Generator>[_Generator()])),
    ];
    final List<List<BuilderEntry>> phases = calculateBuilderPhases(builders);
    expect(phases.length, 2);
    expect(phases[0][0].key, 'c');
    expect(phases[1][0], isA<CombiningBuilderEntry>());
    expect(phases[1][0].key, 'a|d|b');
  });

  test('Should detect cycles in combining builders', () {
    final List<BuilderEntry> builders = <BuilderEntry>[
      BuilderEntry(
        'a',
        (_) => SharedPartBuilder(<Generator>[_Generator()]),
        runsBefore: <String>{'c'},
      ),
      BuilderEntry('b', (_) => SharedPartBuilder(<Generator>[_Generator()])),
      BuilderEntry('c', libBuilderFactory(), runsBefore: <String>{'a'}),
    ];
    expect(() => calculateBuilderPhases(builders), throwsStateError);
  });

  test(
    'Should detect cycles in combining builders with multiple dependencies',
    () {
      final List<BuilderEntry> builders = <BuilderEntry>[
        BuilderEntry(
          'a',
          (_) => SharedPartBuilder(<Generator>[_Generator()]),
          runsBefore: <String>{'c'},
        ),
        BuilderEntry('b', (_) => SharedPartBuilder(<Generator>[_Generator()])),
        BuilderEntry('c', libBuilderFactory(), runsBefore: <String>{'a', 'b'}),
      ];
      expect(() => calculateBuilderPhases(builders), throwsStateError);
    },
  );

  test('Should detect output conflicts', () {
    final List<BuilderEntry> builders = <BuilderEntry>[
      BuilderEntry('a', libBuilderFactory('.a.dart')),
      BuilderEntry('b', libBuilderFactory('.a.dart')),
    ];
    expect(() => validateBuilderEntries(builders), throwsException);
  });

  test('Should detect duplicate builder keys', () {
    final List<BuilderEntry> builders = <BuilderEntry>[
      BuilderEntry('a', libBuilderFactory()),
      BuilderEntry('a', libBuilderFactory('.a.dart')),
    ];
    expect(() => validateBuilderEntries(builders), throwsException);
  });

  test('Should throw if a SharedPartBuilder is used with generateToCache', () {
    final List<BuilderEntry> builders = <BuilderEntry>[
      BuilderEntry(
        'a',
        (_) => SharedPartBuilder(<Generator>[_Generator()]),
        generateToCache: true,
      ),
    ];
    expect(() => validateBuilderEntries(builders), throwsException);
  });
}
