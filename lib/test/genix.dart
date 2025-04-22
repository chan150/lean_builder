class Genix<T> implements GenixBase<T> {
  final dynamic str2;
  @override
  final dynamic type;

  const Genix(this.type) : str2 = 'str2';

  const Genix.named(this.type) : str2 = null;
}

abstract class GenixBase<T> {
  const GenixBase(this.type);

  final dynamic type;
}

//343344223qr3235423
