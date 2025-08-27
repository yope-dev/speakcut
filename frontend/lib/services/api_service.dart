import 'dart:io';
import 'package:dio/dio.dart';
import '../models/job.dart';

class ApiService {
  final Dio _dio = Dio();

  Future<Job> uploadFile(File file, {ProgressCallback? onSendProgress}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });

    final response = await _dio.post(
      'http://127.0.0.1:8000/upload',
      data: formData,
      onSendProgress: onSendProgress,
    );

    return Job.fromJson(response.data);
  }

  Future<Job> checkStatus(String jobId) async {
    final response = await _dio.get('http://127.0.0.1:8000/status/$jobId');
    return Job.fromJson(response.data);
  }

  Future<File> downloadResult(
    String jobId,
    String savePath, {
    ProgressCallback? onReceiveProgress,
  }) async {
    final response = await _dio.get(
      'http://127.0.0.1:8000/result/$jobId',
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: onReceiveProgress,
    );

    final file = File(savePath);
    await file.writeAsBytes(response.data);
    return file;
  }
}
