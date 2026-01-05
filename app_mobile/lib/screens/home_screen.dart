import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../data/services/stats_service.dart';
import 'inventory_screen.dart';
import 'scanner_screen.dart';
import 'profile_screen.dart';
import 'pdf_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const _FileGalleryView(),
    const InventoryScreen(),
    const ScannerScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            selectedIcon: Icon(Icons.qr_code),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '',
          ),
        ],
      ),
    );
  }
}

class _FileGalleryView extends StatefulWidget {
  const _FileGalleryView();

  @override
  State<_FileGalleryView> createState() => _FileGalleryViewState();
}

class _FileGalleryViewState extends State<_FileGalleryView> {
  final List<PlatformFile> _files = [];
  final StatsService _statsService = StatsService();

  Future<void> _updateStats(List<PlatformFile> newFiles) async {
    int pdfCount = 0;
    for (var file in newFiles) {
      if (file.extension?.toLowerCase() == 'pdf') {
        pdfCount++;
      }
    }

    if (pdfCount > 0) {
      await _statsService.addUploadedPdfs(pdfCount);
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'mp4', 'mov'],
      );

      if (result != null) {
        await _updateStats(result.files);
        setState(() {
          _files.addAll(result.files);
        });
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar archivos: $e')),
        );
      }
    }
  }

  void _onFileTap(PlatformFile file) {
    if (file.extension?.toLowerCase() == 'pdf' && file.path != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PdfViewerScreen(filePath: file.path!, fileName: file.name),
        ),
      );
    }
  }

  Widget _buildFilePreview(PlatformFile file) {
    final extension = file.extension?.toLowerCase();

    if (['jpg', 'jpeg', 'png'].contains(extension)) {
      if (file.path != null) {
        return Image.file(
          File(file.path!),
          fit: BoxFit.cover,
          width: double.infinity,
        );
      }
    }

    IconData icon;
    Color color;

    if (extension == 'pdf') {
      icon = Icons.picture_as_pdf;
      color = Colors.red;
    } else if (['mp4', 'mov'].contains(extension)) {
      icon = Icons.movie;
      color = Colors.blue;
    } else {
      icon = Icons.insert_drive_file;
      color = Colors.grey;
    }

    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              file.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: _files.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _files.length) {
                      return InkWell(
                        onTap: _pickFiles,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.15),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.add_rounded,
                              size: 64,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      );
                    }

                    final file = _files[index];
                    return InkWell(
                      onTap: () => _onFileTap(file),
                      borderRadius: BorderRadius.circular(24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _buildFilePreview(file),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
