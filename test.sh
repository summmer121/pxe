#!/bin/bash



n=1
x=()
while true
do
read -p "请输入dhcp网关$n,回车默认结束输入:"  a
if  [ ! -n "$a" ] ;then
	echo '输入为空'
	break
fi
echo $a
x[$n]=$a
n=$[$n+1]
done

for i in ${x[*]}
do 
echo $i
done
