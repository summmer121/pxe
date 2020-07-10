#/bin/bash
#############################

echo "##############################################"
echo "##      一键部署pxe脚本 使用注意事项       ###"
echo "##        1：确保本地yum源设置ok           ###"
echo "##        2：将多个镜像挂载到/mnt子文件夹  ###"
echo "##        3：所有服务器业务网ip相通        ###"
echo "##        4：会自动使用root目录下的        ###"
echo "##        anaconda-ks.cfg应答文件，        ###"
echo "##        其他服务器会按照本机模板批量安装 ###"
echo "##        5: 请将info、脚本放置root目录下  ###"
echo "##############################################"
echo ''

#############设置dhcp服务端

n=1
ip_list=()
echo "请输入多个dhcp网关，第一个输入默认为ftp地址"
while true
do
read -p "请输入dhcp网关$n,回车默认结束输入:"  a
if  [ ! -n "$a" ] ;then
        echo '输入为空'
        break
else
if [ $(echo $a |awk -F. '{print NF}') -ne 4 ];then
        echo "输入ip错误，请重新输入"
        exit 0
fi

fi
echo $a
ip_list[$n]=$a
n=$[$n+1]
done
echo "输入的ip如下，请核对:"
for i in ${ip_list[*]}
do
echo $i
done
ip="${ip_list[1]}"

yum install -y dhcp xinetd tftp-server syslinux vsftpd tcpdump >/dev/null
echo "-----------------检查是否安装完成----------------"
for i in {'dhcp','xinetd','tftp-server','vsftpd','syslinux','tcpdump'}
do
	rpm -q $i>/dev/null
	if [ $? -eq 0 ];then
		echo -e "      $i    \033[32m 安装成功 \033[0m    "
	else
		echo -e "      $i   \033[31m 未安装 \033[0m    "
	fi
done
echo "-------------------全部安装完成-----------------"
echo ''
#echo "-------------------开始设置dhcp服务-------------"
cat>/etc/dhcp/dhcpd.conf<<EOF
log-facility local7;
allow booting;
allow bootp;
option space pxelinux;
option pxelinux.magic code 208 = string;
option pxelinux.configfile code 209 = text;
option pxelinux.pathprefix code 210 = text;
option pxelinux.reboottime code 211 = unsigned integer 32;
option architecture-type code 93 = unsigned integer 16;
EOF
for i in ${ip_list[*]}
do
subnet=${i%%$(echo $i |awk -F. '{print $4}')}"0"
range1=${i%%$(echo $i |awk -F. '{print $4}')}"10"
range2=${i%%$(echo $i |awk -F. '{print $4}')}"254"
cat>>/etc/dhcp/dhcpd.conf<<EOF
subnet $subnet netmask 255.255.255.0 {
  range $range1 $range2;
  option routers $i;
  next-server $i;
  if option architecture-type = 00:07 or
     option architecture-type = 00:09 {
       filename "bootx64.efi";
       } 
  else {
       filename "pxelinux.0";
       }  
}
EOF
done



##判断dhcp服务起来没有#############
systemctl restart dhcpd>/dev/null  
systemctl enable xinetd>/dev/null
systemctl status dhcpd>/dev/null
if [ $? -eq 0 ];then
	echo -e "  dhcp服务    \033[32m 启动成功 \033[0m    "
else
	echo -e "  dhcp服务    \033[31m 启动失败 \033[0m    "
fi

#####设置xinetd服务#################
sed -i 's/^.*disable.*$/disable=no/g'   /etc/xinetd.d/tftp
grep 'disable=no' /etc/xinetd.d/tftp>/dev/null
if [ $? -eq 0 ];then
	echo -e "  xintd服务   \033[32m 设置成功 \033[0m    "
else
	echo -e "  xinetd服务    \033[31m 设置失败 \033[0m    "
fi
systemctl restart xinetd>/dev/null
systemctl enable xinetd>/dev/null
systemctl status xinetd>/dev/null
if [ $? -eq 0 ];then
        echo -e "xinetd服务    \033[32m 启动成功 \033[0m    "
else
        echo -e "xinetd服务    \033[31m 启动失败 \033[0m    "
fi





mkdir -p /var/lib/tftpboot/pxelinux.cfg
cat>/var/lib/tftpboot/pxelinux.cfg/default<<EOF
default vesamenu.c32
timeout 20
display boot.msg
menu clear
menu background splash.png
menu title install  linux  by summer  
menu vshift 8
menu rows 18
menu margin 8
menu helpmsgrow 15
menu tabmsgrow 13
EOF

cat>/var/lib/tftpboot/grub.cfg<<EOF
set default="0"
function load_video {
  insmod efi_gop
  insmod efi_uga
  insmod video_bochs
  insmod video_cirrus
  insmod all_video
}
load_video
set gfxpayload=keep
insmod gzio
insmod part_gpt
insmod ext2
set timeout=20
search --no-floppy --set=root -l 'BCLinux 7 x86_64'
EOF


