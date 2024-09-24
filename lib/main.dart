import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  cameras = await availableCameras();

  // Get the first camera from the list.
  final firstCamera = cameras.first;

  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({Key? key, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: CameraPage(camera: camera),
    );
  }
}

class CameraPage extends StatefulWidget {
  final CameraDescription camera;

  const CameraPage({Key? key, required this.camera}) : super(key: key);

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _controller;
  Future<void>? _initializeControllerFuture;
  bool _isProcessing = false;
  Timer? _timer;
  bool _blackDetected = false;

  @override
  void initState() {
    super.initState();
    // Initialize the camera controller.
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    // Initialize the controller and start image streaming.
    _initializeControllerFuture = _controller.initialize().then((_) {
      if (!mounted) return;
      _controller.startImageStream(_processCameraImage);
    });
  }

  void _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // Calculate the average brightness of the image.
      final brightness = _calculateBrightness(image);
      print('Average Brightness: $brightness');

      // If brightness is below the threshold, start the timer.
      if (brightness < 30 && !_blackDetected) {
        _blackDetected = true;
        _timer = Timer(Duration(seconds: 3), () {
          _takePicture();
        });
      } else if (brightness >= 30 && _blackDetected) {
        // Cancel the timer if brightness increases.
        _blackDetected = false;
        _timer?.cancel();
      }
    } finally {
      _isProcessing = false;
    }
  }

  double _calculateBrightness(CameraImage image) {
    // Assuming YUV420 format and using the Y plane for luminance.
    final plane = image.planes[0];
    final bytes = plane.bytes;
    int totalLuminance = 0;

    // Sample pixels to reduce computation.
    int sampleRate = 100;
    for (int i = 0; i < bytes.length; i += sampleRate) {
      totalLuminance += bytes[i];
    }

    return totalLuminance / (bytes.length / sampleRate);
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;

      final image = await _controller.takePicture();

      // Handle the captured image (e.g., save or display).
      print('Picture taken: ${image.path}');

      // Reset the detection flag.
      _blackDetected = false;
    } catch (e) {
      print('Error taking picture: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Display the camera preview.
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
