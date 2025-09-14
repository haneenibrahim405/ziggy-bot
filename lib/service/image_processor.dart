import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;

import 'package:ziggy/service/prepare_points.dart';

class ImageProcessor {
  // Configuration parameters
  static const int MAX_IMAGE_SIZE = 600;
  static const double DOUGLAS_PEUCKER_TOLERANCE = 2.5;
  static const int MIN_STROKE_LENGTH = 8;
  static const int MAX_STROKES = 10000;
  static const int MORPHOLOGY_KERNEL_SIZE = 2;

  /// Process image directly from Image object - optimized for performance
  static Future<ImageProcessingResult> processImageDirect(img.Image? image) async {
    try {
      if (image == null) {
        throw Exception('Image is null');
      }

      print('🔬 Starting advanced image processing...');

      // تحويل Image إلى bytes
      Uint8List imageBytes = Uint8List.fromList(img.encodePng(image));

      // معالجة في isolate
      ImageProcessingResult result = await compute(_processImageIsolate, imageBytes);

      print('✅ Processing complete: ${result.strokes.length} strokes extracted');
      return result;

    } catch (e) {
      print('❌ Error in image processing: $e');
      return ImageProcessingResult.error(e.toString());
    }
  }

  /// Main processing function - optimized for performance
  static Future<ImageProcessingResult> processImage(File imageFile) async {
    try {
      print('🔬 Starting advanced image processing...');

      // Read and decode image
      Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Process in isolate for better performance
      ImageProcessingResult result = await compute(_processImageIsolate, imageBytes);

      print('✅ Processing complete: ${result.strokes.length} strokes extracted');
      return result;

    } catch (e) {
      print('❌ Error in image processing: $e');
      return ImageProcessingResult.error(e.toString());
    }
  }

  /// Heavy processing in isolate
  static ImageProcessingResult _processImageIsolate(Uint8List imageBytes) {
    try {
      // Decode image in isolate
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Failed to decode image in isolate');

      // Step 1: Resize if needed
      image = _resizeIfNeeded(image);
      print('Image resized to: ${image.width}x${image.height}');

      // Step 2: Convert to grayscale
      img.Image grayImage = img.grayscale(image);

      // Step 3: Apply optimized threshold
      List<List<int>> binary = _optimizedThreshold(grayImage);

      // Step 4: Morphological operations
      binary = _morphologicalOperations(binary);

      // Step 5: Extract strokes using improved algorithm
      List<List<Point>> strokes = _extractStrokesAdvanced(binary);

      // Step 6: Optimize strokes
      List<List<Point>> optimizedStrokes = _optimizeStrokes(strokes);

      // Step 7: Create visualization
      String processedImageBase64 = _createVisualization(image, optimizedStrokes);

      // Step 8: Calculate statistics
      Map<String, dynamic> stats = _calculateDetailedStats(strokes, optimizedStrokes);

      return ImageProcessingResult(
        strokes: optimizedStrokes,
        processedImageBase64: processedImageBase64,
        stats: stats,
        success: true,
      );

    } catch (e) {
      print('Error in isolate: $e');
      return ImageProcessingResult.error(e.toString());
    }
  }

  /// Resize image if too large
  static img.Image _resizeIfNeeded(img.Image image) {
    if (image.width <= MAX_IMAGE_SIZE && image.height <= MAX_IMAGE_SIZE) {
      return image;
    }

    double scale = math.min(
      MAX_IMAGE_SIZE / image.width,
      MAX_IMAGE_SIZE / image.height,
    );

    int newWidth = (image.width * scale).round();
    int newHeight = (image.height * scale).round();

    return img.copyResize(image, width: newWidth, height: newHeight);
  }

