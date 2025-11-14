import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:littlebird/models/chat_message.dart'; // Make sure this path is correct

// Represents a discovered user before connection
class DiscoveredUser {
  final String id;
  final String userName;
  DiscoveredUser({required this.id, required this.userName});
}

class NearbyService with ChangeNotifier {
  final Strategy _strategy = Strategy.P2P_STAR;
  final Nearby _nearby = Nearby();
  final String _selfUserName;

  Map<String, DiscoveredUser> _discoveredUsers = {};
  String? _connectedEndpointId;
  String? _connectedEndpointName;
  bool _permissionsGranted = false; // Flag to track permissions

  final _messageStreamController = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get messageStream => _messageStreamController.stream;

  // Constructor
  NearbyService(this._selfUserName);

  // --- Public Getters ---
  bool get isConnected => _connectedEndpointId != null;
  String? get connectedUserName => _connectedEndpointName;
  List<DiscoveredUser> get discoveredUsers => _discoveredUsers.values.toList();

  // --- Core Logic ---

  Future<bool> _requestPermissions() async {
    // Request all permissions at once
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.nearbyWifiDevices,
      Permission.storage, // For saving files
      Permission.photos, // For picking photos
    ].request();

    // Check if all permissions are granted
    bool allGranted = statuses.values.every((status) => status.isGranted);
    _permissionsGranted = allGranted; // Set the flag
    return allGranted;
  }

  /// Call this once to request permissions and start services.
  Future<void> initializeService() async {
    // Only request if we haven't already
    if (!_permissionsGranted) {
      bool granted = await _requestPermissions();
      if (!granted) {
        print("NearbyService: Permissions not granted. Services not starting.");
        return;
      }
    }

    print("NearbyService: Permissions granted. Starting services.");
    // Now that we know we have permissions, start the services
    await startAdvertising();
    await startDiscovery();
  }

  Future<void> startDiscovery() async {
    if (!_permissionsGranted) {
      print("NearbyService: Cannot start discovery. Permissions not granted.");
      return;
    }

    try {
      _discoveredUsers.clear();
      notifyListeners();
      await _nearby.startDiscovery(
        _selfUserName,
        _strategy,
        onEndpointFound: (id, name, serviceId) {
          // A new user is found
          if (!_discoveredUsers.containsKey(id)) {
            print("NearbyService: Endpoint found: $name ($id)");
            _discoveredUsers[id] = DiscoveredUser(id: id, userName: name);
            notifyListeners();
          }
        },
        onEndpointLost: (id) {
          // A user is no longer visible
          if (_discoveredUsers.containsKey(id)) {
            print("NearbyService: Endpoint lost: $id");
            _discoveredUsers.remove(id);
            notifyListeners();
          }
        },
      );
      print("NearbyService: Discovery started.");
    } catch (e) {
      print("NearbyService: Error starting discovery: $e");
    }
  }

  Future<void> stopDiscovery() async {
    await _nearby.stopDiscovery();
    _discoveredUsers.clear();
    notifyListeners();
    print("NearbyService: Discovery stopped.");
  }

  Future<void> startAdvertising() async {
    if (!_permissionsGranted) {
      print("NearbyService: Cannot start advertising. Permissions not granted.");
      return;
    }

    try {
      await _nearby.startAdvertising(
        _selfUserName,
        _strategy,
        onConnectionInitiated: (id, info) {
          // Someone wants to connect
          print("NearbyService: Connection initiated from $id (${info.endpointName})");
          // Automatically accept the connection
          _nearby.acceptConnection(id, onPayLoadRecieved: _onPayloadReceived);
          _connectedEndpointName = info.endpointName;
          _connectedEndpointId = id;
          notifyListeners();
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            print("NearbyService: Successfully connected to $_connectedEndpointName");
            _connectedEndpointId = id;
            _nearby.stopAdvertising();
            _nearby.stopDiscovery();
            notifyListeners();
          } else if (status == Status.ERROR || status == Status.REJECTED) {
            print("NearbyService: Connection failed or rejected.");
            _connectedEndpointId = null;
            _connectedEndpointName = null;
            notifyListeners();
          }
        },
        onDisconnected: (id) {
          print("NearbyService: Disconnected from $id");
          _connectedEndpointId = null;
          _connectedEndpointName = null;
          notifyListeners();
          // Restart discovery and advertising
          startAdvertising();
          startDiscovery();
        },
      );
      print("NearbyService: Advertising started.");
    } catch (e) {
      print("NearbyService: Error starting advertising: $e");
    }
  }

  Future<void> stopAdvertising() async {
    await _nearby.stopAdvertising();
    print("NearbyService: Advertising stopped.");
  }

  Future<void> connect(DiscoveredUser user) async {
    if (isConnected) return;

    try {
      print("NearbyService: Requesting connection to ${user.userName} (${user.id})");
      await _nearby.requestConnection(
        _selfUserName,
        user.id,
        onConnectionInitiated: (id, info) {
          // Connection initiated
          print("NearbyService: Connection initiated to $id (${info.endpointName})");
          _nearby.acceptConnection(id, onPayLoadRecieved: _onPayloadReceived);
          _connectedEndpointName = info.endpointName;
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            print("NearbyService: Successfully connected to $_connectedEndpointName");
            _connectedEndpointId = id;
            _nearby.stopAdvertising();
            _nearby.stopDiscovery();
            notifyListeners();
          } else if (status == Status.ERROR || status == Status.REJECTED) {
            print("NearbyService: Connection failed or rejected.");
            _connectedEndpointId = null;
            _connectedEndpointName = null;
            notifyListeners();
          }
        },
        onDisconnected: (id) {
          print("NearbyService: Disconnected from $id");
          _connectedEndpointId = null;
          _connectedEndpointName = null;
          notifyListeners();
          // Restart discovery and advertising
          startAdvertising();
          startDiscovery();
        },
      );
    } catch (e) {
      print("NearbyService: Error connecting: $e");
    }
  }

  Future<void> disconnect() async {
    if (_connectedEndpointId != null) {
      await _nearby.disconnectFromEndpoint(_connectedEndpointId!);
      _connectedEndpointId = null;
      _connectedEndpointName = null;
      notifyListeners();
      print("NearbyService: Disconnected.");
    }
    // Restart services
    startAdvertising();
    startDiscovery();
  }

  void _onPayloadReceived(String endpointId, Payload payload) async {
    if (payload.type == PayloadType.BYTES) {
      // This is a TEXT message
      try {
        String text = utf8.decode(payload.bytes!);
        final message = ChatMessage.text(
          text: text,
          timestamp: DateTime.now(),
          isMe: false,
        );
        _messageStreamController.add(message);
        print("NearbyService: Text message received: $text");
      } catch (e) {
        print("NearbyService: Error decoding text payload: $e");
      }
    } else if (payload.type == PayloadType.FILE) {
      // This is an IMAGE file
      try {
        if (payload.filePath == null) {
          print("NearbyService: Error: Received file payload with no filePath.");
          return;
        }

        // The file is in a temporary location. We need to copy it.
        final File tempFile = File(payload.filePath!);
        final Directory appDir = await getApplicationDocumentsDirectory();

        // Create a unique name to avoid conflicts
        final String newFileName = 'nearby_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String newPath = '${appDir.path}/$newFileName';

        // Copy the file to our app's permanent storage
        await tempFile.copy(newPath);
        await tempFile.delete(); // Clean up the temp file

        final message = ChatMessage.image(
          filePath: newPath,
          timestamp: DateTime.now(),
          isMe: false,
        );
        _messageStreamController.add(message);
        print("NearbyService: Image received and saved to: $newPath");
      } catch (e) {
        print("NearbyService: Error handling file payload: $e");
      }
    }
  }

  void sendTextMessage(String text) {
    if (_connectedEndpointId != null) {
      try {
        _nearby.sendBytesPayload(
            _connectedEndpointId!,
            Uint8List.fromList(utf8.encode(text)));
        print("NearbyService: Text message sent: $text");
      } catch (e) {
        print("NearbyService: Error sending text message: $e");
      }
    }
  }

  // --- ADDED this new method for sending images ---
  Future<void> sendImageFile(File file) async {
    if (_connectedEndpointId != null) {
      try {
        // This will send the file and notify onPayloadTransferUpdate
        await _nearby.sendFilePayload(_connectedEndpointId!, file.path);
        print("NearbyService: Image sent: ${file.path}");
      } catch (e) {
        print("NearbyService: Error sending image file: $e");
      }
    }
  }

  void dispose() {
    stopAdvertising();
    stopDiscovery();
    if (_connectedEndpointId != null) {
      _nearby.disconnectFromEndpoint(_connectedEndpointId!);
    }
    _nearby.stopAllEndpoints();
    _messageStreamController.close();
  }
}