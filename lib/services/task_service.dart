import 'dart:convert';
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
      print('Failed to load tasks: $e');
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
      print('Failed to save tasks: $e');
    }
  }

  static Future<void> addTask(TaskHistoryItem task) async {
    final tasks = await loadTasks();
    tasks.add(task);
    await saveTasks(tasks);
  }

  static Future<void> updateTaskStatus(String taskId, TaskStatus status, {String? details}) async {
    final tasks = await loadTasks();
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      tasks[index] = tasks[index].copyWith(
        status: status,
        details: details ?? tasks[index].details,
      );
      await saveTasks(tasks);
    }
  }
  
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
