import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/widgets/loader.dart';
import 'package:galaxy_mobile/models/study_material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:html/dom.dart' as dom;


class StudyMaterials extends StatelessWidget {

  Future<void> _onLinkOpen(
      String url,
  RenderContext context,
      Map<String, String> attributes,
  dom.Element element,
      ) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      FlutterLogs.logInfo("StudyMaterials", "_onLinkOpen", "Could not open link $url");
    }
  }

  Future<List<StudyMaterial>> _loadStudyMaterials(BuildContext context) async {
    List<StudyMaterial> studyMaterials = [];
    try {
      studyMaterials = await context.read<Api>().fetchStudyMaterials();
    } catch (e) {
      FlutterLogs.logInfo(
          "StudyMaterials",
          "_loadStudyMaterials",
          "Failed to fetch study materials: " + e.toString());
    }
    return studyMaterials;
  }

  @override
  Widget build(BuildContext context) {
    return Loader<List<StudyMaterial>>(
      load: () => _loadStudyMaterials(context),
      resultBuilder: (BuildContext context, List<StudyMaterial> studyMaterials) {
        return ListView.separated(
          separatorBuilder: (BuildContext context, int index) => Divider(
            color: Colors.black,
          ),
          itemCount: studyMaterials.length,
          itemBuilder: (BuildContext context, int index) {
            StudyMaterial material = studyMaterials[index];
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
                    data: material.htmlContent,
                    onLinkTap: _onLinkOpen,
                    // customRender: {
                    //   // We need this override div since flutter_html doesn't
                    //   // change direction based on the "dir" attribute on it.
                    //   "div": (renderContext, Widget child, attributes, _) {
                    //     if (attributes['dir'] == null) {
                    //       // Use the default renderer for div.
                    //       return null;
                    //     }
                    //
                    //     return Directionality(
                    //       textDirection: attributes['dir'] == 'rtl' ? ui.TextDirection.rtl
                    //           : ui.TextDirection.ltr,
                    //       child: child
                    //     );
                    //   },
                    // },
                  )
                )
              ],
            );
          }
        );
      }
    );
  }
}