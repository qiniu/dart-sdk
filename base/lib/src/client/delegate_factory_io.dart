import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// SO_SNDBUF 在各平台的 optname。
///
/// 参考：
/// - Linux/Android/Fuchsia: `include/uapi/asm-generic/socket.h` 中 `SO_SNDBUF = 7`
/// - macOS/iOS: `sys/socket.h` 中 `SO_SNDBUF = 0x1001`
/// - Windows: `winsock2.h` 中 `SO_SNDBUF = 0x1001`
const int _kSoSndBufLinux = 7;
const int _kSoSndBufBsd = 0x1001;

/// Native 平台：当 [sendBufferSize] 非空且当前平台支持设置 SO_SNDBUF 时，
/// 构造带 connectionFactory 的 [IOHttpClientAdapter]，
/// 通过 SO_SNDBUF 限制内核发送缓冲以配合写超时检测；
/// 否则退化为 dio 默认 adapter。
HttpClientAdapter createDefaultDelegate(int? sendBufferSize) {
  if (sendBufferSize == null) return HttpClientAdapter();

  final option = _buildSndBufOption(sendBufferSize);
  if (option == null) {
    // 当前平台不支持设置 SO_SNDBUF，回退到默认 adapter
    return HttpClientAdapter();
  }

  return IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.connectionFactory = (uri, proxyHost, proxyPort) async {
        // 直连 HTTPS：必须用 SecureSocket.startConnect，HttpClient 拿到 socket
        // 后不会自己再走 TLS，必须由 connectionFactory 完成。
        // HTTP / 代理 HTTPS：HttpClient 内部会自己处理（HTTP 走明文，代理 HTTPS
        // 走 createProxyTunnel），返回裸 TCP Socket 即可。
        // SO_SNDBUF 在 SecureSocket 完成 TLS 握手后设置的同一 fd 上仍生效。
        final isDirectHttps = uri.isScheme('https') && proxyHost == null;
        final host = proxyHost ?? uri.host;
        final port = proxyPort ?? uri.port;
        final ConnectionTask<Socket> task = isDirectHttps
            ? await SecureSocket.startConnect(host, port)
            : await Socket.startConnect(host, port);
        task.socket.then((socket) {
          try {
            socket.setRawOption(option);
          } catch (_) {
            // SO_SNDBUF 设置失败不影响正常连接，静默忽略
          }
        });
        return task;
      };
      return client;
    },
  );
}

/// 按平台构造 SO_SNDBUF 的 [RawSocketOption]，
/// 不支持的平台返回 null。
RawSocketOption? _buildSndBufOption(int size) {
  final int optionName;
  if (Platform.isLinux || Platform.isAndroid || Platform.isFuchsia) {
    optionName = _kSoSndBufLinux;
  } else if (Platform.isMacOS || Platform.isIOS || Platform.isWindows) {
    optionName = _kSoSndBufBsd;
  } else {
    return null;
  }
  return RawSocketOption.fromInt(
    RawSocketOption.levelSocket,
    optionName,
    size,
  );
}
