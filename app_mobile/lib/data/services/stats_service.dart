import 'package:shared_preferences/shared_preferences.dart';

class StatsService {
  static final StatsService _instance = StatsService._internal();
  factory StatsService() => _instance;
  StatsService._internal();

  static const String keySubidos = 'pdfs_subidos';
  static const String keyPendientes = 'pdfs_pendientes';
  static const String keyLeidos = 'pdfs_leidos';
  static const String keyReadList = 'read_pdfs_list';

  Future<Map<String, int>> getStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'subidos': prefs.getInt(keySubidos) ?? 0,
        'pendientes': prefs.getInt(keyPendientes) ?? 0,
        'leidos': prefs.getInt(keyLeidos) ?? 0,
      };
    } catch (e) {
      return {'subidos': 0, 'pendientes': 0, 'leidos': 0};
    }
  }

  Future<void> addUploadedPdfs(int count) async {
    if (count <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      int currentSubidos = prefs.getInt(keySubidos) ?? 0;
      int currentPendientes = prefs.getInt(keyPendientes) ?? 0;

      await prefs.setInt(keySubidos, currentSubidos + count);
      await prefs.setInt(keyPendientes, currentPendientes + count);
    } catch (e) {
      // Handle or log error silently
    }
  }

  Future<void> markAsRead(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readList = prefs.getStringList(keyReadList) ?? [];

      if (!readList.contains(filePath)) {
        readList.add(filePath);
        await prefs.setStringList(keyReadList, readList);

        int currentLeidos = prefs.getInt(keyLeidos) ?? 0;
        int currentPendientes = prefs.getInt(keyPendientes) ?? 0;

        await prefs.setInt(keyLeidos, currentLeidos + 1);
        if (currentPendientes > 0) {
          await prefs.setInt(keyPendientes, currentPendientes - 1);
        }
      }
    } catch (e) {
      // Handle or log error silently
    }
  }

  Future<void> resetStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(keySubidos, 0);
      await prefs.setInt(keyPendientes, 0);
      await prefs.setInt(keyLeidos, 0);
      await prefs.setStringList(keyReadList, []);
    } catch (e) {
      // Handle or log error silently
    }
  }
}
