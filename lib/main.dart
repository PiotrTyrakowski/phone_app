import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(PhoneApp());
}

class PhoneApp extends StatefulWidget {
  @override
  _PhoneAppState createState() => _PhoneAppState();
}

class _PhoneAppState extends State<PhoneApp> {
  WebSocket? _socket;
  String _status = 'Disconnected';
  TextEditingController _controller = TextEditingController();
  bool _isConnecting = false;

  late CameraController _cameraController;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      _cameraController =
          CameraController(cameras[0], ResolutionPreset.medium);
      _initializeCamera();
    } else {
      print('No cameras available');
    }
  }

  void _initializeCamera() async {
    try {
      await _cameraController.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void connectToWebSocket(String serverAddress) async {
    setState(() {
      _isConnecting = true;
    });

    try {
      _socket = await WebSocket.connect(serverAddress);
      setState(() {
        _status = 'Connected to server';
        _isConnecting = false;
      });
      _socket!.listen((message) {
        handleMessage(message);
      }, onDone: () {
        setState(() {
          _status = 'Disconnected';
        });
      });
    } catch (e) {
      print('Error connecting to server: $e');
      setState(() {
        _status = 'Error connecting to server';
        _isConnecting = false;
      });
    }
  }

  void handleMessage(String message) async {
    Map<String, dynamic> data = jsonDecode(message);
    if (data['command'] == 'take_picture') {
      await takePictureAndSend();
    }
  }

  Future<void> takePictureAndSend() async {
    try {
      if (!_cameraController.value.isInitialized) {
        print('Camera not initialized');
        return;
      }

      // Ensure the camera is not taking a picture already
      if (_cameraController.value.isTakingPicture) {
        print('Camera is already taking a picture');
        return;
      }

      final Directory extDir = await getTemporaryDirectory();
      final String dirPath = '${extDir.path}/Pictures/flutter_test';
      await Directory(dirPath).create(recursive: true);
      final String filePath =
          '$dirPath/${DateTime.now().millisecondsSinceEpoch.toString()}.jpg';

      XFile picture = await _cameraController.takePicture();

      Uint8List imageBytes = await picture.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      _socket?.add(jsonEncode({'image': base64Image}));
    } catch (e) {
      print('Error taking picture: $e');
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _socket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phone App',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Phone App'),
        ),
        body: Center(
          child: _status == 'Disconnected' ||
                  _status == 'Error connecting to server'
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Text('Enter server address (e.g., ws://192.168.x.x:4040)'),
                      TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'ws://192.168.x.x:4040',
                        ),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _isConnecting
                            ? null
                            : () {
                                connectToWebSocket(_controller.text);
                              },
                        child: Text('Connect'),
                      ),
                      SizedBox(height: 20),
                      Text(_status),
                    ],
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Connected to server'),
                    SizedBox(height: 10),
                    _isCameraInitialized
                        ? AspectRatio(
                            aspectRatio:
                                _cameraController.value.aspectRatio,
                            child: CameraPreview(_cameraController),
                          )
                        : CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Waiting for commands...'),
                  ],
                ),
        ),
      ),
    );
  }
}
