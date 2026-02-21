#!/bin/sh
set -e

CONFIG="/tmp/server.properties"
> "$CONFIG"

if [ -d "/ngrams/en" ] && [ -n "$(ls -A /ngrams/en 2>/dev/null)" ]; then
  echo "languageModel=/ngrams" >> "$CONFIG"
fi

FASTTEXT_BIN="$(command -v fasttext 2>/dev/null || true)"
FASTTEXT_MODEL="/opt/languagetool/fasttext/lid.176.bin"
if [ -n "$FASTTEXT_BIN" ] && [ -f "$FASTTEXT_MODEL" ]; then
  echo "fasttextModel=$FASTTEXT_MODEL" >> "$CONFIG"
  echo "fasttextBinary=$FASTTEXT_BIN" >> "$CONFIG"
fi

exec java \
  -Xms${JAVA_XMS:-512m} \
  -Xmx${JAVA_XMX:-2g} \
  -cp languagetool-server.jar \
  org.languagetool.server.HTTPServer \
  --config "$CONFIG" \
  --port ${LISTEN_PORT:-8010} \
  --public \
  --allow-origin "*"
