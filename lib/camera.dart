import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:light/light.dart';
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
  File? _galleryImage;

  FlashMode _flashMode = FlashMode.auto;
  int _currentLux = 0;
  
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 8.0;

  @override
  void initState() { 
    super.initState();

    _blockScreenshots();
    _requestCamera();
    _initCamera();
    _listenToLightSensor();
  }

  // BLOCK SCREENSHOT/SCREEN RECORDING
  Future<void> _blockScreenshots() async {
    await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
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

      try {
        await _controller!.initialize();
        // Query min/max zoom after initialization
        _minZoom = await _controller!.getMinZoomLevel();
        _maxZoom = await _controller!.getMaxZoomLevel();
        _currentZoom = _minZoom;
        if (mounted) setState(() => _isCameraReady = true);
      } catch (e) { /* Handle error */ }
    }
  }

  // BRIGHTNESS DETECTION FOR AUTO FLASH
  void _listenToLightSensor() {
    try {
      Light().lightSensorStream.listen((luxValue) {
        setState(() {
          _currentLux = luxValue;
          // AUTO LIGHTING: AUTO FLASH BASED ON BRIGHTNESS
          if (_flashMode == FlashMode.auto) {
            final shouldFlashBeOn = luxValue < 30;
            _controller?.setFlashMode(
              shouldFlashBeOn ? FlashMode.always : FlashMode.off,
            );
          }
        });
      });
    } catch (e) {
      // Light sensor not available
    }
  }

  @override
  void dispose() {
    _controller?.dispose(); 
    super.dispose();
  }

  // CAPTURE IMAGE FROM CAMERA
  Future<void> _captureImage() async {
    if (!_isCameraReady) return;
    final image = await _controller!.takePicture();
    setState(() {
      _capturedImage = image;
      _galleryImage = null;
    });
  }

  // PICK IMAGE FROM GALLERY
  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _galleryImage = File(picked.path);
        _capturedImage = null;
      });
    }
  }

  // AUTO DELETE IMAGE FROM MEMORY AFTER UPLOAD
  void _cleanupImage() {
    setState(() {
      _capturedImage = null;
      _galleryImage = null;
    });
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.torch:
        return Icons.flash_on;
    }
  }

  void _toggleFlashMode() {
    setState(() {
      switch (_flashMode) {
        case FlashMode.off:
          _flashMode = FlashMode.always;
          _controller?.setFlashMode(FlashMode.always);
          break;
        case FlashMode.always:
          _flashMode = FlashMode.auto;
          _controller?.setFlashMode(FlashMode.off);
          break;
        case FlashMode.auto:
          _flashMode = FlashMode.off;
          _controller?.setFlashMode(FlashMode.off);
          break;
        case FlashMode.torch:
          _flashMode = FlashMode.auto;
          _controller?.setFlashMode(FlashMode.off);
          break;
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold( 
      appBar: AppBar(
        title: Text('Camera App'),
        actions: [
          // FLASH CONTROL (AUTO/MANUAL)
          IconButton(
            icon: Icon(_getFlashIcon()),
            onPressed: _toggleFlashMode,
          ),
        ],
      ),
      body: _isCameraReady
        ? Stack(
            children: [
              if (_capturedImage == null && _galleryImage == null)
                CameraPreview(_controller!)
              else if (_capturedImage != null)
                Image.file(File(_capturedImage!.path))
              else if (_galleryImage != null)
                Image.file(_galleryImage!),
              if (_capturedImage == null && _galleryImage == null) ...[
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 45),
                    child:
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            icon: Icon(Icons.circle_outlined, size: 64, color: Colors.white),
                            onPressed: _captureImage,
                          ),
                          IconButton(
                            icon: Icon(Icons.camera, size: 48, color: Colors.white),
                            onPressed: _captureImage,
                          ),
                        ]
                      ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 55),
                    child:
                      IconButton(
                        icon: Icon(Icons.photo_library, size: 36, color: Colors.white),
                        onPressed: _pickFromGallery,
                      ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.zoom_out), 
                        Expanded(
                          child: Slider(
                            value: _currentZoom, 
                            min: _minZoom,
                            max: _maxZoom,
                            divisions: (_maxZoom - _minZoom).round(),
                            label: 'Zoom: ${_currentZoom.toStringAsFixed(1)}x',
                            onChanged: (value) {
                              setState(() {
                                _currentZoom = value;
                                _controller?.setZoomLevel(_currentZoom);
                              });
                            },
                          ),
                        ),
                        Icon(Icons.zoom_in),
                      ],
                    ),
                  ),
                ),
              ],
              if (_capturedImage != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FilledButton(
                    onPressed: _cleanupImage,
                    child: Text('Retake'),
                  ),
                )
            ],
          )
      : Center(child: CircularProgressIndicator()),
    );
  }

}