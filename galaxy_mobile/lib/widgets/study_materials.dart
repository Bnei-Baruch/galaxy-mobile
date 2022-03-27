
import 'package:flutter/material.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/widgets/loader.dart';
import 'package:galaxy_mobile/models/study_material.dart';
import 'package:provider/provider.dart';

class StudyMaterials extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Loader<List<StudyMaterial>>(
        resultBuilder: (BuildContext context, dynamic questions) {
          // TODO: implement
          return null;
        },
        loadOnInit: true,
        load: () => context.read<Api>().fetchStudyMaterials()
      )
    );
  }
}