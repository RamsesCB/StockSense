import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../data/services/stats_service.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final StatsService _statsService = StatsService();

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    await _statsService.markAsRead(widget.filePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SfPdfViewer.file(File(widget.filePath)),
    );
  }
}
