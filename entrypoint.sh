#!/bin/sh
set -e

ARGS=""

if [ -d "/ngrams/en" ] && [ -n "$(ls -A /ngrams/en 2>/dev/null)" ]; then
  ARGS="$ARGS --languageModel /ngrams"
fi

FASTTEXT_BIN="$(command -v fasttext 2>/dev/null || true)"
FASTTEXT_MODEL="/opt/languagetool/fasttext/lid.176.bin"
if [ -n "$FASTTEXT_BIN" ] && [ -f "$FASTTEXT_MODEL" ]; then
  ARGS="$ARGS --fasttextModel $FASTTEXT_MODEL --fasttextBinary $FASTTEXT_BIN"
fi

exec java \
  -Xms${JAVA_XMS:-512m} \
  -Xmx${JAVA_XMX:-2g} \
  -cp languagetool-server.jar \
  org.languagetool.server.HTTPServer \
  --port ${LISTEN_PORT:-8010} \
  --public \
  --allow-origin "*" \
  $ARGS
