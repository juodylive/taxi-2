import 'package:zearah_rider/core/services/data_store.dart';

import 'package:zearah_rider/core/extensions/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zearah_rider/core/utils/translate.dart';

import '../../presentation/cubits/localizations_cubit.dart';
import '../utils/common_widget.dart';
import '../utils/theme/project_color.dart';
import '../utils/theme/theme_style.dart';

class ChangeLanguage extends StatefulWidget {
  const ChangeLanguage({super.key});

  @override
  State<ChangeLanguage> createState() => _ChangeLanguageState();
}

class _ChangeLanguageState extends State<ChangeLanguage> {
  int selectedRadio = 0;
  int _value = 0;
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: notifires.getbgcolor,
      appBar: CustomAppBars(
        title: "Language".translate(context),
        backgroundColor: notifires.getbgcolor,
        centerTitle: false,
        iconColor: notifires.getwhiteblackColor,
        titleColor: notifires.getwhiteblackColor,
      ),
      body:
          BlocBuilder<LanguageCubit, LanguageState>(builder: (context, state) {
        return SingleChildScrollView(
          // physics: BouncingScrollPhysics(),
          child: SizedBox(
            height: double.maxFinite,
            width: double.maxFinite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: locale.length,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      return InkWell(
                        onTap: () {
                          context
                              .read<LanguageCubit>()
                              .changeLanguage(locale[index]["locale"]);

                          lanBox.put('lCode', locale[index]['locale']);

                          setState(() {
                            _value = index;
                            box.put("lanValue", _value);
                          });
                        },
                        child: languageWidget(
                          name: locale[index]['name'],
                          value: index,
                          radio: Radio(
                            value: index,
                            groupValue: lanBox.get("lanValue") ?? _value,
                            hoverColor: blueColor,
                            onChanged: (value4) {
                              context
                                  .read<LanguageCubit>()
                                  .changeLanguage(locale[index]['locale']);
                              lanBox.put('lCode', locale[index]['locale']);
                              // Navigator.pop(context);
                              setState(() {
                                _value = index;
                                lanBox.put("lanValue", _value);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        );
      }),
    );
  }
}

Widget languageWidget(
    {String? name, int? value, void Function(int?)? onChanged, radio}) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(5),
    ),
    child: Padding(
      padding: const EdgeInsets.only(left: 15, right: 15),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              name ?? "",
              style: appBarNormal.copyWith(
                  fontSize: 16, color: notifires.getwhiteblackColor),
            ),
          ),
          const Spacer(),
          radio,
          const SizedBox(
            width: 10,
          ),
        ],
      ),
    ),
  );
}
