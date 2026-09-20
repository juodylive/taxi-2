import 'dart:async';
import 'dart:typed_data';
import 'package:zearah_rider/core/extensions/workspace.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../cubits/location/set_marker_cubit.dart' show AppMarker;
import 'package:zearah_rider/core/utils/translate.dart';
import 'package:zearah_rider/presentation/screens/search/send_ride_request_screen.dart';
import '../../../core/services/data_store.dart';
import '../../../core/utils/common_widget.dart';
import '../../../core/utils/theme/project_color.dart';
import '../../cubits/book_ride_cubit.dart';
import '../../cubits/location/get_item_price_cubit.dart';
import '../../cubits/location/get_nearby_drivers_cubit.dart';
import '../../cubits/realtime/ride_request_cubit.dart';
import '../../cubits/vehicle_data/get_vehicle_cetgegory_cubit.dart';

class SelectionVehicleScreen extends StatefulWidget {
  final Map<String, List<LatLng>> polylines;
  final List<Map<String, dynamic>> fareList;

  const SelectionVehicleScreen({
    super.key,
    required this.polylines,
    required this.fareList,
  });

  @override
  State<SelectionVehicleScreen> createState() => _SelectionVehicleScreenState();
}

class _SelectionVehicleScreenState extends State<SelectionVehicleScreen> {
  String selectedLat = "28.5868";
  String selectedLong = "77.3152";
  final AppMapController mapController = AppMapController();
  bool isLoadingOnMap = false;
  int selectedIdIndex = -1;
  double traveCharge = 0.0;
  int setIndex=-1;


  Map<String,dynamic> selectedVehicleData={};

  Map<String, List<LatLng>> _polylines = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool isRequestInProgress = false;

  @override
  void initState() {
    super.initState();
    _polylines = widget.polylines;
    selectedIdIndex =
        context.read<VehicleDataUpdateCubit>().state.vehicleSelectedId;
    addMarkers();
  }



  Future<void> addMarkers()async{
    final Uint8List markerIconDropOff =
    await getBytesFromAsset("assets/images/dropmarker.png", 15);
    Uint8List markerIconPickUp =
    await getBytesFromAsset("assets/images/pickupmarker.png", 15);
    // ignore: use_build_context_synchronously
    final bookRideState = context.read<BookRideRealTimeDataBaseCubit>().state;
    markers.add(AppMarker(
      markerId: 'pickup',
      position: LatLng(double.parse(bookRideState.pickupAddressLatitude), double.parse(bookRideState.pickupAddressLongitude)),
      title: 'Pickup Location',
      icon: markerIconPickUp,
    ));


    markers.add(AppMarker(
      markerId: 'dropoff',
      position: LatLng(double.parse(bookRideState.dropoffAddressLatitude), double.parse(bookRideState.dropoffAddressLongitude)),
      title: 'Dropoff Location',
      icon: markerIconDropOff,
    ));
    moveMapAccordingPoline();


    setState(() {

    });
  }

  void moveMapAccordingPoline() {
    final polylinePoints = _polylines.values.expand((points) => points).toList();

    final markerPositions = markers.map((m) => m.position).toList();

    final List<LatLng> allPoints = [...polylinePoints, ...markerPositions];

    if (allPoints.isNotEmpty) {
      try {
        mapController.fitBounds(allPoints);
      } catch (_) {}
    }
  }

  void zoomIn() {
    mapController.zoomIn();
  }

