import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
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
  bool _sensorDataFetched = false;

  String _selectedSeason = "Monsoon";
  Map<String, double> _fetchedSensorData = {};

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
      _predictionText = "";
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
          (_) => List.generate(height, (_) => List.generate(width, (_) => List.filled(channels, 0.0))),
    );

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

  Future<void> _fetchSensorData() async {
    try {
      final socket = await Socket.connect('192.168.220.249', 12345).timeout(Duration(seconds: 5));
      String response = "";

      await socket.listen((List<int> data) {
        response += String.fromCharCodes(data);
      }).asFuture();

      socket.destroy();

      RegExp regex = RegExp(r"\{.*\}");
      final match = regex.firstMatch(response);
      if (match == null) throw Exception("No JSON found in response");

      String jsonLike = match.group(0)!;
      jsonLike = jsonLike.replaceAll("'", '"');

      Map<String, dynamic> sensorData = json.decode(jsonLike);

      setState(() {
        _fetchedSensorData = {
          "nitrogen": (sensorData["nitrogen"] as num).toDouble(),
          "moisture": (sensorData["moisture"] as num).toDouble(),
          "temperature": (sensorData["temperature"] as num).toDouble(),
          "humidity": (sensorData["humidity"] as num).toDouble(),
        };
        _selectedSeason = sensorData["season"];
        _sensorDataFetched = true;
      });

      devtools.log("✅ Sensor Data: $_fetchedSensorData, Season: $_selectedSeason");
    } catch (e) {
      _showSensorError("Failed to fetch sensor data: $e");
    }
  }

  void _showSensorError(String msg) {
    devtools.log("❌ Sensor data error: $msg");
    setState(() => _sensorDataFetched = false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Sensor Data Error"),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("OK"))],
      ),
    );
  }

  Future<void> _runInference() async {
    if (_imageFile == null) {
      setState(() => _predictionText = "⚠️ Please select an image first!");
      return;
    }
    if (!_sensorDataFetched) {
      setState(() => _predictionText = "⚠️ Please fetch sensor data first!");
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

      _runSensorInference();
    } catch (e) {
      setState(() {
        _predictionText = "Error during image processing.";
        _isProcessing = false;
      });
    }
  }

  void _runSensorInference() {
    double nitrogen = _fetchedSensorData["nitrogen"]!;
    double moisture = _fetchedSensorData["moisture"]!;
    double temperature = _fetchedSensorData["temperature"]!;
    double humidity = _fetchedSensorData["humidity"]!;

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

    _sensorInterpreter?.run(inputTensor, outputTensor);
    sensorProbability = outputTensor[0][0];
    devtools.log("📊 Sensor Model Output: $sensorProbability");

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
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: Icon(Icons.camera_alt),
                label: Text('Pick Image'),
                onPressed: () => _pickAndProcessImage(ImageSource.gallery),
              ),
              SizedBox(height: 10),
              _imageFile != null
                  ? Image.file(_imageFile!, height: 200)
                  : Text("No image selected"),
              SizedBox(height: 20),
              Text("Select Season:", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _selectedSeason,
                items: ["Monsoon", "Winter", "Summer"]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedSeason = v!),
              ),
              SizedBox(height: 10),
              ElevatedButton.icon(
                icon: Icon(Icons.sensors),
                label: Text("Fetch Sensor Data"),
                onPressed: _fetchSensorData,
              ),
              SizedBox(height: 10),
              _sensorDataFetched
                  ? Column(
                children: [
                  Text("🌡 Temp: ${_fetchedSensorData["temperature"]?.toStringAsFixed(2)}°C"),
                  Text("💧 Humidity: ${_fetchedSensorData["humidity"]?.toStringAsFixed(2)}%"),
                  Text("🌱 Moisture: ${_fetchedSensorData["moisture"]?.toStringAsFixed(2)}"),
                  Text("🧪 Nitrogen: ${_fetchedSensorData["nitrogen"]?.toStringAsFixed(2)}"),
                ],
              )
                  : Text("No sensor data fetched."),
              SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.play_arrow),
                label: Text("Run Inference"),
                onPressed: _runInference,
              ),
              SizedBox(height: 20),
              Text("Prediction: $_predictionText", style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}