  /// Optimized threshold using Otsu's method
  static List<List<int>> _optimizedThreshold(img.Image grayImage) {
    int width = grayImage.width;
    int height = grayImage.height;

    // Calculate histogram
    List<int> histogram = List.filled(256, 0);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int gray = grayImage.getPixel(x, y).luminance.round();
        histogram[gray]++;
      }
    }

    // Find optimal threshold using Otsu's method
    int threshold = _calculateOtsuThreshold(histogram, width * height);

    // Apply threshold
    List<List<int>> binary = List.generate(height, (i) => List.filled(width, 0));
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int gray = grayImage.getPixel(x, y).luminance.round();
        binary[y][x] = gray < threshold ? 1 : 0;
      }
    }

    return binary;
  }

  /// Calculate Otsu threshold
  static int _calculateOtsuThreshold(List<int> histogram, int totalPixels) {
    double sum = 0;
    for (int i = 0; i < 256; i++) {
      sum += i * histogram[i];
    }

    double sumB = 0;
    int wB = 0;
    int wF = 0;
    double varMax = 0;
    int threshold = 0;

    for (int i = 0; i < 256; i++) {
      wB += histogram[i];
      if (wB == 0) continue;

      wF = totalPixels - wB;
      if (wF == 0) break;

      sumB += i * histogram[i];
      double mB = sumB / wB;
      double mF = (sum - sumB) / wF;

      double varBetween = wB * wF * (mB - mF) * (mB - mF);

      if (varBetween > varMax) {
        varMax = varBetween;
        threshold = i;
      }
    }

    return threshold;
  }

  /// Morphological operations (closing + opening)
  static List<List<int>> _morphologicalOperations(List<List<int>> binary) {
    // Closing: fill gaps
    List<List<int>> closed = _dilate(binary, MORPHOLOGY_KERNEL_SIZE);
    closed = _erode(closed, MORPHOLOGY_KERNEL_SIZE);

    // Opening: remove noise
    List<List<int>> opened = _erode(closed, 1);
    opened = _dilate(opened, 1);

    return opened;
  }

  static List<List<int>> _dilate(List<List<int>> image, int kernelSize) {
    int height = image.length;
    int width = image[0].length;
    List<List<int>> result = List.generate(height, (i) => List.from(image[i]));
    int half = kernelSize ~/ 2;

    for (int y = half; y < height - half; y++) {
      for (int x = half; x < width - half; x++) {
        if (image[y][x] == 1) {
          for (int dy = -half; dy <= half; dy++) {
            for (int dx = -half; dx <= half; dx++) {
              result[y + dy][x + dx] = 1;
            }
          }
        }
      }
    }

    return result;
  }

  static List<List<int>> _erode(List<List<int>> image, int kernelSize) {
    int height = image.length;
    int width = image[0].length;
    List<List<int>> result = List.generate(height, (i) => List.filled(width, 0));
    int half = kernelSize ~/ 2;

    for (int y = half; y < height - half; y++) {
      for (int x = half; x < width - half; x++) {
        bool allSet = true;

        for (int dy = -half; dy <= half && allSet; dy++) {
          for (int dx = -half; dx <= half && allSet; dx++) {
            if (image[y + dy][x + dx] == 0) {
              allSet = false;
            }
          }
        }

        result[y][x] = allSet ? 1 : 0;
      }
    }

    return result;
  }

  /// Advanced stroke extraction with skeletonization
  static List<List<Point>> _extractStrokesAdvanced(List<List<int>> binary) {
    // Apply Zhang-Suen thinning
    List<List<int>> skeleton = _zhangSuenThinning(binary);

    // Find connected components in skeleton
    return _traceSkeletonPaths(skeleton);
  }

  /// Zhang-Suen thinning algorithm
  static List<List<int>> _zhangSuenThinning(List<List<int>> binary) {
    int height = binary.length;
    int width = binary[0].length;
    List<List<int>> skeleton = List.generate(height, (i) => List.from(binary[i]));

    bool changed = true;
    int iterations = 0;

    while (changed && iterations < 20) {
      changed = false;
      iterations++;

      // Sub-iteration 1
      List<List<bool>> toDelete1 = List.generate(height, (i) => List.filled(width, false));

      for (int y = 1; y < height - 1; y++) {
        for (int x = 1; x < width - 1; x++) {
          if (skeleton[y][x] == 1 && _zhangSuenCondition1(skeleton, x, y)) {
            toDelete1[y][x] = true;
          }
        }
      }

      for (int y = 1; y < height - 1; y++) {
        for (int x = 1; x < width - 1; x++) {
          if (toDelete1[y][x]) {
            skeleton[y][x] = 0;
            changed = true;
          }
        }
      }

      // Sub-iteration 2
      List<List<bool>> toDelete2 = List.generate(height, (i) => List.filled(width, false));

      for (int y = 1; y < height - 1; y++) {
        for (int x = 1; x < width - 1; x++) {
          if (skeleton[y][x] == 1 && _zhangSuenCondition2(skeleton, x, y)) {
            toDelete2[y][x] = true;
          }
        }
      }

      for (int y = 1; y < height - 1; y++) {
        for (int x = 1; x < width - 1; x++) {
          if (toDelete2[y][x]) {
            skeleton[y][x] = 0;
            changed = true;
          }
        }
      }
    }

    return skeleton;
  }

  static bool _zhangSuenCondition1(List<List<int>> image, int x, int y) {
    List<int> neighbors = [
      image[y-1][x], image[y-1][x+1], image[y][x+1], image[y+1][x+1],
      image[y+1][x], image[y+1][x-1], image[y][x-1], image[y-1][x-1]
    ];

    int B = neighbors.fold(0, (sum, val) => sum + val);
    if (B < 2 || B > 6) return false;

    int A = 0;
    for (int i = 0; i < 8; i++) {
      if (neighbors[i] == 0 && neighbors[(i + 1) % 8] == 1) A++;
    }
    if (A != 1) return false;

    return (neighbors[0] * neighbors[2] * neighbors[4] == 0) &&
        (neighbors[2] * neighbors[4] * neighbors[6] == 0);
  }

  static bool _zhangSuenCondition2(List<List<int>> image, int x, int y) {
    List<int> neighbors = [
      image[y-1][x], image[y-1][x+1], image[y][x+1], image[y+1][x+1],
      image[y+1][x], image[y+1][x-1], image[y][x-1], image[y-1][x-1]
    ];

    int B = neighbors.fold(0, (sum, val) => sum + val);
    if (B < 2 || B > 6) return false;

    int A = 0;
    for (int i = 0; i < 8; i++) {
      if (neighbors[i] == 0 && neighbors[(i + 1) % 8] == 1) A++;
    }
    if (A != 1) return false;

    return (neighbors[0] * neighbors[2] * neighbors[6] == 0) &&
        (neighbors[0] * neighbors[4] * neighbors[6] == 0);
  }

  /// Trace skeleton paths
  static List<List<Point>> _traceSkeletonPaths(List<List<int>> skeleton) {
    int height = skeleton.length;
    int width = skeleton[0].length;
    List<List<bool>> visited = List.generate(height, (i) => List.filled(width, false));
    List<List<Point>> paths = [];

    // Find endpoints first
    List<Point> endpoints = [];
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        if (skeleton[y][x] == 1) {
          int neighbors = 0;
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              if (skeleton[y + dy][x + dx] == 1) neighbors++;
            }
          }
          if (neighbors == 1) {
            endpoints.add(Point(x.toDouble(), y.toDouble()));
          }
        }
      }
    }

    // Trace from endpoints
    for (Point endpoint in endpoints) {
      int x = endpoint.x.round();
      int y = endpoint.y.round();

      if (!visited[y][x] && skeleton[y][x] == 1) {
        List<Point> path = _tracePath(skeleton, visited, x, y);
        if (path.length >= MIN_STROKE_LENGTH) {
          paths.add(path);
        }
      }
    }

    // Handle remaining components
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (skeleton[y][x] == 1 && !visited[y][x]) {
          List<Point> path = _tracePath(skeleton, visited, x, y);
          if (path.length >= MIN_STROKE_LENGTH) {
            paths.add(path);
          }
        }
      }
    }

    return paths;
  }

  static List<Point> _tracePath(List<List<int>> skeleton, List<List<bool>> visited, int startX, int startY) {
    List<Point> path = [];
    int currentX = startX;
    int currentY = startY;

    while (currentX >= 0 && currentX < skeleton[0].length &&
        currentY >= 0 && currentY < skeleton.length &&
        skeleton[currentY][currentX] == 1 && !visited[currentY][currentX]) {

      visited[currentY][currentX] = true;
      path.add(Point(currentX.toDouble(), currentY.toDouble()));

      // Find next unvisited neighbor
      Point? next = _findNextPixel(skeleton, visited, currentX, currentY);
      if (next == null) break;

      currentX = next.x.round();
      currentY = next.y.round();
    }

    return path;
  }

  static Point? _findNextPixel(List<List<int>> skeleton, List<List<bool>> visited, int x, int y) {
    // Priority: straight directions first, then diagonals
    List<List<int>> directions = [
      [0, -1], [1, 0], [0, 1], [-1, 0],
      [1, -1], [1, 1], [-1, 1], [-1, -1]
    ];

    for (List<int> dir in directions) {
      int nx = x + dir[0];
      int ny = y + dir[1];

      if (nx >= 0 && nx < skeleton[0].length && ny >= 0 && ny < skeleton.length &&
          skeleton[ny][nx] == 1 && !visited[ny][nx]) {
        return Point(nx.toDouble(), ny.toDouble());
      }
    }

    return null;
  }

  /// Optimize strokes using Douglas-Peucker
  static List<List<Point>> _optimizeStrokes(List<List<Point>> strokes) {
    List<List<Point>> optimized = [];

    for (List<Point> stroke in strokes) {
      if (stroke.length >= 3) {
        List<Point> simplified = _douglasPeucker(stroke, DOUGLAS_PEUCKER_TOLERANCE);
        if (simplified.length >= 2) {
          optimized.add(simplified);
        }
      }
    }

    // Sort by length and quality
    optimized.sort((a, b) {
      double scoreA = a.length * _calculateSmoothness(a);
      double scoreB = b.length * _calculateSmoothness(b);
      return scoreB.compareTo(scoreA);
    });

    // Keep best strokes
    if (optimized.length > MAX_STROKES) {
      optimized = optimized.sublist(0, MAX_STROKES);
    }

    return optimized;
  }

  static List<Point> _douglasPeucker(List<Point> points, double tolerance) {
    if (points.length <= 2) return points;

    double maxDistance = 0;
    int maxIndex = 0;

    for (int i = 1; i < points.length - 1; i++) {
      double distance = _pointToLineDistance(points[i], points.first, points.last);
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    if (maxDistance > tolerance) {
      List<Point> left = _douglasPeucker(points.sublist(0, maxIndex + 1), tolerance);
      List<Point> right = _douglasPeucker(points.sublist(maxIndex), tolerance);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [points.first, points.last];
    }
  }

  static double _pointToLineDistance(Point point, Point lineStart, Point lineEnd) {
    double dx = lineEnd.x - lineStart.x;
    double dy = lineEnd.y - lineStart.y;

    if (dx == 0 && dy == 0) {
      return point.distanceTo(lineStart);
    }

    double numerator = (dy * point.x - dx * point.y + lineEnd.x * lineStart.y - lineEnd.y * lineStart.x).abs();
    double denominator = math.sqrt(dx * dx + dy * dy);

    return numerator / denominator;
  }

  static double _calculateSmoothness(List<Point> stroke) {
    if (stroke.length < 3) return 1.0;

    double totalAngleChange = 0;
    int count = 0;

    for (int i = 1; i < stroke.length - 1; i++) {
      Point p1 = stroke[i - 1];
      Point p2 = stroke[i];
      Point p3 = stroke[i + 1];

      double angle1 = math.atan2(p2.y - p1.y, p2.x - p1.x);
      double angle2 = math.atan2(p3.y - p2.y, p3.x - p2.x);

      double angleDiff = (angle2 - angle1).abs();
      if (angleDiff > math.pi) angleDiff = 2 * math.pi - angleDiff;

      totalAngleChange += angleDiff;
      count++;
    }

    double avgAngleChange = count > 0 ? totalAngleChange / count : 0;
    return math.max(0.0, 1.0 - avgAngleChange / math.pi);
  }

  /// Create visualization
  static String _createVisualization(img.Image original, List<List<Point>> strokes) {
    try {
      img.Image result = img.Image(width: original.width, height: original.height);
      img.fill(result, color: img.ColorRgb8(255, 255, 255));

      List<int> colors = [
        0xFF0000, 0x00AA00, 0x0000FF, 0xFFAA00,
        0xFF00AA, 0x00AAFF, 0xAA00FF, 0xFFAA55,
      ];

      for (int i = 0; i < strokes.length; i++) {
        int color = colors[i % colors.length];
        List<Point> stroke = strokes[i];

        // Draw stroke as connected lines
        for (int j = 1; j < stroke.length; j++) {
          _drawLine(result, stroke[j-1], stroke[j], color);
        }

        // Mark endpoints
        if (stroke.isNotEmpty) {
          _drawCircle(result, stroke.first, 3, 0x00FF00);
          _drawCircle(result, stroke.last, 3, 0xFF0000);
        }
      }

      Uint8List pngBytes = Uint8List.fromList(img.encodePng(result));
      return base64Encode(pngBytes);

    } catch (e) {
      print('Error creating visualization: $e');
      img.Image fallback = img.Image(width: 200, height: 200);
      img.fill(fallback, color: img.ColorRgb8(240, 240, 240));
      Uint8List fallbackBytes = Uint8List.fromList(img.encodePng(fallback));
      return base64Encode(fallbackBytes);
    }
  }

  static void _drawLine(img.Image image, Point p1, Point p2, int color) {
    int x0 = p1.x.round().clamp(0, image.width - 1);
    int y0 = p1.y.round().clamp(0, image.height - 1);
    int x1 = p2.x.round().clamp(0, image.width - 1);
    int y1 = p2.y.round().clamp(0, image.height - 1);

    int dx = (x1 - x0).abs();
    int dy = (y1 - y0).abs();
    int x = x0;
    int y = y0;
    int xInc = x0 < x1 ? 1 : -1;
    int yInc = y0 < y1 ? 1 : -1;
    int error = dx - dy;

    dx *= 2;
    dy *= 2;

    while (true) {
      if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
        try {
          image.setPixel(x, y, img.ColorRgb8(
            (color >> 16) & 0xFF,
            (color >> 8) & 0xFF,
            color & 0xFF,
          ));
        } catch (e) {
          // Ignore pixel errors
        }
      }

      if (x == x1 && y == y1) break;

      if (error > 0) {
        x += xInc;
        error -= dy;
      } else {
        y += yInc;
        error += dx;
      }
    }
  }

  static void _drawCircle(img.Image image, Point center, int radius, int color) {
    int centerX = center.x.round().clamp(0, image.width - 1);
    int centerY = center.y.round().clamp(0, image.height - 1);

    for (int dx = -radius; dx <= radius; dx++) {
      for (int dy = -radius; dy <= radius; dy++) {
        if (dx * dx + dy * dy <= radius * radius) {
          int x = (centerX + dx).clamp(0, image.width - 1);
          int y = (centerY + dy).clamp(0, image.height - 1);

          try {
            image.setPixel(x, y, img.ColorRgb8(
              (color >> 16) & 0xFF,
              (color >> 8) & 0xFF,
              color & 0xFF,
            ));
          } catch (e) {
            // Ignore pixel errors
          }
        }
      }
    }
  }

  /// Calculate detailed statistics
  static Map<String, dynamic> _calculateDetailedStats(List<List<Point>> rawStrokes, List<List<Point>> optimizedStrokes) {
    double totalLength = 0.0;
    int totalPoints = 0;

    for (List<Point> stroke in optimizedStrokes) {
      totalPoints += stroke.length;
      for (int i = 1; i < stroke.length; i++) {
        totalLength += stroke[i-1].distanceTo(stroke[i]);
      }
    }

    return {
      'rawStrokes': rawStrokes.length,
      'optimizedStrokes': optimizedStrokes.length,
      'totalPoints': totalPoints,
      'totalLength': totalLength.round(),
      'avgStrokeLength': optimizedStrokes.isNotEmpty ? (totalLength / optimizedStrokes.length).round() : 0,
      'reductionPercent': rawStrokes.isNotEmpty
          ? ((rawStrokes.length - optimizedStrokes.length) / rawStrokes.length * 100).round()
          : 0,
    };
  }

  /// Convert to ESP format with connected path (single start point)
  /// Convert strokes to ESP format with stepper motor commands
  static List<Map<String, dynamic>> convertToESPFormat(List<List<Point>> strokes) {
    // Convert to connected path first
    List<Map<String, dynamic>> connectedPath = _convertConnectedPath(strokes);

    if (connectedPath.isEmpty) return [];

    // Extract the actual path points
    List<Map<String, dynamic>> pathPoints = List<Map<String, dynamic>>.from(
        connectedPath.first['connectedPath']
    );

    // Convert to stepper commands
    List<Map<String, dynamic>> stepperCommands = StepperMotorConverter.convertToStepperCommands(pathPoints);

    // Format for ESP
    return [StepperMotorConverter.formatForESP(stepperCommands)];
  }

  /// Convert as separate strokes (original method)
  static List<Map<String, dynamic>> _convertSeparateStrokes(List<List<Point>> strokes) {
    return strokes.map((stroke) {
      return {
        'points': stroke.map((point) => {
          'x': point.x.round(),
          'y': point.y.round(),
        }).toList(),
        'length': stroke.length,
        'totalDistance': _calculateStrokeLength(stroke).round(),
        'type': 'separate_stroke',
      };
    }).toList();
  }

  /// Convert as connected path starting from single point
  static List<Map<String, dynamic>> _convertConnectedPath(List<List<Point>> strokes) {
    if (strokes.isEmpty) return [];

    // Find the top-left starting point
    Point startPoint = _findTopLeftPoint(strokes);
    print('🎯 Starting point: (${startPoint.x}, ${startPoint.y})');

    // Create connected path
    List<Map<String, dynamic>> connectedPath = [];
    List<List<Point>> remainingStrokes = List.from(strokes);
    Point currentPosition = startPoint;

    // Add starting position
    connectedPath.add({
      'x': startPoint.x.round(),
      'y': startPoint.y.round(),
      'type': 'start',
      'penDown': false,
    });

    while (remainingStrokes.isNotEmpty) {
      // Find closest stroke to current position
      int closestIndex = _findClosestStrokeIndex(currentPosition, remainingStrokes);
      List<Point> nextStroke = remainingStrokes[closestIndex];

      // Determine which end of the stroke is closer
      bool useReverse = _shouldReverseStroke(currentPosition, nextStroke);
      if (useReverse) {
        nextStroke = nextStroke.reversed.toList();
      }

      // Move to stroke start (pen up)
      connectedPath.add({
        'x': nextStroke.first.x.round(),
        'y': nextStroke.first.y.round(),
        'type': 'move',
        'penDown': false,
      });

      // Draw the stroke (pen down)
      for (int i = 0; i < nextStroke.length; i++) {
        connectedPath.add({
          'x': nextStroke[i].x.round(),
          'y': nextStroke[i].y.round(),
          'type': i == 0 ? 'stroke_start' : 'stroke_point',
          'penDown': true,
        });
      }

      currentPosition = nextStroke.last;
      remainingStrokes.removeAt(closestIndex);
    }

    print('Connected path: ${connectedPath.length} points');

    return [{
      'connectedPath': connectedPath,
      'totalPoints': connectedPath.length,
      'startPoint': {'x': startPoint.x.round(), 'y': startPoint.y.round()},
      'type': 'connected_drawing',
    }];
  }

  /// Find the top-left point among all strokes
  static Point _findTopLeftPoint(List<List<Point>> strokes) {
    Point topLeft = Point(double.infinity, double.infinity);

    for (List<Point> stroke in strokes) {
      for (Point point in stroke) {
        if (point.y < topLeft.y || (point.y == topLeft.y && point.x < topLeft.x)) {
          topLeft = point;
        }
      }
    }

    return topLeft;
  }

  /// Find index of closest stroke to current position
  static int _findClosestStrokeIndex(Point currentPos, List<List<Point>> strokes) {
    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < strokes.length; i++) {
      List<Point> stroke = strokes[i];

      // Check distance to both ends of the stroke
      double distToStart = currentPos.distanceTo(stroke.first);
      double distToEnd = currentPos.distanceTo(stroke.last);
      double strokeDistance = math.min(distToStart, distToEnd);

      if (strokeDistance < minDistance) {
        minDistance = strokeDistance;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  /// Determine if stroke should be reversed for optimal path
  static bool _shouldReverseStroke(Point currentPos, List<Point> stroke) {
    double distToStart = currentPos.distanceTo(stroke.first);
    double distToEnd = currentPos.distanceTo(stroke.last);
    return distToEnd < distToStart;
  }

  static double _calculateStrokeLength(List<Point> stroke) {
    double length = 0.0;
    for (int i = 1; i < stroke.length; i++) {
      length += stroke[i-1].distanceTo(stroke[i]);
    }
    return length;
  }
}

// Data classes
class Point {
  final double x;
  final double y;

  Point(this.x, this.y);

  double distanceTo(Point other) {
    double dx = x - other.x;
    double dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  String toString() => 'Point($x, $y)';
}

class ImageProcessingResult {
  final List<List<Point>> strokes;
  final String processedImageBase64;
  final Map<String, dynamic> stats;
  final bool success;
  final String? error;

  ImageProcessingResult({
    required this.strokes,
    required this.processedImageBase64,
    required this.stats,
    required this.success,
    this.error,
  });

  factory ImageProcessingResult.error(String error) {
    return ImageProcessingResult(
      strokes: [],
      processedImageBase64: '',
      stats: {},
      success: false,
      error: error,
    );
  }
}