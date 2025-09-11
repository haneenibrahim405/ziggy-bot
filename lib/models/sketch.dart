import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class Sketch {
  List<Offset> points;
  Color strokeColor;
  double strokeSize;
  bool isEraser;
  int brushmode;
  double estrokeSize;
  String? id;

  Sketch({
    required this.points,
    this.strokeColor = Colors.black,
    this.strokeSize = 4.0,
    this.estrokeSize = 10.0,
    this.isEraser = false,
    this.brushmode = 1,
    this.id,
  });
}