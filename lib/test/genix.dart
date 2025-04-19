class Genix<T> implements GenixBase<T> {
  final String? str2;
  @override
  final String type;

  const Genix(this.type) : str2 = 'str2';

  const Genix.named(this.type) : str2 = null;
}

abstract class GenixBase<T> {
  const GenixBase(this.type);

  final String type;
}

//
