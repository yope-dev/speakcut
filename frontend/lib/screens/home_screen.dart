import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/job_provider.dart';
import 'finish_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<JobProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Upload & Process')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  initialDirectory: path.join(
                    'E',
                    'GIT',
                    'LEARNING',
                    'speakcut',
                  ),
                  type: FileType.any,
                );
                if (result != null && result.files.single.path != null) {
                  File file = File(result.files.single.path!);
                  await provider.uploadFile(file);
                }
              },
              child: Text('Select File & Upload'),
            ),
            if (provider.isUploading)
              Column(
                children: [
                  SizedBox(height: 16),
                  LinearProgressIndicator(value: provider.uploadProgress),
                  SizedBox(height: 8),
                  Text(
                    'Uploading: ${(provider.uploadProgress * 100).toStringAsFixed(0)}%',
                  ),
                ],
              ),
            if (provider.job != null)
              Column(
                children: [
                  SizedBox(height: 16),
                  Text('Job ID: ${provider.job!.jobId}'),
                  Text('Status: ${provider.job!.status}'),
                  if (provider.job!.status == 'completed')
                    ElevatedButton(
                      onPressed: () async {
                        // Дістати доступну директорію для збереження файлу
                        final directory =
                            await getApplicationDocumentsDirectory();
                        // Формуємо повний шлях до файлу
                        final filePath = path.join(
                          directory.path,
                          '${provider.job!.jobId}_processed${provider.job!.extension}',
                        );
                        await provider.downloadResult(filePath);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => FinishScreen()),
                        );
                      },
                      child:
                          provider.isDownloading
                              ? Column(
                                children: [
                                  LinearProgressIndicator(
                                    value: provider.downloadProgress,
                                  ),
                                  Text(
                                    'Downloading: ${(provider.downloadProgress * 100).toStringAsFixed(0)}%',
                                  ),
                                ],
                              )
                              : Text('Download & Finish'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
