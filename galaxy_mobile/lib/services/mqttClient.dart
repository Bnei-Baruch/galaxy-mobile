import 'package:flutter_logs/flutter_logs.dart';
import 'package:galaxy_mobile/config/env.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'logger.dart';

final logger = new Logger("MQTTClient");

class MQTTClient {
  String _username;
  String _password;

  MqttServerClient _client;

  final int _maxConnectionAttempts = 3;
  int _connectionAttempt = 0;
  bool _isConnected = false;

  var _onConnectedCallbackList = new List();
  var _onSubscribedCallbackList = new List();
  var _onMsgReceivedCallbackList = new List();
  var _onConnectionFailedCallbackList = new List();

  MQTTClient() {
    _client =
        MqttServerClient.withPort(APP_MQTT_HOST,
            APP_MQTT_CLIENT_ID, APP_MQTT_PORT);
  }

  void init(String username, String password) {
    _username = username;
    _password = password;
  }

  void addOnConnectedCallback(Function() onConnectedCallback) {
    _onConnectedCallbackList.add(onConnectedCallback);
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

  Future<MqttServerClient> connect() async {
    logger.info(">>> connection attempt: $_connectionAttempt");
    if (_connectionAttempt < _maxConnectionAttempts) {
      _client.logging(on: true);
      _client.onConnected = onConnected;
      _client.onDisconnected = onDisconnected;
      _client.onUnsubscribed = onUnsubscribed;
      _client.onSubscribed = onSubscribed;
      _client.onSubscribeFail = onSubscribeFail;
      _client.pongCallback = pong;
      _client.secure = true;
      _client.connectionMessage = MqttConnectMessage()
          .authenticateAs(_username, _password)
          .withClientIdentifier(APP_MQTT_CLIENT_ID)
          .keepAliveFor(60)
          .startClean()
          .will()
          .withWillTopic(APP_MQTT_WILL_TOPIC)
          .withWillMessage(APP_MQTT_WILL_MESSAGE)
          .withWillRetain()
          .withWillQos(MqttQos.exactlyOnce);

      try {
        Future.delayed(const Duration(seconds: 5), () {
          if (!_isConnected) {
            _connectionAttempt++;
            connect();
          }
        });
        await _client.connect();
      } catch (e) {
        logger.trace("Exception during connection to broker", e);
        _client.disconnect();
        _connectionAttempt++;
        connect();
      }

      _client.updates.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage message = c[0].payload;
        final payload =
        MqttPublishPayload.bytesToStringAsString(message.payload.message);

        logger.info("Received message: $payload from topic: ${c[0].topic}>");
        for (Function(String) msgReceivedCallback in _onMsgReceivedCallbackList) {
          msgReceivedCallback(payload);
        }
      });

      return _client;
    } else {
      logger.error("connection to MQTT failed");
      for (Function() connectionFailedCallback in _onConnectionFailedCallbackList) {
        connectionFailedCallback();
      }
      return null;
    }
  }

  void subscribe(String topic) {
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
      _client.disconnect();
    }
  }
}
