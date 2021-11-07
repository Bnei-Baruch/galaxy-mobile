import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:galaxy_mobile/main.dart';
import 'package:galaxy_mobile/utils/switch_page_helper.dart';
import 'package:galaxy_mobile/utils/utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('leaving first from 3', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false, null);
    // = await rootBundle.loadString("feeds.json");
    var newFeeds_3 = await Utils.parseJson("feeds3.json");
    switchHelper.switchVideos(0, [], newFeeds_3);

    newFeeds_3.forEach((feed) {
      expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, false);
    });
    List feedsNewState = (newFeeds_3 as List)
        .where((feed) => feed["id"] != 26725810025805)
        .toList();
    switchHelper.switchVideos(
        /* page= */ 0,
        newFeeds_3,
        feedsNewState);

    feedsNewState.forEach((feed) {
      if (feedsNewState.indexOf(feed) < 2) {
        expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, false);
      }
    });

    expect(feedsNewState.elementAt(0)["id"] == 666765090359584, true);
    expect(feedsNewState.elementAt(1)["id"] == 1502170363902192, true);
  });

  test('leaving first from 6', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false, null);
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
      if (feedsNewState.indexOf(feed) < 3) {
        expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, false);
      }
    });

    expect(feedsNewState.elementAt(0)["id"] == 666765090359584, true);
    expect(feedsNewState.elementAt(1)["id"] == 1502170363902192, true);
    expect(feedsNewState.elementAt(2)["id"] == 752170363902192, true);
  });
  test('leaving second from 6 feeds', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false, null);
    // = await rootBundle.loadString("feeds.json");
    var newFeeds_6 = await Utils.parseJson("feeds6.json");
    switchHelper.switchVideos(0, [], newFeeds_6);
    // (newFeeds_6 as List)
    //     .removeWhere((element) => element["id"] == 26725810025805);
    List feedsNewState = (newFeeds_6 as List)
        .where((feed) => feed["id"] != 666765090359584)
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
      if (feedsNewState.indexOf(feed) < 3) {
        expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, false);
      }
    });

    expect(feedsNewState.elementAt(0)["id"] == 26725810025805, true);
    expect(feedsNewState.elementAt(1)["id"] == 1502170363902192, true);
    expect(feedsNewState.elementAt(2)["id"] == 752170363902192, true);
  });
  test('leaving third from 6 feeds', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false, null);
    // = await rootBundle.loadString("feeds.json");
    var newFeeds_6 = await Utils.parseJson("feeds6.json");
    switchHelper.switchVideos(0, newFeeds_6, newFeeds_6);
    List feedsNewState = (newFeeds_6 as List)
        .where((feed) => feed["id"] != 1502170363902192)
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
      if (feedsNewState.indexOf(feed) < 3) {
        expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, false);
      }
    });

    expect(feedsNewState.elementAt(0)["id"] == 26725810025805, true);
    expect(feedsNewState.elementAt(1)["id"] == 666765090359584, true);
    expect(feedsNewState.elementAt(2)["id"] == 752170363902192, true);
  });
  test('leaving first form second page in 6 feeds', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false, null);
    // = await rootBundle.loadString("feeds.json");
    var newFeeds_6 = await Utils.parseJson("feeds6.json");
    switchHelper.switchVideos(0, [], newFeeds_6);
    switchHelper.switchVideos(1, newFeeds_6, newFeeds_6);
    List feedsNewState = (newFeeds_6 as List)
        .where((feed) => feed["id"] != 752170363902192)
        .toList();
    switchHelper.switchVideos(
        /* page= */ 1,
        newFeeds_6,
        feedsNewState);

    // this.setState({ feeds: feedsNewState }, () => {
    // if (0 * switchHelper.PAGE_SIZE == newFeeds_6.length) {
    //   switchHelper.sw(0 - 1);
    // }

    feedsNewState.forEach((feed) {
      if (feedsNewState.indexOf(feed) >= 3) {
        expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, false);
      }
    });

    expect(feedsNewState.elementAt(3)["id"] == 8782170363902192, true);
    expect(feedsNewState.elementAt(4)["id"] == 3432170363902192, true);
  });
  test('leaving first form second page in 9 feeds', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false, null);
    // = await rootBundle.loadString("feeds.json");
    var newFeeds_9 = await Utils.parseJson("feeds9.json");
    switchHelper.switchVideos(0, [], newFeeds_9);
    switchHelper.switchVideos(1, newFeeds_9, newFeeds_9);
    List feedsNewState = (newFeeds_9 as List)
        .where((feed) => feed["id"] != 752170363902192)
        .toList();
    switchHelper.switchVideos(
        /* page= */ 1,
        newFeeds_9,
        feedsNewState);

    // this.setState({ feeds: feedsNewState }, () => {
    // if (0 * switchHelper.PAGE_SIZE == newFeeds_6.length) {
    //   switchHelper.sw(0 - 1);
    // }

    feedsNewState.forEach((feed) {
      if (feedsNewState.indexOf(feed) >= 3) {
        expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, false);
      }
    });

    expect(feedsNewState.elementAt(3)["id"] == 8782170363902192, true);
    expect(feedsNewState.elementAt(4)["id"] == 3432170363902192, true);
    expect(feedsNewState.elementAt(5)["id"] == 212170363902192, true);
  });

  test('joining 1 to none streams', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false, null);
    // = await rootBundle.loadString("feeds.json");
    var newFeeds_3 = await Utils.parseJson("feeds3.json");
    switchHelper.switchVideos(0, [], []);

    (newFeeds_3 as List).removeRange(1, 2);

    switchHelper.switchVideos(
        /* page= */ 0,
        [],
        newFeeds_3);

    newFeeds_3.forEach((feed) {
      if (newFeeds_3.indexOf(feed) < 1) {
        expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, false);
      }
    });

    expect(newFeeds_3.elementAt(0)["id"] == 26725810025805, true);
  });
  test('joining 1 to 1 streams', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false, null);
    // = await rootBundle.loadString("feeds.json");
    var newFeeds_3 = await Utils.parseJson("feeds3.json");
    var oldFeed = (newFeeds_3 as List).sublist(0, 1);

    switchHelper.switchVideos(0, [], oldFeed);

    var newFeed = (newFeeds_3 as List).sublist(1, 2);
    newFeed.addAll(oldFeed);

    newFeed = newFeed.reversed.toList();
    switchHelper.switchVideos(
        /* page= */ 0,
        oldFeed,
        newFeed);

    newFeed.forEach((feed) {
      if (newFeed.indexOf(feed) < 2) {
        expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, false);
      }
    });

    expect(newFeed.elementAt(0)["id"] == 26725810025805, true);
    expect(newFeed.elementAt(1)["id"] == 666765090359584, true);
  });
  test('joining 1 to 3 streams', () async {
    var switchHelper = SwitchPageHelper(null, null, null, 3, false, null);
    // = await rootBundle.loadString("feeds.json");
    var newFeeds_6 = await Utils.parseJson("feeds6.json");
    var oldFeed = (newFeeds_6 as List).sublist(0, 3);

    switchHelper.switchVideos(0, [], oldFeed);

    var newFeed = (newFeeds_6 as List).sublist(3, 4);
    newFeed.addAll(oldFeed);

    newFeed = newFeed.reversed.toList();
    switchHelper.switchVideos(
      /* page= */ 0,
        oldFeed,
        newFeed);

    newFeed.forEach((feed) {
      if (newFeed.indexOf(feed) == 3 ) {
        expect(feed["videoSlot"] == null || feed["videoSlot"] == -1, true);
      }
    });

    expect(newFeed.elementAt(3)["id"] ==  752170363902192, true);

  });
}
