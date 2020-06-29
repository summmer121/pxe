#/bin/bash
#############################

echo "##############################################"
echo "##      一键部署pxe脚本 使用注意事项       ###"
echo "##        1：确保本地yum源设置ok           ###"
echo "##        2：将镜像挂载到/mnt目录下        ###"
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
echo $i

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



###############设置syslinux服务###########
cp /usr/share/syslinux/pxelinux.0  /var/lib/tftpboot
cp /mnt/images/pxeboot/{vmlinuz,initrd.img} /var/lib/tftpboot
cp /mnt/isolinux/{vesamenu.c32,boot.msg} /var/lib/tftpboot
cp /mnt/EFI/BOOT/BOOTX64.EFI       /var/lib/tftpboot/bootx64.efi
cp /mnt/EFI/BOOT/grub.cfg               /var/lib/tftpboot/grub.cfg  
cp /mnt/EFI/BOOT/grubx64.efi       /var/lib/tftpboot/grubx64.efi
mkdir -p /var/lib/tftpboot/pxelinux.cfg
cp /mnt/isolinux/isolinux.cfg /var/lib/tftpboot/pxelinux.cfg/default

num=$(ls /var/lib/tftpboot |wc -l)
if [ $num -gt 6 ];then
        echo -e "\033[32m 引导文件已成功复制到tftp目录下 \033[0m    "
else
        echo -e "\033[31m 引导文件复制到tftp目录失败 \033[0m    "
fi

systemctl restart tftp>/dev/null
systemctl enable tftp>/dev/null
systemctl status  tftp>/dev/null
if [ $? -eq 0 ];then
        echo -e "  tftp服务    \033[32m 启动成功 \033[0m    "
else
        echo -e "  tftp服务    \033[31m 启动失败 \033[0m    "
fi

#######bios启动  修改pxelinux.cfg文件 ################
sed -i '1c default linux' /var/lib/tftpboot/pxelinux.cfg/default
sed -i '2c timeout 5' /var/lib/tftpboot/pxelinux.cfg/default
sed  -i "0,/^.*append.*$/s// append initrd=initrd.img inst.stage2=ftp:\/\/$ip ks=ftp:\/\/$ip\/pub\/ks.cfg quiet  /" /var/lib/tftpboot/pxelinux.cfg/default

grep "$ip" /var/lib/tftpboot/pxelinux.cfg/default>/dev/null
if [ $? -eq 0 ];then
        echo -e "  bios引导文件   \033[32m 设置成功 \033[0m    "
else
        echo -e "  bios引导文件    \033[31m 设置失败 \033[0m    "
fi




#######uefi启动  修改grub.cfg文件
sed  -i 's/default="1"/default="0"/g' /var/lib/tftpboot/grub.cfg
sed  -i 's/timeout=60/timeout=5/g' /var/lib/tftpboot/grub.cfg
sed  -i  "0,/^.*linuxefi.*$/s//   linuxefi  (tftp)\/vmlinuz inst.repo=ftp:\/\/$ip ks=ftp:\/\/$ip\/pub\/ks.cfg  ip=dhcp    /" /var/lib/tftpboot/grub.cfg
sed  -i "0,/^.*initrdefi.*$/s//  initrdefi (tftp)\/initrd.img   /" /var/lib/tftpboot/grub.cfg

grep '(tftp)/initrd.img ' /var/lib/tftpboot/grub.cfg>/dev/null
if [ $? -eq 0 ];then
        echo -e "  uefi引导文件   \033[32m 设置成功 \033[0m    "
else
        echo -e "  uefi引导文件    \033[31m 设置失败 \033[0m    "
fi


############################复制镜像到ftp目录下##############################
ftp_num=$(ls /var/ftp |wc -l)
if [ $ftp_num -gt 4 ];then
        echo -e "\033[32m 镜像文件已成功复制到ftp目录下 \033[0m    "
else
	nohup cp -r /mnt/* /var/ftp/>/dev/null 2>&1 &  
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

	



	ftp_num=$(ls /var/ftp |wc -l)
        if [ $ftp_num -gt 4 ];then
        	echo -e "\033[32m 镜像文件已成功复制到ftp目录下 \033[0m    "
	else
        	echo -e "\033[31m 镜像文件复制到ftp目录失败 \033[0m    "
	fi
fi

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
cp /root/network.sh /var/ftp/pub/
cp /root/anaconda-ks.cfg /var/ftp/pub/ks.cfg
chmod +r /var/ftp/pub/ks.cfg
sed -i "s/cdrom/url --url=ftp:\/\/$ip/g" /var/ftp/pub/ks.cfg
sed -i "s/# System timezone/reboot/g" /var/ftp/pub/ks.cfg
sed -i "s/--none/--all/g" /var/ftp/pub/ks.cfg
sed -i "s/^graphical.*$/text/g" /var/ftp/pub/ks.cfg

grep 'reboot' /var/ftp/pub/ks.cfg >/dev/null
if [ $? -eq 0 ];then
        echo -e "  应答文件    \033[32m 设置成功 \033[0m    "
else
        echo -e "  应答文件    \033[31m 设置失败 \033[0m    "
fi


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
chmod -R  +r  /var
echo -e "      防火墙    \033[32m 关闭成功 \033[0m "    
echo "-------------------pxe服务端部署完成-----------------"




