import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class GazeDetectionScreen extends StatefulWidget {
  const GazeDetectionScreen({super.key});

  @override
  _GazeDetectionScreenState createState() => _GazeDetectionScreenState();
}

class _GazeDetectionScreenState extends State<GazeDetectionScreen> {
  late CameraController _cameraController;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableTracking: true,
      enableClassification: true, // Enables eye open detection
      enableLandmarks: false,
    ),
  );

  bool _isWatchingScreen = false;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front);

    _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
    await _cameraController.initialize();

    if (!mounted) return;
    setState(() {
      _isCameraInitialized = true;
    });

    _cameraController.startImageStream(_processCameraImage);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    final inputImage = _convertCameraImage(image);
    if (inputImage == null) return;

    final faces = await _faceDetector.processImage(inputImage);
    if (faces.isNotEmpty) {
      final face = faces.first;
      final isEyeOpen = (face.leftEyeOpenProbability ?? 0) > 0.7 &&
          (face.rightEyeOpenProbability ?? 0) > 0.7;
      final isFacingFront = (face.headEulerAngleY ?? 0).abs() < 15; // Head straight

      setState(() {
        _isWatchingScreen = isEyeOpen && isFacingFront;
      });
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }

      final inputImage = InputImage.fromBytes(
        bytes: allBytes.done().buffer.asUint8List(),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
      return inputImage;
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gaze Detection')),
      body: Column(
        children: [
          if (_isCameraInitialized)
            AspectRatio(
              aspectRatio: _cameraController.value.aspectRatio,
              child: CameraPreview(_cameraController),
            ),
          const SizedBox(height: 20),
          Text(
            _isWatchingScreen ? '👀 Looking at Screen' : '🙈 Not Looking',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
