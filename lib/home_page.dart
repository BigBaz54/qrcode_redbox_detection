// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'detection_page.dart';
import 'image_page.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';

class HomePage extends StatefulWidget {
  const HomePage({required this.cameras, required this.objectModel, Key? key}) : super(key: key);
  
  @override
  State<HomePage> createState() => _HomePageState();

  final List<CameraDescription> cameras;
  final ModelObjectDetection objectModel;
}

class _HomePageState extends State<HomePage> {
  File? _image;
  final _picker = ImagePicker();
  late List<CameraDescription> cameras = widget.cameras;
  late ModelObjectDetection objectModel = widget.objectModel;
  List<String> robotNames = ['1_TER_BUNKER', '1_AIR_ANAFI-AI', '2_TER_SPOT', '2_AIR_ANAFI', '3_TER_LEO'];
  String robotName = '1_TER_BUNKER';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Red box detection'),
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
                    MaterialPageRoute(builder: (context) => DetectionPage(cameras: cameras, objectModel: objectModel)),
                  );
                },
                child: const Text('Live detection'),
              ),
              // dropdown menu for name selection between 'banana' and 'apple'
              DropdownButton<String>(
                value: robotName,
                icon: const Icon(Icons.arrow_downward),
                iconSize: 24,
                elevation: 16,
                style: const TextStyle(color: Colors.black),
                underline: Container(
                  height: 2,
                  color: const Color.fromARGB(255, 15, 110, 0),
                ),
                onChanged: (String? newValue) {
                  setState(() {
                    robotName = newValue!;
                  });
                },
                items: robotNames
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: const TextStyle(fontSize: 16)),
                  );
                }).toList(),
              ),
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
      MaterialPageRoute(builder: (context) => ImagePage(cameras: cameras, image: _image!, objectModel: objectModel)),
    );
  }

  void cameraButton(BuildContext context) async {
    await pickImage(ImageSource.camera);
    if (_image == null) {
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ImagePage(cameras: cameras, image: _image!, objectModel: objectModel)),
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