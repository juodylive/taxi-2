// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:zearah_rider/core/services/data_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:latlong2/latlong.dart';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;

import '../../../core/extensions/workspace.dart';
import '../general_cubit.dart';
import 'set_marker_cubit.dart' show AppMarker;

const String osrmBaseUrl = 'http://158.101.231.22:5000';

abstract class DriverNearByState extends Equatable {
  @override
  List<Object?> get props => [];
}

class DriverInitial extends DriverNearByState {}

class DriverLoading extends DriverNearByState {}

class DriverUpdated extends DriverNearByState {
  final List<Map<String, dynamic>>? nearbyDrivers;
  final bool? checkRestart;

  DriverUpdated({this.nearbyDrivers, this.checkRestart});

  @override
  List<Object?> get props => [nearbyDrivers];
}

class DriverUpdatedRestart extends DriverNearByState {
  final List<Map<String, dynamic>> nearbyDrivers;

  DriverUpdatedRestart(this.nearbyDrivers);

  @override
  List<Object?> get props => [nearbyDrivers];
}

class DriverError extends DriverNearByState {
  final String error;
  DriverError(this.error);

  @override
  List<Object?> get props => [error];
}

class DriverNearByCubit extends Cubit<DriverNearByState> {
  DriverNearByCubit() : super(DriverInitial());

  final FirebaseFirestore firestore = FirebaseFirestore.instance;


