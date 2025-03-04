import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:image/image.dart' as img;
import 'package:tflite/tflite.dart';
//import 'package:flutter_tflite/flutter_tflite.dart';
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
  _ImagePreprocessingScreenState createState() => _ImagePreprocessingScreenState();
}

class _ImagePreprocessingScreenState extends State<ImagePreprocessingScreen> {
  File? _imageFile;
  bool _isProcessing = false; // Flag to show processing message

  // Pick Image and Preprocess
  Future<void> _pickAndProcessImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile == null) return;

    setState(() {
      _isProcessing = true; // Show "Processing..." message
      _imageFile = null;
    });

    File tempImage = File(pickedFile.path);
    File savedImage = await _saveImageLocally(tempImage);

    // Process image (resize + normalize)
    await _preprocessImage(savedImage);

    setState(() {
      _imageFile = savedImage;
      _isProcessing = false; // Hide "Processing..." message
    });

    var recognitions = await Tflite.runModelOnImage(
        path: savedImage.path,   // required
        imageMean: 0.0,   // defaults to 117.0
        imageStd: 255.0,  // defaults to 1.0
        numResults: 2,    // defaults to 5
        threshold: 0.2,   // defaults to 0.1
        asynch: true      // defaults to true
    );

    if (recognitions == null ) {
      devtools.log("recognitions is NULL");
      return;
    }
    devtools.log(recognitions.toString());
  }

  // Save Image Locally
  Future<File> _saveImageLocally(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = basename(imageFile.path);
    final localImage = File('${directory.path}/$fileName');

    return imageFile.copy(localImage.path);
  }

  // Preprocess Image (Resize to 224x224 & Normalize)
  Future<void> _preprocessImage(File imageFile) async {
    // Read image bytes
    List<int> imageBytes = await imageFile.readAsBytes();

    // Decode image using 'image' package
    img.Image? rawImage = img.decodeImage(Uint8List.fromList(imageBytes));
    if (rawImage == null) throw Exception("Failed to decode image");

    // Resize to 224x224
    img.Image resizedImage = img.copyResize(rawImage, width: 224, height: 224);

    // Convert to float32 and normalize (values between 0 and 1)
    List<double> normalizedPixels = [];
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resizedImage.getPixel(x, y);
        normalizedPixels.add(pixel.r / 255.0); // Normalize Red
        normalizedPixels.add(pixel.g / 255.0); // Normalize Green
        normalizedPixels.add(pixel.b / 255.0); // Normalize Blue
      }
    }

    print("Processed Image Data: ${normalizedPixels.sublist(0, 10)} ..."); // Print first 10 values
  }

  Future<void> _tfliteInit() async {
    String? res = await Tflite.loadModel(
        model: "assets/model.tflite",
        labels: "assets/labels.txt",
        numThreads: 1, // defaults to 1
        isAsset: true, // defaults to true, set to false to load resources outside assets
        useGpuDelegate: false // defaults to false, set to true to use GPU delegate
    );
  }
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _tfliteInit();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    Tflite.close();
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
                Text("Processing Image...", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
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
