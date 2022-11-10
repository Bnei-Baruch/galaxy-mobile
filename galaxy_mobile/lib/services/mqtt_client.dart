
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/config/env.dart';
import 'package:mqtt5_client/mqtt5_client.dart';
import 'package:mqtt5_client/mqtt5_server_client.dart';
// import 'package:mqtt_client/mqtt5_client.dart';
// import 'package:mqtt_client/mqtt5_server_client.dart';

import 'keycloak.dart';
import 'logger.dart';

final logger = new Logger("MQTTClient");

class MQTTClient {
  String _username;
  String _password;
  String _id;

  MqttServerClient _client;

  final int _maxConnectionAttempts = 3;
  int _connectionAttempt = 0;
  bool _isConnected = false;

  var _onConnectedCallbackList = new List();
  var _onSubscribedCallbackList = new List();
  var _onMsgReceivedCallbackList = new List();
  var _onConnectionFailedCallbackList = new List();
  var _onDisconnectionFailedCallbackList = new List();

  MQTTClient() {
    FlutterLogs.logInfo("MQTT", "MQTTClient", "ctor");
    _client = MqttServerClient(APP_MQTT_HOST, APP_MQTT_CLIENT_ID);
  }

  void init(String username, String password, String id) {
    _username = username;
    _password = password;
    _id = id;
  }

  void addOnConnectedCallback(Function() onConnectedCallback) {
    _onConnectedCallbackList.add(onConnectedCallback);
  }

  void addOnDisconnectedCallback(Function() onDisconnectedCallback) {
    _onDisconnectionFailedCallbackList.add(onDisconnectedCallback);
  }

  void addOnSubscribedCallback(Function(String) onSubscribedCallback) {
    _onSubscribedCallbackList.add(onSubscribedCallback);
  }

  void addOnMsgReceivedCallback(Function(String payload, String topic) onMsgReceivedCallback) {
    _onMsgReceivedCallbackList.add(onMsgReceivedCallback);
  }

  void addOnConnectionFailedCallback(Function() onConnectionFailedCallback) {
    _onConnectionFailedCallbackList.add(onConnectionFailedCallback);
  }

  void removeOnConnectedCallback() {
    _onConnectedCallbackList.clear();
  }

  void removeOnSubscribedCallback() {
    _onSubscribedCallbackList.clear();
  }

  void removeOnMsgReceivedCallback(Function(String payload, String topic) onMsgReceivedCallback) {
    _onMsgReceivedCallbackList.remove(onMsgReceivedCallback);
  }
  void clearOnMsgReceivedCallback() {
    _onMsgReceivedCallbackList.clear();
  }
  void removeOnConnectionFailedCallback() {
    _onConnectionFailedCallbackList.clear();
  }

  void updateToken(String token)
  {
    print("update mqtt token");
    _client.connectionMessage.authenticateAs(_username, token);
  }

  Future<MqttServerClient> connect({bool internalRetry = false,User user }) async {
    if(!internalRetry)
      _connectionAttempt = 0;
      logger.info(">>> connection attempt: $_connectionAttempt");
    var clientId = _id + "-" + randomString(3);
      _client.logging(on: true);
      _client.onConnected = onConnected;
      _client.onDisconnected = onDisconnected;
      _client.onUnsubscribed = onUnsubscribed;
      _client.onSubscribed = onSubscribed;
      _client.onSubscribeFail = onSubscribeFail;
      _client.pongCallback = pong;
      _client.autoReconnect = true;
      _client.useWebSocket = true;
      _client.clientIdentifier = clientId;


      _client.keepAlivePeriod = 3;
      _client.port = 443; // ( or whatever your WS port is)
      _client.connectionMessage = MqttConnectMessage()
          .authenticateAs(_username, _password)
          .withClientIdentifier(clientId)
          .keepAliveFor(3)
          .startClean();
          // .will()
         // .withWillProperties(prop)
          //.withWillTopic(APP_MQTT_WILL_TOPIC)
      //     .withWillRetain()
      // .withMaximumMessageSize(256000)
      // .withRequestResponseInformation(true)
      // .withRequestProblemInformation(true);
 //         .withWillQos(MqttQos.atMostOnce);

    await _client.connect();

      _client.updates.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        logger.info("xxx got reply in mqtt client");
        final MqttPublishMessage message = c[0].payload;
        final payload =
            MqttUtilities.bytesToStringAsString(message.payload.message);
        final String topic = c[0].topic;

        logger.info("Received message: $payload from topic: $topic>");
        for (Function(String payload, String topic) msgReceivedCallback
            in _onMsgReceivedCallbackList) {
          msgReceivedCallback(payload, topic);
        }
      },onError: (e)=>{
      logger.info("xxx got reply error in mqtt client  $e")
      });


      return _client;

  }

  void subscribe(String topic) {
    logger.info("subscribing to $topic");
    _client.subscribe(topic, MqttQos.exactlyOnce);
  }

  void unsubscribe(String topic) {
    _client.unsubscribeStringTopic(topic);
  }

  void send(String topic, String content,{bool retain = false, List<MqttUserProperty> userProperties}) {
   final builder = MqttPublishMessage();

    _client.publishMessage(topic, MqttQos.exactlyOnce, MqttByteBuffer.fromList(content.codeUnits).buffer,retain: retain,userProperties: userProperties);

  }
  void sendPublishMessage(MqttPublishMessage message)
  {
    _client.publishUserMessage(message);
  }

  MqttConnectionStatus getStatus()
  {
    return _client.connectionStatus;
  }
  void onConnected() {
    logger.info("Connected");
    _isConnected = true;
    for (Function() connectedCallback in _onConnectedCallbackList) {
      connectedCallback();
    }
  }

  void onDisconnected() {
    logger.info("Disconnected");
    _isConnected = false;
    for (Function() disconnectionFailedCallback
        in _onDisconnectionFailedCallbackList) {
      disconnectionFailedCallback();
    }
  }

  void onSubscribed(MqttSubscription subscription) {
    logger.info("Subscribed to topic: ${subscription.topic}");
    for (Function(String) subscribedCallback in _onSubscribedCallbackList) {
      subscribedCallback(subscription.topic.toString());
    }
  }

  void onSubscribeFail(MqttSubscription subscription) {
    logger.warn("Failed to subscribe to ${subscription.topic}");
  }

  void onUnsubscribed(MqttSubscription subscription) {
    logger.info("Unsubscribed from topic: ${subscription.topic}");
  }

  void pong() {
    logger.info("Ping response received");
  }

  void disconnect() {
    if (_isConnected) {
      removeOnConnectedCallback();
      removeOnConnectionFailedCallback();
      clearOnMsgReceivedCallback();
      removeOnSubscribedCallback();
      _client.disconnect();
    }
  }

  String randomString(len) {
    var charSet =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    var randomString = "";
    for (var i = 0; i < len; i++) {
      int randomPoz = (Random().nextInt(charSet.length));
      randomString += charSet.substring(randomPoz, randomPoz + 1);
    }
    return randomString;
  }

  bool isConnected() {
    return _isConnected;
  }
}
