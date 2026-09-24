import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:streak/core/sync/sync_queue.dart';
import 'package:streak/core/utils/app_dirs.dart';
import 'package:streak/features/habits/data/category.dart';
import 'package:streak/features/habits/data/habit.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/habits/data/habit_note.dart';
import 'package:streak/features/todos/data/todo.dart';
import 'package:streak/features/todos/data/todo_tag.dart';

class LocalStore {
  const LocalStore._();

  static const _habitsBox = 'habits';
  static const _settingsBox = 'settings';
  static const _categoriesBox = 'categories';
  static const _notesBox = 'notes';
  static const _focusBox = 'focus';
  static const _todosBox = 'todos';
  static const _todoTagsBox = 'todo_tags';

  static late Box _habits;
  static late Box _settings;
  static late Box _categories;
  static late Box _notes;
  static late Box _focus;
  static late Box _todos;
  static late Box _todoTags;

  // Existing code preserved.
  static int _writing = 0;

  static bool get isWriting => _writing > 0;

  // Flag to avoid re-enqueueing mutations when absorbing updates from cloud sync
  static bool isSyncAbsorption = false;

  static Future<T> guardWrites<T>(Future<T> Function() action) async {
    _writing++;
    try {
      return await action();
    } finally {
      _writing--;
    }
  }

  static Future<void> init() async {
    if (isMobile) {
      await Hive.initFlutter();
    } else {
      Hive.init((await appDataDir()).path);
    }
    _habits = await Hive.openBox(_habitsBox);
    _settings = await Hive.openBox(_settingsBox);
    _categories = await Hive.openBox(_categoriesBox);
    _notes = await Hive.openBox(_notesBox);
    _focus = await Hive.openBox(_focusBox);
    _todos = await Hive.openBox(_todosBox);
    _todoTags = await Hive.openBox(_todoTagsBox);
    // Initialize offline sync mutation queue
    await SyncQueue.init();
  }

  static List<Todo> readTodos() {
    final result = <Todo>[];
    for (final raw in _todos.values) {
      try {
        result.add(Todo.fromMap(Map<String, dynamic>.from(raw as Map)));
      } catch (e) {
        debugPrint('Skipped an unreadable to-do: $e');
      }
    }
    return result;
  }

  // Log todo mutation to SyncQueue for cloud synchronization
  static Future<void> writeTodo(Todo todo) async {
    await _todos.put(todo.id, todo.toMap());
    if (!isSyncAbsorption) {
      unawaited(SyncQueue.enqueue(
        entityId: todo.id,
        entityType: 'todo',
        action: 'update',
        payload: todo.toMap(),
      ));
    }
  }

  // Log todo deletion to SyncQueue for cloud synchronization
  static Future<void> removeTodo(String id) async {
    await _todos.delete(id);
    if (!isSyncAbsorption) {
      unawaited(SyncQueue.enqueue(
        entityId: id,
        entityType: 'todo',
        action: 'delete',
      ));
    }
  }

  // Log batch todo deletion to SyncQueue for cloud synchronization
  static Future<void> removeTodos(Iterable<String> ids) async {
    for (final id in ids) {
      await removeTodo(id);
    }
  }

  static List<TodoTag> readTodoTags() {
    final result = <TodoTag>[];
    for (final raw in _todoTags.values) {
      try {
        result.add(TodoTag.fromJson(raw as String));
      } catch (e) {
        debugPrint('Skipped an unreadable tag: $e');
      }
    }
    return result;
  }

  // Log todo tag mutation to SyncQueue for cloud synchronization
  static Future<void> writeTodoTag(TodoTag tag) async {
    await _todoTags.put(tag.id, tag.toJson());
    if (!isSyncAbsorption) {
      unawaited(SyncQueue.enqueue(
        entityId: tag.id,
        entityType: 'todo_tag',
        action: 'update',
        payload: json.decode(tag.toJson()) as Map<String, dynamic>,
      ));
    }
  }

  // Log todo tag deletion to SyncQueue for cloud synchronization
  static Future<void> removeTodoTag(String id) async {
    await _todoTags.delete(id);
    if (!isSyncAbsorption) {
      unawaited(SyncQueue.enqueue(
        entityId: id,
        entityType: 'todo_tag',
        action: 'delete',
      ));
    }
  }

  static List<FocusSession> readFocusSessions() {
    final result = <FocusSession>[];
    for (final raw in _focus.values) {
      result.add(FocusSession.fromMap(Map<String, dynamic>.from(raw as Map)));
    }
    return result;
  }

  // Log focus session mutation to SyncQueue for cloud synchronization
  static Future<void> writeFocusSession(FocusSession session) async {
    await _focus.put(session.id, session.toMap());
    if (!isSyncAbsorption) {
      unawaited(SyncQueue.enqueue(
        entityId: session.id,
        entityType: 'focus',
        action: 'update',
        payload: session.toMap(),
      ));
    }
  }

  // Log batch focus session deletion to SyncQueue for cloud synchronization
  static Future<void> removeFocusSessions(Iterable<String> ids) async {
    for (final id in ids) {
      await _focus.delete(id);
      if (!isSyncAbsorption) {
        unawaited(SyncQueue.enqueue(
          entityId: id,
          entityType: 'focus',
          action: 'delete',
        ));
      }
    }
  }

