#!/bin/sh

apache2ctl -D Testing -f $PWD/system/etc/apache2/apache2.conf -k $@
./system/etc/init.d/apache2-backend $@
