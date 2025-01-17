import 'patch.dart';
import 'suggestor.dart';

/// Aggregates multiple [Suggestor]s into a single suggestor that yields the
/// aggregate of [Patch]es generated by each individual suggestor.
///     runInteractiveCodemod(
///       filesFromGlob(Glob('**.dart', recursive: true)),
///       aggregate([
///         suggestorA,
///         suggestorB,
///         suggestorC,
///         ...
///       ]),
///     );
Suggestor aggregate(Iterable<Suggestor> suggestors) => (context) async* {
      for (final suggestor in suggestors) {
        yield* suggestor(context);
      }
    };
