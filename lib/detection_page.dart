// ignore_for_file: avoid_print

import 'dart:ffi';
import 'dart:io';
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';
import 'package:flutter_pytorch/pigeon.dart';
import 'home_page.dart';
import 'package:flutter/services.dart';
import 'package:cpu_reader/cpu_reader.dart';
import 'package:cpu_reader/cpuinfo.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image/image.dart' as img;
import 'package:geolocator/geolocator.dart' as gl;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:http/http.dart' as http;
// import 'package:exif/exif.dart';
import 'dart:convert';
import 'yuv_channeling.dart';

class DetectionPage extends StatefulWidget {

  const DetectionPage({required this.cameras, required this.objectModel, required this.robotName, required this.url, required this.authKey, required this.teamName, Key? key}) : super(key: key);

  final List<CameraDescription> cameras;
  final ModelObjectDetection objectModel;
  final String robotName;
  final String url;
  final String authKey;
  final String teamName;

  @override
  State<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage> {
  late List<CameraDescription> cameras = widget.cameras;
  late CameraController cameraController;
  late ModelObjectDetection objectModel = widget.objectModel;
  late String robotName = widget.robotName;
  late String url = widget.url;
  late String authKey = widget.authKey;
  late String teamName = widget.teamName;
  List<ResultObjectDetection?> objDetect = [];
  final platform = const MethodChannel('com.example.qrcode_redbox_detection');

  int direction = 0;
  bool hasLocationPermission = false;

  double cpuTemp = -1;
  int cpuFreq = -1;
  int delayBetweenFrames = 0;
  int detectionWindowStartTime = -1;
  int numberOfImagesProcessed = 0;
  int numberOfPicTaken = 0;
  int numberOfImageDetected = 0;
  int numberOfQRCodeRead = 0;
  double fps = -1;
  double totalPictureTime = 0;
  double avgPictureTime = -1;
  double totalDetectionTime = 0;
  double avgDetectionTime = -1;
  double totalQRCodeTime = 0;
  double avgQRCodeTime = -1;
  double latitude = -1;
  double longitude = -1;
  double heading = -1;

  String nature = "";
  String identifiant = "";
  String rayonNeutralisation = "";
  String desactivableDistance= "";
  String codeDesactivation = "";
  String desactivableContact = "";
  String divers = "";

  Uint8List? processedImg;
  Uint8List? croppedImg;

  bool isProcessing = false;
  YuvChannelling yuvChannelling = YuvChannelling();

  @override
  void initState() {
    super.initState();
    startCamera(direction);
  }

  void startCamera(int direction) async {
    cameraController = CameraController(cameras[direction], ResolutionPreset.high, enableAudio: false);
    cameraController.setFlashMode(FlashMode.off);
    cameraController.setExposureMode(ExposureMode.auto);
    await cameraController.initialize().then((value) {
      if (!mounted) {
        return;
      }
      checkGPS();
      // startDetection();
      startStreamDetection();
    }).catchError((e) {
      print(e);
    });
  }

  void startStreamDetection() async {
    int n = 0;
    await cameraController.startImageStream((CameraImage cameraImage) async {
      if (n % 20 == 0) {
        bool detected = false;
        processedImg = await yuvChannelling.yuvToJpeg(cameraImage);
        getHeading();
        getLocation();
        detected = detected || await runObjectDetection(processedImg);
        // detected = detected || await readQRCode(path);
        if (detected) {
          sendRequest();
        }
        numberOfPicTaken++;
        updateMetrics();
        setState(() {});
      }
      n++;
    });
  }

  checkGPS() async {
      bool servicestatus = await gl.Geolocator.isLocationServiceEnabled();
      if(servicestatus){
            gl.LocationPermission permission = await gl.Geolocator.checkPermission();
          
            if (permission == gl.LocationPermission.denied) {
                permission = await gl.Geolocator.requestPermission();
                if (permission == gl.LocationPermission.denied) {
                    print('Location permissions are denied');
                }else if(permission == gl.LocationPermission.deniedForever){
                    print("'Location permissions are permanently denied");
                }else{
                   hasLocationPermission = true;
                }
            }else{
               hasLocationPermission = true;
            }

            if(hasLocationPermission){
                setState(() {
                });
            }
      }else{
        print("GPS Service is not enabled, turn on GPS location");
      }
      setState(() {
      });
  }

  void getLocation() async {
    try {
      gl.Position position = await gl.Geolocator.getCurrentPosition(desiredAccuracy: gl.LocationAccuracy.high);
      latitude = position.latitude;
      longitude = position.longitude;
    } catch (e) {
      print(e);
    }
  }

  void getHeading() async {
    FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading == null) {
        heading = -1;
      } else {
        double h = event.heading!;
        if (h < 0) {
          heading = 360+h;
        } else {
          heading = h;
        }
      }
    });
  }

  void sendRequest() async {
    if (latitude == -1 || longitude == -1 || heading == -1) {
      return;
    }
    http.post(
      Uri.parse(url),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, Object>{
        'teamName': teamName,
        'authKey': authKey,
        'geolocation': {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
        },
        'heading': heading.toString(),
        'robotName': robotName,
      }),
    );
  }

  void startDetection() async {
    detectionWindowStartTime = DateTime.now().millisecondsSinceEpoch;
    while (true) {
      bool detected = false;
      await Future.delayed(Duration(milliseconds: delayBetweenFrames));
      String path = await takePic();
      getHeading();
      getLocation();
      if (path == "") {
        continue;
      }
      var imgFile = File(path);
      var imgBytes = await imgFile.readAsBytes();
      // final data = await readExifFromBytes(imgBytes);
      // print('EXIF DATA');
      // for (final entry in data!.entries) {
      //   print('${entry.key}: ${entry.value}');
      // }
      processedImg = imgBytes;
      detected = detected || await runObjectDetection(imgBytes);
      detected = detected || await readQRCode(path);
      if (detected) {
        sendRequest();
      }
      updateMetrics();
    }
  }

  Future<String> takePic() async {
    if (!cameraController.value.isInitialized) {
      print("Controller not initialized");
      return "";
    }
    if (cameraController.value.isTakingPicture) {
      return "";
    }
    final stopwatch = Stopwatch()..start();
    var path = (await cameraController.takePicture()).path;
    var time = stopwatch.elapsed.inMilliseconds;
    print('takePic() executed in $time milliseconds');
    totalPictureTime += time;
    numberOfPicTaken++;
    print(path);
    return path;
  }

  void updateMetrics() async {
    CpuInfo cpuInfo = await CpuReader.cpuInfo;
    int freq = await CpuReader.getCurrentFrequency(1) ?? -1;
    double temp = cpuInfo.cpuTemperature ?? -1;
    cpuFreq = freq;
    cpuTemp = temp;
    if (numberOfPicTaken != 0) {
      avgPictureTime = totalPictureTime / numberOfPicTaken;
    }
    if (numberOfImageDetected != 0) {
      avgDetectionTime = totalDetectionTime / numberOfImageDetected;
    }
    if (numberOfQRCodeRead != 0) {
      avgQRCodeTime = totalQRCodeTime / numberOfQRCodeRead;
    }
    numberOfImagesProcessed++;
    if (numberOfImagesProcessed % 10 == 0) {
      fps = 10 / ((DateTime.now().millisecondsSinceEpoch - detectionWindowStartTime) / 1000);
      detectionWindowStartTime = DateTime.now().millisecondsSinceEpoch;
    } 
    setState(() {});
  }

  Future<bool> readQRCode(path) async {
    bool detected = false;
    final stopwatch = Stopwatch()..start();
    Code? resultFromXFile = await zx.readBarcodeImagePathString(path);
    int time = stopwatch.elapsed.inMilliseconds;
    print('readQRCode() executed in $time milliseconds');
    totalQRCodeTime += time;
    numberOfQRCodeRead++;
    var qrCodeText = resultFromXFile.text ?? "";
    var qrCodeTextSplitted = qrCodeText.split("\n");
    if (qrCodeTextSplitted.length == 7) {
      detected = true;
      nature = qrCodeTextSplitted[0];
      identifiant = qrCodeTextSplitted[1];
      rayonNeutralisation = qrCodeTextSplitted[2];
      desactivableDistance = qrCodeTextSplitted[3];
      codeDesactivation = qrCodeTextSplitted[4];
      desactivableContact = qrCodeTextSplitted[5];
      divers = qrCodeTextSplitted[6];
    } else {
      nature = "";
      identifiant = "";
      rayonNeutralisation = "";
      desactivableDistance = "";
      codeDesactivation = "";
      desactivableContact = "";
      divers = "";
    }
    return detected;
  }

  Uint8List cropImage(Uint8List imgBytes, double left, double top, double width, double height) {
    img.Image image = img.decodeImage(imgBytes)!;
    img.Image cropped = img.copyCrop(image, (left * image.width).toInt(), (top * image.height).toInt(), (width * image.width).toInt(), (height * image.height).toInt());
    return Uint8List.fromList(img.encodePng(cropped));
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<bool> runObjectDetection(imageAsBytes) async {
    bool detected = false;
    final stopwatch = Stopwatch()..start();
    objDetect = await objectModel.getImagePrediction(
        imageAsBytes,
        minimumScore: 0.6,
        IOUThershold: 0.6);
    int time = stopwatch.elapsed.inMilliseconds;
    print('runObjectDetection() executed in $time milliseconds');
    totalDetectionTime += time;
    numberOfImageDetected++;
    // objDetect.forEach((element) {
    //   print({"state" : "before correction",
    //     "score": element?.score,
    //     "className": element?.className,
    //     "class": element?.classIndex,
    //     "rect": {
    //       "left": element?.rect.left,
    //       "top": element?.rect.top,
    //       "width": element?.rect.width,
    //       "height": element?.rect.height,
    //       "right": element?.rect.right,
    //       "bottom": element?.rect.bottom,
    //     },
    //   });
      // var temp = element?.rect.top;
      // element?.rect.top = element.rect.left;
      // element?.rect.left = element.rect.bottom;
      // element?.rect.bottom = element.rect.right;
      // element?.rect.right = temp!;

      // // symetry by y axis
      // element?.rect.left = 1 - element.rect.left;  
      // element?.rect.right = 1 - element.rect.right;

      // temp = element?.rect.width;
      // element?.rect.width = element.rect.height;
      // element?.rect.height = temp!;
    // });
    if (objDetect.isNotEmpty) {
      var firstElement = objDetect[0]!;
      croppedImg = cropImage(imageAsBytes, firstElement.rect.left, firstElement.rect.top, firstElement.rect.width, firstElement.rect.height);
      detected = true;
    }

    setState(() {
      // image = File(image.path);
    });
    return detected;
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
    print("Failed to convert YUV to PNG: '${e.message}'.");
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
                                    // child: Image.memory(processedImg ?? Uint8List(0)))),
            // text on the left with cpuFred and cpuTemp and FPS avg
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                color: Colors.black.withOpacity(0.5),
                width: MediaQuery.of(context).size.width*32/90-1,
                child: Text(
                  "CPU freq: $cpuFreq\nCPU temp: $cpuTemp\navg. picture: ${avgPictureTime.round()}ms\navg. detection: ${avgDetectionTime.round()}ms\navg. QR code: ${avgQRCodeTime.round()}ms\navg. FPS: ${(fps*100).round()/100}\nlatitude: $latitude\nlongitude: $longitude\nheading: ${(heading*100000).round()/100000}",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            // text on the right with qrCode information
            // max width = 2/3 
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.5),
                width: MediaQuery.of(context).size.width*58/90-1,
                child: Text(
                  "Nature: $nature\nIdentidiant: $identifiant\nRayon de neutralisation : $rayonNeutralisation\nDésactivable à distance: $desactivableDistance\nCode de désactivation: $codeDesactivation\nDésactivable au contact: $desactivableContact\nDivers: $divers",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            Positioned(
              top: 16*9,
              left: 0,
              child: SizedBox(
                height: 100,
                width: 100,
                child: Image.memory(
                  croppedImg ?? Uint8List(0),
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.search, size: 50, color: Colors.grey);
                  })
              ),
            ),
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
