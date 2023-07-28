# qrcode_redbox_detection

This is a Flutter app that can be used to detect QR codes and red boxes in the CoHoMa 2 format. It can also be used to detect objects using YOLOv5 and YOLOv8 models. The app can be used to detect objects in a single image or in a live camera feed. The app can also be used to POST the detections to a server.

It was developped for a project at TÉLÉCOM NANCY and later during an internship at the [LORIA](https://www.loria.fr/en/) laboratory, in the [SIMBIOT](https://www.loria.fr/fr/la-recherche/les-equipes/simbiot/) team.
## Installation

### Flutter Setup

1. Install Flutter SDK from [here](https://flutter.dev/docs/get-started/install)
2. Verify Flutter installation by running `flutter doctor` in terminal
3. Run `flutter pub get` in the terminal to get all the dependencies.

### Android Studio Setup (Optional)
If you want to run the app on an emulator, you need to install Android Studio and set it up. Follow the steps below to do so:

1. Install Android Studio from [here](https://developer.android.com/studio)
2. Create an Android Virtual Device (AVD) by following the steps [here](https://developer.android.com/studio/run/managing-avds)
3. Pair the AVD camera with your webcam in the settings of the AVD.

## Project Structure

The models are stored in the `assets/models` folder. The labels for the models are stored in the `assets/labels` folder.

The `lib` folder contains the Dart source code for the app and the `flutter_pytorch` which is a Flutter plugin for PyTorch that I modified to work with YOLOv5 and YOLOv8 models of any size.
The `android` folder contains the Android source code for the app.

## Running the App

To run the app on a **physical device**, connect the device to your computer and run `flutter run` in the terminal. Make sure that USB debugging is enabled on your device.

To run the app on an **emulator** open the AVD Manager in Android Studio and click on the play button next to the AVD you want to run the app on. Then run `flutter run` in the terminal.

## Model Integration

If you want to integrate your own YOLOv5 or YOLOv8 model into the app, follow the steps below:

1. Train your custom model (size must be a multiple of 32, size 640 or less is recommended to have a decent inference speed on mobile devices)
2. Convert the model to TorchScript format using the `export.py` script in the [`yolov5` folder](https://github.com/ultralytics/yolov5). Here is an example command:
```
python export.py --weights your_model.pt --include torchscript --optimize --img 160
```
3. Copy the `your_model.pt` file to the `assets/models` folder of the app
4. Add the labels for your model to the `assets/labels` folder. The labels should be in a text file with one label per line.
5. Add your model in the `loadModels` function in the `main.dart` file. Here is an example:
```dart
objectModels.add(await FlutterPytorch.loadObjectDetectionModel(
  "assets/models/your_model.torchscript", nb_classes, img_width, img_height, "name in the app",
  labelPath: "assets/labels/your_labels.txt"));
```


## Model Inference

Inference can be made on a single image picked from the gallery or captured from the camera. It can also be made live from the camera feed.

## QR Code Scanning

QR code scanning is done using Zebra Crossing (ZXing) library. The library is integrated into the app using the [`flutter_zxing` Flutter plugin](https://pub.dev/packages/flutter_zxing). The text in the QR code is then displayed on the screen if it fits the CoHoMa 2 format.

## POSTing detections to a server

You can POST the detections to the server you want by giving the URL of the server on the home page of the app. The detections are sent in the following format:

```json
{
  "teamName": "team_name",
  "authKey": "auth_key",
  "geolocation": {
    "latitude": "0.0",
    "longitude": "0.0"
  },
  "heading": "180.0",
  "robotName": "robot_name",
  "timestamp": "1690449681"
}
```

## Screenshots
**Home page**:

![image](https://github.com/BigBaz54/qrcode_redbox_detection/assets/96493391/210b573b-029b-4f23-ad9b-a2d7f31296fa)

**Model selection**:

![image](https://github.com/BigBaz54/qrcode_redbox_detection/assets/96493391/4d51acc9-a873-48a9-8308-c4364bcf225a)

**Metrics**:

![metriques](https://github.com/BigBaz54/qrcode_redbox_detection/assets/96493391/7682945f-9f6c-4bcf-876e-1dc8020e7bc2)

**Inference**:

![160](https://github.com/BigBaz54/qrcode_redbox_detection/assets/96493391/5e9eaa90-c23f-45a9-a99b-0709b2736576)

