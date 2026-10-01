import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Origen de la imagen a subir.
enum ImagePickSource { gallery, camera, files }

/// Subida de portada / logo / galeria a Storage.
class EstablishmentMediaService {
  EstablishmentMediaService({
    FirebaseStorage? storage,
    ImagePicker? picker,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker();

  final FirebaseStorage _storage;
  final ImagePicker _picker;

  Future<XFile?> pickFromGallery() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
        requestFullMetadata: false,
      );
    } catch (e) {
      // Fallback: selector de documentos si el picker de fotos falla.
      debugPrint('FoodReto: gallery picker failed ($e), trying files');
      return pickFromFiles();
    }
  }

  Future<XFile?> pickFromCamera() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
        requestFullMetadata: false,
      );
    } catch (e) {
      debugPrint('FoodReto: camera picker failed ($e)');
      rethrow;
    }
  }

  /// Explorador de archivos (cualquier carpeta). Usa bytes para content://.
  Future<XFile?> pickFromFiles() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'heic', 'gif'],
      compressionQuality: 85,
    );
    if (file == null) return null;

    try {
      final bytes = await file.readAsBytes();
      final name = file.name.isNotEmpty ? file.name : 'photo.jpg';
      return XFile.fromData(
        bytes,
        name: name,
        mimeType: _mimeFromName(name),
      );
    } catch (_) {
      // Ultimo recurso: XFile desde path/uri si existe.
      final path = file.path;
      if (path != null && path.isNotEmpty) {
        return XFile(path, name: file.name);
      }
      return file.xFile;
    }
  }

  Future<XFile?> pickImage(ImagePickSource source) => switch (source) {
        ImagePickSource.gallery => pickFromGallery(),
        ImagePickSource.camera => pickFromCamera(),
        ImagePickSource.files => pickFromFiles(),
      };

  Future<String> uploadCover({
    required String establishmentId,
    required XFile file,
  }) =>
      _upload(
        establishmentId: establishmentId,
        folder: 'cover',
        fileName: 'main.jpg',
        file: file,
      );

  Future<String> uploadLogo({
    required String establishmentId,
    required XFile file,
  }) =>
      _upload(
        establishmentId: establishmentId,
        folder: 'logo',
        fileName: 'avatar.jpg',
        file: file,
      );

  Future<String> uploadGalleryImage({
    required String establishmentId,
    required XFile file,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    return _upload(
      establishmentId: establishmentId,
      folder: 'gallery',
      fileName: '$id.jpg',
      file: file,
    );
  }

  Future<String> _upload({
    required String establishmentId,
    required String folder,
    required String fileName,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    final ref = _storage
        .ref()
        .child('establishments')
        .child(establishmentId)
        .child(folder)
        .child(fileName);
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: _contentType(file),
        cacheControl: 'public,max-age=3600',
      ),
    );
    return ref.getDownloadURL();
  }

  String _mimeFromName(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  String _contentType(XFile file) {
    final mime = file.mimeType?.toLowerCase();
    if (mime != null && mime.startsWith('image/')) return mime;
    return _mimeFromName(file.name);
  }
}
