import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:developer' as devtools;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ImagePreprocessingScreen(),
    );
  }
}

class ImagePreprocessingScreen extends StatefulWidget {
  @override
  _ImagePreprocessingScreenState createState() =>
      _ImagePreprocessingScreenState();
}

class _ImagePreprocessingScreenState extends State<ImagePreprocessingScreen> {
  File? _imageFile;
  bool _isProcessing = false;
  Interpreter? _interpreter;
  String _predictionText = "";

  Future<void> _pickAndProcessImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _isProcessing = true;
      _imageFile = null;
      _predictionText = "Processing...";
    });

    File tempImage = File(pickedFile.path);
    File savedImage = await _saveImageLocally(tempImage);
    List<double> normalizedPixels = await _preprocessImage(savedImage);

    setState(() {
      _imageFile = savedImage;
    });

    // Prepare input tensor
    var inputTensor = _reshapeInput(normalizedPixels, 224, 224, 3);

    // Updated output tensor shape: [1, 1] instead of [1, 2]
    List<List<double>> outputTensor = List.generate(1, (_) => List.filled(1, 0.0));

    try {
      _interpreter?.run(inputTensor, outputTensor);

      double predictionScore = outputTensor[0][0]; // Model output
      devtools.log("📊 Model Output: $predictionScore");

      setState(() {
        _predictionText = predictionScore >= 0.5 ? "Unhealthy" : "Healthy";
        _isProcessing = false;
      });
    } catch (e) {
      devtools.log("❌ Error running model: $e");
      setState(() {
        _predictionText = "Error processing image";
        _isProcessing = false;
      });
    }
  }

  Future<File> _saveImageLocally(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = basename(imageFile.path);
    final localImage = File('${directory.path}/$fileName');
    return imageFile.copy(localImage.path);
  }

  Future<List<double>> _preprocessImage(File imageFile) async {
    List<int> imageBytes = await imageFile.readAsBytes();
    img.Image? rawImage = img.decodeImage(Uint8List.fromList(imageBytes));
    if (rawImage == null) throw Exception("Failed to decode image");

    img.Image resizedImage = img.copyResize(rawImage, width: 224, height: 224);
    List<double> normalizedPixels = [];
    for (int y = 0; y < resizedImage.height; y++) {
      for (int x = 0; x < resizedImage.width; x++) {
        var pixel = resizedImage.getPixel(x, y);
        double r = pixel.r / 255.0;
        double g = pixel.g / 255.0;
        double b = pixel.b / 255.0;
        normalizedPixels.add(r);
        normalizedPixels.add(g);
        normalizedPixels.add(b);
      }
    }
    return normalizedPixels;
  }

  List<List<List<List<double>>>> _reshapeInput(
      List<double> flat, int height, int width, int channels) {
    List<List<List<List<double>>>> tensor = List.generate(
        1,
            (_) => List.generate(
            height, (_) => List.generate(width, (_) => List.filled(channels, 0.0))));
    int index = 0;
    for (int i = 0; i < height; i++) {
      for (int j = 0; j < width; j++) {
        for (int k = 0; k < channels; k++) {
          tensor[0][i][j][k] = flat[index++];
        }
      }
    }
    return tensor;
  }

  Future<void> _initializeInterpreter() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      print("✅ Interpreter loaded successfully!");
    } catch (e) {
      print("❌ Failed to load model: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeInterpreter();
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Image Classifier')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isProcessing
                ? Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text("Processing Image...",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
              ],
            )
                : _imageFile != null
                ? Column(
              children: [
                Image.file(_imageFile!, height: 300),
                SizedBox(height: 10),
                Text("Prediction: $_predictionText",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue))
              ],
            )
                : Text('No image selected'),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.camera),
                  label: Text('Camera'),
                  onPressed: () => _pickAndProcessImage(ImageSource.camera),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.photo_library),
                  label: Text('Gallery'),
                  onPressed: () => _pickAndProcessImage(ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
