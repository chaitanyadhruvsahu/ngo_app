import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ngo_app/features/jobs/data/jobs_repository.dart';

class JobCapture {
  JobCapture({ImagePicker? picker}) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  Future<JobPhotoCapture?> camera() async {
    // Do not resize or recompress: retain available capture metadata for the
    // server to extract, before it strips metadata from stored evidence.
    final photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return null;
    return JobPhotoCapture(
        bytes: await photo.readAsBytes(), filename: photo.name);
  }

  Future<Position?> optionalLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 8)));
    } catch (_) {
      return null; // Optional metadata never prevents proof-of-work submission.
    }
  }
}
