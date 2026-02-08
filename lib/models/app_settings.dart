import 'package:flutter/material.dart';

class AppSettings {
  AppSettings({
    required this.keepScreenOn,
    required this.defaultServings,
    required this.themeMode,
    required this.galleryMode,
    required this.sortAscending,
  });

  final bool keepScreenOn;
  final int defaultServings;
  final ThemeMode themeMode;
  final bool galleryMode;
  final bool sortAscending;

  AppSettings copyWith({
    bool? keepScreenOn,
    int? defaultServings,
    ThemeMode? themeMode,
    bool? galleryMode,
    bool? sortAscending,
  }) {
    return AppSettings(
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      defaultServings: defaultServings ?? this.defaultServings,
      themeMode: themeMode ?? this.themeMode,
      galleryMode: galleryMode ?? this.galleryMode,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  Map<String, dynamic> toMap() => {
        'keepScreenOn': keepScreenOn,
        'defaultServings': defaultServings,
        'themeMode': themeMode.name,
        'galleryMode': galleryMode,
        'sortAscending': sortAscending,
      };

  factory AppSettings.fromMap(Map<String, dynamic>? map) {
    final themeName = map?['themeMode']?.toString();
    final themeMode = switch (themeName) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return AppSettings(
      keepScreenOn: map?['keepScreenOn'] as bool? ?? false,
      defaultServings: map?['defaultServings'] as int? ?? 2,
      themeMode: themeMode,
      galleryMode: map?['galleryMode'] as bool? ?? false,
      sortAscending: map?['sortAscending'] as bool? ?? true,
    );
  }

  static AppSettings defaults() => AppSettings(
        keepScreenOn: false,
        defaultServings: 2,
        themeMode: ThemeMode.system,
        galleryMode: false,
        sortAscending: true,
      );
}
