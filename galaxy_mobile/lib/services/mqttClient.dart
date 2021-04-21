import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';


class MQTTClient {
  String _username;
  String _password;

  MqttServerClient _client;

  final void Function() _onConnectedcallback;
  final void Function(String) _onMsgReceivedcallback;

  MQTTClient(this._username, this._password,
      this._onMsgReceivedcallback, this._onConnectedcallback)
  {
    _client =
        MqttServerClient.withPort('mqtt.kli.one', 'mobile_test_clientid', 9001);
  }

  Future<MqttServerClient> connect() async {
    // MqttServerClient client =
    // MqttServerClient.withPort('mqtt.kli.one', 'mobile_test_clientid', 9001);

    _client.logging(on: true);
    _client.onConnected = onConnected;
    _client.onDisconnected = onDisconnected;
    _client.onUnsubscribed = onUnsubscribed;
    _client.onSubscribed = onSubscribed;
    _client.onSubscribeFail = onSubscribeFail;
    _client.pongCallback = pong;
    _client.secure = true;
    _client.connectionMessage = MqttConnectMessage()
        // .authenticateAs('kirilsagoth2@gmail.com', _password)
        .authenticateAs(_username, _password)
        .withClientIdentifier('mobile_test_clientid')
        .keepAliveFor(60)
        .startClean()
        .will()
        .withWillTopic('galaxy/service/user')
        .withWillMessage('{ type: \'event\', user: false }')
        .withWillRetain()
        .withWillQos(MqttQos.atMostOnce);

    try {
      await _client.connect();
    } catch (e) {
      print('[MQTTClient] >>> Exception during connection to broker: $e');
      _client.disconnect();
      return null;
    }

    _client.updates.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage message = c[0].payload;
      final payload =
      MqttPublishPayload.bytesToStringAsString(message.payload.message);

      print('[MQTTClient] Received message: $payload from topic: ${c[0].topic}>');
      _onMsgReceivedcallback(payload);
    });

    // _client.subscribe('galaxy/users/broadcast', MqttQos.atMostOnce);
    // client.subscribe('galaxy/users/user', MqttQos.atMostOnce);

    return _client;
  }

  void subscribe(String topic) {
    _client.subscribe(topic, MqttQos.atMostOnce);
  }

  void send(String topic, String content) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(content);
    _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload);
  }

  void onConnected() {
    print('[MQTTClient] Connected');
    _onConnectedcallback();
  }

  void onDisconnected() {
    print('[MQTTClient] Disconnected');
  }

  void onSubscribed(String topic) {
    print('[MQTTClient] Subscribed to topic: $topic');
    send(topic, 'Hello MQTT');
  }

  void onSubscribeFail(String topic) {
    print('[MQTTClient] Failed to subscribe to $topic');
  }

  void onUnsubscribed(String topic) {
    print('[MQTTClient] Unsubscribed from topic: $topic');
  }

  void pong() {
    print('[MQTTClient] Ping response received');
  }
}