  // Log habit-associated focus session deletions to SyncQueue for cloud synchronization
  static Future<void> removeFocusFor(String habitId) async {
    final ids = readFocusSessions()
        .where((s) => s.habitId == habitId)
        .map((s) => s.id)
        .toList();
    await removeFocusSessions(ids);
  }

  static List<HabitNote> readNotes() {
    final result = <HabitNote>[];
    for (final raw in _notes.values) {
      result.add(HabitNote.fromMap(Map<String, dynamic>.from(raw as Map)));
    }
    return result;
  }

  // Log habit note mutation to SyncQueue for cloud synchronization
  static Future<void> writeNote(HabitNote note) async {
    await _notes.put(note.id, note.toMap());
    if (!isSyncAbsorption) {
      unawaited(SyncQueue.enqueue(
        entityId: note.id,
        entityType: 'note',
        action: 'update',
        payload: note.toMap(),
      ));
    }
  }

  // Log habit note deletion to SyncQueue for cloud synchronization
  static Future<void> removeNote(String id) async {
    await _notes.delete(id);
    if (!isSyncAbsorption) {
      unawaited(SyncQueue.enqueue(
        entityId: id,
        entityType: 'note',
        action: 'delete',
      ));
    }
  }

  // Log habit-associated note deletions to SyncQueue for cloud synchronization
  static Future<void> removeNotesFor(String habitId) async {
    final ids = readNotes()
        .where((n) => n.habitId == habitId)
        .map((n) => n.id)
        .toList();
    for (final id in ids) {
      await removeNote(id);
    }
  }

  static Map<String, Habit> readHabits() {
    final result = <String, Habit>{};
    for (final raw in _habits.values) {
      try {
        final habit = Habit.fromJson(raw as String);
        result[habit.id] = habit;
      } catch (e) {
        debugPrint('Skipped an unreadable habit: $e');
      }
    }
    return result;
  }

  // Log habit mutation to SyncQueue for cloud synchronization
  static Future<void> writeHabit(Habit habit) async {
    List<String>? removedCompletions;
    if (!isSyncAbsorption) {
      final oldRaw = _habits.get(habit.id);
      if (oldRaw != null) {
        try {
          final oldHabit = Habit.fromJson(oldRaw as String);
          final removed = oldHabit.completions.keys
              .where((k) => !habit.completions.containsKey(k))
              .toList();
          if (removed.isNotEmpty) {
            removedCompletions = removed;
          }
        } catch (_) {}
      }
    }

    await _habits.put(habit.id, habit.toJson());
    if (!isSyncAbsorption) {
      final payload = habit.toMap();
      if (removedCompletions != null && removedCompletions.isNotEmpty) {
        payload['removedCompletions'] = removedCompletions;
      }
      unawaited(SyncQueue.enqueue(
        entityId: habit.id,
        entityType: 'habit',
        action: 'update',
        payload: payload,
      ));
    }
  }

  // Log habit deletion to SyncQueue for cloud synchronization
  static Future<void> removeHabit(String id) async {
    await _habits.delete(id);
    if (!isSyncAbsorption) {
      unawaited(SyncQueue.enqueue(
        entityId: id,
        entityType: 'habit',
        action: 'delete',
      ));
    }
  }

  static Future<void> reloadHabits() async {
    if (_writing > 0) return;
    if (_habits.isOpen) await _habits.close();
    _habits = await Hive.openBox(_habitsBox);
  }

  static List<Category> readCategories() {
    final result = <Category>[];
    for (final raw in _categories.values) {
      try {
        result.add(Category.fromJson(raw as String));
      } catch (e) {
        debugPrint('Skipped an unreadable category: $e');
      }
    }
    return result;
  }

  // Log category mutation to SyncQueue for cloud synchronization
  static Future<void> writeCategory(Category category) async {
    await _categories.put(category.id, category.toJson());
    if (!isSyncAbsorption) {
      unawaited(SyncQueue.enqueue(
        entityId: category.id,
        entityType: 'category',
        action: 'update',
        payload: category.toMap(),
      ));
    }
  }

  // Log category deletion to SyncQueue for cloud synchronization
  static Future<void> removeCategory(String id) async {
    await _categories.delete(id);
    if (!isSyncAbsorption) {
      unawaited(SyncQueue.enqueue(
        entityId: id,
        entityType: 'category',
        action: 'delete',
      ));
    }
  }

  static bool get hasCategories => _categories.isNotEmpty;

  static T setting<T>(String key, T fallback) {
    final value = _settings.get(key, defaultValue: fallback);
    return value is T ? value : fallback;
  }

  static Map<String, dynamic> settingMap(String key) {
    final value = _settings.get(key);
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  static Future<void> writeSetting(String key, Object value) =>
      _settings.put(key, value);

  static Future<void> clearProgress() async {
    for (final habit in readHabits().values) {
      await writeHabit(habit.copyWith(completions: const {}));
    }
    await _notes.clear();
    await _focus.clear();
  }

  static Future<void> wipeContent() async {
    await _habits.clear();
    await _notes.clear();
    await _focus.clear();
    await _todos.clear();
    await _todoTags.clear();
    await _categories.clear();
  }

  static Future<void> wipeEverything() async {
    await _habits.clear();
    await _notes.clear();
    await _focus.clear();
    await _todos.clear();
    await _todoTags.clear();
    await _categories.clear();
    await _settings.clear();
  }
}
