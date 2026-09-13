import 'dart:async';
import 'dart:convert';
import 'package:ride_on/app/route_settings.dart';
import 'package:ride_on/domain/entities/ride_request.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:ride_on/presentation/screens/Splash/splash_screen.dart';
import '../../../core/utils/theme/project_color.dart';
import '../../cubits/book_ride_cubit.dart';
import '../../cubits/realtime/check_ride_request_cubit.dart';
import '../../cubits/realtime/ride_request_cubit.dart';
import '../Home/item_home_screen.dart';
import '../Onboarding/on_boarding_screen.dart';
import '../Search/send_ride_request_screen.dart';
import '../payment/rider_payment_screen.dart';

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  late Box box;

  @override
  void initState() {
    super.initState();
    box = Hive.box('appBox');
    handleNavigation();
    getCurrency(context);
  }

  // ignore: prefer_typing_uninitialized_variables
  var data;
  RideRequest? ridedata;

  void handleNavigation() {
    final bool isFirstUser = box.get('Firstuser', defaultValue: false) != true;

    final duration = Duration(seconds: isFirstUser ? 4 : 0);
    Timer(duration, () {
      if (isFirstUser) {
        navigateToScreen(context, () => const Onboardingscreen());
      } else {
        data = box.get('ride_data');
        if (data == null) {
          navigateToScreen(context, () => const ItemHomeScreen());
        } else {
          String rideId = data["rideId"] ?? "";
          context.read<CheckStatusCubit>().checkStatus(rideId);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    notifires = Provider.of<ColorNotifires>(context, listen: true);
    return Scaffold(
      backgroundColor: Provider.of<ColorNotifires>(context).getbgcolor,
      body: BlocListener<CheckStatusCubit, CheckRideStatusState>(
          listener: (context, state) {
            if (state is CheckRideSuccess) {
              context.read<RideRequestCubit>().loadRideFromHive();

              final bookride = context.read<BookRideRealTimeDataBaseCubit>();
              bookride.updatePickupLatAndLng(
                  pickupAddressLatitude: data["pickLat"].toString(),
                  pickupAddressLongitude: data["pickLng"].toString());
              bookride.updateDropOffLatAndLng(
                  dropoffAddressLatitude: data["dropLat"].toString(),
                  dropoffAddressLongitude: data["dropLng"].toString());

              Map<String, dynamic> vehicle =
                  jsonDecode(box.get('selected_vehicle'));
              bookride.updateDropOffAddress(
                  dropoffAddress: data["dropAddress"]);
              bookride.updatePickupAddress(pickupAddress: data["pickAddress"]);

              if (state.status == "accepted") {
                goToWithReplacement(SendRideRequestScreen(
                  selectedVehicleData: vehicle,
                  statusOfRide: "accepted",
                  pickUpOtp: box.get("PickOtp"),
                  bookingId: box.get("bookingId").toString(),
                  rideId: data["rideId"],
                  paymentUrl: box.get("payment_url"),
                ));
              } else if (state.status == "ongoing") {
                goToWithReplacement(SendRideRequestScreen(
                  selectedVehicleData: vehicle,
                  statusOfRide: "ongoing",
                  pickUpOtp: box.get("PickOtp"),
                  bookingId: box.get("bookingId").toString(),
                  rideId: data["rideId"],
                  paymentUrl: box.get("payment_url"),
                ));
              } else if (state.status == "completed" &&
                  state.paymentStatus == "collected") {
                box.delete("ride_data");
                navigateToScreen(context, () => const ItemHomeScreen());
              } else if (state.status == "completed" &&
                  state.paymentStatus == "") {
                navigateToScreen(
                    context,
                    () => RiderPaymentScreen(
                          bookingId: box.get("bookingId").toString(),
                          rideId: data["rideId"],
                          fare: vehicle["fare"],
                          paymentUrl: box.get("payment_url"),
                        ));
              } else if (state.status == "rejected") {
                box.delete("ride_data");
                box.delete("payment_url");
                box.delete("PickOtp");
                box.delete("bookingId");
                box.delete("selected_vehicle");

                navigateToScreen(context, () => const ItemHomeScreen());
              }
            } else if (state is CheckRideFailed) {
              box.delete("ride_data");
              box.delete("payment_url");
              box.delete("PickOtp");
              box.delete("bookingId");
              box.delete("selected_vehicle");

              navigateToScreen(context, () => const ItemHomeScreen());
            }
          },
          child: const SplashScreen()),
    );
  }
}