############## 设置legacy 和 uefi 启动文件
sys=()
n=1
for file in `ls /mnt`
do
if [ -d "/mnt/$file" ];then
    if [ -d "/mnt/$file/isolinux" ];then
	sys[$n]=$file
	n=$[$n+1]
        mkdir -p /var/lib/tftpboot/$file
        cp /usr/share/syslinux/pxelinux.0  /var/lib/tftpboot
        cp /mnt/$file/images/pxeboot/{vmlinuz,initrd.img} /var/lib/tftpboot/$file
        cp /mnt/$file/isolinux/{vesamenu.c32,boot.msg} /var/lib/tftpboot
        cp /mnt/$file/EFI/BOOT/grubx64.efi /var/lib/tftpboot
	cp /mnt/$file/EFI/BOOT/BOOTX64.EFI /var/lib/tftpboot/bootx64.efi
####legacy启动菜单
        echo "label $file
menu label ^Install $file 
kernel $file/vmlinuz
append initrd=$file/initrd.img inst.stage2=ftp://$ip/$file ks=ftp://$ip/pub/$file.cfg quiet">>/var/lib/tftpboot/pxelinux.cfg/default
#####efi启动菜单
	echo "menuentry 'Install $file' --class fedora --class gnu-linux --class gnu --class os {
  linuxefi  (tftp)/$file/vmlinuz inst.repo=ftp://$ip/$file ks=ftp://$ip/pub/$file.cfg  ip=dhcp    
  initrdefi (tftp)/$file/initrd.img
}" >>/var/lib/tftpboot/grub.cfg
    fi
fi
done
n=1
echo '/mnt目录下有如下系统：'
for i in ${sys[*]}
do
echo $n.$i
n=$[$n+1]
done
read -p "请设置默认安装系统（1、2、3等）:"  m
s="${sys[$m]}"
sed -i "/$s\/vmlinuz/i\\menu default"  /var/lib/tftpboot/pxelinux.cfg/default
m=$[$m-1]
sed -i "1c set default=$m"  /var/lib/tftpboot/grub.cfg





echo -e "\033[32m 引导文件已成功复制到tftp目录下 \033[0m    "


systemctl restart tftp>/dev/null
systemctl enable tftp>/dev/null
systemctl status  tftp>/dev/null
if [ $? -eq 0 ];then
        echo -e "  tftp服务    \033[32m 启动成功 \033[0m    "
else
        echo -e "  tftp服务    \033[31m 启动失败 \033[0m    "
fi








############################复制镜像到ftp目录下##############################

	nohup cp -rn /mnt/* /var/ftp/>/dev/null 2>&1 &  
	sleep 3
	while :
	do
		ps -ef |grep 'cp -r' |grep -v 'grep'>/dev/mull
		if [ $? -eq 0 ];then
			echo -ne '\r'
			echo -ne '--正                                      \r'
			#sleep 1
			echo -ne '----正在                                  \r'
			sleep 1
			echo -ne '------正在复                              \r'
			#sleep 1
			echo -ne '--------正在复制                          \r'
			sleep 1
			echo -ne '----------正在复制镜                      \r'
			#sleep 1
			echo -ne '------------正在复制镜像                  \r'
			sleep 1
			echo -ne '--------------正在复制镜像到              \r'
			#sleep 1
			echo -ne '----------------正在复制镜像到ftp录       \r'
			sleep 1
			echo -ne '------------------正在复制镜像到ftp目录   \r'
			sleep 1
			echo -ne '                                          \r'
		else 
			break
		fi	
	done	
        	echo -e "\033[32m 镜像文件已成功复制到ftp目录下 \033[0m    "


systemctl restart vsftpd>/dev/null
systemctl enable vsftpd>/dev/null
systemctl status  vsftpd>/dev/null
if [ $? -eq 0 ];then
        echo -e "   ftp服务    \033[32m 启动成功 \033[0m    "
else
        echo -e "   ftp服务    \033[31m 启动失败 \033[0m    "
fi



#################################设置应答文件###################

if [ ! -d "/var/ftp/pub" ]; then
  mkdir -p /var/ftp/pub
fi
cp /root/info /var/ftp/pub/info
cp /root/init.py /var/ftp/pub/

for i in ${sys[*]}
do
cp /root/anaconda-ks.cfg /var/ftp/pub/$i.cfg
chmod +r /var/ftp/pub/$i.cfg
sed -i "s/cdrom/url --url=ftp:\/\/$ip\/$i/g" /var/ftp/pub/$i.cfg
sed -i "s/# System timezone/reboot/g" /var/ftp/pub/$i.cfg
sed -i "s/--none/--all/g" /var/ftp/pub/$i.cfg
sed -i "s/^graphical.*$/text/g" /var/ftp/pub/$i.cfg
done


echo -e "  应答文件    \033[32m 设置成功 \033[0m    "



####################################检查所有服务是否启动成功#############################
echo "-----------------检查所有服务是否启动----------------"
for i in {'dhcpd','xinetd','tftp','vsftpd'}
do
        systemctl status $i>/dev/null
        if [ $? -eq 0 ];then
                echo -e "      $i    \033[32m 启动成功 \033[0m    "
        else
                echo -e "      $i   \033[31m  启动失败 \033[0m    "
        fi
done
systemctl stop firewalld>/dev/null
setenforce 0
chmod -R  755  /var/ftp
chmod -R  755  /var/lib/tftpboot
echo -e "      防火墙    \033[32m 关闭成功 \033[0m "    
echo "-------------------pxe服务端部署完成-----------------"

