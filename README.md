# Rice Sheath Blight Detection App

## Overview
This is a **Flutter-based mobile application** for detecting Rice Sheath Blight disease using **image classification** and **sensor data analysis**. The app provides two detection modes:

1. **Image Detection** – Uses a **TensorFlow Lite (TFLite) model** to classify images of rice plants as **Healthy** or **Unhealthy**.
2. **Multimodal Detection** – Combines **image classification** and **sensor data inference** using a **ANN model** trained in Python.

## Features
- **Image Classification**: Detects sheath blight disease from an image using a **Convolutional Neural Network (CNN)**.
- **Sensor-based Inference**: Uses a **trained ANN model** to predict disease probability based on sensor inputs:
  - **Season** (Monsoon, Winter, Summer)
  - **Nitrogen Level**
  - **Soil Moisture**
  - **Soil Temperature**
  - **Soil Humidity**
- **Fusion Model**: Combines image-based probability (75%) and sensor-based probability (25%) for final classification.
- **User-friendly UI**: A simple and intuitive interface with two detection options.

## Tech Stack
- **Flutter** (Dart) for frontend UI
- **TensorFlow Lite** for image inference
- **Python (scikit-learn, TensorFlow)** for training model
- **Image Picker** for capturing/uploading images
- **TFLite Interpreter** for running inference on-device

## Installation & Setup
### **1. Clone the Repository**
```sh
git clone https://github.com/RajeevSekar.farm_buddy.git
cd rice-sheath-blight-detection
```

### **2. Install Dependencies**
```sh
flutter pub get
```

### **3. Add Model Files**
Ensure that `image_model.tflite` and `ann_model.tflite` are placed in the `assets/` folder.
Update `pubspec.yaml` to include:
```yaml
flutter:
  assets:
    - assets/image_model.tflite
    - assets/ann_model.tflite
```

### **4. Run the App**
```sh
flutter run
```

## How It Works
### **1. Image Detection Mode**
- Select an image from **camera/gallery**.
- The CNN model classifies the image as **Healthy** or **Unhealthy**.

### **2. Multimodal Detection Mode**
- **Sensor values** are taken from the hardware through bluetooth
- Run inference on:
  - **Image** (CNN model - 75% weight)
  - **Sensor Data** (ANN - 25% weight)
- Get the **final fused prediction**.


## License
This project is licensed under the MIT License.

## Contributors
- **Rajeev Sekar** (Developer)
  [GitHub](https://github.com/RajeevSekar)
- **Tulasi Raman** (Developer)
  [GitHub](https://github.com/ItsTulasiRaman)

## Acknowledgments
- TensorFlow Lite for on-device ML inference.
- Flutter Community for UI inspiration.

