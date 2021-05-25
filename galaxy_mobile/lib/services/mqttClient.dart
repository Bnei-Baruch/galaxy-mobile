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

  final void Function() _onConnectedCallback;
  final void Function(String) _onSubscribedCallback;
  final void Function(String) _onMsgReceivedCallback;

  MQTTClient(this._username, this._password, this._onMsgReceivedCallback,
      this._onConnectedCallback, this._onSubscribedCallback) {
    _client =
        MqttServerClient.withPort(APP_MQTT_HOST,
            APP_MQTT_CLIENT_ID, APP_MQTT_PORT);
  }

  Future<MqttServerClient> connect() async {
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
      await _client.connect();
    } catch (e) {
      logger.trace("Exception during connection to broker", e);
      _client.disconnect();
      return null;
    }

    _client.updates.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage message = c[0].payload;
      final payload =
          MqttPublishPayload.bytesToStringAsString(message.payload.message);

      logger.info("Received message: $payload from topic: ${c[0].topic}>");
      _onMsgReceivedCallback(payload);
    });

    return _client;
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
    _onConnectedCallback();
  }

  void onDisconnected() {
    logger.info("Disconnected");
  }

  void onSubscribed(String topic) {
    logger.info("Subscribed to topic: $topic");
    _onSubscribedCallback(topic);
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
    _client.disconnect();
  }
}
