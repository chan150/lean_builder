import 'package:lean_builder/builder.dart';
import 'package:lean_builder/runner.dart';
import 'package:lean_builder/src/runner/build_utils.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

class _Generator extends Generator {}

BuilderFactory libBuilderFactory([String ext = '.lib.dart']) =>
    (_) => LibraryBuilder(_Generator(), outputExtensions: {ext});

void main() {
  test('Builder Entries should be sorted based on runsBefore', () {
    final builders = [
      BuilderEntry('b', libBuilderFactory(), runsBefore: {'a'}),
      BuilderEntry('a', libBuilderFactory()),
      BuilderEntry('c', libBuilderFactory(), runsBefore: {'b'}),
    ];
    final sorted = orderBasedOnRunsBefore(builders);
    expect(sorted[0].key, 'c');
    expect(sorted[1].key, 'b');
    expect(sorted[2].key, 'a');
  });

  test('Builder Entries should be sorted based on runsBefore with multiple dependencies', () {
    final builders = [
      BuilderEntry('a', libBuilderFactory()),
      BuilderEntry('b', libBuilderFactory(), runsBefore: {'a'}),
      BuilderEntry('c', libBuilderFactory(), runsBefore: {'b'}),
      BuilderEntry('d', libBuilderFactory(), runsBefore: {'a', 'c'}),
    ];
    final sorted = orderBasedOnRunsBefore(builders);
    expect(sorted[0].key, 'd');
    expect(sorted[1].key, 'c');
    expect(sorted[2].key, 'b');
    expect(sorted[3].key, 'a');
  });

  test('Builder Entries should be sorted based on runsBefore with no dependencies', () {
    final builders = [
      BuilderEntry('a', libBuilderFactory()),
      BuilderEntry('b', libBuilderFactory()),
      BuilderEntry('c', libBuilderFactory()),
    ];
    final sorted = orderBasedOnRunsBefore(builders);
    expect(sorted[0].key, 'a');
    expect(sorted[1].key, 'b');
    expect(sorted[2].key, 'c');
  });

  test('Builder Entries should be sorted based on runsBefore with multiple dependencies', () {
    final builders = [
      BuilderEntry('a', libBuilderFactory()),
      BuilderEntry('b', libBuilderFactory(), runsBefore: {'a'}),
      BuilderEntry('c', libBuilderFactory(), runsBefore: {'b'}),
      BuilderEntry('d', libBuilderFactory(), runsBefore: {'a', 'c'}),
      BuilderEntry('e', libBuilderFactory(), runsBefore: {'d'}),
      BuilderEntry('f', libBuilderFactory(), runsBefore: {'e'}),
      BuilderEntry('g', libBuilderFactory(), runsBefore: {'f'}),
      BuilderEntry('h', libBuilderFactory(), runsBefore: {'g'}),
      BuilderEntry('i', libBuilderFactory(), runsBefore: {'h', 'j'}),
      BuilderEntry('j', libBuilderFactory(), runsBefore: {'x'}),
    ];
    final sorted = orderBasedOnRunsBefore(builders);
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
  });

  test('Cycle detection in builder dependencies', () {
    final builders = [
      BuilderEntry('a', libBuilderFactory(), runsBefore: {'b'}),
      BuilderEntry('b', libBuilderFactory(), runsBefore: {'c'}),
      BuilderEntry('c', libBuilderFactory(), runsBefore: {'a'}),
    ];
    expect(() => orderBasedOnRunsBefore(builders), throwsStateError);
  });

  test('Direct cycle detection in builder dependencies', () {
    final builders = [
      BuilderEntry('a', libBuilderFactory(), runsBefore: {'b'}),
      BuilderEntry('b', libBuilderFactory(), runsBefore: {'a'}),
    ];
    expect(() => orderBasedOnRunsBefore(builders), throwsStateError);
  });

  test('Should build phases based on order', () {
    final builders = [
      BuilderEntry('c', libBuilderFactory(), runsBefore: {'a'}),
      BuilderEntry('a', libBuilderFactory()),
      BuilderEntry('b', libBuilderFactory()),
    ];
    final phases = calculateBuilderPhases(builders);
    expect(phases[0][0].key, 'c');
    expect(phases[0][1].key, 'b');
    expect(phases[1][0].key, 'a');
  });

  test('Should force shared part builders into the same phase', () {
    final builders = [
      BuilderEntry('a', (_) => SharedPartBuilder([_Generator()])),
      BuilderEntry('b', (_) => SharedPartBuilder([_Generator()])),
    ];
    final phases = calculateBuilderPhases(builders);
    expect(phases.length, 1);
    expect(phases[0][0], isA<CombiningBuilderEntry>());
  });

  test('Should not force shared part builders into the same phase', () {
    final builders = [
      BuilderEntry('b', libBuilderFactory()),
      BuilderEntry('a', (_) => SharedPartBuilder([_Generator()])),
    ];
    final phases = calculateBuilderPhases(builders);
    expect(phases.length, 1);
    expect(phases[0][0], isA<BuilderEntryImpl>());
    expect(phases[0][1], isA<CombiningBuilderEntry>());
  });

  test('Should create phases respecting combining builders', () {
    final builders = [
      BuilderEntry('c', libBuilderFactory(), runsBefore: {'a'}),
      BuilderEntry('a', (_) => SharedPartBuilder([_Generator()])),
      BuilderEntry('d', (_) => SharedPartBuilder([_Generator()])),
      BuilderEntry('b', (_) => SharedPartBuilder([_Generator()])),
    ];
    final phases = calculateBuilderPhases(builders);
    expect(phases.length, 2);
    expect(phases[0][0].key, 'c');
    expect(phases[1][0], isA<CombiningBuilderEntry>());
    expect(phases[1][0].key, 'a|d|b');
  });

  test('Should detect cycles in combining builders', () {
    final builders = [
      BuilderEntry('a', (_) => SharedPartBuilder([_Generator()]), runsBefore: {'c'}),
      BuilderEntry('b', (_) => SharedPartBuilder([_Generator()])),
      BuilderEntry('c', libBuilderFactory(), runsBefore: {'a'}),
    ];
    expect(() => calculateBuilderPhases(builders), throwsStateError);
  });

  test('Should detect cycles in combining builders with multiple dependencies', () {
    final builders = [
      BuilderEntry('a', (_) => SharedPartBuilder([_Generator()]), runsBefore: {'c'}),
      BuilderEntry('b', (_) => SharedPartBuilder([_Generator()])),
      BuilderEntry('c', libBuilderFactory(), runsBefore: {'a', 'b'}),
    ];
    expect(() => calculateBuilderPhases(builders), throwsStateError);
  });
}
