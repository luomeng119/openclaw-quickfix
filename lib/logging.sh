#!/usr/bin/env bash
# logging.sh - 增强日志系统

# 日志级别
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

# 当前日志级别 (默认INFO)
CURRENT_LOG_LEVEL=${LOG_LEVEL:-1}
LOG_FILE="${LOG_FILE:-/tmp/openclaw-quickfix.log}"

# 初始化日志
init_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
}

# 分级日志
log_debug() { [[ $CURRENT_LOG_LEVEL -le 0 ]] && echo "[$(date '+%H:%M:%S')] [DEBUG] $*" | tee -a "$LOG_FILE"; }
log_info()  { [[ $CURRENT_LOG_LEVEL -le 1 ]] && echo "[$(date '+%H:%M:%S')] [INFO]  $*" | tee -a "$LOG_FILE"; }
log_warn()  { [[ $CURRENT_LOG_LEVEL -le 2 ]] && echo "[$(date '+%H:%M:%S')] [WARN]  $*" | tee -a "$LOG_FILE"; }
log_error() { [[ $CURRENT_LOG_LEVEL -le 3 ]] && echo "[$(date '+%H:%M:%S')] [ERROR] $*" | tee -a "$LOG_FILE"; }
