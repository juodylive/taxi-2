// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:zearah_rider/core/extensions/helper/push_notifications.dart';
import 'package:zearah_rider/domain/entities/login_data.dart';
import 'package:zearah_rider/data/repositories/auth_repository.dart';
import 'package:zearah_rider/core/services/data_store.dart';
import 'package:zearah_rider/core/extensions/workspace.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:zearah_rider/presentation/cubits/auth/user_authenticate_cubit.dart';

import '../../../core/utils/common_widget.dart';
import '../../../domain/entities/check_mobile.dart';
import '../book_ride_cubit.dart';

abstract class GoogleLoginState extends Equatable {
  @override
  List<Object?> get props => [];
}

class GoogleInitial extends GoogleLoginState {}

class GoogleLoading extends GoogleLoginState {}

class GoogleLoginSucess extends GoogleLoginState {
  @override
  List<Object?> get props => [];
}

class GoogleLoginFailure extends GoogleLoginState {
  final String error;
  GoogleLoginFailure(this.error);
  @override
  List<Object?> get props => [error];
}

class GoogleLoginCubit extends Cubit<GoogleLoginState> {
  AuthRepository authRepository;
  GoogleLoginCubit(this.authRepository) : super(GoogleInitial());

  Future<void> googleLogin(BuildContext context) async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
    );

    await googleSignIn.signOut();
    try {
      Widgets.showLoader(context);

      var result = await googleSignIn.signIn();
      if (result != null) {

        GoogleSignInAuthentication? googleAuth = await result.authentication;
        OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        UserCredential userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
        User? firebaseUser = userCredential.user;
        if (firebaseUser != null) {

          final response = await authRepository.socialLogin(
            "${result.displayName}",
            result.email,
            result.id,
            "${result.photoUrl}",
            "google",
            "",
            "",
          );
          if (response["status"] == 200) {

            LoginModel socialLoginModel = LoginModel.fromJson(response);
            box.put("UserData", jsonEncode(socialLoginModel.toJson()));
            loginModel = LoginModel.fromJson(socialLoginModel.toJson());
            context.read<BookRideRealTimeDataBaseCubit>().updateUserDetails(
                userName: loginModel!.data!.firstName,
                userPhoneNumber:
                    "${loginModel!.data!.phoneCountry} ${loginModel!.data!.phone}",
                userId: loginModel!.data!.id!.toInt());

            box.put('Remember', true);
            box.put('Firstuser', true);
            UserData userObj = UserData();
            userObj.saveLoginData("UserData", jsonEncode(response));
            getFCMToken();
            token = socialLoginModel.data?.token ?? "";

            if (socialLoginModel.data!.phone == null) {
              Widgets.hideLoder(context);
              emit(AddPhoneNumberState(socialLoginModel));
            } else {
              Widgets.hideLoder(context);
              emit(GoogleLoginSucess());
            }
          }
        }
      } else {
        Widgets.hideLoder(context);

      }
    } catch (error) {
      Widgets.hideLoder(context);
      emit(GoogleLoginFailure(error.toString()));


    }
  }

  Future<void> updatePhonePhone(
    BuildContext context, {
    String? phone,
    String? countryCode,
    String? defaultCode,
    String? socialEmail,
  }) async {
    try {
      Widgets.showLoader(context);
      final response = await authRepository.changePhone(
          phone: phone,
          countryCode: countryCode,
          defaultCode: defaultCode,
          socialEmail: socialEmail);
      Widgets.hideLoder(context);

      if (response["status"] == 200) {
        context.read<SetCountryCubit>().reset();
        emit(GoogleUpdatePhoneSuccess(CheckMobileModel.fromJson(response)));
      } else {
        emit(GoogleCheckFailureState(response["error"]));
      }
    } catch (e) {
      context.read<SetCountryCubit>().reset();
      Widgets.hideLoder(context);
      emit(GoogleCheckFailureState("Failed to check host status."));
    }
  }

  void resetState() {
    emit(GoogleInitial());
  }
}

class AddPhoneNumberState extends GoogleLoginState {
  final LoginModel loginModel;

  AddPhoneNumberState(this.loginModel);

  @override
  List<Object?> get props => [loginModel];
}

class GoogleUpdatePhoneSuccess extends GoogleLoginState {
  final CheckMobileModel checkMobileModel;

  GoogleUpdatePhoneSuccess(this.checkMobileModel);

  @override
  List<Object?> get props => [checkMobileModel];
}

class GoogleCheckLoadingState extends GoogleLoginState {}

class GoogleCheckFailureState extends GoogleLoginState {
  final String error;

  GoogleCheckFailureState(this.error);

  @override
  List<Object?> get props => [error];
}
