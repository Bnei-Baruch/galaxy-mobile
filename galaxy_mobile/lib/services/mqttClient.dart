import 'dart:math';

import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/config/env.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

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

  void addOnMsgReceivedCallback(Function(String) onMsgReceivedCallback) {
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

  void removeOnMsgReceivedCallback() {
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

  Future<MqttServerClient> connect({bool internalRetry = false}) async {
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
      _client.keepAlivePeriod = 10;
      _client.port = 443; // ( or whatever your WS port is)
      _client.connectionMessage = MqttConnectMessage()
          .authenticateAs(_username, _password)
          .withClientIdentifier(clientId)
          .keepAliveFor(10)
          .startClean()
          .will()
          .withProtocolVersion(4)
          .withProtocolName("MQTT")
          .withWillTopic(APP_MQTT_WILL_TOPIC)
          .withWillMessage(APP_MQTT_WILL_MESSAGE)
          .withWillRetain()
          .withWillQos(MqttQos.exactlyOnce);

    await _client.connect();

      _client.updates.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage message = c[0].payload;
        final payload =
            MqttPublishPayload.bytesToStringAsString(message.payload.message);

        logger.info("Received message: $payload from topic: ${c[0].topic}>");
        for (Function(String) msgReceivedCallback
            in _onMsgReceivedCallbackList) {
          msgReceivedCallback(payload);
        }
      });


      return _client;

  }

  void subscribe(String topic) {
    logger.info("subscribing to $topic");
    _client.subscribe(topic, MqttQos.exactlyOnce);
  }

  void unsubscribe(String topic) {
    _client.unsubscribe(topic);
  }

  void send(String topic, String content) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(content);
    _client.publishMessage(topic, MqttQos.exactlyOnce, builder.payload);
  }

  MqttClientConnectionStatus getStatus()
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

  void onSubscribed(String topic) {
    logger.info("Subscribed to topic: $topic");
    for (Function(String) subscribedCallback in _onSubscribedCallbackList) {
      subscribedCallback(topic);
    }
  }

  void onSubscribeFail(String topic) {
    logger.warn("Failed to subscribe to $topic");
  }

  void onUnsubscribed(String topic) {
    logger.info("Unsubscribed from topic: $topic");
  }

  void pong() {
    logger.info("Ping response received");
  }

  void disconnect() {
    if (_isConnected) {
      removeOnConnectedCallback();
      removeOnConnectionFailedCallback();
      removeOnMsgReceivedCallback();
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
