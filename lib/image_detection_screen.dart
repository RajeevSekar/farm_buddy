import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:developer' as devtools;

class ImageDetectionScreen extends StatefulWidget {
  @override
  _ImageDetectionScreenState createState() => _ImageDetectionScreenState();
}

class _ImageDetectionScreenState extends State<ImageDetectionScreen> {
  File? _imageFile;
  bool _isProcessing = false;
  Interpreter? _imageInterpreter;
  String _predictionText = "No Prediction Yet";
  double imageProbability = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeInterpreter();
  }

  Future<void> _initializeInterpreter() async {
    try {
      _imageInterpreter = await Interpreter.fromAsset('assets/image_model.tflite');
      devtools.log("✅ Image Model Loaded Successfully!");
    } catch (e) {
      devtools.log("❌ Error loading image model: $e");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _imageFile = File(pickedFile.path);
      _predictionText = "Image selected. Click 'Run Inference'";
    });
  }

  Future<void> _runInference() async {
    if (_imageFile == null) {
      setState(() {
        _predictionText = "⚠️ Please select an image first!";
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _predictionText = "Processing...";
    });

    try {
      List<double> normalizedPixels = await _preprocessImage(_imageFile!);
      var inputTensor = _reshapeInput(normalizedPixels, 224, 224, 3);
      List<List<double>> outputTensor = List.generate(1, (_) => [0.0]);

      _imageInterpreter?.run(inputTensor, outputTensor);
      imageProbability = outputTensor[0][0];

      devtools.log("📊 Image Model Output: $imageProbability");

      setState(() {
        _predictionText = imageProbability >= 0.5 ? "❌ Sheath Blight Detected" : "✅ Healthy Plant";
        _isProcessing = false;
      });
    } catch (e) {
      devtools.log("❌ Error processing image: $e");
      setState(() {
        _predictionText = "Error processing image!";
        _isProcessing = false;
      });
    }
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
        normalizedPixels.add((pixel.r / 255.0));
        normalizedPixels.add((pixel.g / 255.0));
        normalizedPixels.add((pixel.b / 255.0));
      }
    }

    return normalizedPixels;
  }

  List<List<List<List<double>>>> _reshapeInput(List<double> flat, int height, int width, int channels) {
    List<List<List<List<double>>>> tensor = List.generate(
        1,
            (_) => List.generate(height, (_) => List.generate(width, (_) => List.filled(channels, 0.0))));

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

  @override
  void dispose() {
    _imageInterpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Image-Based Detection')),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: Icon(Icons.camera_alt),
                label: Text('Pick Image'),
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
              SizedBox(height: 20),
              _imageFile != null
                  ? Image.file(_imageFile!, height: 250)
                  : Text("No image selected", textAlign: TextAlign.center),
              SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.science),
                label: Text('Run Inference'),
                onPressed: _runInference,
              ),
              SizedBox(height: 20),
              Text(
                "Prediction: $_predictionText",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}