  Future<void> getNearbyDrivers(
      {double? pickupLat,
        double? pickupLng,
        String? vehicleTypeId,
        double? distance,
        bool? checkRestart}) async {
    emit(DriverLoading());
    final rideId = box.get("rideId");



    try {

      double degreesToRadians(double degrees) {
        return degrees * pi / 180;
      }
      double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
        const double earthRadius = 6371.0; // Earth radius in kilometers

        final double dLat = degreesToRadians(lat2 - lat1);
        final double dLon = degreesToRadians(lon2 - lon1);

        final double a = sin(dLat / 2) * sin(dLat / 2) +
            cos(degreesToRadians(lat1)) *
                cos(degreesToRadians(lat2)) *
                sin(dLon / 2) *
                sin(dLon / 2);

        final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

        return earthRadius * c;
      }


      final collectionRef = firestore.collection('drivers');
      final center = GeoFirePoint(GeoPoint(
        pickupLat ?? 0.0,
        pickupLng ?? 0.0,
      ));



      final geoCollection = GeoCollectionReference(collectionRef);


      final docs = await geoCollection.fetchWithin(
        center: center,
        radiusInKm: distance ?? 15.0,
        field: 'geo',
        geopointFrom: (data) {
          final geo = data['geo'] as Map<String, dynamic>?;
          return geo?['geopoint'] as GeoPoint;
        },
        strictMode: true,
        queryBuilder: (query) => query
            .where('driverStatus', isEqualTo: 'active')
            .where("docApprovedStatus", isEqualTo: 'approved')
            .where("itemTypeId", isEqualTo: vehicleTypeId)
            .where("rideStatus", isEqualTo: 'available'),
      );




     
      final nearbyDrivers = docs.map((doc) {
        final data = doc.data();
        if (data == null) return null;

        final geoData = data['geo'] as Map<String, dynamic>?;
        final geopoint = geoData?['geopoint'] as GeoPoint?;
        final rejectedRides = data['rejected_rides'] as List<dynamic>? ?? [];
        final timestamp = data['timestamp'];

        if (rejectedRides.contains(rideId)) {
          return null;
        }

        // 🔥 Check timestamp validity
        final context = navigatorKey.currentContext;
        if (context != null) {
          final lastActiveState = context.read<LastActiveApp>().state.value;

          if (lastActiveState != null && lastActiveState.toString() != "0" && lastActiveState.toString().isNotEmpty) {
            debugPrint('Using Last active: $lastActiveState');

            if (timestamp is Timestamp) {
              final lastUpdate = timestamp.toDate();
              final now = DateTime.now();
              final difference = now.difference(lastUpdate).inMinutes;

              if (difference > 20) {
                debugPrint("Driver ${doc.id} removed: last update $difference min ago");
                return null;
              }
            } else {
              debugPrint("Driver ${doc.id} removed: no valid timestamp found");
              return null;
            }
          } else {
            debugPrint("Driver ${doc.id} skipped: LastActiveApp is empty or 0");
          }
        } else {
          debugPrint("No valid context found — skipping driver ${doc.id}");
        }

        if (geopoint != null) {
          final distanceInKm = calculateDistance(
            pickupLat ?? 0.0,
            pickupLng ?? 0.0,
            geopoint.latitude,
            geopoint.longitude,
          );

          return {
            'id': doc.id,
            'latitude': geopoint.latitude,
            'longitude': geopoint.longitude,
            'distance': distanceInKm,
            ...data,
          };
        }

        return null;
      }).whereType<Map<String, dynamic>>().toList();


      nearbyDrivers.sort((a, b) {
        final distanceA = a['distance'] as double;
        final distanceB = b['distance'] as double;
        return distanceA.compareTo(distanceB);
      });
      final nearestDrivers = nearbyDrivers.take(20).toList();

      debugPrint('Nearest 20 Drivers: ${nearestDrivers.length}');
      debugPrint('all nearbyDrivers ${nearbyDrivers.length}');


      if (navigatorKey.currentContext!
          .read<UseGoogleSourceDestination>()
          .state
          .value ==
          "1") {
        List<Map<String, dynamic>> finalFilteredDrivers = [];

        List<List<Map<String, dynamic>>> chunkDrivers(
            List<Map<String, dynamic>> list, int chunkSize) {
          List<List<Map<String, dynamic>>> chunks = [];
          for (var i = 0; i < list.length; i += chunkSize) {
            chunks.add(list.sublist(
                i, i + chunkSize > list.length ? list.length : i + chunkSize));
          }
          return chunks;
        }

        final driverChunks = chunkDrivers(nearestDrivers, 25);


        final futures = driverChunks.map((chunk) async {
          // Build OSRM /table coordinates: drivers first, destination last
          final coordParts = <String>[];
          for (final driver in chunk) {
            coordParts.add("${driver['longitude']},${driver['latitude']}");
          }
          coordParts.add("$pickupLng,$pickupLat");

          final coordsStr = coordParts.join(';');
          final destIndex = chunk.length;
          final sourcesStr =
              List.generate(chunk.length, (i) => i.toString()).join(';');

          final String url =
              "$osrmBaseUrl/table/v1/driving/$coordsStr?sources=$sourcesStr&destinations=$destIndex&annotations=distance";

          List<Map<String, dynamic>> filtered = [];

          try {
            final response = await http.get(Uri.parse(url));

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              if (data['code'] == 'Ok') {
                final distances = data['distances'] as List;

                for (int i = 0; i < distances.length; i++) {
                  final distanceMeters = distances[i][0];
                  if (distanceMeters != null) {
                    final distanceKm = (distanceMeters as num) / 1000;
                    if (distanceKm <= distance) {
                      filtered.add(chunk[i]);
                    }
                  }
                }
              }
            }
          } catch (_) {
            // If OSRM is unreachable, fall back to including the whole chunk
            // (straight-line distance was already applied earlier).
            filtered.addAll(chunk);
          }

          return filtered;
        }).toList();


        final results = await Future.wait(futures);

        for (var list in results) {
          finalFilteredDrivers.addAll(list);
        }

        emit(DriverUpdated(
            nearbyDrivers: finalFilteredDrivers, checkRestart: checkRestart));

        debugPrint(
            "Filtered ${finalFilteredDrivers.length} drivers within $distance km route using OSRM");
      } else {
        emit(DriverUpdated(nearbyDrivers: nearestDrivers, checkRestart: checkRestart));
        debugPrint(
            "Filtered ${nearestDrivers.length} drivers within $distance km route using geoLocation");
      }


    } catch (e) {
      emit(DriverError(e.toString()));
      debugPrint("Error fetching nearby drivers (once): $e");
    }
  }


  resetNearByDriverState() {
    emit(DriverInitial());
  }
}

// Driver States
abstract class DriverMapState extends Equatable {
  @override
  List<Object?> get props => [];
}

class DriverMapInitial extends DriverMapState {}

class DriverMapLoading extends DriverMapState {
  final Set<AppMarker> markers;
  DriverMapLoading(this.markers);

  @override
  List<Object?> get props => [markers];
}

