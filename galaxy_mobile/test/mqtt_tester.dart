import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:galaxy_mobile/services/mqtt_client.dart';
import 'package:galaxy_mobile/utils/utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('prepare mqtt test', () async {
    var mqtt = MQTTClient();
    mqtt.init(
        "igal@hotmail.com",
        "eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJxVHZYMkh3elFhbjVadlNlUHJtRWxkZE0zUFYzYUU0R1liRVFvSnJ3U2hZIn0.eyJleHAiOjE2MzI3ODk0MjMsImlhdCI6MTYzMjc4NzYyMywiYXV0aF90aW1lIjoxNjMyNzg3NjIxLCJqdGkiOiI5OGUwNTAyNS05ODQxLTRjYmYtYjNkNC1hMDY4ODI3YmU1ZWMiLCJpc3MiOiJodHRwczovL2FjY291bnRzLmthYi5pbmZvL2F1dGgvcmVhbG1zL21haW4iLCJhdWQiOiJhY2NvdW50Iiwic3ViIjoiZDA0NGVlN2ItMmUyYi00Y2E3LWE3ZTUtOWMxNDg4ODlmZjdiIiwidHlwIjoiQmVhcmVyIiwiYXpwIjoiZ2FsYXh5Iiwic2Vzc2lvbl9zdGF0ZSI6IjkyNTcxNGFmLWRkNDgtNGZkZS04MTg5LTUyZjlhNjE5MmFjZCIsImFjciI6IjEiLCJhbGxvd2VkLW9yaWdpbnMiOlsiKiJdLCJyZWFsbV9hY2Nlc3MiOnsicm9sZXMiOlsiZ3h5X3VzZXIiLCJvZmZsaW5lX2FjY2VzcyIsInVtYV9hdXRob3JpemF0aW9uIl19LCJyZXNvdXJjZV9hY2Nlc3MiOnsiYWNjb3VudCI6eyJyb2xlcyI6WyJtYW5hZ2UtYWNjb3VudCIsIm1hbmFnZS1hY2NvdW50LWxpbmtzIiwidmlldy1wcm9maWxlIl19fSwic2NvcGUiOiJvcGVuaWQgcHJvZmlsZSBlbWFpbCIsInNpZCI6IjkyNTcxNGFmLWRkNDgtNGZkZS04MTg5LTUyZjlhNjE5MmFjZCIsImJiIjoidXNlciIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJuYW1lIjoiaWdhbCB0ZXN0IEF2cmFoYW0iLCJwcmVmZXJyZWRfdXNlcm5hbWUiOiJpZ2FsQGhvdG1haWwuY29tIiwiZ2l2ZW5fbmFtZSI6ImlnYWwgdGVzdCIsImZhbWlseV9uYW1lIjoiQXZyYWhhbSIsImVtYWlsIjoiaWdhbEBob3RtYWlsLmNvbSJ9.PB-PUzdoip93waQU6KUbTxZyUov3AEN8UkGa8x3WFV0J6hyD0sulO_dizrg5k0XcP9Lw1YGKx-8DvrJ0m0f8zkKCua6YuOt8SS9FBkicKd3a4idGFm5W1Seh_98yUTHCUNvFLVUISLScgUuo6MU2dGmVJGEa-nkq4n7depa4oEt18uAiotRTmS5dLrR9iPtsAIHAHYzxbw5cLwRYTr5vMFitTANR48fc2RRAmmpv4DcsOFNkdQbi99lJNjMny83ygYB6z-yYwSPrg8U0khPJfIze3YhcnEK9Xc96O8h7sD2NjEfmdVvNkwG3hKHhIlP_a4eH6L1mBN1nIkzeoduCaA",
        "");
    mqtt.connect();
  });
}
