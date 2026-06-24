/// A standard string-based JSON-RPC transport, mirroring polkadot-api's
/// `JsonRpcProvider` (`@polkadot-api/json-rpc-provider`).
///
/// Call a [JsonRpcProvider] with an `onMessage` callback to open a
/// [JsonRpcConnection]; every inbound JSON-RPC response/notification arrives as
/// a raw JSON string on `onMessage`. The caller owns the JSON-RPC envelope
/// (ids, params) and subscription-id correlation — i.e. runs its own JSON-RPC
/// client on top, exactly as on the JS/TS path.
library;

/// A live JSON-RPC connection opened by a [JsonRpcProvider].
///
/// Mirrors polkadot-api's `JsonRpcConnection`.
abstract interface class JsonRpcConnection {
  /// Send a raw JSON-RPC request string to the peer.
  void send(String message);

  /// Close the connection and release its resources.
  void disconnect();
}

/// Open a [JsonRpcConnection], delivering each inbound JSON-RPC message string
/// to [onMessage]. Mirrors polkadot-api's string-based `JsonRpcProvider`.
typedef JsonRpcProvider =
    JsonRpcConnection Function(void Function(String message) onMessage);
