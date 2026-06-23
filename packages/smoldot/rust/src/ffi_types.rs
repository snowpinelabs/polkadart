//! FFI type definitions

use serde::{Deserialize, Serialize};
use std::os::raw::c_char;

/// Opaque handle to a smoldot client
pub type ClientHandle = u64;

/// Opaque handle to a chain
pub type ChainHandle = u64;

/// Callback function type for async operations
///
/// # Arguments
/// * `callback_id` - ID to match callback with request
/// * `result` - Result value (handle, string pointer, or 0 for error)
/// * `error` - Error message pointer (null if success)
pub type DartCallback = unsafe extern "C" fn(
    callback_id: i64,
    result: i64,
    error: *const c_char,
);

/// Client configuration (JSON-serializable)
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClientConfigJson {
    /// Maximum log level (0 = off, 1 = error, 2 = warn, 3 = info, 4 = debug, 5 = trace)
    #[serde(default = "default_log_level")]
    pub max_log_level: u8,

    /// System name
    #[serde(default)]
    pub system_name: Option<String>,

    /// System version
    #[serde(default)]
    pub system_version: Option<String>,
}

fn default_log_level() -> u8 {
    3 // Info
}

impl Default for ClientConfigJson {
    fn default() -> Self {
        Self {
            max_log_level: default_log_level(),
            system_name: None,
            system_version: None,
        }
    }
}

/// Add chain configuration (JSON-serializable)
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AddChainConfigJson {
    /// Chain specification (JSON string)
    pub chain_spec: String,

    /// Potential relay chain handles
    #[serde(default)]
    pub potential_relay_chains: Vec<ChainHandle>,

    /// Database content for resuming sync
    #[serde(default)]
    pub database_content: Option<String>,

    /// Disable JSON-RPC (default: false)
    #[serde(default)]
    pub disable_json_rpc: bool,
}

/// Statement-store configuration (JSON-serializable).
///
/// Mirrors the `statementStore` option of the official smoldot JS bindings. The presence of this
/// object (passed via the `statement_config_json` FFI argument) enables the statement-store
/// networking protocol on the chain. The bloom-filter seed is generated randomly and is therefore
/// not configurable here, matching upstream behaviour.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StatementStoreConfigJson {
    /// Maximum number of seen statements to cache per subscription. Defaults to 65536.
    #[serde(default = "default_max_seen_statements")]
    pub max_seen_statements: u64,

    /// Bloom-filter false-positive rate used for topic affinity. Must be in `(0, 1)`.
    /// Defaults to 0.01 (1%).
    #[serde(default = "default_false_positive_rate")]
    pub false_positive_rate: f64,

    /// Debounce interval (milliseconds) for sending affinity filter updates to peers.
    /// Must be greater than zero. Defaults to 1000.
    #[serde(default = "default_affinity_update_interval_ms")]
    pub affinity_update_interval_ms: u64,
}

fn default_max_seen_statements() -> u64 {
    65536
}

fn default_false_positive_rate() -> f64 {
    0.01
}

fn default_affinity_update_interval_ms() -> u64 {
    1000
}

/// Log message from smoldot
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LogMessage {
    /// Log level
    pub level: u8,

    /// Log message
    pub message: String,

    /// Timestamp (milliseconds since epoch)
    pub timestamp: u64,
}

/// Chain status
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChainStatus {
    /// Whether the chain is synced
    pub is_synced: bool,

    /// Current block number
    pub block_number: Option<u64>,

    /// Best block hash
    pub best_block_hash: Option<String>,
}
