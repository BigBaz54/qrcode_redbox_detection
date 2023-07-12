// Copyright (c) 2020 Facebook, Inc. and its affiliates.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.

package com.aneeqmalik.flutter_pytorch;

import android.graphics.Rect;
import android.util.Log;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.Map;

public class PrePostProcessor {
    // for yolov5 model, no need to apply MEAN and STD
    float[] NO_MEAN_RGB = new float[] {0.0f, 0.0f, 0.0f};
    float[] NO_STD_RGB = new float[] {1.0f, 1.0f, 1.0f};

    int mNumberOfClasses;


    // model output is of size 25200*(num_of_class+5)
    int mOutputRow = 25200; // as decided by the YOLOv5 model for input image of size 640*640
    int mOutputColumn = (mNumberOfClasses+5); // left, top, right, bottom, score and n class probability
    float mScoreThreshold = 0.30f; // score above which a detection is generated
    float mIOUThreshold = 0.30f; // IOU thershold
    int mImageWidth = 640;
    int mImageHeight = 640;
    int mNmsLimit = 15;
    int[] strides = new int[]{8, 16, 32};
    int nbPredictionsPerCellV5 = 3;
    int nbPredictionsPerCellV8 = 1;
    int nbPredictionsTotalV5;
    int nbPredictionsTotalV8;
    int sizeOfPredictionV5 = 5 + mNumberOfClasses;
    int sizeOfPredictionV8 = 4 + mNumberOfClasses;
    String modelType;

    static String[] mClasses;

    PrePostProcessor(){
    }
    PrePostProcessor(int imageWidth,int imageHeight){
        mImageWidth=imageWidth;
        mImageHeight=imageHeight;
    }
    PrePostProcessor(int numberOfClasses,int imageWidth,int imageHeight){
        // to handle different model image size
        strides = new int[]{8, 16, 32};
        nbPredictionsPerCellV5 = 3;
        nbPredictionsPerCellV8 = 1;
        nbPredictionsTotalV5 = 
                imageHeight/strides[0] * imageWidth/strides[0] * nbPredictionsPerCellV5 +
                imageHeight/strides[1] * imageWidth/strides[1] * nbPredictionsPerCellV5 +
                imageHeight/strides[2] * imageWidth/strides[2] * nbPredictionsPerCellV5;
        nbPredictionsTotalV8 =
                imageHeight/strides[0] * imageWidth/strides[0] * nbPredictionsPerCellV8 +
                imageHeight/strides[1] * imageWidth/strides[1] * nbPredictionsPerCellV8 +
                imageHeight/strides[2] * imageWidth/strides[2] * nbPredictionsPerCellV8;
        sizeOfPredictionV5 = 5 + numberOfClasses;
        sizeOfPredictionV8 = 4 + numberOfClasses;
        mImageWidth=imageWidth;
        mImageHeight=imageHeight;
        mNumberOfClasses=numberOfClasses;
    }
    // The two methods nonMaxSuppression and IOU below are ported from https://github.com/hollance/YOLO-CoreML-MPSNNGraph/blob/master/Common/Helpers.swift
    /**
     Removes bounding boxes that overlap too much with other boxes that have
     a higher score.
     - Parameters:
     - boxes: an array of bounding boxes and their scores
     - limit: the maximum number of boxes that will be selected
     - threshold: used to decide whether boxes overlap too much
     */
    ArrayList<Pigeon.ResultObjectDetection> nonMaxSuppression(ArrayList<Pigeon.ResultObjectDetection> boxes) {
        //Log.i("PytorchLitePlugin","first score before sorting  "+boxes.get(0).getScore());
        // Do an argsort on the confidence scores, from high to low.
        Collections.sort(boxes,
                (o2, o1) -> o1.getScore().compareTo(o2.getScore()));
        // Log.i("PytorchLitePlugin","first score after sorting  "+boxes.get(0).getScore());
        ArrayList<Pigeon.ResultObjectDetection> selected = new ArrayList<>();
        boolean[] active = new boolean[boxes.size()];
        Arrays.fill(active, true);
        int numActive = active.length;

        // The algorithm is simple: Start with the box that has the highest score.
        // Remove any remaining boxes that overlap it more than the given threshold
        // amount. If there are any boxes left (i.e. these did not overlap with any
        // previous boxes), then repeat this procedure, until no more boxes remain
        // or the limit has been reached.
        boolean done = false;
        for (int i=0; i<boxes.size() && !done; i++) {
            if (active[i]) {
                Pigeon.ResultObjectDetection boxA = boxes.get(i);
                selected.add(boxA);
                if (selected.size() >= mNmsLimit) break;

                for (int j=i+1; j<boxes.size(); j++) {
                    if (active[j]) {
                        Pigeon.ResultObjectDetection boxB = boxes.get(j);
                        if (IOU(boxA.getRect(), boxB.getRect()) > mIOUThreshold) {
                            active[j] = false;
                            numActive -= 1;
                            if (numActive <= 0) {
                                done = true;
                                break;
                            }
                        }
                    }
                }
            }
        }
        Log.i("PytorchLitePlugin","result length after processing "+String.valueOf(selected.size()));

        return selected;
    }

