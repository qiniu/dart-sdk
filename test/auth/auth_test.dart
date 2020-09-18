import 'dart:convert';

import 'package:qiniu_sdk_base/src/auth/auth.dart';
import 'package:test/test.dart';
import 'package:qiniu_sdk_base/src/auth/put_policy.dart';

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

class ManageTokenTestData {
  final List<int> bytes;
  final String expectedToken;

  ManageTokenTestData(
    this.bytes,
    this.expectedToken,
  );
}

void main() {
  group('Auth', () {
    var auth = Auth(
      accessKey: 'iN7NgwM31j4-BZacMjPrOQBs34UG1maYCAQmhdCV',
      secretKey: '6QTOr2Jg1gcZEWDQXKOGZh5PziC2MCV5KsntT70j',
    );

    test('GenerateUploadToken and parseToken should all well', () {
      var testDataTable = <UploadTokenTestData>[
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
            deadline: 0,
          ),
          'iN7NgwM31j4-BZacMjPrOQBs34UG1maYCAQmhdCV:QtVzBdciokbNk10yD9R11yI1DYU=:eyJzY29wZSI6InRlc3RCdWNrZXQiLCJkZWFkbGluZSI6MH0=',
        )
      ];

      testDataTable.forEach((testData) {
        var token = auth.generateUploadToken(putPolicy: testData.putPolicy);
        expect(token, equals(testData.expectedToken));

        var tokenInfo = Auth.parseToken(token);
        expect(tokenInfo.accessKey, equals(auth.accessKey));

        expect(
          jsonEncode(tokenInfo.putPolicy),
          equals(jsonEncode(testData.putPolicy)),
        );
      });
    });

    test('GenerateDownloadToken and parseToken should all well', () {
      var testDataTable = <DownloadTokenTestData>[
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

      testDataTable.forEach((testData) {
        var token = auth.generateDownloadToken(
          key: testData.key,
          deadline: testData.deadline,
          bucketDomain: testData.bucketDomain,
        );

        expect(token, equals(testData.expectedToken));
        var tokenInfo = Auth.parseToken(token);
        expect(tokenInfo.accessKey, equals(auth.accessKey));
        expect(tokenInfo.putPolicy, equals(null));
      });
    });

    test('GenerateAccessToken and parseToken should all well', () {
      var testDataTable = <ManageTokenTestData>[
        ManageTokenTestData(
          utf8.encode('POST /move/test\nHost: rs.qiniu.com\n\n'),
          'iN7NgwM31j4-BZacMjPrOQBs34UG1maYCAQmhdCV:-m6mplPX8YzlVQ-NE08BqHvFC-Y=',
        ),
        ManageTokenTestData(
          utf8.encode(''),
          'iN7NgwM31j4-BZacMjPrOQBs34UG1maYCAQmhdCV:6RuDjSaXfS6YN6FjMLgjOHRbQ2I=',
        ),
      ];

      testDataTable.forEach((testData) {
        var token = auth.generateAccessToken(bytes: testData.bytes);
        expect(token, equals(testData.expectedToken));
        var tokenInfo = Auth.parseToken(token);
        expect(tokenInfo.accessKey, equals(auth.accessKey));
        expect(tokenInfo.putPolicy, equals(null));
      });
    });
  });
}
