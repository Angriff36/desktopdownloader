
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: DownloaderScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  final TextEditingController _urlController = TextEditingController();
  String status = "";
  double _downloadProgress = 0.0;

  static const platform = MethodChannel(
    'com.angriff.x_video_downloader/media_scanner',
  );

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    // Only listen for shared text on mobile platforms
    if (Platform.isAndroid || Platform.isIOS) {
      _listenForSharedText();
    }
  }

  void _listenForSharedText() {
    ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          final sharedText = value.first.path;
          setState(() {
            _urlController.text = sharedText;
            status = "Link received via Share";
          });
        }
      },
      onError: (err) {
        print("Sharing Error: $err");
      },
    );

    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        final sharedText = value.first.path;
        setState(() {
          _urlController.text = sharedText;
          status = "Link received via Share";
        });
      }
    });
  }

  Future<void> _requestPermissions() async {
    await Permission.manageExternalStorage.request();
    await Permission.storage.request();
  }

Future<void> downloadVideo() async {
  final url = _urlController.text.trim();
  if (url.isEmpty) return;

  setState(() => status = "Requesting download...");

  final backendEndpoint =
      "http://localhost:8000/download?url=$url";

  try {
    final response = await http.Client().send(http.Request('GET', Uri.parse(backendEndpoint)));

    if (response.statusCode == 200) {
      final contentType = response.headers['content-type'];
      if (contentType != null && contentType.contains('application/json')) {
        // If backend returns JSON (error case)
        final textBody = await response.stream.bytesToString();
        setState(() {
          status = "Download failed: $textBody";
          _downloadProgress = 0.0;
        });
        return;
      }

      // Normal file download
      final contentLength = response.contentLength;
      int receivedBytes = 0;
      List<int> bytes = [];

      final downloadDir = Directory('/storage/emulated/0/Download');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final filePath =
          "${downloadDir.path}/x_video_${DateTime.now().millisecondsSinceEpoch}.mp4";
      final file = File(filePath);

      response.stream.listen(
        (List<int> chunk) {
          bytes.addAll(chunk);
          receivedBytes += chunk.length;
          if (contentLength != null) {
            setState(() {
              _downloadProgress = receivedBytes / contentLength;
            });
          }
        },
        onDone: () async {
          await file.writeAsBytes(bytes);
          if (Platform.isAndroid || Platform.isIOS) {
            await platform.invokeMethod('scanFile', {"path": filePath});
          }
          setState(() {
            status = "Downloaded to: $filePath";
            _downloadProgress = 0.0;
          });
        },
        onError: (e) {
          setState(() {
            status = "Error during download: $e";
            _downloadProgress = 0.0;
          });
        },
        cancelOnError: true,
      );
    } else {
      setState(() {
        status = "Failed: HTTP ${response.statusCode}";
        _downloadProgress = 0.0;
      });
    }
  } catch (e) {
    setState(() {
      status = "Error: $e";
      _downloadProgress = 0.0;
    });
  }
}

Future<void> _handleAuthRequired() async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Additional Access Needed'),
      content: Text('Some videos require extra access. Please select the access file to continue.'),
      actions: [
        TextButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.pop(context, false),
        ),
        ElevatedButton(
          child: Text('Select File'),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );

  if (result == true) {
    FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (picked != null && picked.files.single.path != null) {
      final file = File(picked.files.single.path!);
      final uri = Uri.parse('http://localhost:8000/upload-cookies');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        setState(() {
          status = "Access file uploaded. Retrying download...";
        });
      } else {
        setState(() {
          status = "Failed to upload access file.";
        });
      }
    }
  }
}


  Future<void> _launchDonationPage() async {
    final Uri url = Uri.parse('https://buymeacoffee.com/angriff');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("X Video Downloader")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: "Paste X Video URL",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final intent = AndroidIntent(
                  action: 'android.intent.action.VIEW',
data: Uri.encodeFull('content://media/internal/video/media'),
                  flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
                );
                await intent.launch();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text('Open Gallery'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: downloadVideo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text("Download"),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _launchDonationPage,
              icon: const Icon(Icons.coffee),
              label: const Text("Buy Me a Coffee"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: _downloadProgress),
            const SizedBox(height: 20),
            Text(status),
          ],
        ),
      ),
    );
  }
}
