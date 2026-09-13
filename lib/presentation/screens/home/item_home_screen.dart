import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_on/core/utils/theme/project_color.dart';
import 'package:ride_on/core/utils/translate.dart';
import 'package:ride_on/core/extensions/helper/push_notifications.dart';
import 'package:ride_on/core/utils/common_widget.dart';
import 'package:ride_on/core/utils/theme/theme_style.dart';
import 'package:ride_on/domain/entities/catrgory.dart';
import 'package:ride_on/core/extensions/workspace.dart';
import 'package:ride_on/presentation/widgets/drawer_custom.dart';
import '../../../core/services/data_store.dart';
import '../../cubits/book_ride_cubit.dart';
import '../../cubits/general_cubit.dart';
import '../../cubits/location/user_current_location_cubit.dart';
import '../../cubits/profile/edit_profile_cubit.dart';
import '../../cubits/realtime/update_ride_request_parameter.dart';
import '../../cubits/vehicle_data/get_vehicle_cetgegory_cubit.dart';
import '../search/loading_nearby_search_screen.dart';
import '../search/route_location_screen.dart';


class ItemHomeScreen extends StatefulWidget {
  const ItemHomeScreen({super.key});

  @override
  State<ItemHomeScreen> createState() => _ItemHomeScreenState();
}

