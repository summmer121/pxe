# pxe
一键部署centos7 pxe无人值守自动批量安装系统脚本

脚本作用：
  在centos7上 一键自动部署pxe服务，支持uefi、legacy启动方式引导自动安装系统
  
使用脚本前置条件：
  1.确保yum可用，可以yum安装dhcp、tftp、xinetd、vsftpd、syslinux、tcpdump等基本服务
  2.在/mnt目录下以系统名创建目录，比如/mnt/centos7
  3.挂载不通系统到不同目录mount  /dev/sr0  /mnt/centos7,mount /dev/sr1 /mnt/centos6
  
 脚本效果：
  脚本会自动安装服务，以部署服务机器的应答文件为模板，即批量安装系统的服务器分区信息、root密码、时区均和服务端相同
  
 
