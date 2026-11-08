#!/bin/bash
# Enable token usage tracking in existing Open WebUI installation
# This script updates the database directly since environment variables
# only apply on first start for existing installations

set -euo pipefail

# Check if we're running on the server
if [ ! -d "/mnt/data/open-webui" ]; then
    echo "ERROR: This script must be run on the Open WebUI server"
    echo "Usage: ssh deploy@chat.ncg-it.com 'bash /path/to/this/script.sh'"
    exit 1
fi

DB_PATH="/mnt/data/open-webui/db.sqlite3"

if [ ! -f "$DB_PATH" ]; then
    echo "ERROR: Database not found at $DB_PATH"
    exit 1
fi

echo "Checking Open WebUI database for token usage tracking settings..."

# Check if token usage tracking is already enabled
ENABLED=$(sqlite3 "$DB_PATH" "SELECT value FROM config WHERE key = 'ENABLE_TOKEN_USAGE_TRACKING'" 2>/dev/null || echo "")
MODE=$(sqlite3 "$DB_PATH" "SELECT value FROM config WHERE key = 'TOKEN_USAGE_TRACKING_MODE'" 2>/dev/null || echo "")

echo "Current settings:"
echo "  ENABLE_TOKEN_USAGE_TRACKING: ${ENABLED:-not set}"
echo "  TOKEN_USAGE_TRACKING_MODE: ${MODE:-not set}"

# Check if token_usage table exists
if sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='token_usage'" 2>/dev/null | grep -q token_usage; then
    echo "  token_usage table: EXISTS"
    
    # Check if there's any data
    COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM token_usage" 2>/dev/null || echo "0")
    echo "  Token usage entries: $COUNT"
else
    echo "  token_usage table: NOT FOUND"
fi

echo ""

# Enable token usage tracking if not already enabled
if [ "$ENABLED" != "true" ]; then
    echo "Enabling token usage tracking..."
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO config (key, value) VALUES ('ENABLE_TOKEN_USAGE_TRACKING', 'true')"
    echo "  ✓ ENABLE_TOKEN_USAGE_TRACKING set to true"
else
    echo "  ✓ ENABLE_TOKEN_USAGE_TRACKING is already enabled"
fi

# Set tracking mode to 'all' if not set
if [ -z "$MODE" ] || [ "$MODE" != "all" ]; then
    echo "Setting token usage tracking mode to 'all'..."
    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO config (key, value) VALUES ('TOKEN_USAGE_TRACKING_MODE', 'all')"
    echo "  ✓ TOKEN_USAGE_TRACKING_MODE set to 'all'"
else
    echo "  ✓ TOKEN_USAGE_TRACKING_MODE is already set to 'all'"
fi

# Create token_usage table if it doesn't exist
if ! sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='token_usage'" 2>/dev/null | grep -q token_usage; then
    echo "Creating token_usage table..."
    sqlite3 "$DB_PATH" <<'EOF'
CREATE TABLE IF NOT EXISTS token_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    model TEXT NOT NULL,
    prompt_tokens INTEGER NOT NULL DEFAULT 0,
    completion_tokens INTEGER NOT NULL DEFAULT 0,
    total_tokens INTEGER NOT NULL DEFAULT 0,
    conversation_id TEXT,
    message_id TEXT,
    created_at DATETIME NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_token_usage_user ON token_usage(user_id);
CREATE INDEX IF NOT EXISTS idx_token_usage_model ON token_usage(model);
CREATE INDEX IF NOT EXISTS idx_token_usage_created ON token_usage(created_at);
EOF
    echo "  ✓ token_usage table created"
else
    echo "  ✓ token_usage table already exists"
fi

echo ""
echo "✅ Token usage tracking is now enabled!"
echo ""
echo "Next steps:"
echo "1. Restart Open WebUI container:"
echo "   docker compose -f /opt/open-webui/docker-compose.yml restart open-webui"
echo ""
echo "2. Send a test message in the chat"
echo ""
echo "3. Check token usage in Admin Panel -> Usage"
echo "   or query the database directly:"
echo "   sqlite3 $DB_PATH 'SELECT * FROM token_usage ORDER BY created_at DESC LIMIT 10;'"
