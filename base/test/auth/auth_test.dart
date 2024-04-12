import 'dart:convert';

import 'package:qiniu_sdk_base/src/auth/auth.dart';
import 'package:test/test.dart';

class UploadTokenTestData {
  final PutPolicy putPolicy;
  final String expectedToken;

  UploadTokenTestData(
    this.putPolicy,
    this.expectedToken,
  );
}

class DownloadTokenTestData {
  final String key;
  final int deadline;
  final String bucketDomain;
  final String expectedToken;

  DownloadTokenTestData(
    this.key,
    this.deadline,
    this.bucketDomain,
    this.expectedToken,
  );
}

class AccessTokenTestData {
  final List<int> bytes;
  final String expectedToken;

  AccessTokenTestData(
    this.bytes,
    this.expectedToken,
  );
}

void main() {
  group('Auth', () {
    final auth = Auth(
      accessKey: 'iN7NgwM31j4-BZacMjPrOQBs34UG1maYCAQmhdCV',
      secretKey: '6QTOr2Jg1gcZEWDQXKOGZh5PziC2MCV5KsntT70j',
    );

    test('GenerateUploadToken and parseToken should all well', () {
      final testDataTable = <UploadTokenTestData>[
        UploadTokenTestData(
          PutPolicy(
            scope: 'testBucket',
            deadline: 1600000000,
          ),
          'iN7NgwM31j4-BZacMjPrOQBs34UG1maYCAQmhdCV:1uOlX2X1DDzYAAqtRx6Fm3qCI5g=:eyJzY29wZSI6InRlc3RCdWNrZXQiLCJkZWFkbGluZSI6MTYwMDAwMDAwMH0=',
        ),
        UploadTokenTestData(
          PutPolicy(
            scope: 'testBucket:testFileName',
            deadline: 1600000000,
          ),
          'iN7NgwM31j4-BZacMjPrOQBs34UG1maYCAQmhdCV:IajPT4vS-XXx5pBoGJzniPAXOQU=:eyJzY29wZSI6InRlc3RCdWNrZXQ6dGVzdEZpbGVOYW1lIiwiZGVhZGxpbmUiOjE2MDAwMDAwMDB9',
        ),
        UploadTokenTestData(
          PutPolicy(
            scope: 'testBucket',
            deadline: 1600000000,
            returnBody: '{"key": \$(key)}',
          ),
          'iN7NgwM31j4-BZacMjPrOQBs34UG1maYCAQmhdCV:eoB_J567JC0ihTlAIlPC40ypH1s=:eyJzY29wZSI6InRlc3RCdWNrZXQiLCJkZWFkbGluZSI6MTYwMDAwMDAwMCwicmV0dXJuQm9keSI6IntcImtleVwiOiAkKGtleSl9In0=',
        ),
        UploadTokenTestData(
          PutPolicy(
            scope: 'testBucket',
            deadline: 1600000000,
            returnBody: '{"key": \$(key)}',
            callbackUrl: 'http://test.qiniu.com',
          ),
          'iN7NgwM31j4-BZacMjPrOQBs34UG1maYCAQmhdCV:noK7jkMNZbw-padaaHy71buHpy8=:eyJzY29wZSI6InRlc3RCdWNrZXQiLCJkZWFkbGluZSI6MTYwMDAwMDAwMCwicmV0dXJuQm9keSI6IntcImtleVwiOiAkKGtleSl9IiwiY2FsbGJhY2tVcmwiOiJodHRwOi8vdGVzdC5xaW5pdS5jb20ifQ==',
        ),
        UploadTokenTestData(
          PutPolicy(
            scope: 'testBucket',
            deadline: 0,
          ),
          'iN7NgwM31j4-BZacMjPrOQBs34UG1maYCAQmhdCV:QtVzBdciokbNk10yD9R11yI1DYU=:eyJzY29wZSI6InRlc3RCdWNrZXQiLCJkZWFkbGluZSI6MH0=',
        ),
      ];

      for (final testData in testDataTable) {
        final token = auth.generateUploadToken(putPolicy: testData.putPolicy);
        expect(token, equals(testData.expectedToken));

        final tokenInfo = Auth.parseToken(token);
        expect(tokenInfo.accessKey, equals(auth.accessKey));

        expect(
          jsonEncode(tokenInfo.putPolicy),
          equals(jsonEncode(testData.putPolicy)),
        );
      }
    });

    test('GenerateDownloadToken and parseToken should all well', () {
      final testDataTable = <DownloadTokenTestData>[
        DownloadTokenTestData(
          'testFileName',
          1600000000,
          'http://test.com',
          'iN7NgwM31j4-BZacMjPrOQBs34UG1maYCAQmhdCV:ppahIsv-ehlkAzqiQmVOZ2ouTuU=',
        ),
        DownloadTokenTestData(
          '',
          1600000000,
          'http://test.com',
          'iN7NgwM31j4-BZacMjPrOQBs34UG1maYCAQmhdCV:Ez68XTdH7Fnffhkv3qIeeEElHA0=',
        ),
        DownloadTokenTestData(
          '',
          1600000000,
          '',
          'iN7NgwM31j4-BZacMjPrOQBs34UG1maYCAQmhdCV:afaZUdigQVqeKwPuYHrFGeZ1TRM=',
        ),
        DownloadTokenTestData(
          '',
          0,
          '',
          'iN7NgwM31j4-BZacMjPrOQBs34UG1maYCAQmhdCV:mhf_F_hEI7tLc7CnF499zEfqfLU=',
        ),
      ];

      for (final testData in testDataTable) {
        final token = auth.generateDownloadToken(
          key: testData.key,
          deadline: testData.deadline,
          bucketDomain: testData.bucketDomain,
        );

        expect(token, equals(testData.expectedToken));
        final tokenInfo = Auth.parseToken(token);
        expect(tokenInfo.accessKey, equals(auth.accessKey));
        expect(tokenInfo.putPolicy, equals(null));
      }
    });

    test('GenerateAccessToken and parseToken should all well', () {
      final testDataTable = <AccessTokenTestData>[
        AccessTokenTestData(
          utf8.encode('POST /move/test\nHost: rs.qiniu.com\n\n'),
          'iN7NgwM31j4-BZacMjPrOQBs34UG1maYCAQmhdCV:-m6mplPX8YzlVQ-NE08BqHvFC-Y=',
        ),
        AccessTokenTestData(
          utf8.encode(''),
          'iN7NgwM31j4-BZacMjPrOQBs34UG1maYCAQmhdCV:6RuDjSaXfS6YN6FjMLgjOHRbQ2I=',
        ),
      ];

      for (final testData in testDataTable) {
        final token = auth.generateAccessToken(bytes: testData.bytes);
        expect(token, equals(testData.expectedToken));
        final tokenInfo = Auth.parseToken(token);
        expect(tokenInfo.accessKey, equals(auth.accessKey));
        expect(tokenInfo.putPolicy, equals(null));
      }
    });

    test('parseUpToken should works well.', () async {
      try {
        Auth.parseUpToken('123');
      } catch (e) {
        expect(e, isA<ArgumentError>());
      }

      final token = auth.generateUploadToken(
        putPolicy: PutPolicy(
          scope: 'testBucket',
          deadline: 1600000000,
        ),
      );

      final tokenInfo = Auth.parseUpToken(token);
      expect(tokenInfo.putPolicy.scope, 'testBucket');
    });
  });
}
