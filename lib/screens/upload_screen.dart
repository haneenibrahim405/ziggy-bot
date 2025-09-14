import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import '../service/image_processor.dart';
import '../widgets/bottom_nav.dart';
import 'package:http/http.dart' as http;

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _image;
  String? _processedImageBase64;
  bool isLoading = false;
  String? responseMessage;
  img.Image? selectedImage;
  List<List<Point>> _extractedStrokes = [];
  Map<String, dynamic> _processingStats = {};
  bool _isESPConnected = false;

  // المتغيرات الجديدة لمنع التكرار
  bool _isSendingCommands = false;
  List<Map<String, dynamic>> _lastProcessedCommands = [];

  // متغير الـ scale
  double _drawingScale = 1.0; // القيمة الافتراضية 1.0 (الحجم الطبيعي)

  final Color containerColor = Color(0xFFE0E0E0);
  final Color chooseButtonColor = Color(0xFF231A4E);
  final Color uploadButtonColor = Color(0xFF231A4E);
  final Color iconColor = Color(0xFF231A4E);

  @override
  void initState() {
    super.initState();
    _checkESPConnection();
  }

  // Test ESP32 connection
  Future<void> _checkESPConnection() async {
    try {
      print("🔍 Testing ESP32 connection...");
      final response = await http.get(
        Uri.parse('http://192.168.4.1/status'),
        headers: {'Connection': 'close'},
      ).timeout(Duration(seconds: 3));

      if (response.statusCode == 200) {
        setState(() {
          _isESPConnected = true;
          responseMessage = "ESP32 connected successfully!";
        });
        print("✅ ESP32 connection: SUCCESS");
      } else {
        setState(() {
          _isESPConnected = false;
          responseMessage = "ESP32 responded with status ${response.statusCode}";
        });
        print("⚠️ ESP32 connection: Status ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _isESPConnected = false;
        responseMessage = "Cannot connect to ESP32: $e";
      });
      print("❌ ESP32 connection: FAILED - $e");
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        File imageFile = File(picked.path);

        await _convertFileToImage(imageFile);

        setState(() {
          _image = imageFile;
          _processedImageBase64 = null;
          _extractedStrokes = [];
          _processingStats = {};
          responseMessage = null;
          _lastProcessedCommands.clear(); // امسح الكوماندز القديمة
          _drawingScale = 1.0; // إعادة تعيين الـ scale
        });
      }
    } catch (e) {
      setState(() {
        responseMessage = "Error picking image: ${e.toString()}";
      });
    }
  }

  Future<void> _convertFileToImage(File imageFile) async {
    try {
      Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image != null) {
        selectedImage = image;
        print('Image converted successfully');
      } else {
        print('Failed to convert image');
        selectedImage = null;
      }
    } catch (e) {
      print('Error converting image: $e');
      selectedImage = null;
    }
  }

  // دالة معدلة لمعالجة الصورة
  Future<void> _processImage() async {
    if (_image == null || selectedImage == null) {
      setState(() {
        responseMessage = "Please choose an image first";
      });
      return;
    }

    setState(() {
      isLoading = true;
      responseMessage = "Processing image...";
      _lastProcessedCommands.clear(); // امسح الكوماندز القديمة
    });

    try {
      ImageProcessingResult result = await ImageProcessor.processImageDirect(selectedImage);

      if (result.success) {
        setState(() {
          _extractedStrokes = result.strokes;
          _processedImageBase64 = result.processedImageBase64;
          _processingStats = result.stats;
          responseMessage = "Image processed successfully! Found ${result.strokes.length} strokes.";
          isLoading = false;
          _lastProcessedCommands.clear(); // امسح الكوماندز لإعادة المعالجة
        });
      } else {
        setState(() {
          responseMessage = "Error processing image: ${result.error}";
          isLoading = false;
        });
      }

    } catch (e) {
      setState(() {
        responseMessage = "Error processing image: ${e.toString()}";
        isLoading = false;
      });
    }
  }

  void _clearImage() {
    setState(() {
      _image = null;
      selectedImage = null;
      _processedImageBase64 = null;
      _extractedStrokes = [];
      _processingStats = {};
      responseMessage = null;
      isLoading = false;
      _lastProcessedCommands.clear(); // امسح الكوماندز
      _isSendingCommands = false; // إعادة تعيين حالة الإرسال
      _drawingScale = 1.0; // إعادة تعيين الـ scale
    });
  }

  // دالة لاستخراج الكوماندز مرة واحدة فقط مع تطبيق الـ scale
  List<Map<String, dynamic>> _extractCommandsOnce() {
    // لو الكوماندز موجودة مسبقاً والـ scale نفسه، ارجعها
    if (_lastProcessedCommands.isNotEmpty) {
      print("🔄 Using cached commands: ${_lastProcessedCommands.length} with scale $_drawingScale");
      return _applyScaleToCommands(_lastProcessedCommands);
    }

    List<Map<String, dynamic>> espData = ImageProcessor.convertToESPFormat(_extractedStrokes);
    List<Map<String, dynamic>> commands = [];

    for (var item in espData) {
      if (item.containsKey('commands') && item['commands'] is List) {
        List<dynamic> commandList = item['commands'];
        for (var cmd in commandList) {
          if (cmd is Map<String, dynamic>) {
            int steps = (cmd['steps'] ?? 0).round();
            if (steps > 0) {
              int angle = (cmd['angle'] ?? 90).round() % 360;
              int repeats = ((steps / 50).ceil()).clamp(1, 20);
              commands.add({
                'angle': angle,
                'repeats': repeats,
                'originalSteps': steps, // احفظ القيمة الأصلية
                'estimatedTime': _estimateCommandTime(repeats),
              });
            }
          }
        }
      }
    }

    // احفظ الكوماندز الأصلية
    _lastProcessedCommands = List.from(commands);
    print("🆕 Extracted fresh commands: ${commands.length}");

    // طبق الـ scale وارجع النتيجة
    return _applyScaleToCommands(commands);
  }

  // دالة لتطبيق الـ scale على الكوماندز
  List<Map<String, dynamic>> _applyScaleToCommands(List<Map<String, dynamic>> originalCommands) {
    if (_drawingScale == 1.0) {
      return originalCommands; // لو الـ scale = 1، ارجع نفس الكوماندز
    }

    List<Map<String, dynamic>> scaledCommands = [];

    for (var cmd in originalCommands) {
      int originalSteps = cmd['originalSteps'] ?? cmd['repeats'] * 50;

      // طبق الـ scale على عدد الخطوات
      int scaledSteps = (originalSteps * _drawingScale).round();
      int scaledRepeats = ((scaledSteps / 50).ceil()).clamp(1, 50); // حد أقصى 50 repeat

      scaledCommands.add({
        'angle': cmd['angle'],
        'repeats': scaledRepeats,
        'originalSteps': originalSteps,
        'scaledSteps': scaledSteps,
        'estimatedTime': _estimateCommandTime(scaledRepeats),
      });
    }

    print("🔧 Applied scale $_drawingScale: ${originalCommands.length} commands scaled");
    return scaledCommands;
  }

  // دالة لحساب الحجم التقديري للرسم
  String _getEstimatedDrawingSize() {
    if (_extractedStrokes.isEmpty) return "N/A";

    // حساب تقديري بناء على عدد الكوماندز والـ scale
    List<Map<String, dynamic>> commands = _extractCommandsOnce();
    double totalSteps = 0;

    for (var cmd in commands) {
      totalSteps += (cmd['scaledSteps'] ?? cmd['repeats'] * 50);
    }

    // كل 50 خطوة = 3 سم تقريباً
    double estimatedSizeCm = (totalSteps / 50) * 3 * _drawingScale;

    if (estimatedSizeCm < 100) {
      return "${estimatedSizeCm.toStringAsFixed(1)} cm";
    } else {
      return "${(estimatedSizeCm / 100).toStringAsFixed(2)} m";
    }
  }

  // حساب الوقت المتوقع لتنفيذ command (بالميللي ثانية)
  int _estimateCommandTime(int repeats) {
    const int baseTimePerRepeat = 150; // ms
    const int setupTime = 50; // وقت البدء
    return setupTime + (repeats * baseTimePerRepeat);
  }

  // حساب فترة الانتظار الذكية
  int _calculateSmartDelay(int repeats) {
    if (repeats <= 2) {
      return 300; // 0.3 ثانية للحركات الصغيرة
    } else if (repeats <= 5) {
      return 500; // 0.5 ثانية للحركات المتوسطة
    } else if (repeats <= 10) {
      return 800; // 0.8 ثانية للحركات الكبيرة
    } else {
      return 1200; // 1.2 ثانية للحركات الكبيرة جدًا
    }
  }

  // تجميع الكوماندز المتتالية ذات الزاوية نفسها
  List<Map<String, dynamic>> _groupSimilarCommands(List<Map<String, dynamic>> commands) {
    if (commands.isEmpty) return [];

    List<Map<String, dynamic>> grouped = [];
    Map<String, dynamic> current = Map.from(commands[0]);

    for (int i = 1; i < commands.length; i++) {
      Map<String, dynamic> next = commands[i];

      // لو نفس الزاوية، اجمعهم
      if (current['angle'] == next['angle']) {
        int totalRepeats = (current['repeats'] + next['repeats']).clamp(1, 50);
        current['repeats'] = totalRepeats;

        // اجمع الخطوات المقيسة أيضاً
        if (current.containsKey('scaledSteps') && next.containsKey('scaledSteps')) {
          current['scaledSteps'] = current['scaledSteps'] + next['scaledSteps'];
        }
      } else {
        grouped.add(current);
        current = Map.from(next);
      }
    }

    grouped.add(current); // أضف آخر واحد
    return grouped;
  }

  // دالة لإرسال command واحد مع retry
  Future<bool> _sendSingleCommandWithRetry(int angle, int repeats, int commandNumber) async {
    String url = 'http://192.168.4.1/move?angle=$angle&repeats=$repeats';

    const int maxRetries = 2;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print("📡 Attempt $attempt/$maxRetries for command $commandNumber");

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Flutter-App',
            'Connection': 'close',
          },
        ).timeout(Duration(seconds: 5));

        if (response.statusCode == 200) {
          print("✅ Command $commandNumber sent successfully on attempt $attempt");
          return true;
        } else {
          print("❌ Command $commandNumber failed on attempt $attempt - Status: ${response.statusCode}");
        }
      } catch (e) {
        print("💥 Command $commandNumber error on attempt $attempt: $e");
      }

      // انتظار قبل المحاولة التالية
      if (attempt < maxRetries) {
        await Future.delayed(Duration(milliseconds: 300));
      }
    }

    return false;
  }

  // دالة للتحقق من إنجاز الـ ESP
  Future<void> _checkIfESPFinished() async {
    try {
      print("🔍 Checking if ESP32 finished executing...");

      final response = await http.get(
        Uri.parse('http://192.168.4.1/status'),
        headers: {'Connection': 'close'},
      ).timeout(Duration(seconds: 3));

      if (response.statusCode == 200) {
        print("📊 ESP32 status: ${response.body}");

        // لو في معلومات عن الحالة في الـ response
        if (response.body.contains('"busy":false') || response.body.contains('"status":"idle"')) {
          setState(() {
            responseMessage = responseMessage! + "\n🤖 ESP32 confirmed: Drawing completed!";
          });
        }
      }
    } catch (e) {
      print("ℹ️ Could not check ESP32 completion status: $e");
    }
  }

  // الدالة المحسنة لإرسال الكوماندز (مصححة)
  Future<void> _sendToESPOptimized() async {
    if (!_isESPConnected) {
      setState(() {
        responseMessage = "ESP32 not connected! Check connection first.";
      });
      return;
    }

    if (_isSendingCommands) {
      setState(() {
        responseMessage = "Commands already being sent! Please wait...";
      });
      return;
    }

    setState(() {
      _isSendingCommands = true;
    });

    try {
      // استخرج الكوماندز مرة واحدة فقط مع الـ scale
      List<Map<String, dynamic>> commands = _extractCommandsOnce();

      if (commands.isEmpty) {
        setState(() {
          responseMessage = "No valid commands to send!";
          _isSendingCommands = false;
        });
        return;
      }

      // تجميع الكوماندز المتشابهة
      List<Map<String, dynamic>> optimizedCommands = _groupSimilarCommands(commands);

      print("🔍 Original commands: ${commands.length}");
      print("🔍 Optimized commands: ${optimizedCommands.length}");
      print("📏 Drawing scale: $_drawingScale");

      setState(() {
        responseMessage = "Sending ${optimizedCommands.length} scaled commands (scale: ${_drawingScale}x)...";
      });

      int successCount = 0;
      int failCount = 0;
      Stopwatch stopwatch = Stopwatch()..start();

      for (int i = 0; i < optimizedCommands.length; i++) {
        Map<String, dynamic> command = optimizedCommands[i];

        int angle = command['angle'];
        int repeats = command['repeats'];

        print("📤 Sending scaled command ${i + 1}/${optimizedCommands.length}: Angle=$angle, Repeats=$repeats (Scale: $_drawingScale)");

        bool success = await _sendSingleCommandWithRetry(angle, repeats, i + 1);

        if (success) {
          successCount++;
          print("✅ Command ${i + 1} completed successfully");
        } else {
          failCount++;
          print("❌ Command ${i + 1} failed after retries");
        }

        // انتظار ذكي بناء على حجم الحركة
        if (success && i < optimizedCommands.length - 1) {
          int smartDelay = _calculateSmartDelay(repeats);
          print("⏳ Smart delay: ${smartDelay}ms for $repeats repeats");

          setState(() {
            responseMessage = "Command ${i + 1}/${optimizedCommands.length} sent. Waiting ${smartDelay}ms...";
          });

          await Future.delayed(Duration(milliseconds: smartDelay));
        }

        // تحديث التقدم
        double progress = ((i + 1) / optimizedCommands.length * 100);
        double elapsedSeconds = stopwatch.elapsedMilliseconds / 1000;
        setState(() {
          responseMessage = "Progress: ${progress.toStringAsFixed(0)}% (✅$successCount ❌$failCount) - ${elapsedSeconds.toStringAsFixed(1)}s - Scale: ${_drawingScale}x";
        });
      }

      stopwatch.stop();
      double totalTimeSeconds = stopwatch.elapsedMilliseconds / 1000;

      // رسالة الإنجاز النهائية
      setState(() {
        if (failCount == 0) {
          responseMessage = "🎉 ALL SCALED COMMANDS COMPLETED! ✅$successCount sent in ${totalTimeSeconds.toStringAsFixed(1)}s (Scale: ${_drawingScale}x). Robot finished drawing!";
        } else {
          responseMessage = "⚠️ Completed with issues: ✅$successCount successful, ❌$failCount failed in ${totalTimeSeconds.toStringAsFixed(1)}s";
        }
      });

      // اختياري: تحقق من حالة الـ ESP للتأكد إنه خلص
      await _checkIfESPFinished();

    } catch (e) {
      setState(() {
        responseMessage = "💥 Error during sending: $e";
      });
    } finally {
      setState(() {
        _isSendingCommands = false;
      });
    }
  }

  // إرسال command واحد للاستخدام في المتوازي
  Future<bool> _sendSingleCommand(Map<String, dynamic> command) async {
    int angle = command['angle'];
    int repeats = command['repeats'];
    String url = 'http://192.168.4.1/move?angle=$angle&repeats=$repeats';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Connection': 'close'},
      ).timeout(Duration(seconds: 4));

      return response.statusCode == 200;
    } catch (e) {
      print("Command error: $e");
      return false;
    }
  }

  // دالة محسنة للإرسال المتوازي مع منع التكرار
  Future<void> _sendToESPSuperOptimized() async {
    if (!_isESPConnected) {
      setState(() {
        responseMessage = "ESP32 not connected!";
      });
      return;
    }

    if (_isSendingCommands) {
      setState(() {
        responseMessage = "Commands already being sent! Please wait...";
      });
      return;
    }

    setState(() {
      _isSendingCommands = true;
    });

    try {
      // استخرج الكوماندز مرة واحدة فقط مع الـ scale
      List<Map<String, dynamic>> commands = _extractCommandsOnce();

      if (commands.isEmpty) {
        setState(() {
          responseMessage = "No valid commands to send!";
          _isSendingCommands = false;
        });
        return;
      }

      // تجميع الكوماندز المتشابهة
      List<Map<String, dynamic>> optimizedCommands = _groupSimilarCommands(commands);

      setState(() {
        responseMessage = "Super optimized ${commands.length} → ${optimizedCommands.length} commands with ${_drawingScale}x scale. Parallel processing...";
      });

      await _sendCommandsWithConcurrencyFixed(optimizedCommands);

    } catch (e) {
      setState(() {
        responseMessage = "💥 Error during parallel sending: $e";
      });
    } finally {
      setState(() {
        _isSendingCommands = false;
      });
    }
  }

  // دالة مصححة للإرسال المتوازي
  Future<void> _sendCommandsWithConcurrencyFixed(List<Map<String, dynamic>> commands) async {
    const int maxConcurrent = 2;
    int successCount = 0;
    int failCount = 0;
    Stopwatch stopwatch = Stopwatch()..start();

    print("🚀 Starting parallel sending of ${commands.length} scaled commands...");

    for (int i = 0; i < commands.length; i += maxConcurrent) {
      int endIndex = (i + maxConcurrent < commands.length) ? i + maxConcurrent : commands.length;
      List<Map<String, dynamic>> batch = commands.sublist(i, endIndex);

      print("📦 Processing batch ${(i ~/ maxConcurrent) + 1}: commands ${i + 1} to $endIndex");

      // إرسال المجموعة بشكل متوازي
      List<Future<bool>> futures = batch.asMap().entries.map((entry) {
        int batchIndex = entry.key;
        Map<String, dynamic> cmd = entry.value;
        int globalIndex = i + batchIndex + 1;
        return _sendSingleCommandWithRetry(cmd['angle'], cmd['repeats'], globalIndex);
      }).toList();

      List<bool> results = await Future.wait(futures);

      // حساب النتائج وطباعة التفاصيل
      for (int j = 0; j < results.length; j++) {
        bool success = results[j];
        Map<String, dynamic> cmd = batch[j];
        int globalIndex = i + j + 1;

        if (success) {
          successCount++;
          print("✅ Parallel command $globalIndex completed - Angle: ${cmd['angle']}, Repeats: ${cmd['repeats']} (Scale: $_drawingScale)");
        } else {
          failCount++;
          print("❌ Parallel command $globalIndex failed - Angle: ${cmd['angle']}, Repeats: ${cmd['repeats']}");
        }
      }

      // تحديث التقدم
      double progress = ((i + batch.length) / commands.length * 100);
      double elapsedSeconds = stopwatch.elapsedMilliseconds / 1000;
      setState(() {
        responseMessage = "Parallel Progress: ${progress.toStringAsFixed(0)}% (✅$successCount ❌$failCount) - ${elapsedSeconds.toStringAsFixed(1)}s - Scale: ${_drawingScale}x";
      });

      // انتظار بين المجموعات
      if (i + maxConcurrent < commands.length) {
        print("⏸️ Waiting 400ms before next batch...");
        await Future.delayed(Duration(milliseconds: 400));
      }
    }

    stopwatch.stop();
    double totalTimeSeconds = stopwatch.elapsedMilliseconds / 1000;

    setState(() {
      if (failCount == 0) {
        responseMessage = "🚀 ALL PARALLEL SCALED COMMANDS COMPLETED! ✅$successCount sent in ${totalTimeSeconds.toStringAsFixed(1)}s (Scale: ${_drawingScale}x). Robot finished drawing!";
      } else {
        responseMessage = "⚠️ Parallel completed: ✅$successCount successful, ❌$failCount failed in ${totalTimeSeconds.toStringAsFixed(1)}s";
      }
    });

    // تحقق من حالة الـ ESP
    await _checkIfESPFinished();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: BottomNav(currentIndex: 0),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("assets/ziggy.png", height: 120),
              const SizedBox(height: 20),

              Text(
                "IMAGE PROCESSOR",
                style: GoogleFonts.audiowide(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: uploadButtonColor,
                ),
              ),
              const SizedBox(height: 10),

              // ESP Connection Status
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _isESPConnected ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isESPConnected ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isESPConnected ? Icons.wifi : Icons.wifi_off,
                      color: _isESPConnected ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      _isESPConnected ? "ESP32 Connected" : "ESP32 Disconnected",
                      style: GoogleFonts.audiowide(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isESPConnected ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: _checkESPConnection,
                      child: Icon(
                        Icons.refresh,
                        color: _isESPConnected ? Colors.green : Colors.red,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Image display container
              Container(
                height: 300,
                width: double.infinity,
                constraints: BoxConstraints(maxWidth: 300),
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _processedImageBase64 != null
                    ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.memory(
                        base64Decode(_processedImageBase64!),
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Processed",
                          style: GoogleFonts.audiowide(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _clearImage,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                )
                    : _image == null
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload, size: 60, color: Colors.white),
                    SizedBox(height: 10),
                    Text(
                      "Upload Image",
                      style: GoogleFonts.audiowide(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Tap 'Choose Image' to select",
                      style: GoogleFonts.audiowide(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                )
                    : Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.file(
                        _image!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Original",
                          style: GoogleFonts.audiowide(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _clearImage,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Scale Control Section
              if (_extractedStrokes.isNotEmpty) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.zoom_in, color: Colors.purple.shade700, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Drawing Scale Control",
                            style: GoogleFonts.audiowide(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            "0.5x",
                            style: GoogleFonts.audiowide(
                              fontSize: 12,
                              color: Colors.purple.shade600,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _drawingScale,
                              min: 0.5,
                              max: 3.0,
                              divisions: 25,
                              activeColor: Colors.purple.shade600,
                              inactiveColor: Colors.purple.shade200,
                              onChanged: _isSendingCommands ? null : (value) {
                                setState(() {
                                  _drawingScale = value;
                                  _lastProcessedCommands.clear(); // إعادة حساب الكوماندز
                                });
                              },
                            ),
                          ),
                          Text(
                            "3.0x",
                            style: GoogleFonts.audiowide(
                              fontSize: 12,
                              color: Colors.purple.shade600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                "${_drawingScale.toStringAsFixed(1)}x",
                                style: GoogleFonts.audiowide(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                              Text(
                                "Scale",
                                style: GoogleFonts.audiowide(
                                    fontSize: 12,
                                    color: Colors.purple.shade600
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                _getEstimatedDrawingSize(),
                                style: GoogleFonts.audiowide(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              Text(
                                "Est. Size",
                                style: GoogleFonts.audiowide(
                                    fontSize: 12,
                                    color: Colors.orange.shade600
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildScalePresetButton("0.5x", 0.5),
                          _buildScalePresetButton("1x", 1.0),
                          _buildScalePresetButton("1.5x", 1.5),
                          _buildScalePresetButton("2x", 2.0),
                          _buildScalePresetButton("3x", 3.0),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ],

              // Action buttons
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: (isLoading || _isSendingCommands) ? null : _pickImage,
                    icon: Icon(Icons.image, size: 18, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: chooseButtonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    label: Text(
                      "Choose Image",
                      style: GoogleFonts.audiowide(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),

                  ElevatedButton.icon(
                    onPressed: (isLoading || _image == null || selectedImage == null || _isSendingCommands) ? null : _processImage,
                    icon: isLoading
                        ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Icon(Icons.auto_fix_high, size: 18, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: uploadButtonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    label: Text(
                      isLoading ? "Processing..." : "Process",
                      style: GoogleFonts.audiowide(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),

                  if (_extractedStrokes.isNotEmpty) ...[
                    // زرار الإرسال المحسن (الأساسي)
                    ElevatedButton.icon(
                      onPressed: (_isESPConnected && !_isSendingCommands) ? _sendToESPOptimized : null,
                      icon: _isSendingCommands
                          ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : Icon(Icons.send, size: 18, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_isESPConnected && !_isSendingCommands) ? Colors.green : Colors.grey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      ),
                      label: Text(
                        _isSendingCommands
                            ? "Sending..."
                            : _isESPConnected
                            ? "Send Scaled"
                            : "ESP32 not connected",
                        style: GoogleFonts.audiowide(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),

                    // زرار الإرسال المتقدم (متوازي)
                    ElevatedButton.icon(
                      onPressed: (_isESPConnected && !_isSendingCommands) ? _sendToESPSuperOptimized : null,
                      icon: _isSendingCommands
                          ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : Icon(Icons.flash_on, size: 18, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_isESPConnected && !_isSendingCommands) ? Colors.purple.shade600 : Colors.grey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                      ),
                      label: Text(
                        _isSendingCommands
                            ? "Sending..."
                            : _isESPConnected
                            ? "Super Fast"
                            : "ESP32 not connected",
                        style: GoogleFonts.audiowide(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 20),

              // Processing stats
              if (_processingStats.isNotEmpty) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics, color: Colors.blue.shade700, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Processing Results",
                            style: GoogleFonts.audiowide(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                "${_processingStats['optimizedStrokes']}",
                                style: GoogleFonts.audiowide(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              Text(
                                "Strokes",
                                style: GoogleFonts.audiowide(fontSize: 12, color: Colors.blue.shade600),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                "${_processingStats['totalLength']}px",
                                style: GoogleFonts.audiowide(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                "Total Length",
                                style: GoogleFonts.audiowide(fontSize: 12, color: Colors.green.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ],

              // Loading indicator
              if (isLoading) ...[
                Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(uploadButtonColor),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Processing image...",
                      style: GoogleFonts.audiowide(fontSize: 16, color: uploadButtonColor),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "This may take a few seconds",
                      style: GoogleFonts.audiowide(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                SizedBox(height: 20),
              ],

              // Status message
              if (responseMessage != null) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: responseMessage!.contains("successfully") || responseMessage!.contains("Connected") || responseMessage!.contains("🎉") || responseMessage!.contains("🚀") || responseMessage!.contains("COMPLETED")
                        ? Colors.green.shade50
                        : responseMessage!.contains("Error") || responseMessage!.contains("failed") || responseMessage!.contains("Cannot") || responseMessage!.contains("❌")
                        ? Colors.red.shade50
                        : responseMessage!.contains("Optimized") || responseMessage!.contains("Progress") || responseMessage!.contains("Parallel") || responseMessage!.contains("Sending") || responseMessage!.contains("Scale")
                        ? Colors.orange.shade50
                        : Colors.blue.shade50,
                    border: Border.all(
                      color: responseMessage!.contains("successfully") || responseMessage!.contains("Connected") || responseMessage!.contains("🎉") || responseMessage!.contains("🚀") || responseMessage!.contains("COMPLETED")
                          ? Colors.green.shade300
                          : responseMessage!.contains("Error") || responseMessage!.contains("failed") || responseMessage!.contains("Cannot") || responseMessage!.contains("❌")
                          ? Colors.red.shade300
                          : responseMessage!.contains("Optimized") || responseMessage!.contains("Progress") || responseMessage!.contains("Parallel") || responseMessage!.contains("Sending") || responseMessage!.contains("Scale")
                          ? Colors.orange.shade300
                          : Colors.blue.shade300,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        responseMessage!.contains("successfully") || responseMessage!.contains("Connected") || responseMessage!.contains("🎉") || responseMessage!.contains("🚀") || responseMessage!.contains("COMPLETED")
                            ? Icons.check_circle
                            : responseMessage!.contains("Error") || responseMessage!.contains("failed") || responseMessage!.contains("Cannot") || responseMessage!.contains("❌")
                            ? Icons.error
                            : responseMessage!.contains("Progress") || responseMessage!.contains("Sending") || responseMessage!.contains("Parallel")
                            ? Icons.sync
                            : responseMessage!.contains("Optimized") || responseMessage!.contains("Scale")
                            ? Icons.speed
                            : Icons.info,
                        color: responseMessage!.contains("successfully") || responseMessage!.contains("Connected") || responseMessage!.contains("🎉") || responseMessage!.contains("🚀") || responseMessage!.contains("COMPLETED")
                            ? Colors.green.shade700
                            : responseMessage!.contains("Error") || responseMessage!.contains("failed") || responseMessage!.contains("Cannot") || responseMessage!.contains("❌")
                            ? Colors.red.shade700
                            : responseMessage!.contains("Optimized") || responseMessage!.contains("Progress") || responseMessage!.contains("Parallel") || responseMessage!.contains("Sending") || responseMessage!.contains("Scale")
                            ? Colors.orange.shade700
                            : Colors.blue.shade700,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          responseMessage!,
                          style: GoogleFonts.audiowide(
                            fontSize: 14,
                            color: responseMessage!.contains("successfully") || responseMessage!.contains("Connected") || responseMessage!.contains("🎉") || responseMessage!.contains("🚀") || responseMessage!.contains("COMPLETED")
                                ? Colors.green.shade700
                                : responseMessage!.contains("Error") || responseMessage!.contains("failed") || responseMessage!.contains("Cannot") || responseMessage!.contains("❌")
                                ? Colors.red.shade700
                                : responseMessage!.contains("Optimized") || responseMessage!.contains("Progress") || responseMessage!.contains("Parallel") || responseMessage!.contains("Sending") || responseMessage!.contains("Scale")
                                ? Colors.orange.shade700
                                : Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ],

            ],
          ),
        ),
      ),
    );
  }

  // Helper method لإنشاء أزرار الـ scale المعدة مسبقاً
  Widget _buildScalePresetButton(String label, double scale) {
    bool isSelected = (_drawingScale - scale).abs() < 0.05;

    return GestureDetector(
      onTap: _isSendingCommands ? null : () {
        setState(() {
          _drawingScale = scale;
          _lastProcessedCommands.clear(); // إعادة حساب الكوماندز
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple.shade600 : Colors.purple.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.purple.shade600 : Colors.purple.shade300,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.audiowide(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.purple.shade700,
          ),
        ),
      ),
    );
  }
}