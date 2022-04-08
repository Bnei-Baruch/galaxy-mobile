

import 'package:flutter/material.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:galaxy_mobile/widgets/study_materials.dart';
import 'main_dialog_header.dart';

void displayStudyMaterialDialog(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    pageBuilder: (context, animation, secondaryAnimation) {
      return WillPopScope(
          onWillPop: () {
            Navigator.of(context).pop();
            return Future.value(true);
          },
          child: SafeArea(
              child: Material(
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        MainDialogHeader(
                          title: "study_material".tr(),
                          onBackPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(child: StudyMaterials())
                      ]
                  ),
                ),
              )
          )
      );
    },
  );
}