class DriverMapUpdated extends DriverMapState {
  final Set<AppMarker> markers;
  DriverMapUpdated(this.markers);

  @override
  List<Object?> get props => [markers];
}

class DriverMapError extends DriverMapState {
  final String error;
  DriverMapError(this.error);

  @override
  List<Object?> get props => [error];
}

class DriverMapCubit extends Cubit<DriverMapState> {
  DriverMapCubit() : super(DriverMapInitial());

  Future<void> updateMapWithNearbyDrivers({
    required BuildContext context,
    required double sourcelat,
    required double sourcelng,
    required double destinationlat,
    required double destinationlng,
    required String pickupImage,
    required String dropOffImage,
    required List<Map<String, dynamic>> nearbyDrivers,
  }) async {

    try {
      final Uint8List markerIconDropOff =
          await getBytesFromAsset(dropOffImage, 15);
      final Uint8List markerIconPickUp =
          await getBytesFromAsset(pickupImage, 15);

      Set<AppMarker> markers = {};
      markers.add(AppMarker(
        markerId: 'pickup',
        position: LatLng(sourcelat, sourcelng),
        title: 'Pickup Location',
        icon: markerIconPickUp,
      ));

      markers.add(AppMarker(
        markerId: 'dropoff',
        position: LatLng(destinationlat, destinationlng),
        title: 'Dropoff Location',
        icon: markerIconDropOff,
      ));

      emit(DriverMapUpdated(markers));
    } catch (e) {

      emit(DriverMapError(e.toString()));
    }
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  void resetState() {
    emit(DriverMapInitial());
  }
}

abstract class GetPolylineState extends Equatable {
  @override
  List<Object?> get props => [];
}

class GetPolylineInitial extends GetPolylineState {}

class GetPolylineLoading extends GetPolylineState {
  final Map<String, List<LatLng>> polylines;
  GetPolylineLoading(this.polylines);

  @override
  List<Object?> get props => [polylines];
}

class GetPolylineUpdated extends GetPolylineState {
  final Map<String, List<LatLng>>? polylines;
  GetPolylineUpdated({this.polylines});

  @override
  List<Object?> get props => [polylines];
}

class GetPolylineUpdatedError extends GetPolylineState {
  final String error;
  GetPolylineUpdatedError(this.error);

  @override
  List<Object?> get props => [error];
}

class GetPolylineCubit extends Cubit<GetPolylineState> {
  GetPolylineCubit() : super(GetPolylineInitial());

  final Map<String, List<LatLng>> _polylines = {};

  Future<void> getPolyline({
    required double sourcelat,
    required double sourcelng,
    required double destinationlat,
    required double destinationlng,
    required bool isPickupRoute, // true for pickup, false for dropoff
  }) async {
    try {
      if (sourcelat == 0.0 ||
          sourcelng == 0.0 ||
          destinationlat == 0.0 ||
          destinationlng == 0.0) {
        emit(GetPolylineUpdatedError("Invalid coordinates"));
        return;
      }

      emit(GetPolylineLoading(Map.from(_polylines)));

      final url = Uri.parse(
          '$osrmBaseUrl/route/v1/driving/$sourcelng,$sourcelat;$destinationlng,$destinationlat?overview=full&geometries=geojson');

      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (data['code'] == 'Ok') {
        final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
        final polylineCoordinates = coordinates
            .map<LatLng>((point) => LatLng(point[1] as double, point[0] as double))
            .toList();

        final String polylineId =
            isPickupRoute ? "DriverPickupToUser" : "DriverDropoffToUser";
        final String oppositePolylineId =
            isPickupRoute ? "DriverDropoffToUser" : "DriverPickupToUser";

        _polylines.remove(oppositePolylineId);
        _polylines[polylineId] = polylineCoordinates;

        emit(GetPolylineUpdated(polylines: Map.from(_polylines)));
      } else {
        emit(GetPolylineUpdatedError(
            data['message']?.toString() ?? "Failed to get polyline"));
      }
    } catch (e) {
      emit(GetPolylineUpdatedError("Exception: $e"));
    }
  }

  Map<String, List<LatLng>> get currentPolylines => Map.from(_polylines);

  void resetPolylines() {
    _polylines.clear();
    emit(GetPolylineInitial());
  }
}
