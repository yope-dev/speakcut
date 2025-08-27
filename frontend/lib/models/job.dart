class Job {
  final String jobId;
  String status;

  String extension;

  Job({required this.jobId, required this.status, this.extension = '.mp4'});

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      jobId: json['job_id'],
      status: json['status'],
      extension: json.containsKey('extension') ? json['extension'] : '.mp4',
    );
  }

  @override
  String toString() =>
      'Job(jobId: $jobId, status: $status, extension: $extension)';
}
