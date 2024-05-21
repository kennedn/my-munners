#!/bin/bash

COMMAND=${1}
shift
SEARCH=$*

[ "${COMMAND}" == "post" ] && [ -z "${SEARCH}" ] && echo "Must provide a search for post" && exit 1

[ -z "${MUNNER_USER}" ] && read -rp "Username: " MUNNER_USER
[ -z "${MUNNER_PASS}" ] && read -rsp "Password: " MUNNER_PASS

BASE_URL='https://gsdqxsedgygflroywsnl.supabase.co'

API_KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdzZHF4c2VkZ3lnZmxyb3l3c25sIiwicm9sZSI6ImFub24iLCJpYXQiOjE2NjQyNzY4MTksImV4cCI6MTk3OTg1MjgxOX0.u31t9CnAnzR60oCr9Z2mIP_u75DcwU6fwDb4IhK9QdU'

JSON=$(jq -cn \
         --arg username "$MUNNER_USER" \
         --arg password "$MUNNER_PASS" \
         '{"email":$username,"password":$password,"data":{},"gotrue_meta_security":{}}')

[ -z "${ACCESS_TOKEN}" ] && ACCESS_TOKEN=$(curl -s "${BASE_URL}/auth/v1/token?grant_type=password" -X POST -H 'Content-Type: application/json' -H "Authorization: Bearer ${API_KEY}" -H "apikey: ${API_KEY}" -H 'Origin: https://munrobagger.scot' --data-binary "${JSON}" | jq -r '.access_token // ""')

PROFILE_ID=$(jq -rR 'split(".") | .[1] | @base64d | fromjson | .sub' <<<"${ACCESS_TOKEN}")

if [ "${COMMAND}" == "get" ]; then
    MUNRO_IDS=$(curl -s "${BASE_URL}/rest/v1/bagged_munros?select=munro_id" -H "Authorization: Bearer ${ACCESS_TOKEN}" -H "apikey: ${API_KEY}" -H 'Origin: https://munrobagger.scot')
    jq -r --argjson ids "${MUNRO_IDS}" '.[] | select(.id as $id | $ids | any(.munro_id == $id)) | .name' munners.json
elif [ "${COMMAND}" == "post" ] || [ "${COMMAND}" == "delete" ]; then
    SEARCH_RESULT_JSONS=$(jq -r --arg search "${SEARCH}" '($search | split(" ") | map(ascii_downcase)) as $words | [.[] | reduce $words[] as $word (.; select((. != null) and (.name | ascii_downcase | contains($word)))) | select(. != null)]' munners.json)
    [ "$(jq length <<<"${SEARCH_RESULT_JSONS}")" -gt 1 ] && echo "More than one munro found:" && jq -r '.[].name' <<<"${SEARCH_RESULT_JSONS}" && exit 1
    MUNRO_ID=$(jq -r '.[0].id' <<<"${SEARCH_RESULT_JSONS}")
    [ -z "${MUNRO_ID}" ] && echo "No matches" && exit 0
    jq -r '.[0].name' <<<"${SEARCH_RESULT_JSONS}"
    ANSWER=
    while [ "${ANSWER}" != "y" ] && [ "${ANSWER}" != "n" ]; do
        read -rp "${COMMAND^} selected munro (y/n)? " ANSWER
    done
    [ "${ANSWER}" == "n" ] && exit 0
    if [ "${COMMAND}" == "post" ]; then
        POST_JSON=$(jq -cn \
                    --arg profile_id "$PROFILE_ID" \
                    --arg munro_id "$MUNRO_ID" \
                    '[{"profile_id":$profile_id,"munro_id":$munro_id}]')
        curl "${BASE_URL}/rest/v1/bagged_munros?columns=%22profile_id%22%2C%22munro_id%22" -X POST -H 'content-type: application/json' -H "Authorization: Bearer ${ACCESS_TOKEN}" -H "apikey: ${API_KEY}" -H 'Origin: https://munrobagger.scot' --data-binary "${POST_JSON}"
    else
        curl "${BASE_URL}/rest/v1/bagged_munros?munro_id=eq.${MUNRO_ID}" -X DELETE -H "Authorization: Bearer ${ACCESS_TOKEN}" -H "apikey: ${API_KEY}" -H 'Origin: https://munrobagger.scot' 
    fi
fi

#curl "${BASE_URL}/auth/v1/logout" -X POST -H "Authorization: Bearer ${ACCESS_TOKEN}" -H "apikey: ${API_KEY}" -H 'Origin: https://munrobagger.scot'
