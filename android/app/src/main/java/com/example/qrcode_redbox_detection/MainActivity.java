package com.example.qrcode_redbox_detection;

import android.graphics.ImageFormat;
import android.graphics.Rect;
import android.graphics.YuvImage;
import android.os.Environment;
import java.io.ByteArrayOutputStream;
import java.io.FileOutputStream;
import java.nio.ByteBuffer;
import java.util.Map;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.example.qrcode_redbox_detection";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            if (call.method.equals("convertToPNG")) {
                                Map<String, Object> args = call.arguments();
                                int width = (Integer) args.get("width");
                                int height = (Integer) args.get("height");
                                ByteBuffer yPlane = ByteBuffer.wrap((byte[]) args.get("yPlane"));
                                ByteBuffer uPlane = ByteBuffer.wrap((byte[]) args.get("uPlane"));
                                ByteBuffer vPlane = ByteBuffer.wrap((byte[]) args.get("vPlane"));
                                int yRowStride = (Integer) args.get("yRowStride");
                                int uvRowStride = (Integer) args.get("uvRowStride");
                                int uvPixelStride = (Integer) args.get("uvPixelStride");

                                byte[] yuvBytes = new byte[width * height * 3 / 2];
                                yPlane.get(yuvBytes, 0, width * height);
                                uPlane.get(yuvBytes, width * height, width * height / 4);
                                vPlane.get(yuvBytes, width * height + width * height / 4, width * height / 4);

                                YuvImage yuvImage = new YuvImage(yuvBytes, ImageFormat.NV21, width, height, null);
                                ByteArrayOutputStream os = new ByteArrayOutputStream();
                                yuvImage.compressToJpeg(new Rect(0, 0, width, height), 100, os);
                                byte[] pngByteArray = os.toByteArray();
                                result.success(pngByteArray);
                            } else {
                                result.notImplemented();
                            }
                        }
                );
    }
}
