import 'dart:io';
import 'package:flutter/material.dart';
import '../models/job.dart';
import '../services/api_service.dart';

class JobProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  Job? job;
  bool isUploading = false;
  bool isDownloading = false;
  double uploadProgress = 0.0;
  double downloadProgress = 0.0;

  String? originalFilePath;
  String? processedFilePath;

  Future<void> uploadFile(File file) async {
    originalFilePath = file.path;
    isUploading = true;
    uploadProgress = 0.0;
    notifyListeners();

    job = await _apiService.uploadFile(
      file,
      onSendProgress: (sent, total) {
        uploadProgress = sent / total;
        notifyListeners();
      },
    );

    isUploading = false;
    notifyListeners();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (job == null) return;

    while (job!.status != 'completed') {
      await Future.delayed(Duration(seconds: 2));
      job = await _apiService.checkStatus(job!.jobId);
      print(job);
      notifyListeners();
    }
  }

  Future<File?> downloadResult(String savePath) async {
    if (job == null || job!.status != 'completed') return null;

    isDownloading = true;
    downloadProgress = 0.0;
    notifyListeners();

    final file = await _apiService.downloadResult(
      job!.jobId,
      savePath,
      onReceiveProgress: (received, total) {
        downloadProgress = received / total;
        notifyListeners();
      },
    );

    processedFilePath = file.path;
    isDownloading = false;
    notifyListeners();

    return file;
  }
}
