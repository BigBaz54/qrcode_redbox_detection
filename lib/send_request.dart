// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

void sendRequest(latitude, longitude, heading, url, teamName, authKey, robotName) async {
    if (latitude == -1 || longitude == -1 || heading == -1) {
      return;
    }
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      print("No internet connection : can't send request");
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
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }