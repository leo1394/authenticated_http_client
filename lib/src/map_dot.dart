// Copyright (c) 2025, the Dart project authors. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Inspired by Dart Map access items by dot notation: https://github.com/dart-lang/language/issues/952
class MapDot {
  final Map<String, dynamic> _data;
  MapDot() : _data = {};
  MapDot.fromMap(Map<String, dynamic> map) : _data = Map.from(map);

  dynamic operator [](String key) {
    return _data[key];
  }

  void operator []=(String key, dynamic value) {
    _data[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = _getKeyName(invocation.memberName);
    final dynamic value = _data[key];
    if (invocation.isMethod) {
      if (value is Function) {
        // hack for authenticated_http_client's ajax fnc allow no arguments call and first argument is null, this argument is not a named one
        final arguments = invocation.positionalArguments.isNotEmpty ? invocation.positionalArguments : [null];
        final namedArguments = invocation.namedArguments ;
        try{
          return Function.apply(value, arguments, namedArguments);
        }catch(e, stackTrace) {
          print("[MapDot] failed in Function.apply ... $e \n $stackTrace");
          throw ArgumentError("[MapDot] failed in $key Function.apply ... ");
        }
      } else {
        throw ArgumentError("$key is not a function.");
      }
    }else if (invocation.isGetter) {
      return _data[key];
    } else if (invocation.isSetter) {
      _data[key] = invocation.positionalArguments[0];
      return null;
    }
    return super.noSuchMethod(invocation);
  }

  String _getKeyName(Symbol symbol) {
    final key = symbol.toString().replaceFirst('Symbol("', '').replaceFirst('")', '');
    return key;
  }
}