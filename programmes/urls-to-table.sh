#!/bin/bash

if [ $# -ne 1 ]; then
	echo "Usage: $0 fichier_urls"
	exit 1
fi

fichier_urls=$1
mkdir -p tableaux

{
    echo "<html>"
    echo "<head><meta charset=\"UTF-8\"></head>"
    echo "<body>"
    echo "<table border='1'>"
    echo "<tr><th>numero</th><th>URL</th><th>code</th><th>encodage</th></tr>"
    
    lineno=1
    while read -r line; do
	read http_code content_type <<< $(
  	 curl -s -L \
        	-k \
        	-A "Mozilla/5.0" \
        	-o /dev/null \
       		-w "%{http_code} %{content_type}" \
        	"$line"
	)
    	encoding=$(echo "$content_type" | grep -o "charset=\S+" | cut -d= -f2)
   	encoding=${encoding:-"N/A"}

        echo "<tr>"
        echo "  <td>$lineno</td>"
        echo "  <td>$line</td>"
        echo "  <td>$http_code</td>"
        echo "  <td>$encoding</td>"
        echo "</tr>"

        lineno=$((lineno+1))
    done < "$fichier_urls"

    echo "</table>"
    echo "</body>"
    echo "</html>"
}
