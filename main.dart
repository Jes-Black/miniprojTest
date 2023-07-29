import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity/connectivity.dart';
import 'package:turncue/utils/constants.dart';
import 'package:turncue/pages/home_page.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.light,
    ));
    return GetMaterialApp(
      title: 'TurnCue',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: InitializationScreen(),
    );
  }
}

class InitializationScreen extends StatefulWidget {
  const InitializationScreen({Key? key}) : super(key: key);

  @override
  _InitializationScreenState createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen>
    with SingleTickerProviderStateMixin {
  bool isDataServiceOn = false;
  bool isLocationServiceOn = false;
  bool isBluetoothServiceOn = false;
  bool isTurnCuePaired = false;
  bool isScanning = false;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _initializeServices();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _stopCheckingServices();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    _startCheckingServices();
    _checkLocationService(); // Check location service status once initially
  }

  Future<void> _checkDataService() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      isDataServiceOn = connectivityResult != ConnectivityResult.none;
    });
  }

  StreamSubscription<Position>? _locationSubscription;

  Future<void> _checkLocationService() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        isLocationServiceOn =
            false; // Set location status to false if service is disabled
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          isLocationServiceOn =
              false; // Set location status to false if permission is denied
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        isLocationServiceOn =
            false; // Set location status to false if permission is denied forever
      });
      return;
    }

    setState(() {
      isLocationServiceOn =
          true; // Set location status to true if location service is enabled and permission is granted
    });

    // Start listening to location changes
    _locationSubscription = Geolocator.getPositionStream().listen((position) {
      // You can use the `position` object if you need to access the current location.
      // This callback will be called whenever the location changes.
    });
  }

  Future<void> _checkBluetoothService() async {
    bool isBluetoothOn =
        (await FlutterBluetoothSerial.instance.isEnabled) ?? false;
    setState(() {
      isBluetoothServiceOn = isBluetoothOn;
    });
  }

  Future<void> _checkTurnCuePaired() async {
    List<BluetoothDevice> bondedDevices =
        await FlutterBluetoothSerial.instance.getBondedDevices();
    bool isPaired = false;

    for (var device in bondedDevices) {
      if (device.name == "TURN_CUE") {
        isPaired = true;
        break;
      }
    }

    setState(() {
      isTurnCuePaired = isPaired;
    });
  }

  void _startCheckingServices() {
    const duration = Duration(seconds: 2);
    Timer.periodic(duration, (Timer timer) async {
      await _checkDataService();
      await _checkLocationService();
      await _checkBluetoothService();
      await _checkTurnCuePaired();

      if (isDataServiceOn &&
          isLocationServiceOn &&
          isBluetoothServiceOn &&
          isTurnCuePaired) {
        timer.cancel();
        _proceedToHomePage();
      }
    });
  }

  void _stopCheckingServices() {
    _locationSubscription?.cancel();
  }

  void _proceedToHomePage() {
    Future.delayed(Duration(seconds: 2)).then((_) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(Constants.logo,
                width: 200, height: 150, fit: BoxFit.fitHeight),
            Image.asset(Constants.logomini,
                width: 300, height: 150, fit: BoxFit.fitWidth),
            SizedBox(height: 20),
            AnimatedTextKit(
              animatedTexts: [
                TypewriterAnimatedText(
                  'Initializing...',
                  textStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF02558a),
                  ),
                  speed: const Duration(milliseconds: 200),
                ),
              ],
            ),
            SizedBox(height: 20),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  _buildStatusTile('Data service status', isDataServiceOn),
                  _buildStatusTile(
                      'Location service status', isLocationServiceOn),
                  _buildStatusTile(
                      'Bluetooth service status', isBluetoothServiceOn),
                  _buildStatusTile(
                      'turnCue vest pairing status', isTurnCuePaired),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildStatusTile(String title, bool isOn) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        if (isOn)
          Icon(Icons.check_circle, color: Colors.green)
        else
          Icon(Icons.cancel, color: Colors.red),
      ],
    ),
  );
}
