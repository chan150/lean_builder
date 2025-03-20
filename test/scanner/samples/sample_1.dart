// Top-level variables with different modifiers
String normalString = 'regular';
final int finalInt = 42;
const double kPi = 3.14159;
late String lateVar;
const inferredConst = 'dynamic';
const List<String> constants = ['A', 'B'];

// Enum declaration
enum Color { red, green, blue }

// Typedef declarations
typedef JsonMap = Map<String, dynamic>;
typedef Record = (String key, dynamic value);
typedef Callback = void Function(String);
typedef GenericCallback<T> = void Function(T);

// Extension declaration
extension StringExt on String {
  String capitalize() => this;
}

// Mixin declaration
mixin Logger {
  void log(String msg) {}
}

class Annotation {
  const Annotation();
}

// Abstract class
abstract class Shape {
  double get area;
}

// Regular class
@Annotation()
class Rectangle implements Shape {
  final double width;
  const Rectangle(this.width);

  @override
  double get area => 0;
}

// Generic class
class Box<T> {
  final T value;
  const Box(this.value);
}

// Top-level functions
void printMsg(String message) {}

int add(int a, int b) => a + b;

// Function with named parameters
void configure({required String apiKey}) {}

// Function with optional parameters
List<int> getRange(int start, [int end = 10]) => [];

// Generic function
T identity<T>(T value) => value;

// Async function
Future<String> fetchData() async => '';

// Stream function
Stream<int> countStream(int max) async* {
  yield 1;
}
