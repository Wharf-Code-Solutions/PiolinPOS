import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// UUID v7: ordenable por tiempo, seguro para generar en el celular.
String newId() => _uuid.v7();