class _ItemHomeScreenState extends State<ItemHomeScreen>   {
  final ValueNotifier<LatLng> _selectedLocation =
      ValueNotifier(const LatLng(0, 0));
  static const LatLng _defaultLocation = LatLng(37.7749, -122.4194);
  Timer? _debounceTimer; // San Francisco
   bool showAlert = false;
  @override
  void initState() {

    super.initState();
    getFCMToken();
    _loadRecentDropLocations();
    context.read<MyImageCubit>().updateMyImage(myImage);
    context
        .read<BookRideRealTimeDataBaseCubit>()
        .updateUserImageUrl(userImageUrl: myImage);
    context.read<UpdateRideRequestParameterCubit>().updateFirebaseUserParameter(
        rideId: context.read<BookRideRealTimeDataBaseCubit>().state.rideId,
        userParameter: {"userImageUrl": myImage});
    context.read<NameCubit>().updateName(loginModel?.data?.firstName ?? "");
    context.read<EmailCubit>().updateEmail(loginModel?.data?.email ?? "");

    isNumeric = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
      showNotification(context); // Assuming this is defined elsewhere
    });
  }
  List<Map<String, String>> recentDropLocations = [];
  void _loadRecentDropLocations() {
    final storedList = box.get('recent_drop_locations', defaultValue: []);
    if (storedList is List) {
      recentDropLocations = storedList.map((e) => Map<String, String>.from(e)).toList();
    }
    setState(() {});
  }
  String _currentAddress = "";
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
   bool _isInitialLocationLoaded = false;
  bool _isLoadingLocation = false;
  Future<void> _initializeApp() async {
    context.read<GetVehicleDataCubit>().getAllCategories();
    getCurrency(context); // Assuming this is defined elsewhere
    getUserDataLocallyToHandleTheState(
        context); // Assuming this is defined elsewhere
    await _loadInitialLocation();
  }
  Future<void> _loadInitialLocation() async {
    if (_isInitialLocationLoaded || _isLoadingLocation) return;
    setState(() => _isLoadingLocation = true);
     final cachedLocation = await _loadCachedLocation();
    if (cachedLocation != null) {
      _selectedLocation.value = cachedLocation;
      setState(() => _isInitialLocationLoaded = true);
    }
     try {
      await startLiveLocationTracking(isInitialLoad: true).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _selectedLocation.value = _defaultLocation;
          setState(() => _isInitialLocationLoaded = true);
        },
      );
    } catch (e) {
      showErrorToastMessage('Error getting location: $e');
      _selectedLocation.value = _defaultLocation;
      setState(() => _isInitialLocationLoaded = true);
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }
  Future<LatLng?> _loadCachedLocation() async {
    final lat = box.get('last_latitude');
    final lng = box.get('last_longitude');
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return null;
  }

  Future<void> startLiveLocationTracking({bool isInitialLoad = false}) async {
    if (_isLoadingLocation && !isInitialLoad) return;

    try {
      _isLoadingLocation = true;

      LocationPermission permission = await _checkPermissions();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
            if(showAlert==true){
              return;
            }
        _showPermissionDeniedDialog();
          showAlert = true;
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        // ignore: deprecated_member_use
        desiredAccuracy: LocationAccuracy.high,
      );

      updateUserLocation(position);
    } catch (e) {
      showErrorToastMessage('Error getting location: $e');
    } finally {
      if (!isInitialLoad) {
        _isLoadingLocation = false;
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: notifires.getbgcolor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Location Access Needed".translate(context),
                style: heading2Grey1(context),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "To keep your rides accurate and smooth, please allow location access. You can enable it easily by following these steps:"
                  .translate(context),
              style: regular2(context),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("👉 "),
                Expanded(
                  child: Text("Open your phone's Settings".translate(context), style: regular2(context)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("👉 "),
                Expanded(
                  child: Text("Go to App Permissions".translate(context), style: regular2(context)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("👉 "),
                Expanded(
                  child: Text("Allow Location Access for this app".translate(context), style: regular2(context)),
                ),
              ],
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Not Now".translate(context),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Geolocator.openAppSettings();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.settings, size: 18, color: Colors.white),
            label: Text(
              "Open Settings".translate(context),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<LocationPermission> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      showErrorToastMessage(
          // ignore: use_build_context_synchronously
          "Please enable location services".translate(context));
      return LocationPermission.denied;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  void updateUserLocation(Position position) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () {

      context.read<UpdateCurrentAddressCubit>().getAddressFromLatLng(
            latitude: position.latitude,
            longitude: position.longitude,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // ignore: deprecated_member_use
      onPopInvoked: (v) async =>
          dialogExit(context), // Assuming this is defined elsewhere
      canPop: false,
      child: Scaffold(
        extendBodyBehindAppBar: true,

        drawer: const MyDrawer(),
        key: _scaffoldKey,
        appBar: PreferredSize(
          preferredSize:
              const Size.fromHeight(170), // Custom height for both sections
          child: Container(
            color: Colors.transparent,

            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 5),
                  _buildLocationInput(),
                ],
              ),
            ),
          ),
        ),
        body: Container(
          height: double.maxFinite,
          width: double.maxFinite,
          decoration:   BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFFFFFFF),

               const Color(0xFFFFFBF3), // white
               const Color(0xFFFAE4A9), // white
               const Color(0xFFFAE4A9), // white
               const Color(0xFFFAE4A9), // white
               const Color(0xFFFDDD8C),
                themeColor.withValues(alpha: 0.7)// white
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                  left: 0,right: 0,bottom: 0,
                  child: SvgPicture.asset("assets/images/home_group.svg",)),
              SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPromoBanner(),
                      const SizedBox(height: 20),
                      if (recentDropLocations.isNotEmpty) _buildRecentSearches(),
                      const SizedBox(height: 20),
                      _buildExploreSection(),
                      const SizedBox(height: 20),

                    ],
                  ),
                ),
              ),



            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          BlocBuilder<MyImageCubit, dynamic>(builder: (context, state) {
            return InkWell(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: myImage.isEmpty
                  ? Icon(
                      CupertinoIcons.profile_circled,
                      size: 60,
                      color: blackColor,
                    )
                  : ClipOval(
                    child: Container(
                      color: Colors.white,
                        height: 60,
                        width: 60,
                        child: ClipOval(
                          child: myNetworkImage(context.read<MyImageCubit>().state),
                        ),
                      ),
                  ),
            );
          }),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BlocBuilder<NameCubit, dynamic>(builder: (context, state) {
                  return Row(
                    children: [
                      Text("Hi".translate(context),
                          style: heading2Grey1(context)),
                      const SizedBox(
                        width: 7,
                      ),
                      Text(context.read<NameCubit>().state,
                          style: heading2Grey1(context))
                    ],
                  );
                }),
                Text(
                  "Where do you want to go today?".translate(context),
                  style: heading3Grey1(context).copyWith(color: grey2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInput() {
    return BlocBuilder<UpdateCurrentAddressCubit, UpdateCurrentAddressState>(
      builder: (context, state) {
        if (state is UpdateCurrentAddresSuccess) {
          _currentAddress = state.currentAddress ?? '';
          context.read<BookRideRealTimeDataBaseCubit>().updatePickupAddress(pickupAddress: _currentAddress);

          context.read<BookRideRealTimeDataBaseCubit>().updatePickupLatAndLng(
                pickupAddressLatitude: state.lat.toString(),
                pickupAddressLongitude: state.lng.toString(),
              );
          context.read<UpdateCurrentAddressCubit>().removeAddress();
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child:
                          const Icon(Icons.menu_outlined, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Flexible(
                    child: InkWell(
                      onTap: () async {
                        context
                            .read<VehicleDataUpdateCubit>()
                            .updateVehicleTypeSelectedId(1);

                          context
                              .read<SelectedAddressCubit>()
                              .pickupAddressController
                              .text = _currentAddress;
                          context
                              .read<GetSuggestionAddressCubit>()
                              .getSuggestions("");
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserSearchLocation(
                                currentAddress: _currentAddress,
                              ),
                            ),
                          );
                          _loadRecentDropLocations();

                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.green),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _currentAddress.isEmpty
                                    ? "Your Current Location".translate(context)
                                    : _currentAddress,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          height: 120,

          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFDF5), // halka cream
                Color(0xFFFFFFFF), // white
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left Black Part (tedha cut ke sath)
              Expanded(
                flex: 5,
                child: ClipPath(
                  clipper: DiagonalClipper(),
                  child: Container(
                    height: double.maxFinite,
                    alignment: Alignment.center,


                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
                    ),
                    child:   Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Get 20% Off".translate(context),
                          style: heading2Grey1(context).copyWith(color: whiteColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Your First Ride".translate(context),
                          style: heading2Grey1(context).copyWith(color: whiteColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Right White Part
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                     Image.asset("assets/images/appIcon.png",height: 60,),
                      const SizedBox(height: 2),
                        Text(
                        "Ride On".translate(context),
                        style: heading2Grey1(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      )

      ,
    );
  }

  Widget _buildRecentSearches() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Recent Searches".translate(context),
              style: heading3Grey1(context).copyWith(fontSize: 14),
            ),
            ListView.builder(

              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentDropLocations.length,
              itemBuilder: (context, index) {
                final item = recentDropLocations[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4,vertical: 0),
                  leading: Icon(Icons.history, color: themeColor),
                  title: Text(item['address'] ?? "",style: regular(context).copyWith(color: notifires.getGrey1whiteColor),),
                  onTap: () {

                    if(_currentAddress.isEmpty){
                       showAlert = false;
                      startLiveLocationTracking();
                      setState(() {

                      });
                      return;
                    }

                    context.read<SelectedAddressCubit>().dropOffAddressController.text = item['address'] ?? "";
                    context.read<BookRideRealTimeDataBaseCubit>().updateDropOffLatAndLng(
                      dropoffAddressLatitude: item['lat'] ?? "",
                      dropoffAddressLongitude: item['lng'] ?? "",
                    );


                     final bookRide = context.read<BookRideRealTimeDataBaseCubit>();



                    bookRide.updatePickupAddress(
                      pickupAddress:_currentAddress,
                    );
                    bookRide.updateDropOffAddress(
                      dropoffAddress: item['address'] ?? "",
                    );
                    debugPrint(
                        'pic latLang with address ${bookRide.state.pickupAddressLatitude},${bookRide.state.pickupAddressLongitude} ${bookRide.state.pickupAddress}');
                    debugPrint(
                        'drop latLang with address ${bookRide.state.dropoffAddressLatitude},${bookRide.state.dropoffAddressLongitude} ${bookRide.state.dropoffAddress}');

                    if (bookRide.state.pickupAddress.isNotEmpty &&
                        bookRide.state.dropoffAddress.isNotEmpty &&
                        bookRide.state.pickupAddressLatitude.isNotEmpty &&
                        bookRide.state.pickupAddressLongitude.isNotEmpty &&
                        bookRide.state.dropoffAddressLatitude.isNotEmpty &&
                        bookRide.state.dropoffAddressLongitude.isNotEmpty) {
                      goTo(const LoadingNearbySearchScreen());




                    } else {
                    }




                    // setState(() {});
                  },
                );
              },
            ),

          ],
        ),
      ),
    );
  }


  Widget _buildExploreSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                Text(
                "Explore".translate(context),
                style: heading3Grey1(context),
              ),

            ],
          ),
          BlocBuilder<GetVehicleDataCubit, GetVehicleDataState>(
              builder: (context, state) {
                List<ItemTypes> itemList = [];
                if (state is GetVehicleSuccess && state.itemTypes.isNotEmpty) {
                  itemList = state.itemTypes;
                  context
                      .read<SetVehicleCategoryCubit>()
                      .updateSetVehicleCategoryList(itemList);
                }
                bool isLoading = state is GetVehicleLoading;
                return _buildVehicleGrid(itemList, isLoading);
              }
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleGrid(List<ItemTypes> items, bool isLoading) {
    return items.isEmpty && isLoading == false
        ? Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Center(
          child: InkWell(
              onTap: () {
                context
                    .read<GetVehicleDataCubit>()
                    .getAllCategories( );
                setState(() {});
              },
              child: Text(
                "Retry".translate(context),
                style: regular2(context),
              ))),
    )
        : GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 15),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: isLoading ? 4 : items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
        mainAxisExtent: 80
      ),
      itemBuilder: (_, index) {
        if (isLoading) return ShimmerLoader();
        final item = items[index];

        return InkWell(
          onTap: () async {
            context
                .read<VehicleDataUpdateCubit>()
                .updateVehicleTypeSelectedId(
                item.id);

              context
                  .read<SelectedAddressCubit>()
                  .pickupAddressController
                  .text = _currentAddress;
              context
                  .read<GetSuggestionAddressCubit>()
                  .getSuggestions("");

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserSearchLocation(
                    currentAddress: _currentAddress,
                  ),
                ),
              );
              _loadRecentDropLocations();

          },
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
             color: whiteColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
                  item.image ?? "",
                  width: 50,
                  height: 50,
                
                  errorBuilder: (_, __, ___) => const Icon(Icons.image),
                ),
                Text(item.name ?? "",
                    style: heading3(context)
                        .copyWith(color: blackColor, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }


 }



void getCurrency(BuildContext context) {
  context.read<GeneralCubit>().fetchGeneralSetting(context);
}
class DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(size.width , 0); // thoda slope upar
    path.lineTo(size.width-40, size.height); // neeche right tak slope
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
