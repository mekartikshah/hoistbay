import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_history.dart';

class TaskService {
  static const String _key = 'task_history';
  static const int _maxHistory = 1000; // Keep last 1000 tasks

  static Future<List<TaskHistoryItem>> loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_key);
      if (jsonString == null) return [];

      final list = jsonDecode(jsonString) as List;
      return list.map((e) => TaskHistoryItem.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Failed to load tasks: $e');
      return [];
    }
  }

  static Future<void> saveTasks(List<TaskHistoryItem> tasks) async {
    try {
      // Limit history size to prevent prefs from growing too large
      if (tasks.length > _maxHistory) {
        tasks = tasks.sublist(tasks.length - _maxHistory);
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(tasks.map((e) => e.toMap()).toList());
      await prefs.setString(_key, jsonString);
    } catch (e) {
      debugPrint('Failed to save tasks: $e');
    }
  }

  /// Inserts [task], or replaces the stored task with the same id.
  static Future<void> saveTask(TaskHistoryItem task) async {
    final tasks = await loadTasks();
    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) {
      tasks.add(task);
    } else {
      tasks[index] = task;
    }
    await saveTasks(tasks);
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
