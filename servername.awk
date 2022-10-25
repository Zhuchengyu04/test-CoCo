$0~ /Product.*/ {printf "%s","\nserver型号: "$(NF-1)" "$NF}
$0~ /Serial.*/ {printf "%s",$0"\n"}