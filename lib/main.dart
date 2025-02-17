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
  Interpreter? interpreter;

  // Pick image, process it, and run inference.
  Future<void> _pickAndProcessImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _isProcessing = true;
      _imageFile = null;
    });

    File tempImage = File(pickedFile.path);
    File savedImage = await _saveImageLocally(tempImage);

    // Preprocess the image to get normalized pixel data.
    List<double> normalizedPixels = await _preprocessImage(savedImage);

    // Update UI with the saved image.
    setState(() {
      _imageFile = savedImage;
      _isProcessing = false;
    });

    // Reshape the flat pixel list to the 4D tensor expected by the model.
    // Here we assume the model expects [1, 224, 224, 3] input.
    var inputTensor = _reshapeInput(normalizedPixels, 224, 224, 3);

    // Prepare an output tensor.
    // Adjust the shape based on your model’s output.
    // For demonstration, assume the output is [1, 2] (e.g., two classification scores).
    List<List<double>> outputTensor =
    List.generate(1, (_) => List.filled(2, 0.0));

    // Run inference.
    interpreter?.run(inputTensor, outputTensor);
    print("Predictions: $outputTensor");
    devtools.log("Predictions: $outputTensor");

    // Get the predicted class.
    var predictedClass = outputTensor[0].indexOf(outputTensor[0].reduce((a, b) => a > b ? a : b));
    print("Predicted class: $predictedClass");
    devtools.log("Predicted class: $predictedClass");
  }

  // Save image locally.
  Future<File> _saveImageLocally(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = basename(imageFile.path);
    final localImage = File('${directory.path}/$fileName');
    return imageFile.copy(localImage.path);
  }

  // Preprocess the image: resize to 224x224 and normalize pixel values.
  Future<List<double>> _preprocessImage(File imageFile) async {
    // Read image bytes.
    List<int> imageBytes = await imageFile.readAsBytes();

    // Decode the image.
    img.Image? rawImage = img.decodeImage(Uint8List.fromList(imageBytes));
    if (rawImage == null) throw Exception("Failed to decode image");

    // Resize the image to 224x224.
    img.Image resizedImage = img.copyResize(rawImage, width: 224, height: 224);

    // Normalize the pixels (values between 0 and 1).
    List<double> normalizedPixels = [];
    for (int y = 0; y < resizedImage.height; y++) {
      for (int x = 0; x < resizedImage.width; x++) {
        // Get the pixel value.
        var pixel = resizedImage.getPixel(x, y); // pixel is a Pixel object
        double r = pixel.r / 255.0;
        double g = pixel.g / 255.0;
        double b = pixel.b / 255.0;
        normalizedPixels.add(r);
        normalizedPixels.add(g);
        normalizedPixels.add(b);
      }
    }
    print(
        "Processed Image Data (first 10 values): ${normalizedPixels.sublist(0, 10)} ...");
    return normalizedPixels;
  }

  // Reshape a flat list into a 4D tensor with shape [1, height, width, channels].
  List<List<List<List<double>>>> _reshapeInput(
      List<double> flat, int height, int width, int channels) {
    // Create a tensor of shape [1, height, width, channels].
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

  // Initialize the TFLite interpreter.
  Future<void> _initializeInterpreter() async {
    try {
      interpreter = await Interpreter.fromAsset('assets/model.tflite');
      print("Interpreter loaded successfully!");
    } catch (e) {
      print("Failed to load model: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeInterpreter();
  }

  @override
  void dispose() {
    interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Image Preprocessing')),
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
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold))
              ],
            )
                : _imageFile != null
                ? Image.file(_imageFile!, height: 300)
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
