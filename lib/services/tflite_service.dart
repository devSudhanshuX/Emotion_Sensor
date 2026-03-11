import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';

class TfLiteService {
  Interpreter? _interpreter;
  List<String>? _labels;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      print("Model loaded successfully");
    } catch (e) {
      print("Error loading model: $e");
    }
  }

  List<double> predict(List<double> input) {
    if (_interpreter == null) return [];
    
    // Model expects [1, 48, 48, 1] or similar. 
    // This is a simplified placeholder for the logic.
    var output = List.filled(1 * 7, 0.0).reshape([1, 7]);
    _interpreter!.run(input.reshape([1, 48, 48, 1]), output);
    return List<double>.from(output[0]);
  }

  void dispose() {
    _interpreter?.close();
  }
}
