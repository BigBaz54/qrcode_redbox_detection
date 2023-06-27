import 'package:camera/camera.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';
import 'package:flutter_pytorch/pigeon.dart';
import "dart:io";
import 'package:flutter/material.dart';
import 'home_page.dart';

class ImagePage extends StatefulWidget {

  const ImagePage({required this.image, required this.cameras, required this.objectModels, required this.selectedModel, Key? key}) : super(key: key);
  final File image;
  final List<CameraDescription> cameras;
  final List<ModelObjectDetection> objectModels;
  final ModelObjectDetection selectedModel;

  @override
  State<ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<ImagePage> {
  late List<CameraDescription> cameras = widget.cameras;
  late List<ModelObjectDetection> objectModels = widget.objectModels;
  late ModelObjectDetection selectedModel = widget.selectedModel;
  late File image = widget.image;
  List<ResultObjectDetection?> objDetect = [];

  Future runObjectDetection() async {
    objDetect = await selectedModel.getImagePrediction(
        await image.readAsBytes(),
        minimumScore: 0.3,
        IOUThershold: 0.5);
    objDetect.forEach((element) {
      print({
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
    });
    setState(() {
      // image = File(image.path);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Processed image'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage(cameras: cameras, objectModels: objectModels, selectedModel: selectedModel)),
              );
            },
          ),
        ),
      body: Stack(
        children: [
          LayoutBuilder(builder: (context, constraints) {
            double maxWidth = constraints.maxWidth;
            double maxHeight = constraints.maxHeight;
            return Stack(children: 
            [
              Positioned(
                left: 0,
                top: 0,
                width: maxWidth,
                height: maxHeight,
                child: Container(
                    child: Image.file(
                      image,
                      fit: BoxFit.fill,
                    )),
              )
            ]);
          }),
          renderBoxesWithoutImage(objDetect, boxesColor: Color.fromARGB(255, 68, 255, 0)),
          Container(
            alignment: Alignment.bottomCenter,
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(100, 30)
                ),
                onPressed: () {
                  runObjectDetection();
                },
                child: const Text('Detect'),
              ),)
        ],
      ),
    );
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
}


