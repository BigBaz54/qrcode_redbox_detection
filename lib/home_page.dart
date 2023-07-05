// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'detection_page.dart';
import 'image_page.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';

class HomePage extends StatefulWidget {
  const HomePage({required this.cameras, required this.objectModels, Key? key, required this.selectedModel}) : super(key: key);
  
  @override
  State<HomePage> createState() => _HomePageState();

  final List<CameraDescription> cameras;
  final List<ModelObjectDetection> objectModels;
  final ModelObjectDetection selectedModel;
}

class _HomePageState extends State<HomePage> {
  File? _image;
  final _picker = ImagePicker();
  late List<CameraDescription> cameras = widget.cameras;
  late List<ModelObjectDetection> objectModels = widget.objectModels;
  late ModelObjectDetection selectedModel = objectModels[0];
  bool readQrcode = false;
  bool sendRequests = false;
  bool detectionOverview = false;
  String robotName = '1_TER_BUNKER';
  String url = 'https://webhook.site/ae72f93c-0eef-4f9e-9f7f-9aaab19920a8';
  String authKey = '';
  String teamName = 'test';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Red box detection'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 0.0),
            child: Image.asset(
              'assets/img/logo_loria.jpg',
              fit: BoxFit.contain,
              height: 32,
            ),
          ),
        ],
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color.fromARGB(255, 15, 110, 0),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(180, 30),
                ),
                onPressed: () {
                  cameraButton(context);
                },
                child: const Text('Take a picture'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(180, 30),
                ),
                onPressed: () {
                  galleryButton(context);
                },
                child: const Text('Chose from gallery'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(180, 30),
                  backgroundColor: const Color.fromARGB(255, 15, 110, 0)
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => DetectionPage(cameras: cameras, objectModels: objectModels, selectedModel: selectedModel, readQrcode: readQrcode, sendRequests: sendRequests, detectionOverview: detectionOverview, robotName: robotName, url: url, authKey: authKey, teamName: teamName,)),
                  );
                },
                child: const Text('Live detection'),
              ),
              SizedBox(width: 180,
              child: Column(children: [
                TextField(
                  onChanged: (text) {
                    teamName = text;
                  },
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Team name',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  ),
                ),
                const SizedBox(height: 5),
                TextField(
                  onChanged: (text) {
                    robotName = text;
                  },
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Robot name',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  ),
                ),
                const SizedBox(height: 5),
                TextField(
                  onChanged: (text) {
                    url = text;
                  },
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'URL',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  ),
                ),
                const SizedBox(height: 5),
                TextField(
                  onChanged: (text) {
                    authKey = text;
                  },
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Auth key',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  ),
                ),
                // model selection
                const SizedBox(height: 5),
                DropdownButton<ModelObjectDetection>(
                  value: selectedModel,
                  onChanged: (ModelObjectDetection? newValue) {
                    setState(() {
                      selectedModel = newValue!;
                    });
                  },
                  items: objectModels.map((ModelObjectDetection model) {
                    return DropdownMenuItem<ModelObjectDetection>(
                      value: model,
                      child: Text(model.name),
                    );
                  }).toList(),
                ),
                // 3 centered Checkboxes to enable/disable QR code reading, renquest sending and detection overview
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('   Read QR codes'),
                    Checkbox(
                      value: readQrcode,
                      onChanged: (bool? value) {
                        setState(() {
                          readQrcode = value!;
                        });
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('   Send requests'),
                    Checkbox(
                      value: sendRequests,
                      onChanged: (bool? value) {
                        setState(() {
                          sendRequests = value!;
                        });
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('   Detection overview'),
                    Checkbox(
                      value: detectionOverview,
                      onChanged: (bool? value) {
                        setState(() {
                          detectionOverview = value!;
                        });
                      },
                    ),
                  ],
                ),
              ]),)
            ],
          ),
        ),
      ),
    );
  }

  void galleryButton(BuildContext context) async {
    await pickImage(ImageSource.gallery);
    if (_image == null) {
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ImagePage(cameras: cameras, image: _image!, objectModels: objectModels, selectedModel: selectedModel)),
    );
  }

  void cameraButton(BuildContext context) async {
    await pickImage(ImageSource.camera);
    if (_image == null) {
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ImagePage(cameras: cameras, image: _image!, objectModels: objectModels, selectedModel: selectedModel)),
    );
  }
  
  Future<void> pickImage(ImageSource source) async {
    final image = await _picker.pickImage(source: source);
    if (image != null && (image.path.endsWith('.jpg') || image.path.endsWith('.jpeg') || image.path.endsWith('.png'))) {
      _image = File(image.path);
    }
  }

  Future<void> getLostData() async {
  final LostDataResponse response =
      await _picker.retrieveLostData();
  if (response.isEmpty) {
    print("Retrieved data is empty.");
    return;
  }
  if (response.files != null) {
    for (final XFile file in response.files!) {
      print("Retrieved lost data: ${file.path}");
      _image = File(file.path);
    }
  } else {
    print("Error retrieving lost data: ${response.exception}");
  }
}
}