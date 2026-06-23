// import 'dart:io';
// import 'dart:typed_data';
// import 'dart:ui';

// import 'package:flutter/material.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:pretty_qr_code/pretty_qr_code.dart';

// class QrDisplayPage extends StatefulWidget {
//   final String data;

//   QrDisplayPage({required this.data});

//   @override
//   _QrDisplayPageState createState() => _QrDisplayPageState();
// }

// class _QrDisplayPageState extends State<QrDisplayPage> {
//   late QrImage qrImage;

//   @override
//   void initState() {
//     super.initState();
//     final qrCode = QrCode(
//       8,
//       QrErrorCorrectLevel.H,
//     )..addData(widget.data);

//     qrImage = QrImage(qrCode);
//   }

//   Future<void> _saveQrCodeImage() async {
//     // Request storage permission
//     final status = await Permission.storage.request();
//     if (status.isGranted) {
//       // Generate QR code image bytes
//       final qrImageBytes = await qrImage.toImageAsBytes(
//         size: 512,
//         format: ImageByteFormat.png,
//         decoration: PrettyQrDecoration(),
//       );

//       // Convert ByteData to Uint8List
//       final uint8List = Uint8List.view(qrImageBytes!.buffer);

//       // Get the Downloads directory
//       Directory? downloadsDirectory;
//       if (Platform.isAndroid) {
//         downloadsDirectory = Directory('/storage/emulated/0/Download');
//       } else if (Platform.isIOS) {
//         downloadsDirectory =
//             await getApplicationDocumentsDirectory(); // iOS alternative
//       }

//       if (downloadsDirectory != null && await downloadsDirectory.exists()) {
//         final filePath = '${downloadsDirectory.path}/qr_code.png';

//         // Write the file
//         final file = File(filePath);
//         await file.writeAsBytes(uint8List);

//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('QR code saved at: $filePath')),
//         );
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Failed to access the Downloads folder.')),
//         );
//       }
//     } else if (status.isPermanentlyDenied) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text(
//             'Storage permission is permanently denied. Please enable it in settings.',
//           ),
//         ),
//       );
//       await openAppSettings(); // Opens the app settings so the user can manually grant the permission
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Storage permission denied. Unable to save QR code.'),
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("QR Code Display"),
//         backgroundColor: Colors.black,
//       ),
//       backgroundColor: Colors.black,
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Container(
//               height: size.width / 1.1,
//               width: size.width / 1.1,
//               color: Colors.white,
//               child: SizedBox(
//                 height: size.width / 1.3,
//                 width: size.width / 1.3,
//                 // color: Colors.white,
//                 child: PrettyQrView(
//                   qrImage: qrImage,
//                   decoration: const PrettyQrDecoration(),
//                 ),
//               ),
//             ),
//             SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: _saveQrCodeImage,
//               child: Text("Save QR Code"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:connect/Config/app_theme.dart';

class QrDisplayPage extends StatefulWidget {
  final String data;

  const QrDisplayPage({super.key, required this.data});

  @override
  State<QrDisplayPage> createState() => _QrDisplayPageState();
}

class _QrDisplayPageState extends State<QrDisplayPage> {
  late QrImage qrImage;
  bool hasError = false;
  String errorMessage = '';

  // Function to determine appropriate QR version based on data length
  int _getQrVersion(int dataLength) {
    // Version capacity with error correction level H
    final capacities = {
      14: 1624, // Version 14
      15: 1812, // Version 15
      16: 2032, // Version 16
    };

    for (var entry in capacities.entries) {
      if (entry.value >= dataLength) {
        return entry.key;
      }
    }

    // If data is too long for all specified versions, return the highest version (40)
    return 40;
  }

  @override
  void initState() {
    super.initState();
    try {
      final version = _getQrVersion(widget.data.length);
      print(
          'Using QR version: $version for data length: ${widget.data.length}');

      final qrCode = QrCode(
        version,
        QrErrorCorrectLevel.H,
      )..addData(widget.data);

      qrImage = QrImage(qrCode);
    } catch (e) {
      print('QR Generation Error: $e');
      setState(() {
        hasError = true;
        errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Identity QR Code",
          style: context.screenHeading,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: const GlassmorphicFlexibleSpace(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: context.canvasBackground,
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasError)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error generating QR code: $errorMessage',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: size.width / 1.25,
                      height: size.width / 1.25,
                      constraints: const BoxConstraints(
                        maxWidth: 320,
                        maxHeight: 320,
                      ),
                      decoration: BoxDecoration(
                        color: context.surfacePrimary,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusPremiumCard),
                        border: Border.all(
                          color: context.surfaceSecondary,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(24.0), // interior safety field padding of 24.0 pixels on all sides
                        child: PrettyQrView(
                          qrImage: qrImage,
                          decoration: const PrettyQrDecoration(
                            background: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      "Show this code to complete connection",
                      style: context.captionText.copyWith(
                        color: context.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
