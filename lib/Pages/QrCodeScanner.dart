import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:connect/Providers/ProviderSQL.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  Barcode? result;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    }
    controller?.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("QR Scanner"),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildQrView(context)),
          const Expanded(
            flex: 1,
            child: Center(
              child: const Text(
                "Scan a QR Code",
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // bool isTripleQuoted(String str) {
  //     return str.startsWith("'''") && str.endsWith("'''");
  //   }

  //   // Check for single quotes by context (this test won't work exactly in Dart's runtime but demonstrates logic)
  //   bool isSingleQuoted(String str) {
  //     return !isTripleQuoted(str); // Fallback logic for single-quoted strings
  //   }
  Widget _buildQrView(BuildContext context) {
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 200.0
        : 300.0;
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: Colors.red,
        borderRadius: 10,
        borderLength: 30,
        borderWidth: 10,
        cutOutSize: scanArea,
      ),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  // String convertToJsonFormat(String input) {
  //   // Add quotes around the keys.
  //   String fixedData = input.replaceAllMapped(RegExp(r'(\w+):'), (match) {
  //     return '"${match.group(1)}":'; // Add quotes around the keys
  //   });

  //   // Add quotes around values. This will also handle multi-word values properly.
  //   fixedData =
  //       fixedData.replaceAllMapped(RegExp(r'(\w+)(?=\s*,|\s*})'), (match) {
  //     return '"${match.group(1)}"'; // Add quotes around values
  //   });

  //   // Handle special cases like multi-word names (e.g., "Santosh Patil" should stay intact).
  //   fixedData = fixedData.replaceAllMapped(RegExp(r'(\w+ [\w\s]+)'), (match) {
  //     return '"${match.group(0)}"'; // Add quotes around multi-word strings
  //   });

  //   // Fix any unescaped quotes inside the values by escaping them.
  //   fixedData = fixedData.replaceAll('"', '\\"');

  //   return fixedData;
  // }

  String convertToJsonFormat(String input) {
    // Add quotes around the keys.
    String fixedData = input.replaceAllMapped(RegExp(r'(\w+):'), (match) {
      return '"${match.group(1)}":'; // Add quotes around the keys
    });

    // Add quotes around values and ensure there are no leading or trailing spaces.
    fixedData = fixedData
        .replaceAllMapped(RegExp(r'(\w+[\w\s@.]+)(?=\s*,|\s*})'), (match) {
      // Remove leading/trailing spaces and add quotes
      return '"${match.group(1)!.trim()}"';
    });

    // Fix any issues in the email field and remove unnecessary quote marks
    fixedData = fixedData.replaceAll(RegExp(r'\"'), '"');

    return fixedData;
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });

    controller.scannedDataStream.listen((scanData) async {
      print("Scanned QR Code: ${scanData.code}");

      setState(() {
        result = scanData;
      });

      if (result != null) {
        try {
          // Ensure raw input is used for decoding
          String rawData = scanData.code ?? "";

          Map<String, dynamic> decodedData;
          final trimmed = rawData.trim();
          if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
            decodedData = jsonDecode(trimmed) as Map<String, dynamic>;
          } else {
            // Convert to valid JSON format
            String jsonFormatted = convertToJsonFormat(rawData);
            print("Converted to Data Map: $jsonFormatted");
            // Decode the JSON
            decodedData = jsonDecode(jsonFormatted) as Map<String, dynamic>;
          }

          print("Decoded Data Map: $decodedData");

          // Pause the camera to prevent additional scans
          controller.pauseCamera();

          if (decodedData.containsKey('userId')) {
            final userIdVal = decodedData['userId'];
            final int idToFetch = userIdVal is int ? userIdVal : int.parse(userIdVal.toString());

            // Show a progress dialog while fetching profile
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F2FE)),
                  ),
                ),
              );
            }

            if (!mounted) return;
            final profileProvider = Provider.of<ProfileProvider2>(context, listen: false);
            final fetchedData = await profileProvider.fetchProfileDataOnly(idToFetch);
            if (fetchedData.isNotEmpty) {
              fetchedData['sharedCard'] = decodedData['sharedCard'] ?? 'both';
            }

            if (mounted) {
              Navigator.pop(context); // Dismiss progress dialog
            }

            if (fetchedData.isNotEmpty && fetchedData['name'].toString().isNotEmpty) {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileCard(profileData: fetchedData),
                  ),
                ).then((_) {
                  controller.resumeCamera();
                });
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Profile data not found")),
                );
                controller.resumeCamera();
              }
            }
          } else {
            decodedData['sharedCard'] = decodedData['sharedCard'] ?? 'both';
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileCard(profileData: decodedData),
                ),
              ).then((_) {
                controller.resumeCamera();
              });
            }
          }
        } catch (e) {
          // Handle any parsing errors gracefully
          print("Error decoding QR data: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Invalid QR Code")),
            );
          }
          controller.resumeCamera();
        }
      }
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    log('${DateTime.now().toIso8601String()}_onPermissionSet $p');
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Permission')),
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

class ProfileCard extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const ProfileCard({Key? key, required this.profileData}) : super(key: key);

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  // final profileProvider = Provider.of<ProfileProvider2>(context);
  late final ProfileProvider2 provider;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    provider = Provider.of<ProfileProvider2>(context, listen: false);
  }

  void saveProfile() async {
    if (provider.userId == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please set up your profile first")),
      );
      return;
    }
    final otherUserIdVal = widget.profileData['id'];
    if (otherUserIdVal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid scanned profile data")),
      );
      return;
    }
    final int scannedUserId = otherUserIdVal is int ? otherUserIdVal : int.parse(otherUserIdVal.toString());

    final String presenterSharedCard = widget.profileData['sharedCard'] ?? 'both';

    provider.connectUsers(
      provider.userId, 
      scannedUserId, 
      sharedCardByPresenter: presenterSharedCard,
    ).then((v) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connected successfully!")),
      );
      Navigator.pop(context); // Pop back to previous screen
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving connection: $e")),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Profile Details",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 8,
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.profileData["name"] ?? "N/A",
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.profileData["profession"] ?? "N/A",
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const Divider(),
                    _buildDetailRow("Email", widget.profileData["email"]),
                    _buildDetailRow("Phone", widget.profileData["phoneNumber"]),
                    _buildDetailRow(
                        "Instagram", widget.profileData["instagram"]),
                    _buildDetailRow("LinkedIn", widget.profileData["linkedin"]),
                    _buildDetailRow("Twitter", widget.profileData["twitter"]),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: saveProfile, child: Text("Save"))
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, color: Colors.white)),
          Text(
            value ?? "N/A",
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
