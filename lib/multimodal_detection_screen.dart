import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:developer' as devtools;

class MultiModalDetectionScreen extends StatefulWidget {
  @override
  _MultiModalDetectionScreenState createState() => _MultiModalDetectionScreenState();
}

class _MultiModalDetectionScreenState extends State<MultiModalDetectionScreen> {
  File? _imageFile;
  bool _isProcessing = false;
  Interpreter? _imageInterpreter;
  Interpreter? _sensorInterpreter;
  String _predictionText = "";
  double imageProbability = 0.0;
  double sensorProbability = 0.0;

  String _selectedSeason = "Monsoon";
  TextEditingController nitrogenController = TextEditingController();
  TextEditingController moistureController = TextEditingController();
  TextEditingController temperatureController = TextEditingController();
  TextEditingController humidityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeInterpreters();
  }

  Future<void> _initializeInterpreters() async {
    try {
      _imageInterpreter = await Interpreter.fromAsset('assets/image_model.tflite');
      _sensorInterpreter = await Interpreter.fromAsset('assets/ann_model.tflite');
      devtools.log("✅ Models loaded successfully!");
    } catch (e) {
      devtools.log("❌ Error loading models: $e");
    }
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _imageFile = File(pickedFile.path);
      _predictionText = ""; // Reset prediction
    });

    devtools.log("📷 Image selected");
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
        normalizedPixels.add((pixel.r / 255.0)); // Normalize R
        normalizedPixels.add((pixel.g / 255.0)); // Normalize G
        normalizedPixels.add((pixel.b / 255.0)); // Normalize B
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
    } catch (e) {
      devtools.log("❌ Error processing image: $e");
      setState(() {
        _predictionText = "Error processing image!";
        _isProcessing = false;
      });
      return;
    }

    _runSensorInference();
  }

  Future<void> _runSensorInference() async {
    double nitrogen = double.tryParse(nitrogenController.text) ?? 10.0;
    double moisture = double.tryParse(moistureController.text) ?? 10.0;
    double temperature = double.tryParse(temperatureController.text) ?? 25.0;
    double humidity = double.tryParse(humidityController.text) ?? 60.0;

    // Normalizing sensor inputs using min-max scaling
    double normNitrogen = (nitrogen - 10) / (300 - 10);
    double normMoisture = (moisture - 10) / (60 - 10);
    double normTemperature = (temperature - 25) / (38 - 25);
    double normHumidity = (humidity - 60) / (100 - 60);

    List<double> inputValues = [
      _selectedSeason == "Monsoon" ? 0.0 : _selectedSeason == "Winter" ? 1.0 : 2.0,
      normNitrogen,
      normMoisture,
      normTemperature,
      normHumidity,
    ];

    List<List<double>> inputTensor = [inputValues];
    List<List<double>> outputTensor = List.generate(1, (_) => [0.0]);

    try {
      _sensorInterpreter?.run(inputTensor, outputTensor);
      sensorProbability = outputTensor[0][0];
      devtools.log("📊 Sensor Model Output: $sensorProbability");
    } catch (e) {
      devtools.log("❌ Error running sensor model: $e");
    }

    _runFinalPrediction();
  }

  void _runFinalPrediction() {
    double finalProbability = (imageProbability * 0.75) + (sensorProbability * 0.25);
    devtools.log("🔄 Final Probability: $finalProbability");

    setState(() {
      _predictionText = finalProbability >= 0.5 ? "❌ Sheath Blight Detected" : "✅ Healthy Plant";
      _isProcessing = false;
    });
  }

  @override
  void dispose() {
    _imageInterpreter?.close();
    _sensorInterpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Multimodal Detection')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: ElevatedButton.icon(
                icon: Icon(Icons.camera),
                label: Text('Pick Image'),
                onPressed: () => _pickAndProcessImage(ImageSource.gallery),
              ),
            ),
            SizedBox(height: 10),
            _imageFile != null
                ? Center(child: Image.file(_imageFile!, height: 200))
                : Text("No image selected", textAlign: TextAlign.center),
            SizedBox(height: 20),

            // FORM
            Text("Enter Sensor Data:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _selectedSeason,
              items: ["Monsoon", "Winter", "Summer"]
                  .map((season) => DropdownMenuItem(value: season, child: Text(season)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedSeason = value!),
            ),
            TextField(controller: nitrogenController, decoration: InputDecoration(labelText: "Nitrogen Level")),
            TextField(controller: moistureController, decoration: InputDecoration(labelText: "Soil Moisture")),
            TextField(controller: temperatureController, decoration: InputDecoration(labelText: "Soil Temperature")),
            TextField(controller: humidityController, decoration: InputDecoration(labelText: "Soil Humidity")),
            SizedBox(height: 20),

            Center(
              child: ElevatedButton.icon(
                icon: Icon(Icons.science),
                label: Text('Run Multimodal Detection'),
                onPressed: _runInference,
              ),
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
    );
  }
}
