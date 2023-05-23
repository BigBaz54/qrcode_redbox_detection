// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';
import 'package:flutter_pytorch/pigeon.dart';
import 'home_page.dart';
import 'package:flutter/services.dart';
import 'package:cpu_reader/cpu_reader.dart';
import 'package:cpu_reader/cpuinfo.dart';

class DetectionPage extends StatefulWidget {
  const DetectionPage({required this.cameras, required this.objectModel, Key? key}) : super(key: key);

  final List<CameraDescription> cameras;
  final ModelObjectDetection objectModel;

  @override
  State<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage> {
  late List<CameraDescription> cameras = widget.cameras;
  late CameraController cameraController;
  late ModelObjectDetection objectModel = widget.objectModel;
  List<ResultObjectDetection?> objDetect = [];
  final platform = const MethodChannel('com.example.qrcode_redbox_detection');
  double cpuTemp = -1;
  int cpuFreq = -1;

  int direction = 0;

  int delayBetweenFrames = 0;

  Uint8List? displayedImg;

  @override
  void initState() {
    super.initState();
    startCamera(direction);
  }

  void startCamera(int direction) async {
    cameraController = CameraController(cameras[direction], ResolutionPreset.high, enableAudio: false);
    await cameraController.initialize().then((value) {
      if (!mounted) {
        return;
      }
      startDetection();
      setState(() {});
    }).catchError((e) {
      print(e);
    });
  }

  void startDetection() async {
    while (true) {
      await Future.delayed(Duration(milliseconds: delayBetweenFrames));
      Uint8List imgBytes = await takePic();
      runObjectDetection(imgBytes);
      updateMetrics();
    }
  }

  Future<Uint8List> takePic() async {
    var path = (await cameraController.takePicture()).path;
    print(path);
    var imgFile = File(path);
    var imgBytes = await imgFile.readAsBytes();
    displayedImg = imgBytes;
    return imgBytes;
  }

  void updateMetrics() async {
    CpuInfo cpuInfo = await CpuReader.cpuInfo;
    int freq = await CpuReader.getCurrentFrequency(1) ?? -1;
    double temp = cpuInfo.cpuTemperature ?? -1;
    cpuFreq = freq;
    cpuTemp = temp;
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future runObjectDetection(imageAsBytes) async {
    final stopwatch = Stopwatch()..start();
    objDetect = await objectModel.getImagePrediction(
        imageAsBytes,
        minimumScore: 0.6,
        IOUThershold: 0.6);
    print('runObjectDetection() executed in ${stopwatch.elapsed.inMilliseconds} milliseconds');
    objDetect.forEach((element) {
      print({"state" : "before correction",
        "score": element?.score,
        "className": element?.className,
        "class": element?.classIndex,
        "rect": {
          "left": element?.rect.left,
          "top": element?.rect.top,
          "width": element?.rect.width,
          "height": element?.rect.height,
          "right": element?.rect.right,
          "bottom": element?.rect.bottom,
        },
      });
      var temp = element?.rect.top;
      element?.rect.top = element.rect.left;
      element?.rect.left = element.rect.bottom;
      element?.rect.bottom = element.rect.right;
      element?.rect.right = temp!;

      // symetry by y axis
      element?.rect.left = 1 - element.rect.left;  
      element?.rect.right = 1 - element.rect.right;

      temp = element?.rect.width;
      element?.rect.width = element.rect.height;
      element?.rect.height = temp!;
    });
    setState(() {
      // image = File(image.path);
    });
  }

  Future<Uint8List> convertCameraImageToPNG(CameraImage cameraImage) async {
  Uint8List pngBytes = Uint8List(0);
  try {
    final result = await platform.invokeMethod('convertToPNG', {
      'width': cameraImage.width,
      'height': cameraImage.height,
      'yPlane': cameraImage.planes[0].bytes,
      'uPlane': cameraImage.planes[1].bytes,
      'vPlane': cameraImage.planes[2].bytes,
      'yRowStride': cameraImage.planes[0].bytesPerRow,
      'uvRowStride': cameraImage.planes[1].bytesPerRow,
      'uvPixelStride': cameraImage.planes[1].bytesPerPixel,
    });
    pngBytes = result;
  } on PlatformException catch (e) {
    print("Failed to convert YUV to PNG: '\${e.message}'.");
  }
  return pngBytes;
}

  Widget renderBoxesWithoutImage(
    List<ResultObjectDetection?> _recognitions,
      {Color? boxesColor, bool showPercentage = true}) {

    return LayoutBuilder(builder: (context, constraints) {
      debugPrint(
          'Max height: ${constraints.maxHeight}, max width: ${constraints.maxWidth}');
      double factorX = constraints.maxWidth;
      double factorY = constraints.maxHeight;
      return Stack(
        children: [
          ..._recognitions.map((re) {
            if (re == null) {
              return Container();
            }
            Color usedColor;
            if (boxesColor == null) {
              //change colors for each label
              usedColor = Colors.primaries[
              ((re.className ?? re.classIndex.toString()).length +
                  (re.className ?? re.classIndex.toString())
                      .codeUnitAt(0) +
                  re.classIndex) %
                  Colors.primaries.length];
            } else {
              usedColor = boxesColor;
            }

            print({
              "left": re.rect.left.toDouble() * factorX,
              "top": re.rect.top.toDouble() * factorY,
              "width": re.rect.width.toDouble() * factorX,
              "height": re.rect.height.toDouble() * factorY,
            });
            return Positioned(
              left: re.rect.left * factorX,
              top: re.rect.top * factorY - 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 20,
                    alignment: Alignment.centerRight,
                    color: usedColor,
                    child: Text(
                      (re.className ?? re.classIndex.toString()) +
                          "_" +
                          (showPercentage
                              ? (re.score * 100).toStringAsFixed(2) + "%"
                              : ""),
                    ),
                  ),
                  Container(
                    width: re.rect.width.toDouble() * factorX,
                    height: re.rect.height.toDouble() * factorY,
                    decoration: BoxDecoration(
                        border: Border.all(color: usedColor, width: 3),
                        borderRadius: BorderRadius.all(Radius.circular(2))),
                    child: Container(),
                  ),
                ],
              ),
            );
          }).toList()
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (cameraController.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Live detection'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage(cameras: cameras, objectModel: objectModel)),
              );
            },
          ),
        ),
        body: Stack(
          children: [
            Center(child: SizedBox(
                                    height: MediaQuery.of(context).size.height,
                                    width: MediaQuery.of(context).size.width,
                                    child: CameraPreview(cameraController))),
            // text with cpuFred and cpuTemp
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Text(
                  "CPU freq: $cpuFreq\nCPU temp: $cpuTemp",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            // SizedBox(height: 200, width: 200, child: Positioned(top: 0, left:0, child: Image.memory(displayedImg ?? Uint8List(1)))),
            renderBoxesWithoutImage(objDetect, boxesColor: Color.fromARGB(255, 68, 255, 0)),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            setState(() {
              direction = direction == 0 ? 1 : 0;
              startCamera(direction);
            });
          },
          child: const Icon(Icons.flip_camera_android),
        ),
      );
    } else {
      return const Center(
          child:
            CircularProgressIndicator(),
        );
    }
  }
}