    /**
     Computes intersection-over-union overlap between two bounding boxes.
     */
    Double IOU(Pigeon.PyTorchRect a, Pigeon.PyTorchRect b) {
        Double areaA = ((a.getRight() - a.getLeft()) * (a.getBottom() - a.getTop()));
        if (areaA <= 0.0) return 0.0;

        Double areaB =  ((b.getRight() - b.getLeft()) * (b.getBottom() - b.getTop()));
        if (areaB <= 0.0) return 0.0;

        Double intersectionMinX =  Math.max(a.getLeft(), b.getLeft());
        Double intersectionMinY =  Math.max(a.getTop(), b.getTop());
        Double intersectionMaxX = Math.min(a.getRight(), b.getRight());
        Double intersectionMaxY = Math.min(a.getBottom(), b.getBottom());
        Double intersectionArea = Math.max(intersectionMaxY - intersectionMinY, 0) *
                Math.max(intersectionMaxX - intersectionMinX, 0);
        return intersectionArea / (areaA + areaB - intersectionArea);
    }
    public static Double getFloatAsDouble(Float fValue) {
        return Double.valueOf(fValue.toString());
    }
    ArrayList<Pigeon.ResultObjectDetection> outputsToNMSPredictions(float[] outputs) {
        // Log.i("PytorchLitePlugin","output length " + String.valueOf(outputs.length));
        // for (int i = 2000; i < outputs.length; i++) {

        //     Log.i("PytorchLitePlugin","output " + String.valueOf(i) + " " + String.valueOf(outputs[i]));
        // }
        // Log.i("PytorchLitePlugin","number of detection (predicted) " + String.valueOf(nbPredictionsTotal));
        // Log.i("PytorchLitePlugin","number of detection (actual) " + String.valueOf(outputs.length / sizeOfPrediction));
        Log.i("PytorchLitePlugin","output length " + String.valueOf(outputs.length));
        Log.i("PytorchLitePlugin","number of detection V5 " + String.valueOf(nbPredictionsTotalV5));
        Log.i("PytorchLitePlugin","size of predictions V5" + String.valueOf(sizeOfPredictionV5));
        Log.i("PytorchLitePlugin","number of detection V8 " + String.valueOf(nbPredictionsTotalV8));
        Log.i("PytorchLitePlugin","size of predictions V8" + String.valueOf(sizeOfPredictionV8));
        if (nbPredictionsTotalV5 * sizeOfPredictionV5 == outputs.length) {
            modelType = "v5";
        } else if (nbPredictionsTotalV8 * sizeOfPredictionV8 == outputs.length) {
            modelType = "v8";
        } else {
            modelType = "unknown";
        }
        ArrayList<Pigeon.ResultObjectDetection> results = new ArrayList<>();
        if (modelType.equals("v5")) {
            // v5 models (v8-pose has sizeOfPrediction = 56 and nbPredictionsPerCell = 1)
            for (int i = 0; i < nbPredictionsTotalV5; i++) {
                if (outputs[i * sizeOfPredictionV5 + 4] > mScoreThreshold) {
                    float x = outputs[i * sizeOfPredictionV5];
                    float y = outputs[i * sizeOfPredictionV5 + 1];
                    float w = outputs[i * sizeOfPredictionV5 + 2];
                    float h = outputs[i * sizeOfPredictionV5 + 3];
    
                    float left =  (x - w/2);
                    float top =  (y - h/2);
                    float right =  (x + w/2);
                    float bottom = (y + h/2);
    
                    float max = outputs[i* sizeOfPredictionV5 + 5]; // 5 is the offset of the first class.
                    int cls = 0;
                    for (int j = 0; j < mNumberOfClasses; j++) {
                        if (outputs[i * sizeOfPredictionV5 + 5 + j] > max) {
                            max = outputs[i * sizeOfPredictionV5 + 5 + j];
                            cls = j;
                        }
                    }
    
                    Pigeon.PyTorchRect rect = new Pigeon.PyTorchRect.Builder().setLeft(
                            getFloatAsDouble(left/mImageWidth)
                    ).setTop(
                            getFloatAsDouble(top/mImageHeight)
                    ).setWidth(
                            getFloatAsDouble(w/mImageWidth)
                    ).setHeight(
                            getFloatAsDouble(h/mImageHeight)
                    ).setBottom(
                            getFloatAsDouble(bottom/mImageHeight)
                    ).setRight(
                            getFloatAsDouble(right/mImageWidth)
                    ).build();
                    Pigeon.ResultObjectDetection result = new Pigeon.ResultObjectDetection.Builder().setClassIndex((long) cls).setScore(getFloatAsDouble(outputs[i * sizeOfPredictionV5 + 4])).setRect(rect).build();
    
                    results.add(result);
                }
            }
        } else if (modelType.equals("v8")) {
            // v8 models
            for (int i = 0; i < nbPredictionsTotalV8; i++) {
                float max = outputs[4 * nbPredictionsTotalV8 + i]; // the first class scores are between index 4*nbPredictionsTotalV8 and 5*nbPredictionsTotalV8
                int cls = 0;
                for (int j = 0; j < mNumberOfClasses; j++) {
                    if (outputs[(4 + j) * nbPredictionsTotalV8 + i] > max) {
                        max = outputs[(4 + j) * nbPredictionsTotalV8 + i];
                        cls = j;
                    }
                }

                // the max of the class scores is used as the score of the detection.
                if (max > mScoreThreshold) {
                    // coordinates of the center of the box
                    float x = outputs[i];
                    float y = outputs[i + 1 * nbPredictionsTotalV8];

                    // width and height of the box
                    float w = outputs[i + 2 * nbPredictionsTotalV8];
                    float h = outputs[i + 3 * nbPredictionsTotalV8];
    
                    // coordinates of the corners of the box
                    float left =  (x - w/2);
                    float top =  (y - h/2);
                    float right =  (x + w/2);
                    float bottom = (y + h/2);
    
                    Pigeon.PyTorchRect rect = new Pigeon.PyTorchRect.Builder().setLeft(
                            getFloatAsDouble(left/mImageWidth)
                    ).setTop(
                            getFloatAsDouble(top/mImageHeight)
                    ).setWidth(
                            getFloatAsDouble(w/mImageWidth)
                    ).setHeight(
                            getFloatAsDouble(h/mImageHeight)
                    ).setBottom(
                            getFloatAsDouble(bottom/mImageHeight)
                    ).setRight(
                            getFloatAsDouble(right/mImageWidth)
                    ).build();
                    Pigeon.ResultObjectDetection result = new Pigeon.ResultObjectDetection.Builder().setClassIndex((long) cls).setScore(getFloatAsDouble(max)).setRect(rect).build();
    
                    results.add(result);
                }
            }
        } else {
            Log.i("PytorchLitePlugin","model type not supported");
        }


        // Log.i("PytorchLitePlugin","result length before processing "+String.valueOf(results.size()));
        return nonMaxSuppression(results);
    }

}
