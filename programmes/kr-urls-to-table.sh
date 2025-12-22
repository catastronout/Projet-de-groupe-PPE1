while read -r URL
do
    HTTP_CODE=$(curl -A "Mozilla/5.0" --max-time 20 -s -L -o /dev/null -w "%{http_code}" "$URL")

    if [[ "$HTTP_CODE" -lt 200 || "$HTTP_CODE" -ge 300 ]]; then
        echo "$URL,$HTTP_CODE" >> errors.csv
        continue
    fi

    HTML=$(curl -A "Mozilla/5.0" -s -L "$URL")

done < "$1"


