import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/emotion_model.dart';
import '../services/face_detector_service.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({super.key, required this.cameras});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _cameraController;
  late FaceDetectorService _faceDetectorService;
  bool _isProcessing = false;
  Emotion? _currentEmotion;
  String _status = "Initializing...";
  final List<Emotion> _history = [];

  @override
  void initState() {
    super.initState();
    _faceDetectorService = FaceDetectorService();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;

    final camera = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras[0],
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.low,
      enableAudio: false,
    );

    try {
      await _cameraController?.initialize();
      if (!mounted) return;

      _cameraController?.startImageStream((CameraImage image) {
        if (_isProcessing) return;
        _isProcessing = true;
        _processFrame(image);
      });
      setState(() => _status = "Camera Ready");
    } catch (e) {
      setState(() => _status = "Error: $e");
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final List<Face> faces = await _faceDetectorService.detectFaces(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        final double smilingProb = face.smilingProbability ?? 0.0;
        
        String label = "Neutral";
        double confidence = 50.0;

        if (smilingProb > 0.7) {
          label = "HAPPY 😊";
          confidence = smilingProb * 100;
        } else if (smilingProb < 0.05) { // Very low smiling probability
          label = "ANGRY 😠";
          confidence = 85.0;
        } else if (smilingProb < 0.2) {
          label = "SERIOUS 😐";
          confidence = 90.0;
        } else {
          label = "NEUTRAL 😐";
          confidence = 60.0;
        }

        if (mounted) {
          setState(() {
            _currentEmotion = Emotion(label: label, confidence: confidence);
            _status = "Detected: $label";
            _history.insert(0, _currentEmotion!);
            if (_history.length > 5) _history.removeLast();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _status = "Face Not Detected";
            _currentEmotion = null;
          });
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      await Future.delayed(const Duration(milliseconds: 100));
      _isProcessing = false;
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final camera = _cameraController!.description;
      final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
      
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetectorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Live Emotion Detector"), backgroundColor: Colors.blueAccent),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AspectRatio(
                  aspectRatio: _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                ),
                if (_currentEmotion != null)
                  Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _currentEmotion!.label,
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 30, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Confidence: ${_currentEmotion!.confidence.toStringAsFixed(0)}%",
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.black26,
                      child: Text(_status, style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          const Text("Recent Detections", style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: ListView.builder(
              itemCount: _history.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(_history[index].label),
                trailing: Text("${_history[index].confidence.toStringAsFixed(0)}%"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
