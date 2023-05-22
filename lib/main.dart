import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'home_page.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final List<CameraDescription> cameras = await availableCameras();
  final ModelObjectDetection model = await loadModel();
  runApp(MyApp(cameras: cameras, objectModel: model));
}

class MyApp extends StatelessWidget {
  const MyApp({required this.cameras, required this.objectModel, Key? key}) : super(key: key);

  final List<CameraDescription> cameras;
  final ModelObjectDetection objectModel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Detection app',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: HomePage(cameras: cameras, objectModel: objectModel),
    );
  }

}

Future loadModel() async {
  String pathObjectDetectionModel = "assets/models/best.torchscript";
  try {
    final ModelObjectDetection objectModel = await FlutterPytorch.loadObjectDetectionModel(
              pathObjectDetectionModel, 1, 640, 640,
              labelPath: "assets/labels/labels.txt");
    return objectModel;
  } catch (e) {
    if (e is PlatformException) {
      print("Only supported for android, Error is $e");
    } else {
      print("Error is $e");
    }
    return null;
  }
}