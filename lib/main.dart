import 'package:ride_on/app/app_localizations.dart';
import 'package:ride_on/app/register_cubits.dart';
import 'package:ride_on/presentation/cubits/localizations_cubit.dart';
import 'package:ride_on/presentation/screens/splash/initial_screen.dart';
import 'package:ride_on/core/extensions/workspace.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'core/extensions/helper/push_notifications.dart';
import 'core/utils/theme/project_color.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();
  await Hive.openBox('appBox');
  await Hive.openBox('lanBox');
  await initializeNotifications();
  await setupOneSignal();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
   FlutterError.onError = (FlutterErrorDetails details) {};
  runApp(
    MultiBlocProvider(
      providers: [
        ...RegisterCubits().providers,
        ChangeNotifierProvider(
          create: (_) => ColorNotifires(),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          context.read<LanguageCubit>().loadCurrentLanguage();
          return BlocBuilder<LanguageCubit, LanguageState>(
              builder: (context, state) {
            if (state is LanguageLoader) {
              appLocale = Locale(state.language ?? "en");
            }
            return MaterialApp(
              navigatorKey: navigatorKey,
              builder: BotToastInit(),  
              theme: ThemeData(
                fontFamily: 'Gilroy Regular',
              ),
              supportedLocales: const [
                Locale('en', 'US'),
                Locale('ar', 'AR'),

              ],
              locale: appLocale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              debugShowCheckedModeBanner: false,
              home: const InitialScreen(),
            );
          });
        },
      ),
    ),
  );
}
