#!/bin/bash

set -a
source .env
set +a

subject="Test results"
file="../results.txt"
filetype="text/plain"

curl -s --url 'smtps://smtp.gmail.com:465' --ssl-reqd \
    --mail-from "$SENDER_MAIL" \
    --mail-rcpt "$RECEIVER_MAIL" \
    --user "$SENDER_MAIL:$SENDER_PASSWD" \
    -H "From: ${SENDER_MAIL}" \
    -H "To: ${RECEIVER_MAIL}" \
    -H "Subject : ${subject}" \
    -F '=(;type=multipart/mixed' \
    -F '="Here are the results";type=text/plain' \
    -F "file=@$file;type=$filetype;encoder=base64" \
    -F "=)" \
