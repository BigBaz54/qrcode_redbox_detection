import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'home_page.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final List<CameraDescription> cameras = await availableCameras();
  final List<ModelObjectDetection> models = await loadModels();
  runApp(MyApp(cameras: cameras, objectModels: models));
}

class MyApp extends StatelessWidget {
  const MyApp({required this.cameras, required this.objectModels, Key? key}) : super(key: key);

  final List<CameraDescription> cameras;
  final List<ModelObjectDetection> objectModels;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Detection app',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: HomePage(cameras: cameras, objectModels: objectModels, selectedModel: objectModels[0]),
    );
  }

}

Future loadModels() async {
  try {
    final List<ModelObjectDetection> objectModels = [];
    objectModels.add(await FlutterPytorch.loadObjectDetectionModel(
              "assets/models/yolov8s-pose.torchscript", 2, 640, 640, "v8s640-pose",
              labelPath: "assets/labels/redbox_labels.txt"));
    objectModels.add(await FlutterPytorch.loadObjectDetectionModel(
              "assets/models/v5n160fin.torchscript", 2, 160, 160, "v5n160fin",
              labelPath: "assets/labels/redbox_qr_labels.txt"));
    objectModels.add(await FlutterPytorch.loadObjectDetectionModel(
              "assets/models/v5s160fin.torchscript", 2, 160, 160, "v5s160fin",
              labelPath: "assets/labels/redbox_qr_labels.txt"));
    objectModels.add(await FlutterPytorch.loadObjectDetectionModel(
              "assets/models/v5s640fin.torchscript", 2, 640, 640, "v5s640fin",
              labelPath: "assets/labels/redbox_qr_labels.txt")); 
    objectModels.add(await FlutterPytorch.loadObjectDetectionModel(
              "assets/models/v5s160_fit_within.torchscript", 1, 160, 160, "v5s160",
              labelPath: "assets/labels/redbox_labels.txt"));
    objectModels.add(await FlutterPytorch.loadObjectDetectionModel(
              "assets/models/old.torchscript", 1, 640, 640, "v5s640",
              labelPath: "assets/labels/redbox_labels.txt"));
    return objectModels;
  } catch (e) {
    if (e is PlatformException) {
      print("Only supported for android, Error is $e");
    } else {
      print("Error is $e");
    }
    return null;
  }
}