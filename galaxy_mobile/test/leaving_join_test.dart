import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:galaxy_mobile/main.dart';
import 'package:galaxy_mobile/utils/switch_page_helper.dart';
import 'package:galaxy_mobile/utils/utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('leaving', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false);
    // = await rootBundle.loadString("feeds.json");
    var newFeeds_3 = await Utils.parseJson("feeds3.json");
    switchHelper.switchVideos(0, [], newFeeds_3);

    newFeeds_3.forEach((feed) {
      expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, false);
    });
    //expect(result, 'Enter Email!');
  });

  test('leaving from 6', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false);
    // = await rootBundle.loadString("feeds.json");
    var newFeeds_6 = await Utils.parseJson("feeds6.json");
    switchHelper.switchVideos(0, [], newFeeds_6);
    // (newFeeds_6 as List)
    //     .removeWhere((element) => element["id"] == 26725810025805);
    List feedsNewState = (newFeeds_6 as List)
        .where((feed) => feed["id"] != 26725810025805)
        .toList();
    switchHelper.switchVideos(
        /* page= */ 0,
        newFeeds_6,
        feedsNewState);

    // this.setState({ feeds: feedsNewState }, () => {
    // if (0 * switchHelper.PAGE_SIZE == newFeeds_6.length) {
    //   switchHelper.sw(0 - 1);
    // }

    feedsNewState.forEach((feed) {
      if (feedsNewState.indexOf(feed) < 3)
        expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, false);
    });
  });
  test('switch second page 6 feeds', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false);
    // = await rootBundle.loadString("feeds.json");
    var newFeeds_6 = await Utils.parseJson("feeds6.json");
    switchHelper.switchVideos(1, newFeeds_6, newFeeds_6);

    newFeeds_6.forEach((feed) {
      if (newFeeds_6.indexOf(feed) >= 3)
        expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, false);
    });
  });
  test('switch third page 6 feeds', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false);
    // = await rootBundle.loadString("feeds.json");
    var newFeeds_6 = await Utils.parseJson("feeds6.json");
    switchHelper.switchVideos(0, newFeeds_6, newFeeds_6);

    newFeeds_6.forEach((feed) {
      if (newFeeds_6.indexOf(feed) < 3)
        expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, false);
    });
  });
  test('switch back to page 0  6 feeds', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false);
    // = await rootBundle.loadString("feeds.json");
    var newFeeds_6 = await Utils.parseJson("feeds6.json");
    switchHelper.switchVideos(0, [], newFeeds_6);
    switchHelper.switchVideos(1, newFeeds_6, newFeeds_6);
    switchHelper.switchVideos(0, newFeeds_6, newFeeds_6);

    newFeeds_6.forEach((feed) {
      if (newFeeds_6.indexOf(feed) < 3)
        expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, false);
    });
  });
  test('switch back to page 0  6 feeds negative test', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false);
    // = await rootBundle.loadString("feeds.json");
    var newFeeds_6 = await Utils.parseJson("feeds6.json");
    switchHelper.switchVideos(0, [], newFeeds_6);
    switchHelper.switchVideos(1, newFeeds_6, newFeeds_6);
    switchHelper.switchVideos(0, newFeeds_6, newFeeds_6);

    newFeeds_6.forEach((feed) {
      if (newFeeds_6.indexOf(feed) >= 3)
        expect(feed["videoSlot"] != null && feed["videoSlot"] != -1, false);
    });
  });

  test('switch remove one feed from start', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false);
    // = await rootBundle.loadString("feeds.json");
    var newFeeds_6 = await Utils.parseJson("feeds6.json");
    switchHelper.switchVideos(0, [], newFeeds_6);
    var oldfeeds = List(6);
    List.copyRange(oldfeeds, 0, newFeeds_6);
    (newFeeds_6 as List).removeAt(0);
    switchHelper.switchVideos(0, oldfeeds, newFeeds_6);

    newFeeds_6.forEach((feed) {
      if (newFeeds_6.indexOf(feed) < 3)
        expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, false);
    });
  });
  test('switch remove one feed from end', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false);
    // = await rootBundle.loadString("feeds.json");
    var newFeeds_6 = await Utils.parseJson("feeds6.json");
    switchHelper.switchVideos(0, [], newFeeds_6);
    var oldfeeds = List(6);
    List.copyRange(oldfeeds, 0, newFeeds_6);
    (newFeeds_6 as List).removeAt(5);
    switchHelper.switchVideos(0, oldfeeds, newFeeds_6);

    newFeeds_6.forEach((feed) {
      if (newFeeds_6.indexOf(feed) < 3)
        expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, false);
    });
  });

  test('switch remove one feed from the middle', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false);
    // = await rootBundle.loadString("feeds.json");
    var newFeeds_6 = await Utils.parseJson("feeds6.json");
    switchHelper.switchVideos(0, [], newFeeds_6);
    var oldfeeds = List(6);
    List.copyRange(oldfeeds, 0, newFeeds_6);
    (newFeeds_6 as List).removeAt(2);
    switchHelper.switchVideos(0, oldfeeds, newFeeds_6);

    newFeeds_6.forEach((feed) {
      if (newFeeds_6.indexOf(feed) < 3)
        expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, false);
    });
  });

  test('switch add one feed from the beggining', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false);
    // = await rootBundle.loadString("feeds.json");
    var newFeeds_6 = await Utils.parseJson("feeds6.json");
    switchHelper.switchVideos(0, [], newFeeds_6);
    var oldfeeds = List(6);
    List.copyRange(oldfeeds, 0, newFeeds_6);
    (newFeeds_6 as List).insert(0, oldfeeds.last);
    switchHelper.switchVideos(0, oldfeeds, newFeeds_6);

    newFeeds_6.forEach((feed) {
      if (newFeeds_6.indexOf(feed) < 3)
        expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, false);
    });
  });
}
