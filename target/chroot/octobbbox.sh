#!/bin/sh -e
#
# Copyright (c) 2014-2016 Robert Nelson <robertcnelson@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

export LC_ALL=C

u_boot_release="v2017.07"
u_boot_release_x15="ti-2017.01"

#contains: rfs_username, release_date
if [ -f /etc/rcn-ee.conf ] ; then
	. /etc/rcn-ee.conf
fi

if [ -f /etc/oib.project ] ; then
	. /etc/oib.project
fi

export HOME=/home/${rfs_username}
export USER=${rfs_username}
export USERNAME=${rfs_username}

echo "env: [`env`]"

is_this_qemu () {
	unset warn_qemu_will_fail
	if [ -f /usr/bin/qemu-arm-static ] ; then
		warn_qemu_will_fail=1
	fi
}

qemu_warning () {
	if [ "${warn_qemu_will_fail}" ] ; then
		echo "Log: (chroot) Warning, qemu can fail here... (run on real armv7l hardware for production images)"
		echo "Log: (chroot): [${qemu_command}]"
	fi
}

git_clone () {
	mkdir -p ${git_target_dir} || true
	qemu_command="git clone ${git_repo} ${git_target_dir} --depth 1 || true"
	qemu_warning
	git clone ${git_repo} ${git_target_dir} --depth 1 || true
	sync
	echo "${git_target_dir} : ${git_repo}" >> /opt/source/list.txt
}

git_clone_branch () {
	mkdir -p ${git_target_dir} || true
	qemu_command="git clone -b ${git_branch} ${git_repo} ${git_target_dir} --depth 1 || true"
	qemu_warning
	git clone -b ${git_branch} ${git_repo} ${git_target_dir} --depth 1 || true
	sync
	echo "${git_target_dir} : ${git_repo}" >> /opt/source/list.txt
}

git_clone_full () {
	mkdir -p ${git_target_dir} || true
	qemu_command="git clone ${git_repo} ${git_target_dir} || true"
	qemu_warning
	git clone ${git_repo} ${git_target_dir} || true
	sync
	echo "${git_target_dir} : ${git_repo}" >> /opt/source/list.txt
}

setup_system () {
	#For when sed/grep/etc just gets way to complex...
	cd /
	if [ -f /opt/scripts/mods/debian-add-sbin-usr-sbin-to-default-path.diff ] ; then
		if [ -f /usr/bin/patch ] ; then
			echo "Patching: /etc/profile"
			patch -p1 < /opt/scripts/mods/debian-add-sbin-usr-sbin-to-default-path.diff
		fi
	fi

	echo "" >> /etc/securetty
	echo "#USB Gadget Serial Port" >> /etc/securetty
	echo "ttyGS0" >> /etc/securetty
}


install_pip_pkgs () {
	if [ -f /usr/bin/python ] ; then
		wget https://bootstrap.pypa.io/get-pip.py || true
		if [ -f get-pip.py ] ; then
			python get-pip.py
			rm -f get-pip.py || true

			if [ -f /usr/local/bin/pip ] ; then
				echo "Installing pip packages"
				git_repo="https://github.com/adafruit/adafruit-beaglebone-io-python.git"
				git_target_dir="/opt/source/adafruit-beaglebone-io-python"
				git_clone
				if [ -f ${git_target_dir}/.git/config ] ; then
					cd ${git_target_dir}/
					sed -i -e 's:4.1.0:3.4.0:g' setup.py
					python setup.py install
				fi
				pip install iw_parse
				git_repo="https://github.com/foosel/OctoPrint.git"
				git_target_dir="/opt/source/OctoPrint"
				git_clone
				if [ -f ${git_target_dir}/.git/config ] ; then
					cd ${git_target_dir}/
					pip install -r requirements.txt
					python setup.py install
				fi
				git_repo="https://github.com/foosel/netconnectd.git"
				git_target_dir="/opt/source/netconnectd"
				git_clone
				if [ -f ${git_target_dir}/.git/config ] ; then
					cd ${git_target_dir}/
					python setup.py install
				fi
			fi
		fi
	fi
}

install_git_repos () {
	git_repo="https://github.com/strahlex/BBIOConfig.git"
	git_target_dir="/opt/source/BBIOConfig"
	git_clone

	git_repo="https://github.com/RobertCNelson/dtb-rebuilder.git"
	git_target_dir="/opt/source/dtb-4.4-ti"
	git_branch="4.4-ti"
	git_clone_branch

	git_repo="https://github.com/RobertCNelson/dtb-rebuilder.git"
	git_target_dir="/opt/source/dtb-4.9-ti"
	git_branch="4.9-ti"
	git_clone_branch

	git_repo="https://github.com/beagleboard/bb.org-overlays"
	git_target_dir="/opt/source/bb.org-overlays"
	git_clone
}

install_build_pkgs () {
	cd /opt/
	cd /
}

other_source_links () {
	rcn_https="https://rcn-ee.com/repos/git/u-boot-patches"

	mkdir -p /opt/source/u-boot_${u_boot_release}/
	wget --directory-prefix="/opt/source/u-boot_${u_boot_release}/" ${rcn_https}/${u_boot_release}/0001-omap3_beagle-uEnv.txt-bootz-n-fixes.patch
	wget --directory-prefix="/opt/source/u-boot_${u_boot_release}/" ${rcn_https}/${u_boot_release}/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch
	wget --directory-prefix="/opt/source/u-boot_${u_boot_release}/" ${rcn_https}/${u_boot_release}/0002-U-Boot-BeagleBone-Cape-Manager.patch
	mkdir -p /opt/source/u-boot_${u_boot_release_x15}/
	wget --directory-prefix="/opt/source/u-boot_${u_boot_release_x15}/" ${rcn_https}/${u_boot_release_x15}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch

	echo "u-boot_${u_boot_release} : /opt/source/u-boot_${u_boot_release}" >> /opt/source/list.txt
	echo "u-boot_${u_boot_release_x15} : /opt/source/u-boot_${u_boot_release_x15}" >> /opt/source/list.txt

	chown -R ${rfs_username}:${rfs_username} /opt/source/
}

unsecure_root () {
	root_password=$(cat /etc/shadow | grep root | awk -F ':' '{print $2}')
	sed -i -e 's:'$root_password'::g' /etc/shadow

	if [ -f /etc/ssh/sshd_config ] ; then
		#Make ssh root@beaglebone work..
		sed -i -e 's:PermitEmptyPasswords no:PermitEmptyPasswords yes:g' /etc/ssh/sshd_config
		sed -i -e 's:UsePAM yes:UsePAM no:g' /etc/ssh/sshd_config
		#Starting with Jessie:
		sed -i -e 's:PermitRootLogin without-password:PermitRootLogin yes:g' /etc/ssh/sshd_config
	fi

	if [ -f /etc/sudoers ] ; then
		#Don't require password for sudo access
		echo "${rfs_username}  ALL=NOPASSWD: ALL" >>/etc/sudoers
	fi
}

is_this_qemu

setup_system
#setup_desktop


#install_pip_pkgs
if [ -f /usr/bin/git ] ; then
	git config --global user.email "${rfs_username}@example.com"
	git config --global user.name "${rfs_username}"
	install_git_repos
	git config --global --unset-all user.email
	git config --global --unset-all user.name
fi
#install_build_pkgs
#other_source_links
#unsecure_root