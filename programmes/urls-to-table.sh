{
echo "<html>
<head><meta charset=\"UTF-8\"></head>
<body>
<table>
<tr><th>numero</th><th>URL</th><th>code</th><th>encodage</th></tr>"

lineno=1
while read -r line
do
    read http_code content_type <<< $(curl -s -L -o /dev/null -w "%{http_code} %{content_type}" "$line")
    encoding=$(echo "$content_type" | grep -o "charset=\S+" | cut -d= -f2)
    encoding=${encoding:-"N/A"}

    echo "<tr>
<td>$lineno</td>
<td>$line</td>
<td>$http_code</td>
<td>$encoding</td>
</tr>"

    lineno=$((lineno+1))
done < "$fichier_urls"

echo "</table></body></html>"
} > tableaux/kr.html
