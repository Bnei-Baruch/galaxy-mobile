
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/widgets/loader.dart';
import 'package:galaxy_mobile/models/study_material.dart';
import 'package:provider/provider.dart';

class StudyMaterials extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Loader<List<StudyMaterial>>(
      resultBuilder: (BuildContext context, dynamic studyMaterials) {
        // TODO: make it a list. click on headline to make it stick to top.
        return Column(
          children: (studyMaterials as List<StudyMaterial>).map((StudyMaterial material) {
            return ExpansionTile(
              title: Text(
                material.title,
                style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold
                ),
              ),
              children: <Widget>[
                SingleChildScrollView(
                  child: Html(
                    data: material.htmlContent
                  )
                )
              ],
            );
          }).toList()
        );
      },
      load: () => context.read<Api>().fetchStudyMaterials()
    );
  }
}