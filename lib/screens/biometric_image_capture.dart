// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';

import '../widgets/custom_dialog.dart';

class BiometricImageCaptureScreen extends StatefulWidget {
  const BiometricImageCaptureScreen({super.key});

  @override
  State<BiometricImageCaptureScreen> createState() =>
      _BiometricImageCaptureScreenState();
}

class _BiometricImageCaptureScreenState
    extends State<BiometricImageCaptureScreen> {
  final TextEditingController _cnicController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  File? _capturedImage;
  bool _posting = false;
  String _consoleMessage = '';

  /// ---------------- PICK IMAGE ----------------
  Future<void> _pickImage() async {
    try {
      XFile? pickedFile;

      if (kIsWeb) {
        // Web: Always pick from gallery
        pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      } else if (Platform.isAndroid || Platform.isIOS) {
        // Mobile: Use camera
        pickedFile = await _picker.pickImage(source: ImageSource.camera);
      } else {
        // Windows/Linux/Mac: Use file selector
        final typeGroup = XTypeGroup(
          label: 'images',
          extensions: ['jpg', 'jpeg', 'png'],
        );
        final file = await openFile(acceptedTypeGroups: [typeGroup]);
        if (file != null) {
          pickedFile = XFile(file.path);
        }
      }

      if (pickedFile != null) {
        setState(
          () => _capturedImage = kIsWeb
              ? File(pickedFile!.path)
              : File(pickedFile!.path),
        );
      }
    } catch (e) {
      ErrorDialog.show(
        context: context,
        title: 'Error',
        message: 'Unable to pick image: $e',
      );
    }
  }

  /// ---------------- POST IMAGE ----------------
  Future<void> _postImage() async {
    InfoDialog.show(
      context: context,
      title: 'File Upload',
      message: 'Coming Soon...',
      width: 300,
      height: 230,
    );
    return;
  }

  /// ---------------- LEFT COLUMN ----------------
  Widget _buildLeftColumn() {
    if (_capturedImage == null) {
      return Center(
        child: Text(
          'Capture an image to verify',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return Column(
      children: [
        Image.file(_capturedImage!, width: 200, height: 200, fit: BoxFit.cover),
      ],
    );
  }

  /// ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          TextField(
            controller: _cnicController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'CNIC',
              prefixIcon: const Icon(Icons.verified_user),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildLeftColumn()),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Icon(
                      Icons.camera_alt,
                      size: 100,
                      color: _capturedImage != null
                          ? Colors.green
                          : Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Browse Image'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _posting ? null : _postImage,
                      icon: const Icon(Icons.upload),
                      label: const Text('Upload File'),
                    ),
                    const SizedBox(height: 12),
                    if (_consoleMessage.isNotEmpty)
                      Text(
                        _consoleMessage,
                        style: TextStyle(color: Colors.green.shade700),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
