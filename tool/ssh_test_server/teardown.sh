#!/bin/sh
# Menghapus semua jejak server uji: proses sshd uji, konfigurasi, host key lain, user, dan kunci uji.
U=termul_t
for f in /run/termul_test_*.pid; do
  [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null
  rm -f "$f"
done
pkill -u $U 2>/dev/null
sleep 1
userdel -r $U 2>&1 | grep -v "mail spool" || true
rm -f /etc/ssh/termul_test_*.conf
rm -rf /etc/ssh/termul_alt /tmp/termul_keys
echo "--- verifikasi"
id $U 2>&1
ls /etc/ssh | grep termul || echo "tidak ada berkas termul di /etc/ssh"
ls /home | grep $U || echo "tidak ada home $U"
getent group $U || echo "grup $U: tidak ada"
pgrep -af "termul_test" || echo "tidak ada sshd uji berjalan"