  void zoomOut() {
    mapController.zoomOut();
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
  Set<AppMarker> markers={};

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        body:Stack(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height / 1.6,
              child: Stack(
                children: [
                  FlutterMap(
                    key: const ValueKey('flutter_map'),
                    mapController: mapController.raw,
                    options: MapOptions(
                      initialCenter: LatLng(
                        double.parse(context
                            .read<BookRideRealTimeDataBaseCubit>()
                            .state
                            .pickupAddressLatitude),
                        double.parse(context
                            .read<BookRideRealTimeDataBaseCubit>()
                            .state
                            .pickupAddressLongitude),
                      ),
                      initialZoom: 12,
                      onMapReady: () {
                        moveMapAccordingPoline();
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            "https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}{r}.png?api_key=7fd22148-c7d7-4f1f-b33f-677c8dbc8496",
                        userAgentPackageName: 'com.zearah.rider',
                      ),
                      if (_polylines.values.isNotEmpty)
                        PolylineLayer(
                          polylines: _polylines.values
                              .map((points) => Polyline(
                                    points: points,
                                    strokeWidth: 4,
                                    color: Colors.blue,
                                  ))
                              .toList(),
                        ),
                      MarkerLayer(
                        markers: markers
                            .map((m) => Marker(
                                  point: m.position,
                                  width: 48,
                                  height: 48,
                                  child: Image.memory(m.icon),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 60,
                    left: 30,
                    right: 30,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () {
                            goBack();
                          },
                          child: Container(
                            height: 40,
                            width: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: notifires.getbgcolor,
                              border:
                              Border.all(color: notifires.getGrey3whiteColor),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 5),
                              child: Icon(
                                Icons.arrow_back,
                                size: 18,
                                color: notifires.getwhiteblackColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.55,
              minChildSize: 0.45,
              maxChildSize: 0.85,
              builder: (context, scrollController) {
                return SafeArea(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ListView(
                      controller:
                      scrollController, // ✅ Required for drag + scroll
                      children: [
                        const SizedBox(height: 10),
                        Center(
                          child: Container(
                            width: 50,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Pickup & Drop UI
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: notifires.getBoxColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                buildLocationRow(
                                  icon: Icons.circle,
                                  color: Colors.green,
                                  bgColor: Colors.green.shade100,
                                  text: context
                                      .read<BookRideRealTimeDataBaseCubit>()
                                      .state
                                      .pickupAddress,
                                  context: context,
                                ),
                                const SizedBox(height: 10),
                                buildLocationRow(
                                  icon: Icons.location_on_outlined,
                                  color: Colors.red,
                                  bgColor: Colors.red.shade100,
                                  text: context
                                      .read<BookRideRealTimeDataBaseCubit>()
                                      .state
                                      .dropoffAddress,
                                  context: context,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        Divider(
                          color: grey5,
                        ),

                        const SizedBox(height: 10),

                        ListView.builder(
                          shrinkWrap: true,
                          physics:
                          const NeverScrollableScrollPhysics(), // Prevent nested scroll
                          itemCount: widget.fareList.length,
                          itemBuilder: (context, index) {
                            final data = widget.fareList[index];
                            final isSelected = selectedIdIndex == data["id"];

                            final fares = context
                                .watch<GetDistanceRouteCubit>()
                                .state
                                .vehicleFares;
                            final hasFares = fares.length > index &&
                                fares[index].isNotEmpty;

                            final fare = hasFares
                                ? fares[index]["fare"] ?? "NA"
                                : "NA";
                            final duration = hasFares
                                ? fares[index]["duration"]?? "NA"
                                : "NA";
                            final distance = hasFares
                                ? fares[index]["distance"] ?? "0"
                                : "0";

                            if (isSelected) {
                              setIndex=index;
                              traveCharge =
                                  double.tryParse(fare.toString()) ?? 0.0;



                            }

                            return GestureDetector(
                              onTap: () {
                                if (!isSelected) {
                                  setState(() {
                                    setIndex=index;
                                    selectedIdIndex = data["id"]!;
                                    context
                                        .read<VehicleDataUpdateCubit>()
                                        .updateVehicleTypeSelectedId(
                                       
                                      data["id"],
                                    );
                                    // _updateMapWithDrivers();
                                  });
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? themeColor
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 80,
                                          height: 40,
                                          child: Image.network(
                                            data["image"],
                                            fit: BoxFit.contain,
                                            
                                            errorBuilder: (_, __, ___) =>
                                                SvgPicture.asset(
                                                    "assets/images/car.svg"),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          data["vehicleName"] ?? "Unknown".translate(context),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: blackColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (hasFares)
                                      Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            "$currency $fare",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: blackColor,
                                            ),
                                          ),
                                          Text(
                                            "$duration ($distance ${"Km".translate(context)})",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: grey2,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Book Now Button
                      ],
                    ),
                  ),
                );
              },
            )
          ],
        ),
        bottomNavigationBar: selectedIdIndex != -1
            ? SizedBox(
            height: 75,
            child: Container(
              padding: const EdgeInsets.only(
                  left: 16, right: 15, bottom: 20, top: 5),
              color: notifires.getbgcolor,
              child: CustomsButtons(
                text: isRequestInProgress
                    ? "Requesting...".translate(context)
                    : "Book Now".translate(context),
                textColor: blackColor,
                backgroundColor:
                isRequestInProgress ? Colors.grey : themeColor,
                onPressed: () {

                  if (selectedIdIndex == -1) {
                    showErrorToastMessage(
                        "Please select a vehicle type."
                            .translate(context));
                    return;
                  }
                  context.read<BookRideUserCubit>().removeBookRideState();
                  context.read<DriverNearByCubit>().resetNearByDriverState();
                  context.read<RideRequestCubit>().resetState();
                  box.delete("rideId");


                  goTo(SendRideRequestScreen(selectedVehicleData: widget.fareList[setIndex], statusOfRide: "",));


                },
              ),
            ))
            : null,
      ),
    );
  }

  void updateRide({String? rideId, String? bookingId}) {
    final rideRequestRef =
    FirebaseDatabase.instance.ref().child("ride_requests");
    if (rideId != null &&
        rideId.isNotEmpty &&
        bookingId != null &&
        bookingId.isNotEmpty) {
      rideRequestRef.child(rideId).update({
        'bookingId': bookingId,
        'status': 'Confirmed',
      }).then((_) {
        debugPrint("Ride updated successfully.");
      }).catchError((error) {
        debugPrint("Failed to update ride: $error");
        showErrorToastMessage("Failed to update ride.");
      });
    }
  }
}
