# pxe
一键部署centos7 pxe无人值守自动批量安装系统脚本

脚本作用：
  在centos7上 一键自动部署pxe服务，支持uefi、legacy启动方式引导自动安装系统
  
使用脚本前置条件：
  1.确保yum可用，可以yum安装dhcp、tftp、xinetd、vsftpd、syslinux、tcpdump等基本服务
  2.将iso镜像挂载到/mnt目录下  mount  /dev/sr0  /mnt
  
 脚本效果：
  脚本会自动安装服务，以部署服务机器的应答文件为模板，即批量安装系统的服务器分区信息、root密码、时区均和服务端相同
  
 测试案例：
  vmware centos7.7测试ok
  华为服务器5288 v3   实战批量安装128台
  hp服务器（型号忘了） 实战批量安装96台
  浪潮服务器          实战批量安装47台
  
  待安装服务器：
  华为服务器5288 v5
  曙光服务器
