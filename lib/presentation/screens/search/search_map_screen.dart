import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:zearah_rider/core/utils/translate.dart';
import '../../../core/utils/common_widget.dart';
import '../../../core/utils/theme/project_color.dart';
import '../../../core/utils/theme/theme_style.dart';
import '../../cubits/book_ride_cubit.dart';
import '../../cubits/location/user_current_location_cubit.dart';

class SearchMapScreen extends StatefulWidget {
  final String? selectedAddressTitle;
  final bool? checkStatus;
  const SearchMapScreen(
      {super.key, this.selectedAddressTitle, this.checkStatus});
  @override
  State<SearchMapScreen> createState() => _SearchMapScreenState();
}

class _SearchMapScreenState extends State<SearchMapScreen> {
  double selectedMapLat = 28.5865;
  double selectedMapLng = 77.3152;
  final AppMapController mapController = AppMapController();
  TextEditingController textEditingAddressSearchController =
      TextEditingController();
  FocusNode focusNode1 = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      selectedMapLat = double.parse(context
          .read<BookRideRealTimeDataBaseCubit>()
          .state
          .pickupAddressLatitude);
      selectedMapLng = double.parse(context
          .read<BookRideRealTimeDataBaseCubit>()
          .state
          .pickupAddressLongitude);

      textEditingAddressSearchController.clear();
      mapController.moveTo(LatLng(selectedMapLat, selectedMapLng));
    });
    focusNode1.addListener(() {
      if (!focusNode1.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });
    super.initState();
  }

  void _zoomIn() {
    mapController.zoomIn();
  }

  void _zoomOut() {
    mapController.zoomOut();
  }

  void _moveToCurrentLocation({LatLng? currentLocation}) {
    if (currentLocation == null) return;
    selectedMapLat = currentLocation.latitude;
    selectedMapLng = currentLocation.longitude;
    mapController.moveTo(currentLocation);
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isEmpty) {
        context.read<GetSuggestionAddressCubit>().getSuggestions("");
        setState(() => _showSuggestions = false);
        return;
      }
      context.read<GetSuggestionAddressCubit>().getSuggestions(query);
      setState(() => _showSuggestions = true);
    });
  }

  void _onSuggestionTap(String suggestion) async {
    textEditingAddressSearchController.text = suggestion;
    setState(() => _showSuggestions = false);
    focusNode1.unfocus();
    context.read<GetCordinatesCubit>().getCoordinates(address: suggestion);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchDebounce?.cancel();
    mapController.dispose();
    super.dispose();
  }

  Timer? _debounce;
  Timer? _searchDebounce;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<GetCordinatesCubit, GetCordinatesState>(
          listener: (context, state) {
            if (state is GetCordinatesSuccess) {
              final lat = double.tryParse(state.lattiude ?? "");
              final lng = double.tryParse(state.longitude ?? "");
              if (lat != null && lng != null) {
                _moveToCurrentLocation(currentLocation: LatLng(lat, lng));
              }
            }
          },
        ),
      ],
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          toolbarHeight: 55,
          elevation: 0,
          surfaceTintColor: Colors.white,
          backgroundColor: Colors.white,
          centerTitle: true,
          title: Text(
              widget.checkStatus == true
                  ? "Pickup Location".translate(context)
                  : "Drop-off Location".translate(context),
              style: headingBlack(context)
                  .copyWith(fontSize: 18, color: blackColor)),
          leadingWidth: 80,
          leading: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            child: InkWell(
              onTap: () {
                Navigator.of(context).pop();
              },
              child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: notifires.getbgcolor,
                      border:
                          Border.all(color: notifires.getGrey3whiteColor)),
                  child: Icon(Icons.arrow_back,
                      size: 20, color: notifires.getwhiteblackColor)),
            ),
          ),
          bottom: PreferredSize(
              preferredSize: const Size(double.infinity, 60),
              child: Column(
                children: [
                  const SizedBox(
                    height: 10,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        bottom: 10, left: 20, right: 20),
                    child: SizedBox(
                      width: double.maxFinite,
                      height: 60,
                      child: TextField(
                        focusNode: focusNode1,
                        controller: textEditingAddressSearchController,
                        style: regularBlack(context).copyWith(fontSize: 14),
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: whiteColor,
                          prefixIcon: Icon(
                            Icons.location_on_outlined,
                            color: blackColor,
                          ),
                          hintStyle:
                              regular3(context).copyWith(color: blackColor),
                          hintText: "Search Address".translate(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: grey4),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: grey4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )),
        ),
        body: Stack(
          children: [
            BlocBuilder<UpdateSearchMapAddressCubit,
                UpdateSearchMapAddressState>(builder: (context, state) {
              if (state is UpdateSearchMapAddresSuccess) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  textEditingAddressSearchController.text =
                      state.currentAddress.toString();
                  context.read<UpdateSearchMapAddressCubit>().removeAddress();
                });
              }
              return FlutterMap(
                mapController: mapController.raw,
                options: MapOptions(
                  initialCenter: LatLng(selectedMapLat, selectedMapLng),
                  initialZoom: 14,
                  onPositionChanged: (position, hasGesture) {
                    if (position.center != null) {
                      selectedMapLat = position.center!.latitude;
                      selectedMapLng = position.center!.longitude;
                    }
                    if (hasGesture) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _debounce =
                          Timer(const Duration(milliseconds: 700), () {
                        context
                            .read<UpdateSearchMapAddressCubit>()
                            .removeAddress();
                        context
                            .read<UpdateSearchMapAddressCubit>()
                            .getAddressFromLatLng(
                                latitude: selectedMapLat,
                                longitude: selectedMapLng);
                      });
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}{r}.png?api_key=7fd22148-c7d7-4f1f-b33f-677c8dbc8496",
                    userAgentPackageName: 'com.zearah.rider',
                  ),
                ],
              );
            }),

            Positioned(
              top: 0,
              right: 0,
              bottom: 0, // Center vertically, offset by half icon height
              left: 0, // Center horizontally, offset by half icon width
              child: Transform.translate(
                offset: const Offset(0, -15),
                child: Center(
                  child: Image.asset(
                    "assets/images/dropmarker.png",
                    height: 34,
                    width: 34,
                    alignment: Alignment
                        .bottomCenter, // Ensure pin's tip points to the location
                  ),
                ),
              ),
            ),

            Positioned(
              top: 40,
              right: 16,
              child: zoomButton(
                icon: Icons.zoom_out,
                onPressed: () {
                  _zoomOut();
                },
              ),
            ),

            // **Zoom In Button**
            Positioned(
              top: 90,
              right: 16,
              child: zoomButton(
                icon: Icons.zoom_in,
                onPressed: () {
                  _zoomIn();
                },
              ),
            ),

            // Address suggestions dropdown (replaces google_places_flutter's built-in list)
            if (_showSuggestions)
              Positioned(
                top: 0,
                left: 20,
                right: 20,
                child: BlocBuilder<GetSuggestionAddressCubit,
                    GetSuggestionAddressState>(
                  builder: (context, state) {
                    final suggestions = state is GetSuggestionAddressSuccess
                        ? (state.suggestions ?? const <String>[])
                        : const <String>[];
                    if (suggestions.isEmpty) return const SizedBox();
                    return Container(
                      constraints: const BoxConstraints(maxHeight: 260),
                      decoration: BoxDecoration(
                        color: notifires.getbgcolor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 8),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: blackColor, thickness: 1),
                        itemBuilder: (context, index) {
                          final suggestion = suggestions[index];
                          return InkWell(
                            onTap: () => _onSuggestionTap(suggestion),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: blackColor,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      suggestion,
                                      style: regular2(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
        bottomNavigationBar: Container(
          color: whiteColor,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Quickly type your address or drop".translate(context),
                style: heading3Grey1(context),
              ),
              const SizedBox(height: 10),
              CustomsButtons(
                text: "Set Address",
                backgroundColor: themeColor,
                onPressed: () {
                  if (textEditingAddressSearchController.text.isNotEmpty) {
                    if (widget.checkStatus == true) {
                      context
                          .read<SelectedAddressCubit>()
                          .updateIsSelectePickupdAddress(
                              isCheckedSelectedPickup: true);
                      context
                          .read<SelectedAddressCubit>()
                          .updateIsSelectedDropOffAddress(
                              isCheckedSelectedDropOff: false);
                      context
                          .read<SelectedAddressCubit>()
                          .updateIsCrossIconSelectePickup(
                              icheckedCrossIconPickup: true);
                      context
                              .read<SelectedAddressCubit>()
                              .pickupAddressController
                              .text =
                          textEditingAddressSearchController.text.toString();
                      context.read<GetCordinatesCubit>().getCoordinates(
                          address: textEditingAddressSearchController.text
                              .toString());

                      Navigator.of(context).pop();
                    } else {
                      context
                          .read<SelectedAddressCubit>()
                          .updateIsSelectePickupdAddress(
                              isCheckedSelectedPickup: false);
                      context
                          .read<SelectedAddressCubit>()
                          .updateIsSelectedDropOffAddress(
                              isCheckedSelectedDropOff: true);
                      context
                          .read<SelectedAddressCubit>()
                          .updateIsCrossIconSelectedDropOff(
                              ischeckedCrossIconDropOff: true);

                      context
                              .read<SelectedAddressCubit>()
                              .dropOffAddressController
                              .text =
                          textEditingAddressSearchController.text.toString();
                      context.read<GetCordinatesCubit>().getCoordinates(
                          address: textEditingAddressSearchController.text
                              .toString());

                      if (context
                              .read<SelectedAddressCubit>()
                              .dropOffAddressController
                              .text ==
                          context
                              .read<SelectedAddressCubit>()
                              .pickupAddressController
                              .text) {
                        showErrorToastMessage(
                            "Please select different address");
                        return;
                      }
                      Navigator.of(context).pop();
                    }
                  } else {
                    showErrorToastMessage(
                        "please selected the address".translate(context));
                  }
                },
                textColor: blackColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
