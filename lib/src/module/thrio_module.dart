// The MIT License (MIT)
//
// Copyright (c) 2019 Hellobike Group
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.

// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../exception/thrio_exception.dart';
import '../navigator/navigator_logger.dart';
import 'module_anchor.dart';
import 'module_context.dart';
import 'module_json_deserializer.dart';
import 'module_json_serializer.dart';
import 'module_page_builder.dart';
import 'module_page_observer.dart';
import 'module_protobuf_deserializer.dart';
import 'module_protobuf_serializer.dart';
import 'module_route_observer.dart';
import 'module_route_transitions_builder.dart';

mixin ThrioModule {
  /// Modular initialization function, needs to be called
  /// once during App initialization.
  ///
  static void init(ThrioModule rootModule, [String entrypoint]) {
    if (_anchor.modules.length == 1) {
      throw ThrioException('init method can only be called once.');
    } else {
      final moduleContext = ModuleContext(entrypoint: entrypoint);
      moduleContext.moduleOf[moduleContext] = _anchor;
      _anchor
        .._moduleContext = moduleContext
        ..registerModule(rootModule, moduleContext)
        ..onModuleInit(moduleContext)
        ..initModule();
    }
  }

  /// Get instance by `T`, `url` and `key`.
  ///
  /// `T` can be `ThrioModule`, `NavigatorPageBuilder`, `JsonSerializer`,
  /// `JsonDeserializer`, `ProtobufSerializer`, `ProtobufDeserializer`,
  /// `RouteTransitionsBuilder`, default is `ThrioModule`.
  ///
  /// If `T` is `ThrioModule`, returns the last module matched by the `url`.
  ///
  /// If `T` is `ThrioModule`, `RouteTransitionsBuilder` or
  /// `NavigatorPageBuilder`, then `url` must not be null or empty.
  ///
  /// If `T` is not `ThrioModule`, `RouteTransitionsBuilder` or
  /// `NavigatorPageBuilder`, and `url` is null or empty, find instance of `T`
  /// in all modules.
  ///
  static T get<T>({
    String url,
    String key,
  }) =>
      _anchor.get<T>(url: url, key: key);

  /// Get instances by `T` and `url`.
  ///
  /// `T` can not be optional. Can be `NavigatorPageObserver`,
  /// `NavigatorRouteObserver`.
  ///
  /// If `T` is `NavigatorPageObserver`, returns all page observers
  /// matched by `url`.
  ///
  /// If `T` is `NavigatorRouteObserver`, returns all route observers
  /// matched by `url`.
  ///
  static Iterable<T> gets<T>({@required String url}) => _anchor.gets<T>(url);

  static ModuleAnchor get anchor => _anchor;

  @protected
  final modules = <String, ThrioModule>{};

  /// A [Key] is an identifier for a module.
  ///
  String get key => '';

  /// Associate parent module to current module.
  ///
  /// Get parent module of `module` by `parentOf[module]`.
  ///
  final parentOf = Expando<ThrioModule>();

  /// `ModuleContext` of current module.
  ///
  ModuleContext _moduleContext;

  /// A function for registering a module, which will call
  /// the `onModuleRegister` function of the `module`.
  ///
  @protected
  void registerModule(
    ThrioModule module,
    ModuleContext moduleContext,
  ) {
    if (modules.containsKey(module.key)) {
      throw ThrioException('A module with the same key $key already exists');
    } else {
      final submoduleContext =
          ModuleContext(entrypoint: moduleContext.entrypoint);
      submoduleContext.moduleOf[submoduleContext] = module;
      modules[module.key] = module;
      module
        ..parentOf[module] = this
        .._moduleContext = submoduleContext
        ..onModuleRegister(submoduleContext);
    }
  }

  /// A function for module initialization that will call the
  /// `onModuleInit`, `onPageBuilderRegister`,
  /// `onRouteTransitionsBuilderRegister`, `onPageObserverRegister`
  /// `onRouteObserverRegister`, `onJsonSerializerRegister`,
  /// `onJsonDeserializerRegister`, `onProtobufSerializerRegister`,
  /// `onProtobufDeserializerRegister` and `onModuleAsyncInit`
  /// methods of all modules.
  ///
  @protected
  void initModule() {
    final values = modules.values;
    for (final module in values) {
      module
        ..onModuleInit(module._moduleContext)
        ..initModule();
    }
    for (final module in values) {
      if (module is ModulePageBuilder) {
        module.onPageBuilderSetting(module._moduleContext);
      }
      if (module is ModuleRouteTransitionsBuilder) {
        module.onRouteTransitionsBuilderSetting(module._moduleContext);
      }
    }
    for (final module in values) {
      if (module is ModulePageObserver) {
        module.onPageObserverRegister(module._moduleContext);
      }
      if (module is ModuleRouteObserver) {
        module.onRouteObserverRegister(module._moduleContext);
      }
    }
    for (final module in values) {
      if (module is ModuleJsonSerializer) {
        module.onJsonSerializerRegister(module._moduleContext);
      }
      if (module is ModuleJsonDeserializer) {
        module.onJsonDeserializerRegister(module._moduleContext);
      }
    }
    for (final module in values) {
      if (module is ModuleProtobufSerializer) {
        module.onProtobufSerializerRegister(module._moduleContext);
      }
      if (module is ModuleProtobufDeserializer) {
        module.onProtobufDeserializerRegister(module._moduleContext);
      }
    }
    for (final module in values) {
      Future.microtask(() {
        module.onModuleAsyncInit(module._moduleContext);
      });
    }
  }

  /// A function for registering submodules.
  ///
  @protected
  void onModuleRegister(ModuleContext moduleContext) {
    debugPrint(
        'onModuleRegister: ${moduleContext.moduleOf[moduleContext].key}');
  }

  /// A function for module initialization.
  ///
  @protected
  void onModuleInit(ModuleContext moduleContext) {
    debugPrint('onModuleInit: ${moduleContext.moduleOf[moduleContext].key}');
  }

  /// A function for module asynchronous initialization.
  ///
  @protected
  void onModuleAsyncInit(ModuleContext moduleContext) {
    debugPrint(
        'onModuleAsyncInit: ${moduleContext.moduleOf[moduleContext].key}');
  }

  @protected
  bool get navigatorLogEnabled => navigatorLogging;

  @protected
  set navigatorLogEnabled(bool enabled) => navigatorLogging = enabled;

  @override
  String toString() => '$key: ${modules.keys.toString()}';
}

final _anchor = ModuleAnchor();
