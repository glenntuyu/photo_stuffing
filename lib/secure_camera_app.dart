import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class SecureCameraApp extends StatefulWidget {
  @override
  State<SecureCameraApp> createState() => _SecureCameraAppState();
}

class _SecureCameraAppState extends State<SecureCameraApp> {
  bool _isCameraReady = false;

  CameraController? _controller;
  late List<CameraDescription> _cameras;

  XFile? _capturedImage;

  @override
  void initState() {
    super.initState();

    _requestCamera();
  }

  Future<bool> _requestCamera() async {
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied) { openAppSettings();
    }
    return status.isGranted;
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();

    if (_cameras.isNotEmpty == true) {
      _controller = CameraController(
        _cameras.first, 
        ResolutionPreset.high,
        enableAudio: false,
      );
    }

    try {
      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (e) {

    }
  }

  @override
  void dispose() {
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Secure Camera App'),
      ),
      body: _isCameraReady
        ? Stack(
          children: [
            if (_capturedImage == null)
              CameraPreview(_controller!)
            else 
              Image.file(File(_capturedImage!.path))
          ],
        )
      : Center(child: CircularProgressIndicator())
    );
  }
}
